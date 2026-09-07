-- Indexed exact-project ProjectOS Memory search v1.
-- Preserves the existing ProjectOS grant, approval, canon, current-head,
-- environment, project and user boundaries while replacing wildcard ILIKE
-- scans with PostgreSQL full-text search.

begin;

create index if not exists memory_items_projectos_approved_search_fts_idx
on public.memory_items
using gin (
  to_tsvector(
    'simple',
    coalesce(title,'') || ' ' || coalesce(body,'')
  )
)
where is_active = true
  and approved_by is not null
  and approved_at is not null
  and superseded_at is null
  and revoked_at is null
  and canon_status in (
    'hard_canon'::public.canon_status,
    'soft_canon'::public.canon_status
  );

create or replace function public.memory_projectos_search_scoped_v1(
  p_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_principal_key text,
  p_environment text,
  p_terms text[],
  p_canon_statuses text[],
  p_limit integer default 12
)
returns table (
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
set search_path = pg_catalog, public
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
    raise exception 'memory_projectos_search_invalid_request' using errcode='22023';
  end if;

  if coalesce(cardinality(p_canon_statuses),0) = 0
     or exists (
       select 1
       from unnest(p_canon_statuses) as s(status)
       where status not in ('hard_canon','soft_canon')
     )
  then
    raise exception 'memory_projectos_search_invalid_canon' using errcode='22023';
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

comment on function public.memory_projectos_search_scoped_v1(
  uuid,text,uuid,text,text,text[],text[],integer
) is
  'Indexed ProjectOS Memory retrieval with exact project/environment/read-grant/user/approved-canon/current-head/record-type enforcement.';

revoke all on function public.memory_projectos_search_scoped_v1(
  uuid,text,uuid,text,text,text[],text[],integer
) from public, anon, authenticated;
grant execute on function public.memory_projectos_search_scoped_v1(
  uuid,text,uuid,text,text,text[],text[],integer
) to service_role;

commit;
