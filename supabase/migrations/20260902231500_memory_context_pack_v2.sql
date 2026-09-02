-- Tasks 14 + 16: bounded exact-project MemoryContextPack v2 and negative-knowledge wiring.
-- This is a read-only service-side composition surface. It does not use legacy
-- unscoped memory_context_packs and never falls back across projects.
create or replace function public.memory_context_pack_v2(
  p_project_id uuid,
  p_principal_key text,
  p_namespace text default 'real_life',
  p_as_of timestamptz default now(),
  p_max_bytes integer default 12288
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_project public.pandora_projects%rowtype;
  v_grant public.pandora_project_grants%rowtype;
  v_allowed text[];
  v_canonical jsonb := '[]'::jsonb;
  v_negative jsonb := '[]'::jsonb;
  v_decisions jsonb := '[]'::jsonb;
  v_loops jsonb := '[]'::jsonb;
  v_conflicts jsonb := '[]'::jsonb;
  v_pack jsonb;
  v_hash text;
  v_total_canonical integer := 0;
  v_total_negative integer := 0;
  v_total_decisions integer := 0;
  v_total_loops integer := 0;
  v_total_conflicts integer := 0;
  v_latest_memory_at timestamptz;
  v_redaction_pattern constant text := '(api[_ -]?key|password|passwd|authorization|bearer[[:space:]]+[A-Za-z0-9._~+/-]{8,}|private[_ -]?key|access[_ -]?token|refresh[_ -]?token|database[_ -]?url|service[_ -]?role)';
begin
  if p_project_id is null
     or nullif(btrim(coalesce(p_principal_key,'')),'') is null
     or p_namespace <> 'real_life'
     or p_max_bytes not between 8192 and 12288 then
    raise exception 'memory_context_pack_invalid_request' using errcode='22023';
  end if;

  select * into v_project
  from public.pandora_projects
  where id=p_project_id and lifecycle_status='active';
  if not found then
    raise exception 'project_not_allowed' using errcode='42501';
  end if;

  select * into v_grant
  from public.pandora_project_grants
  where project_id=p_project_id
    and principal_key=p_principal_key
    and environment='production'
    and can_read is true
    and is_active is true
    and revoked_at is null
  order by updated_at desc
  limit 1;
  if not found then
    raise exception 'project_not_allowed' using errcode='42501';
  end if;
  v_allowed := coalesce(v_grant.allowed_record_types,'{}'::text[]);

  select count(*)::integer,max(coalesce(effective_at,updated_at,created_at))
    into v_total_canonical,v_latest_memory_at
  from public.memory_items m
  where m.project_id=p_project_id
    and m.namespace::text=p_namespace
    and m.is_active is true
    and m.canon_status::text='hard_canon'
    and m.superseded_at is null
    and m.revoked_at is null
    and m.record_type=any(v_allowed);

  select coalesce(jsonb_agg(item order by sort_at desc,item_id),'[]'::jsonb)
  into v_canonical
  from (
    select
      m.id as item_id,
      coalesce(m.effective_at,m.updated_at,m.created_at) as sort_at,
      jsonb_strip_nulls(jsonb_build_object(
        'id',m.id,
        'recordType',m.record_type,
        'title',left(nullif(m.title,''),180),
        'summary',left(coalesce(nullif(m.source_summary,''),nullif(m.title,''),'approved memory'),360),
        'contentHash',m.content_hash,
        'effectiveAt',m.effective_at,
        'updatedAt',m.updated_at,
        'sourceRepository',m.source_repository,
        'sourceCommit',m.source_commit_sha,
        'correlationId',m.correlation_id
      )) as item
    from public.memory_items m
    where m.project_id=p_project_id
      and m.namespace::text=p_namespace
      and m.is_active is true
      and m.canon_status::text='hard_canon'
      and m.superseded_at is null
      and m.revoked_at is null
      and m.record_type=any(v_allowed)
    order by coalesce(m.effective_at,m.updated_at,m.created_at) desc,m.id
    limit 24
  ) ranked;

  select count(*)::integer into v_total_negative
  from (
    select c.id
    from public.operating_project_constraints c
    where c.project_id=p_project_id
      and c.namespace=p_namespace
      and c.status='active'
    union all
    select m.id
    from public.memory_items m
    where m.project_id=p_project_id
      and m.namespace::text=p_namespace
      and m.is_active is true
      and m.canon_status::text='hard_canon'
      and m.superseded_at is null
      and m.revoked_at is null
      and m.record_type=any(v_allowed)
      and m.metadata->>'negativeKnowledgeType' in ('security_constraint','guardrail','known_bad_path','superseded_path','failure_pattern','never_repeat')
  ) n;

  select coalesce(jsonb_agg(item order by priority asc,sort_at desc,item_id),'[]'::jsonb)
  into v_negative
  from (
    select c.id as item_id,c.updated_at as sort_at,
      case when lower(coalesce(c.severity,'')) in ('critical','high') then 0 else 2 end as priority,
      jsonb_build_object(
        'id',c.id,
        'taxonomy',case when lower(coalesce(c.severity,'')) in ('critical','high') then 'security_constraint' else 'guardrail' end,
        'severity',coalesce(c.severity,'unspecified'),
        'summary',case when c.constraint_text ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(c.constraint_text,320) end,
        'privacyRedacted',c.constraint_text ~* v_redaction_pattern,
        'updatedAt',c.updated_at,
        'source','operating_project_constraints'
      ) as item
    from public.operating_project_constraints c
    where c.project_id=p_project_id and c.namespace=p_namespace and c.status='active'
    union all
    select m.id,coalesce(m.effective_at,m.updated_at,m.created_at),1,
      jsonb_strip_nulls(jsonb_build_object(
        'id',m.id,
        'taxonomy',m.metadata->>'negativeKnowledgeType',
        'severity',m.metadata->>'severity',
        'summary',case when coalesce(m.source_summary,m.title,'') ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(coalesce(nullif(m.source_summary,''),nullif(m.title,''),'approved negative knowledge'),320) end,
        'privacyRedacted',coalesce(m.source_summary,m.title,'') ~* v_redaction_pattern,
        'contentHash',m.content_hash,
        'updatedAt',m.updated_at,
        'source','memory_items'
      ))
    from public.memory_items m
    where m.project_id=p_project_id
      and m.namespace::text=p_namespace
      and m.is_active is true
      and m.canon_status::text='hard_canon'
      and m.superseded_at is null
      and m.revoked_at is null
      and m.record_type=any(v_allowed)
      and m.metadata->>'negativeKnowledgeType' in ('security_constraint','guardrail','known_bad_path','superseded_path','failure_pattern','never_repeat')
    order by priority,sort_at desc,item_id
    limit 10
  ) n;

  select count(*)::integer into v_total_decisions
  from public.operating_project_decisions d
  where d.project_id=p_project_id and d.namespace=p_namespace
    and d.status not in ('superseded','revoked','closed');
  select coalesce(jsonb_agg(item order by sort_at desc,item_id),'[]'::jsonb) into v_decisions
  from (
    select d.id item_id,d.updated_at sort_at,
      jsonb_build_object(
        'id',d.id,
        'decision',case when d.decision ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(d.decision,320) end,
        'reason',case when coalesce(d.reason,'') ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(coalesce(d.reason,''),240) end,
        'privacyRedacted',(d.decision ~* v_redaction_pattern or coalesce(d.reason,'') ~* v_redaction_pattern),
        'status',d.status,
        'updatedAt',d.updated_at
      ) item
    from public.operating_project_decisions d
    where d.project_id=p_project_id and d.namespace=p_namespace
      and d.status not in ('superseded','revoked','closed')
    order by d.updated_at desc,d.id limit 10
  ) d;

  select count(*)::integer into v_total_loops
  from public.operating_project_open_loops l
  where l.project_id=p_project_id and l.namespace=p_namespace
    and l.status not in ('resolved','closed','cancelled');
  select coalesce(jsonb_agg(item order by sort_at desc,item_id),'[]'::jsonb) into v_loops
  from (
    select l.id item_id,l.updated_at sort_at,
      jsonb_build_object(
        'id',l.id,
        'summary',case when l.loop_text ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(l.loop_text,320) end,
        'nextAction',case when coalesce(l.next_action,'') ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(coalesce(l.next_action,''),240) end,
        'privacyRedacted',(l.loop_text ~* v_redaction_pattern or coalesce(l.next_action,'') ~* v_redaction_pattern),
        'status',l.status,
        'updatedAt',l.updated_at
      ) item
    from public.operating_project_open_loops l
    where l.project_id=p_project_id and l.namespace=p_namespace
      and l.status not in ('resolved','closed','cancelled')
    order by l.updated_at desc,l.id limit 10
  ) l;

  select count(*)::integer into v_total_conflicts
  from public.pandora_memory_conflicts c
  where c.project_id=p_project_id and c.status not in ('resolved','closed');
  select coalesce(jsonb_agg(item order by sort_at desc,item_id),'[]'::jsonb) into v_conflicts
  from (
    select c.id item_id,c.updated_at sort_at,
      jsonb_build_object(
        'id',c.id,
        'subjectKey',left(c.subject_key,160),
        'conflictType',left(c.conflict_type,120),
        'detail',case when coalesce(c.detail,'') ~* v_redaction_pattern then '[REDACTED_BY_CONTEXT_PACK]' else left(coalesce(c.detail,''),280) end,
        'privacyRedacted',coalesce(c.detail,'') ~* v_redaction_pattern,
        'status',c.status,
        'updatedAt',c.updated_at
      ) item
    from public.pandora_memory_conflicts c
    where c.project_id=p_project_id and c.status not in ('resolved','closed')
    order by c.updated_at desc,c.id limit 10
  ) c;

  loop
    v_pack := jsonb_build_object(
      'schemaVersion','2.0',
      'status','available',
      'namespace',p_namespace,
      'project',jsonb_build_object('id',v_project.id,'projectKey',v_project.project_key,'name',v_project.name),
      'authorization',jsonb_build_object(
        'principalKey',v_grant.principal_key,
        'environment',v_grant.environment,
        'canRead',true,
        'allowedRecordTypes',to_jsonb(v_allowed)
      ),
      'precedence',jsonb_build_array('authorization','negative_knowledge','unresolved_conflicts','canonical_memory','decisions','open_loops'),
      'negativeKnowledge',v_negative,
      'conflicts',v_conflicts,
      'canonicalMemory',v_canonical,
      'decisions',v_decisions,
      'openLoops',v_loops,
      'counts',jsonb_build_object(
        'canonicalEligible',v_total_canonical,
        'negativeEligible',v_total_negative,
        'decisionEligible',v_total_decisions,
        'openLoopEligible',v_total_loops,
        'conflictEligible',v_total_conflicts
      ),
      'freshness',jsonb_build_object('asOf',p_as_of,'latestCanonicalAt',v_latest_memory_at),
      'degradation',jsonb_build_object(
        'degraded',(
          jsonb_array_length(v_canonical)<least(v_total_canonical,24)
          or jsonb_array_length(v_negative)<least(v_total_negative,10)
          or jsonb_array_length(v_decisions)<least(v_total_decisions,10)
          or jsonb_array_length(v_loops)<least(v_total_loops,10)
          or jsonb_array_length(v_conflicts)<least(v_total_conflicts,10)
        ),
        'omittedCanonical',greatest(v_total_canonical-jsonb_array_length(v_canonical),0),
        'omittedNegative',greatest(v_total_negative-jsonb_array_length(v_negative),0),
        'omittedDecisions',greatest(v_total_decisions-jsonb_array_length(v_decisions),0),
        'omittedOpenLoops',greatest(v_total_loops-jsonb_array_length(v_loops),0),
        'omittedConflicts',greatest(v_total_conflicts-jsonb_array_length(v_conflicts),0),
        'legacyUnscopedPackUsed',false
      )
    );
    exit when octet_length(v_pack::text)+96 <= p_max_bytes;
    if jsonb_array_length(v_canonical)>0 then
      v_canonical:=v_canonical-(jsonb_array_length(v_canonical)-1);
    elsif jsonb_array_length(v_decisions)>0 then
      v_decisions:=v_decisions-(jsonb_array_length(v_decisions)-1);
    elsif jsonb_array_length(v_loops)>0 then
      v_loops:=v_loops-(jsonb_array_length(v_loops)-1);
    elsif jsonb_array_length(v_conflicts)>0 then
      v_conflicts:=v_conflicts-(jsonb_array_length(v_conflicts)-1);
    elsif jsonb_array_length(v_negative)>1 then
      v_negative:=v_negative-(jsonb_array_length(v_negative)-1);
    else
      raise exception 'memory_context_pack_budget_exceeded' using errcode='54000';
    end if;
  end loop;

  v_hash:=encode(extensions.digest(convert_to(v_pack::text,'utf8'),'sha256'),'hex');
  v_pack:=v_pack||jsonb_build_object('contextSha256',v_hash,'byteSize',octet_length((v_pack||jsonb_build_object('contextSha256',v_hash))::text));
  if octet_length(v_pack::text)>p_max_bytes then
    raise exception 'memory_context_pack_budget_exceeded' using errcode='54000';
  end if;
  return v_pack;
end;
$$;

comment on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) is 'Tasks14/16 service-only exact-project MemoryContextPack v2. Requires active production can_read grant, uses hard-canon scoped Memory plus exact-project governed negative knowledge/decisions/open loops/conflicts, never uses legacy unscoped packs, redacts credential-shaped text, and enforces <=12KiB output.';
revoke all on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) from public, anon, authenticated;
grant execute on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) to service_role;
