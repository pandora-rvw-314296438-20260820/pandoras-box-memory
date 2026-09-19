-- Additive Pandora-native Memory bridge identity and search surface.
-- Historical migration files remain intact for replay integrity.

insert into public.pandora_service_principals (
  principal_key, provider, issuer, audience, subject, owner_id, project_id,
  project_name, environment, memory_user_id, allowed_namespaces, scopes, is_active
)
select
  'pandora-mcpmaster-production', provider, issuer, audience, subject, owner_id, project_id,
  project_name, environment, memory_user_id, allowed_namespaces, scopes, is_active
from public.pandora_service_principals
where principal_key = concat('project', 'os-mcpmaster-production')
on conflict (principal_key) do update set
  provider = excluded.provider,
  issuer = excluded.issuer,
  audience = excluded.audience,
  subject = excluded.subject,
  owner_id = excluded.owner_id,
  project_id = excluded.project_id,
  project_name = excluded.project_name,
  environment = excluded.environment,
  memory_user_id = excluded.memory_user_id,
  allowed_namespaces = excluded.allowed_namespaces,
  scopes = excluded.scopes,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.pandora_project_grants (
  principal_key, project_id, environment, allowed_record_types,
  can_read, can_propose, can_approve, is_active, revoked_at, revocation_reason
)
select
  'pandora-mcpmaster-production', project_id, environment, allowed_record_types,
  can_read, can_propose, can_approve, is_active, revoked_at, revocation_reason
from public.pandora_project_grants
where principal_key = concat('project', 'os-mcpmaster-production')
on conflict (principal_key, project_id, environment) do update set
  allowed_record_types = excluded.allowed_record_types,
  can_read = excluded.can_read,
  can_propose = excluded.can_propose,
  can_approve = excluded.can_approve,
  is_active = excluded.is_active,
  revoked_at = excluded.revoked_at,
  revocation_reason = excluded.revocation_reason,
  updated_at = now();

create or replace function public.memory_pandora_search_scoped_v1(
  p_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_principal_key text,
  p_environment text,
  p_terms text[],
  p_canon_statuses text[],
  p_limit integer default 12
)
returns table(
  id uuid,
  project_id uuid,
  title text,
  body text,
  confidence numeric,
  source_summary text,
  created_at timestamptz,
  updated_at timestamptz,
  canon_status text,
  memory_type text,
  strength text,
  metadata jsonb,
  record_type text
)
language plpgsql
stable
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_limit integer := least(greatest(coalesce(p_limit,12),1),50);
  v_allowed text[];
  v_tsquery tsquery;
  v_term_query tsquery;
  v_term text;
begin
  if p_user_id is null
     or p_project_id is null
     or btrim(coalesce(p_principal_key,'')) = ''
     or btrim(coalesce(p_environment,'')) = ''
     or p_namespace not in ('real_life','au')
  then
    raise exception 'memory_pandora_search_invalid_request' using errcode='22023';
  end if;

  if coalesce(cardinality(p_canon_statuses),0) = 0
     or exists (
       select 1
       from unnest(p_canon_statuses) as s(status)
       where status not in ('hard_canon','soft_canon')
     )
  then
    raise exception 'memory_pandora_search_invalid_canon' using errcode='22023';
  end if;

  select g.allowed_record_types
    into v_allowed
  from public.pandora_project_grants g
  join public.pandora_projects p
    on p.id = g.project_id
   and p.id = p_project_id
   and p.memory_namespace::text = p_namespace
   and p.lifecycle_status = 'active'
  where g.principal_key = p_principal_key
    and g.project_id = p_project_id
    and g.environment = p_environment
    and g.is_active = true
    and g.can_read = true
    and g.revoked_at is null
  limit 1;

  if not found or coalesce(cardinality(v_allowed),0) = 0 then
    raise exception 'project_not_allowed' using errcode='42501';
  end if;

  foreach v_term in array coalesce(p_terms,'{}'::text[])
  loop
    v_term := btrim(left(v_term,64));
    if length(v_term) < 3 then
      continue;
    end if;
    v_term_query := plainto_tsquery('simple', v_term);
    if numnode(v_term_query) = 0 then
      continue;
    end if;
    v_tsquery := case
      when v_tsquery is null then v_term_query
      else v_tsquery || v_term_query
    end;
  end loop;

  return query
  select
    m.id,
    m.project_id,
    m.title,
    m.body,
    m.confidence,
    m.source_summary,
    m.created_at,
    m.updated_at,
    m.canon_status::text,
    m.memory_type::text,
    m.strength::text,
    m.metadata,
    m.record_type
  from public.memory_items m
  where m.user_id = p_user_id
    and m.namespace::text = p_namespace
    and m.project_id = p_project_id
    and m.is_active = true
    and m.approved_by is not null
    and m.approved_at is not null
    and m.superseded_at is null
    and m.revoked_at is null
    and m.record_type = any(v_allowed)
    and m.canon_status in (
      'hard_canon'::public.canon_status,
      'soft_canon'::public.canon_status
    )
    and m.canon_status::text = any(p_canon_statuses)
    and (
      v_tsquery is null
      or to_tsvector(
        'simple',
        coalesce(m.title,'') || ' ' || coalesce(m.body,'')
      ) @@ v_tsquery
    )
  order by
    case
      when v_tsquery is null then 0::real
      else ts_rank_cd(
        to_tsvector(
          'simple',
          coalesce(m.title,'') || ' ' || coalesce(m.body,'')
        ),
        v_tsquery
      )::real
    end desc,
    m.updated_at desc,
    m.id
  limit v_limit;
end
$function$;

revoke all on function public.memory_pandora_search_scoped_v1(
  uuid,text,uuid,text,text,text[],text[],integer
) from public;
grant execute on function public.memory_pandora_search_scoped_v1(
  uuid,text,uuid,text,text,text[],text[],integer
) to service_role;
