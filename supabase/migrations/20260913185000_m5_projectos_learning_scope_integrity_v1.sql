-- R-042 / M5 prerequisite: bind ProjectOS learning to governed Memory project scope.
-- Additive only: no legacy row updates, no backfill, no canonical promotion, no deployment.
-- New ProjectOS learning candidates must resolve an active Memory project and active
-- production can_propose grant before they enter review. New review rows receive
-- immutable candidate/project lineage. Canonical inserts fail closed for legacy or
-- mismatched ProjectOS review lineage.

create or replace function public.memory_bind_projectos_learning_scope_v1()
returns trigger
language plpgsql
security invoker
set search_path='pg_catalog','public'
as $function$
declare
  v_source_key text;
  v_metadata_project_id uuid;
  v_project_id uuid;
  v_project_key text;
  v_match_count integer := 0;
  v_grant_count integer := 0;
begin
  if new.source not in ('projectos-post-task','projectos-visible-creation')
     or new.requires_review is not true
     or new.status is distinct from 'pending' then
    return new;
  end if;

  if new.user_id is null
     or new.namespace is null
     or nullif(trim(new.source_ref),'') is null then
    raise exception 'ProjectOS learning candidate requires exact user/namespace/source lineage'
      using errcode='23514';
  end if;

  v_source_key := nullif(trim(new.metadata->>'project_key'),'');
  begin
    v_metadata_project_id := nullif(trim(new.metadata->>'project_id'),'')::uuid;
  exception when others then
    v_metadata_project_id := null;
  end;

  if new.project_id is not null then
    select p.id,p.project_key
      into v_project_id,v_project_key
    from public.pandora_projects p
    where p.id=new.project_id
      and p.lifecycle_status='active'
      and p.memory_namespace=new.namespace::text;

    if not found then
      raise exception 'ProjectOS learning project scope is inactive or namespace-mismatched'
        using errcode='23514';
    end if;

    if v_source_key is not null and not exists (
      select 1
      from public.pandora_projects p
      where p.id=v_project_id
        and (
          p.project_key=v_source_key
          or v_source_key=any(coalesce(p.aliases,'{}'::text[]))
        )
    ) then
      raise exception 'ProjectOS learning relational project does not match canonical key/alias'
        using errcode='23514';
    end if;
  else
    if v_metadata_project_id is not null then
      select count(*)::integer
        into v_match_count
      from public.pandora_projects p
      where p.id=v_metadata_project_id
        and p.lifecycle_status='active'
        and p.memory_namespace=new.namespace::text
        and (
          v_source_key is null
          or p.project_key=v_source_key
          or v_source_key=any(coalesce(p.aliases,'{}'::text[]))
        );

      if v_match_count=1 then
        select p.id,p.project_key
          into v_project_id,v_project_key
        from public.pandora_projects p
        where p.id=v_metadata_project_id;
      end if;
    end if;

    if v_project_id is null then
      if v_source_key is null then
        raise exception 'ProjectOS learning project scope is unresolved'
          using errcode='23514';
      end if;

      select count(*)::integer
        into v_match_count
      from public.pandora_projects p
      where p.lifecycle_status='active'
        and p.memory_namespace=new.namespace::text
        and (
          p.project_key=v_source_key
          or v_source_key=any(coalesce(p.aliases,'{}'::text[]))
        );

      if v_match_count<>1 then
        raise exception 'ProjectOS learning project scope must resolve uniquely'
          using errcode='23514';
      end if;

      select p.id,p.project_key
        into v_project_id,v_project_key
      from public.pandora_projects p
      where p.lifecycle_status='active'
        and p.memory_namespace=new.namespace::text
        and (
          p.project_key=v_source_key
          or v_source_key=any(coalesce(p.aliases,'{}'::text[]))
        );
    end if;
  end if;

  select count(*)::integer
    into v_grant_count
  from public.pandora_project_grants g
  where g.principal_key='projectos-mcpmaster-production'
    and g.project_id=v_project_id
    and g.environment='production'
    and g.is_active is true
    and g.can_propose is true
    and g.revoked_at is null;

  if v_grant_count<>1 then
    raise exception 'ProjectOS learning project lacks active can_propose grant'
      using errcode='23514';
  end if;

  new.project_id:=v_project_id;
  new.metadata:=coalesce(new.metadata,'{}'::jsonb)||jsonb_build_object(
    'memory_project_id',v_project_id,
    'memory_project_key',v_project_key,
    'memory_project_resolution','canonical_or_alias_v1'
  );
  return new;
