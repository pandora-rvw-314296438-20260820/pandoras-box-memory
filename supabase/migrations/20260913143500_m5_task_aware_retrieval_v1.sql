-- M5-002: task-aware bounded retrieval for typed governed Memory.
-- Additive source change only. No production data mutation or grant expansion occurs here.
-- Requires M5-001 typed Memory columns/functions to be present first.

create or replace function public.memory_task_context_v1(
  p_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_principal_key text,
  p_environment text,
  p_intent text,
  p_action_mode text,
  p_consequential boolean default false,
  p_terms text[] default '{}'::text[],
  p_required_capabilities text[] default '{}'::text[],
  p_canon_statuses text[] default array['hard_canon','soft_canon']::text[],
  p_max_bytes integer default 12288,
  p_as_of timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','extensions'
as $function$
declare
  v_project public.pandora_projects%rowtype;
  v_grant public.pandora_project_grants%rowtype;
  v_allowed text[] := '{}'::text[];
  v_typed_classes constant text[] := array[
    'fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance'
  ]::text[];
  v_intents constant text[] := array[
    'communication','research','coding_building','files','device_operations',
    'business','travel','scheduling','future_capability','general_assistance'
  ]::text[];
  v_action_modes constant text[] := array['no_action','read_only','state_change']::text[];
  v_terms text[] := '{}'::text[];
  v_caps text[] := '{}'::text[];
  v_canon text[] := '{}'::text[];
  v_tsquery tsquery;
  v_term text;
  v_term_query tsquery;
  v_policy jsonb := '[]'::jsonb;
  v_advisory jsonb := '[]'::jsonb;
  v_pack jsonb;
  v_hash text;
  v_as_of timestamptz := coalesce(p_as_of, now());
  v_policy_eligible integer := 0;
  v_advisory_eligible integer := 0;
  v_policy_limit integer := 4;
  v_advisory_limit integer := 12;
  v_consequential boolean := coalesce(p_consequential,false);
  v_terms_supplied boolean := false;
  v_warnings jsonb := '[]'::jsonb;
begin
  if p_user_id is null
     or p_project_id is null
     or nullif(btrim(coalesce(p_principal_key,'')),'') is null
     or nullif(btrim(coalesce(p_environment,'')),'') is null
     or p_namespace not in ('real_life','au')
     or not (p_intent = any(v_intents))
     or not (p_action_mode = any(v_action_modes))
     or p_max_bytes not between 4096 and 16384
  then
    raise exception 'memory_task_context_invalid_request' using errcode='22023';
  end if;

  if coalesce(cardinality(p_terms),0) > 12
     or coalesce(cardinality(p_required_capabilities),0) > 16
     or coalesce(cardinality(p_canon_statuses),0) = 0
     or coalesce(cardinality(p_canon_statuses),0) > 2
  then
    raise exception 'memory_task_context_invalid_bounds' using errcode='22023';
  end if;

  select coalesce(array_agg(distinct t order by t),'{}'::text[])
    into v_terms
  from (
    select btrim(left(x,64)) as t
    from unnest(coalesce(p_terms,'{}'::text[])) x
    where length(btrim(x)) between 3 and 64
      and btrim(x) ~ '^[[:alnum:]_.:/+-]+$'
  ) q;
  v_terms_supplied := cardinality(v_terms) > 0;

  select coalesce(array_agg(distinct c order by c),'{}'::text[])
    into v_caps
  from (
    select btrim(x) as c
    from unnest(coalesce(p_required_capabilities,'{}'::text[])) x
    where length(btrim(x)) between 3 and 96
      and btrim(x) ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'
  ) q;

  select coalesce(array_agg(distinct s order by s),'{}'::text[])
    into v_canon
  from (
    select btrim(x) as s
    from unnest(coalesce(p_canon_statuses,'{}'::text[])) x
    where btrim(x) in ('hard_canon','soft_canon')
  ) q;
  if cardinality(v_canon) <> cardinality(p_canon_statuses) then
    raise exception 'memory_task_context_invalid_canon' using errcode='22023';
  end if;

  select * into v_project
  from public.pandora_projects
  where id=p_project_id
    and memory_namespace=p_namespace
    and lifecycle_status='active';
  if not found then
    raise exception 'project_not_allowed' using errcode='42501';
  end if;

  select * into v_grant
  from public.pandora_project_grants
  where principal_key=p_principal_key
    and project_id=p_project_id
    and environment=p_environment
    and is_active is true
    and can_read is true
    and revoked_at is null
  order by updated_at desc
  limit 1;
  if not found then
    raise exception 'project_not_allowed' using errcode='42501';
  end if;

  select coalesce(array_agg(x order by x),'{}'::text[])
    into v_allowed
  from (
    select distinct x
    from unnest(coalesce(v_grant.allowed_record_types,'{}'::text[])) x
    where x = any(v_typed_classes)
  ) q;

  foreach v_term in array v_terms loop
    v_term_query := plainto_tsquery('simple', v_term);
    if numnode(v_term_query) = 0 then continue; end if;
    v_tsquery := case when v_tsquery is null then v_term_query else v_tsquery || v_term_query end;
  end loop;

  if cardinality(v_allowed)=0 then
    v_warnings := v_warnings || jsonb_build_array('No M5 typed Memory classes are present in this project grant; retrieval remains empty rather than expanding authority.');
  end if;
  if not v_terms_supplied then
    v_warnings := v_warnings || jsonb_build_array('No usable task terms were supplied; bounded class-priority plus recency ordering is used.');
  end if;

  select count(*)::integer into v_policy_eligible
  from public.memory_items m
  where m.user_id=p_user_id and m.namespace::text=p_namespace and m.project_id=p_project_id
    and m.knowledge_schema_version='m5.v1' and m.record_type='policy' and m.record_type=any(v_allowed)
    and m.is_active is true and m.approved_by is not null and m.approved_at is not null
    and m.revoked_at is null and m.superseded_at is null and m.canon_status::text=any(v_canon)
    and m.authority_kind in ('explicit_current_user_instruction','active_explicit_standing_policy')
    and (v_tsquery is null or to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery or p_action_mode='state_change');

  select coalesce(jsonb_agg(item order by text_match desc,sort_at desc,item_id),'[]'::jsonb) into v_policy
  from (
    select m.id item_id, coalesce(m.effective_at,m.updated_at,m.created_at) sort_at,
      case when v_tsquery is null then false else to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery end text_match,
      jsonb_strip_nulls(jsonb_build_object(
        'id',m.id,'recordType',m.record_type,'title',left(m.title,180),'canonStatus',m.canon_status::text,
        'memoryType',m.memory_type::text,'knowledgeSchemaVersion',m.knowledge_schema_version,
        'provenanceSemanticSource',m.provenance->>'semanticSource',
        'summary',left(coalesce(nullif(m.source_summary,''),nullif(m.promotion_basis,''),nullif(m.body,''),m.title),560),
        'confidence',m.confidence,'authorityKind',m.authority_kind,'authorityRef',m.authority_ref,
        'evidenceRefs',m.evidence_refs,'observedAt',m.observed_at,'effectiveAt',m.effective_at,
        'promotionBasis',left(m.promotion_basis,420),'authorizationEffect','requires_exact_runtime_scope_validity_revocation_validation',
        'requiresRuntimeAuthorizationValidation',true,
        'taskTextMatch',case when v_tsquery is null then false else to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery end
      )) item
    from public.memory_items m
    where m.user_id=p_user_id and m.namespace::text=p_namespace and m.project_id=p_project_id
      and m.knowledge_schema_version='m5.v1' and m.record_type='policy' and m.record_type=any(v_allowed)
      and m.is_active is true and m.approved_by is not null and m.approved_at is not null
      and m.revoked_at is null and m.superseded_at is null and m.canon_status::text=any(v_canon)
      and m.authority_kind in ('explicit_current_user_instruction','active_explicit_standing_policy')
      and (v_tsquery is null or to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery or p_action_mode='state_change')
    order by text_match desc,sort_at desc,m.id limit v_policy_limit
  ) ranked;

  select count(*)::integer into v_advisory_eligible
  from public.memory_items m
  where m.user_id=p_user_id and m.namespace::text=p_namespace and m.project_id=p_project_id
    and m.knowledge_schema_version='m5.v1' and m.record_type<>'policy' and m.record_type=any(v_allowed)
    and m.is_active is true and m.approved_by is not null and m.approved_at is not null
    and m.revoked_at is null and m.superseded_at is null and m.canon_status::text=any(v_canon)
    and (v_tsquery is null or to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery);

  select coalesce(jsonb_agg(item order by score desc,sort_at desc,item_id),'[]'::jsonb) into v_advisory
  from (
    select m.id item_id,coalesce(m.effective_at,m.updated_at,m.created_at) sort_at,
      (case m.record_type
        when 'failure_lesson' then case when v_consequential or p_action_mode='state_change' then 100 else 72 end
        when 'procedure' then case when p_action_mode='state_change' then 90 else 58 end
        when 'fact' then 84
        when 'outcome' then case when p_action_mode='state_change' then 80 else 70 end
        when 'pattern' then case when p_intent in ('communication','business','travel','scheduling','general_assistance') then 66 else 42 end
        when 'provider_performance' then case when p_intent in ('coding_building','future_capability') then 62 else 36 end
        else 0 end
        + coalesce(m.confidence,0)::numeric*10
        + case when v_tsquery is null then 0 else ts_rank_cd(to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')),v_tsquery)::numeric*120 end
        + greatest(0,18-least(18,floor(extract(epoch from (v_as_of-coalesce(m.effective_at,m.updated_at,m.created_at)))/604800.0))))::numeric(12,4) score,
      jsonb_strip_nulls(jsonb_build_object(
        'id',m.id,'recordType',m.record_type,'title',left(m.title,180),'canonStatus',m.canon_status::text,
        'memoryType',m.memory_type::text,'knowledgeSchemaVersion',m.knowledge_schema_version,
        'provenanceSemanticSource',m.provenance->>'semanticSource',
        'summary',left(coalesce(nullif(m.source_summary,''),nullif(m.promotion_basis,''),nullif(m.body,''),m.title),560),
        'confidence',m.confidence,'authorityKind',m.authority_kind,'authorityRef',m.authority_ref,
        'evidenceRefs',m.evidence_refs,'observedAt',m.observed_at,'effectiveAt',m.effective_at,
        'promotionBasis',left(m.promotion_basis,420),'correctionOf',m.correction_of,
        'relevanceScore',(case m.record_type
          when 'failure_lesson' then case when v_consequential or p_action_mode='state_change' then 100 else 72 end
          when 'procedure' then case when p_action_mode='state_change' then 90 else 58 end
          when 'fact' then 84
          when 'outcome' then case when p_action_mode='state_change' then 80 else 70 end
          when 'pattern' then case when p_intent in ('communication','business','travel','scheduling','general_assistance') then 66 else 42 end
          when 'provider_performance' then case when p_intent in ('coding_building','future_capability') then 62 else 36 end
          else 0 end + coalesce(m.confidence,0)::numeric*10 + case when v_tsquery is null then 0 else ts_rank_cd(to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')),v_tsquery)::numeric*120 end),
        'authorizationEffect','none'
      )) item
    from public.memory_items m
    where m.user_id=p_user_id and m.namespace::text=p_namespace and m.project_id=p_project_id
      and m.knowledge_schema_version='m5.v1' and m.record_type<>'policy' and m.record_type=any(v_allowed)
      and m.is_active is true and m.approved_by is not null and m.approved_at is not null
      and m.revoked_at is null and m.superseded_at is null and m.canon_status::text=any(v_canon)
      and (v_tsquery is null or to_tsvector('simple',coalesce(m.title,'')||' '||coalesce(m.body,'')||' '||coalesce(m.source_summary,'')||' '||coalesce(m.promotion_basis,'')) @@ v_tsquery)
    order by score desc,sort_at desc,m.id limit v_advisory_limit
  ) ranked;

  loop
    v_pack := jsonb_build_object(
      'schemaVersion','m5.task-aware-retrieval.v1','status','available','namespace',p_namespace,
      'project',jsonb_build_object('id',v_project.id,'projectKey',v_project.project_key,'name',v_project.canonical_name),
      'task',jsonb_build_object('intent',p_intent,'actionMode',p_action_mode,'consequential',v_consequential,'terms',to_jsonb(v_terms),'requiredCapabilities',to_jsonb(v_caps)),
      'authorization',jsonb_build_object('principalKey',p_principal_key,'environment',p_environment,'canRead',true,'allowedRecordTypes',to_jsonb(v_grant.allowed_record_types),'allowedTypedClasses',to_jsonb(v_allowed),'retrievalDoesNotGrantExecutionAuthority',true),
      'policyMemory',v_policy,'advisoryMemory',v_advisory,
      'counts',jsonb_build_object('eligiblePolicy',v_policy_eligible,'eligibleAdvisory',v_advisory_eligible,'returnedPolicy',jsonb_array_length(v_policy),'returnedAdvisory',jsonb_array_length(v_advisory)),
      'degradation',jsonb_build_object('degraded',(jsonb_array_length(v_policy)<least(v_policy_eligible,v_policy_limit) or jsonb_array_length(v_advisory)<least(v_advisory_eligible,v_advisory_limit)),'omittedPolicy',greatest(v_policy_eligible-jsonb_array_length(v_policy),0),'omittedAdvisory',greatest(v_advisory_eligible-jsonb_array_length(v_advisory),0)),
      'invariants',jsonb_build_object('taskAwareBoundedRetrieval',true,'rawEventsExcluded',true,'advisoryMemoryNeverAuthorizes',true,'policiesSeparatedFromAdvisoryMemory',true,'policyRequiresRuntimeScopeValidityRevocationValidation',true,'similarityNeverDeterminesAuthority',true,'revokedAndSupersededExcludedByDefault',true,'grantExpansionPerformed',false),
      'warnings',v_warnings,'asOf',v_as_of
    );
    exit when octet_length(v_pack::text)<=p_max_bytes-192;
    if jsonb_array_length(v_advisory)>0 then v_advisory:=v_advisory-(jsonb_array_length(v_advisory)-1);
    elsif jsonb_array_length(v_policy)>0 then v_policy:=v_policy-(jsonb_array_length(v_policy)-1);
    else raise exception 'memory_task_context_budget_exceeded' using errcode='54000'; end if;
  end loop;

  v_hash:=encode(extensions.digest(convert_to(v_pack::text,'utf8'),'sha256'),'hex');
  v_pack:=v_pack||jsonb_build_object('contextSha256',v_hash,'maxBytes',p_max_bytes);
  v_pack:=v_pack||jsonb_build_object('byteSize',octet_length(v_pack::text));
  if octet_length(v_pack::text)>p_max_bytes then raise exception 'memory_task_context_budget_exceeded' using errcode='54000'; end if;
  return v_pack;
end;
$function$;

revoke all on function public.memory_task_context_v1(uuid,text,uuid,text,text,text,text,boolean,text[],text[],text[],integer,timestamptz) from public,anon,authenticated;
comment on function public.memory_task_context_v1(uuid,text,uuid,text,text,text,text,boolean,text[],text[],text[],integer,timestamptz) is
  'M5-002 task-aware bounded typed-Memory retrieval. Enforces project/principal grants, separates policies from advisory Memory, excludes revoked/superseded rows, and never grants execution authority.';