end;
$function$;

drop trigger if exists trg_memory_bind_projectos_learning_scope_v1
  on public.memory_capture_candidates;
create trigger trg_memory_bind_projectos_learning_scope_v1
before insert on public.memory_capture_candidates
for each row execute function public.memory_bind_projectos_learning_scope_v1();

create or replace function public.memory_bind_projectos_review_lineage_v1()
returns trigger
language plpgsql
security invoker
set search_path='pg_catalog','public'
as $function$
declare
  v_source text;
  v_candidate_id uuid;
  v_project_id uuid;
  v_project_key text;
  v_candidate_count integer := 0;
  v_existing_candidate_id uuid;
  v_existing_project_id uuid;
  v_grant_count integer := 0;
begin
  if new.candidate_type is distinct from 'projectos_outcome' then
    return new;
  end if;

  v_source:=nullif(trim(new.source_metadata->>'source'),'');
  if v_source is not null
     and v_source not in ('projectos-post-task','projectos-visible-creation') then
    raise exception 'Unsupported ProjectOS review source'
      using errcode='23514';
  end if;

  select count(*)::integer
    into v_candidate_count
  from public.memory_capture_candidates c
  where c.user_id=new.user_id
    and c.namespace::text=new.namespace::text
    and c.source_ref=new.source_ref
    and c.source in ('projectos-post-task','projectos-visible-creation')
    and (v_source is null or c.source=v_source);

  if v_candidate_count<>1 then
    raise exception 'ProjectOS review must bind exactly one capture candidate'
      using errcode='23514';
  end if;

  select c.id,c.project_id,p.project_key,c.source
    into v_candidate_id,v_project_id,v_project_key,v_source
  from public.memory_capture_candidates c
  join public.pandora_projects p
    on p.id=c.project_id
   and p.lifecycle_status='active'
   and p.memory_namespace=c.namespace::text
  where c.user_id=new.user_id
    and c.namespace::text=new.namespace::text
    and c.source_ref=new.source_ref
    and c.source in ('projectos-post-task','projectos-visible-creation')
    and (v_source is null or c.source=v_source);

  if v_candidate_id is null or v_project_id is null then
    raise exception 'ProjectOS review candidate lacks governed project scope'
      using errcode='23514';
  end if;

  begin
    v_existing_candidate_id:=nullif(trim(new.source_metadata->>'candidateId'),'')::uuid;
  exception when others then
    raise exception 'Invalid ProjectOS candidateId lineage'
      using errcode='23514';
  end;
  begin
    v_existing_project_id:=nullif(trim(new.source_metadata->>'projectId'),'')::uuid;
  exception when others then
    raise exception 'Invalid ProjectOS projectId lineage'
      using errcode='23514';
  end;

  if v_existing_candidate_id is not null and v_existing_candidate_id<>v_candidate_id then
    raise exception 'ProjectOS review candidateId lineage mismatch'
      using errcode='23514';
  end if;
  if v_existing_project_id is not null and v_existing_project_id<>v_project_id then
    raise exception 'ProjectOS review projectId lineage mismatch'
      using errcode='23514';
  end if;

  select count(*)::integer
    into v_grant_count
  from public.pandora_project_grants g
  where g.principal_key='projectos-mcpmaster-production'
    and g.project_id=v_project_id
    and g.environment='production'
    and g.is_active is true
    and g.can_propose is true
    and g.revoked_at is null;

  if v_grant_count<>1 then
    raise exception 'ProjectOS review project lacks active can_propose grant'
      using errcode='23514';
  end if;

  new.source_metadata:=coalesce(new.source_metadata,'{}'::jsonb)||jsonb_build_object(
    'source',v_source,
    'candidateId',v_candidate_id,
    'projectId',v_project_id,
    'memoryProjectKey',v_project_key,
    'lineageBinding','m5_projectos_scope_integrity_v1'
  );
  new.evidence_snapshot:=coalesce(new.evidence_snapshot,'{}'::jsonb)||jsonb_build_object(
    'candidateId',v_candidate_id,
    'projectId',v_project_id
  );
  new.audit_metadata:=coalesce(new.audit_metadata,'{}'::jsonb)||jsonb_build_object(
    'candidateId',v_candidate_id,
    'projectId',v_project_id,
    'lineageBinding','m5_projectos_scope_integrity_v1'
  );
  return new;
end;
$function$;

drop trigger if exists trg_memory_bind_projectos_review_lineage_v1
  on public.memory_review_queue_items;
create trigger trg_memory_bind_projectos_review_lineage_v1
before insert on public.memory_review_queue_items
for each row execute function public.memory_bind_projectos_review_lineage_v1();

create or replace function public.memory_guard_projectos_canonical_lineage_v1()
returns trigger
language plpgsql
security invoker
set search_path='pg_catalog','public'
as $function$
declare
  v_review_id uuid;
  v_review public.memory_review_queue_items%rowtype;
  v_candidate_id uuid;
  v_project_id uuid;
  v_grant_count integer := 0;
begin
  begin
    v_review_id:=nullif(trim(new.metadata->>'reviewItemId'),'')::uuid;
  exception when others then
    raise exception 'Invalid reviewItemId lineage'
      using errcode='23514';
  end;

  if v_review_id is null then
    return new;
  end if;

  select *
    into v_review
  from public.memory_review_queue_items r
  where r.id=v_review_id
    and r.user_id=new.user_id
    and r.namespace::text=new.namespace::text;

  if not found or v_review.candidate_type is distinct from 'projectos_outcome' then
    return new;
  end if;

  begin
    v_candidate_id:=nullif(trim(v_review.source_metadata->>'candidateId'),'')::uuid;
    v_project_id:=nullif(trim(v_review.source_metadata->>'projectId'),'')::uuid;
  exception when others then
    raise exception 'Invalid ProjectOS canonical lineage metadata'
      using errcode='23514';
  end;

  if v_candidate_id is null or v_project_id is null then
    raise exception 'ProjectOS canonical persistence requires exact candidate/project lineage'
      using errcode='23514';
  end if;

  if new.project_id is distinct from v_project_id then
    raise exception 'ProjectOS canonical project scope mismatch'
      using errcode='23514';
  end if;

  if not exists (
    select 1
    from public.memory_capture_candidates c
    join public.pandora_projects p
      on p.id=c.project_id
     and p.lifecycle_status='active'
     and p.memory_namespace=c.namespace::text
    where c.id=v_candidate_id
      and c.user_id=new.user_id
      and c.namespace::text=new.namespace::text
      and c.project_id=v_project_id
      and c.source_ref=v_review.source_ref
      and c.source in ('projectos-post-task','projectos-visible-creation')
  ) then
    raise exception 'ProjectOS canonical candidate/review lineage mismatch'
      using errcode='23514';
  end if;

  select count(*)::integer
    into v_grant_count
  from public.pandora_project_grants g
  where g.principal_key='projectos-mcpmaster-production'
    and g.project_id=v_project_id
    and g.environment='production'
    and g.is_active is true
    and g.can_propose is true
    and g.revoked_at is null;

  if v_grant_count<>1 then
    raise exception 'ProjectOS canonical project grant is not active'
      using errcode='23514';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_memory_guard_projectos_canonical_lineage_v1
  on public.memory_items;
create trigger trg_memory_guard_projectos_canonical_lineage_v1
before insert on public.memory_items
for each row execute function public.memory_guard_projectos_canonical_lineage_v1();

comment on function public.memory_bind_projectos_learning_scope_v1() is
  'R-042: fail-closed binding of new governed ProjectOS learning candidates to one active Memory project plus active production can_propose grant. No legacy backfill.';
comment on function public.memory_bind_projectos_review_lineage_v1() is
  'R-042: inject exact candidate/project lineage into new ProjectOS review rows after governed project binding.';
comment on function public.memory_guard_projectos_canonical_lineage_v1() is
  'R-042: block canonical persistence of ProjectOS outcomes when candidate/project lineage is absent, mismatched, inactive or grant-revoked.';
