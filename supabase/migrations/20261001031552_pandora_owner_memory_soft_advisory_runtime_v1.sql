begin;
CREATE OR REPLACE FUNCTION public.memory_task_context_v1(p_user_id uuid, p_namespace text, p_project_id uuid, p_principal_key text, p_environment text, p_intent text, p_action_mode text, p_consequential boolean DEFAULT false, p_terms text[] DEFAULT '{}'::text[], p_required_capabilities text[] DEFAULT '{}'::text[], p_canon_statuses text[] DEFAULT ARRAY['hard_canon'::text, 'soft_canon'::text], p_max_bytes integer DEFAULT 12288, p_as_of timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'extensions'
AS $function$
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
    and m.revoked_at is null and m.superseded_at is null and m.canon_status::text='hard_canon'
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
      and m.revoked_at is null and m.superseded_at is null and m.canon_status::text='hard_canon'
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
$function$
;
CREATE OR REPLACE FUNCTION public.memory_operations_bridge_v1(p_operation text, p_memory_user_id uuid, p_namespace text, p_project_id uuid, p_principal_key text, p_environment text, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  principal public.pandora_service_principals%rowtype;
  grant_row public.pandora_project_grants%rowtype;
  receipt private.pandora_ops_memory_receipts_v1%rowtype;
  item public.memory_capture_candidates%rowtype;
  review public.memory_review_queue_items%rowtype;
  body jsonb; reply jsonb; source_id uuid; fingerprint text; k text;
  refs text[]; observed timestamptz; due timestamptz; replayed boolean := false;
begin
  if p_operation is null or p_operation not in ('context','propose_outcome','readback')
    or p_memory_user_id is null or p_project_id is null
    or p_namespace is distinct from 'real_life'
    or jsonb_typeof(p_payload) is distinct from 'object'
    or octet_length(p_payload::text) > 32768 then
    raise exception 'OPS_MEMORY_REQUEST_INVALID' using errcode = '22023';
  end if;
  if p_payload::text ~* '(github_pat_|gh[pousr]_[A-Za-z0-9_]{16,}|sb_secret_|AIza[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{16,}|Bearer[[:space:]]+[A-Za-z0-9._~-]{12,}|-----BEGIN [^-]*PRIVATE KEY)' then
    raise exception 'OPS_MEMORY_CREDENTIAL_REJECTED' using errcode = '22023';
  end if;
  -- Shared row locks prevent grant/principal revocation racing this transaction.
  select * into principal from public.pandora_service_principals
    where principal_key = p_principal_key and memory_user_id = p_memory_user_id
      and environment = p_environment and is_active is true for share;
  if not found or not coalesce(p_namespace = any(principal.allowed_namespaces),false)
    or not coalesce((case when p_operation = 'context' then 'memory:read' else 'memory:write' end) = any(principal.scopes),false) then
    raise exception 'OPS_MEMORY_PRINCIPAL_DENIED' using errcode = '42501';
  end if;
  perform 1 from public.pandora_projects where id = p_project_id
    and memory_namespace = p_namespace and lifecycle_status = 'active' for share;
  if not found then raise exception 'OPS_MEMORY_PROJECT_DENIED' using errcode = '42501'; end if;
  select * into grant_row from public.pandora_project_grants
    where principal_key = p_principal_key and project_id = p_project_id
      and environment = p_environment and is_active is true and revoked_at is null for share;
  if not found or (p_operation = 'context' and grant_row.can_read is distinct from true)
    or (p_operation <> 'context' and (grant_row.can_propose is distinct from true
      or not coalesce('model_outcome' = any(grant_row.allowed_record_types),false))) then
    raise exception 'OPS_MEMORY_GRANT_DENIED' using errcode = '42501';
  end if;
  if p_operation = 'context' then
    if p_payload - array['intent','actionMode','consequential','terms','requiredCapabilities','maxBytes'] <> '{}'::jsonb
      or not coalesce(p_payload->>'intent' = any(array['communication','research','coding_building','files','device_operations','business','travel','scheduling','future_capability','general_assistance']),false)
      or not coalesce(p_payload->>'actionMode' = any(array['no_action','read_only','state_change']),false)
      or (p_payload ? 'consequential' and jsonb_typeof(p_payload->'consequential') is distinct from 'boolean') then
      raise exception 'OPS_MEMORY_CONTEXT_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['terms','requiredCapabilities'] loop
      if p_payload ? k and (jsonb_typeof(p_payload->k) is distinct from 'array') then
        raise exception 'OPS_MEMORY_CONTEXT_INVALID' using errcode = '22023';
      end if;
      if jsonb_array_length(coalesce(p_payload->k,'[]')) > (case when k = 'terms' then 12 else 16 end)
        or exists (select 1 from jsonb_array_elements(coalesce(p_payload->k,'[]')) v where jsonb_typeof(v) <> 'string') then
        raise exception 'OPS_MEMORY_CONTEXT_INVALID' using errcode = '22023';
      end if;
    end loop;
    if p_payload ? 'maxBytes' and (jsonb_typeof(p_payload->'maxBytes') is distinct from 'number'
      or not coalesce(p_payload->>'maxBytes' ~ '^[0-9]+$',false)) then
      raise exception 'OPS_MEMORY_CONTEXT_INVALID' using errcode = '22023';
    end if;
    -- Range-check before the integer cast so oversized JSON numbers stay a bounded input error.
    if p_payload ? 'maxBytes'
      and (p_payload->>'maxBytes')::numeric not between 4096 and 16384 then
      raise exception 'OPS_MEMORY_CONTEXT_INVALID' using errcode = '22023';
    end if;
    reply := public.memory_task_context_v1(p_memory_user_id,p_namespace,p_project_id,p_principal_key,p_environment,
      p_payload->>'intent',p_payload->>'actionMode',coalesce((p_payload->>'consequential')::boolean,false),
      array(select jsonb_array_elements_text(coalesce(p_payload->'terms','[]'))),
      array(select jsonb_array_elements_text(coalesce(p_payload->'requiredCapabilities','[]'))),
      array['hard_canon','soft_canon'],coalesce((p_payload->>'maxBytes')::integer,12288),clock_timestamp());
    return jsonb_build_object('kind','task_context','projectId',p_project_id,'namespace',p_namespace,
      'context',reply,'authorizationGranted',false);
  end if;
  if p_operation = 'readback' then
    if p_payload - array['sourceRunId','expectedPayload'] <> '{}'::jsonb
      or jsonb_typeof(p_payload->'expectedPayload') is distinct from 'object'
      or p_payload->>'sourceRunId' is distinct from p_payload#>>'{expectedPayload,sourceRunId}' then
      raise exception 'OPS_MEMORY_READBACK_INVALID' using errcode = '22023';
    end if;
    body := p_payload->'expectedPayload';
  else body := p_payload;
  end if;
  if not coalesce(body->>'sourceRunId' ~ '^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',false) then
    raise exception 'OPS_MEMORY_SOURCE_REQUIRED' using errcode = '22023';
  end if;
  source_id := (body->>'sourceRunId')::uuid;
  fingerprint := encode(extensions.digest(convert_to(body::text,'UTF8'),'sha256'),'hex');
  if p_operation = 'propose_outcome' then
    perform pg_advisory_xact_lock(hashtextextended(concat_ws('|','ops-memory',p_memory_user_id,p_namespace,p_project_id,source_id),0));
  end if;
  select * into receipt from private.pandora_ops_memory_receipts_v1
    where memory_user_id = p_memory_user_id and namespace = p_namespace
      and project_id = p_project_id and source_run_id = source_id;
  if found then
    if receipt.payload_sha256 <> fingerprint or receipt.principal_key <> p_principal_key
      or receipt.environment <> p_environment then
      raise exception 'OPS_MEMORY_REPLAY_CONFLICT' using errcode = '22023';
    end if;
    replayed := true;
  elsif p_operation = 'readback' then
    return jsonb_build_object('found',false,'requiresReconciliation',true,'canonicalMemoryWritten',false);
  else
    if body->>'contractVersion' is distinct from 'pandora-operations-model-outcome-v1'
      or not(body ?& array['contractVersion','sourceRunId','provider','model','modelRevision','taskClass','routingPolicyVersion','executionStatus','verificationStatus','downstreamOutcomeStatus','qualitySignal','latencyMs','estimatedCostMicros','billedCostMicros','occurredAt','evidenceRefs','sourceCommit','sourceDeploymentRef','reviewDueAt','usage','retryCount','configurationDigest'])
      or body - array['contractVersion','sourceRunId','provider','model','modelRevision','taskClass','routingPolicyVersion','executionStatus','verificationStatus','downstreamOutcomeStatus','qualitySignal','latencyMs','estimatedCostMicros','billedCostMicros','occurredAt','evidenceRefs','sourceCommit','sourceDeploymentRef','reviewDueAt','usage','retryCount','configurationDigest'] <> '{}'::jsonb then
      raise exception 'OPS_MEMORY_OUTCOME_FIELDS_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['provider','model','taskClass','routingPolicyVersion'] loop
      if jsonb_typeof(body->k) is distinct from 'string'
        or not coalesce(body->>k ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,179}$',false) then
        raise exception 'OPS_MEMORY_IDENTITY_INVALID' using errcode = '22023';
      end if;
    end loop;
    if body->>'provider' <> lower(body->>'provider') or length(body->>'provider') > 120
      or (body->'modelRevision' <> 'null'::jsonb and not coalesce(body->>'modelRevision' ~ '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,179}$',false))
      or not coalesce(body->>'sourceCommit' ~ '^[a-f0-9]{40}$',false)
      or (body->'configurationDigest' <> 'null'::jsonb and not coalesce(body->>'configurationDigest' ~ '^[a-f0-9]{64}$',false))
      or not coalesce(body->>'executionStatus' in ('succeeded','failed','cancelled'),false)
      or not coalesce(body->>'verificationStatus' in ('pass','fail','disagree','remediated'),false)
      or not coalesce(body->>'downstreamOutcomeStatus' in ('succeeded','failed','accepted','rejected','regressed','unknown'),false) then
      raise exception 'OPS_MEMORY_OUTCOME_IDENTITY_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['latencyMs','estimatedCostMicros','billedCostMicros'] loop
      if body->k <> 'null'::jsonb and (jsonb_typeof(body->k) is distinct from 'number'
        or not coalesce(body->>k ~ '^[0-9]+$',false) or (body->>k)::numeric > 9007199254740991) then
        raise exception 'OPS_MEMORY_METRIC_INVALID' using errcode = '22023';
      end if;
    end loop;
    if body->'qualitySignal' <> 'null'::jsonb and (jsonb_typeof(body->'qualitySignal') is distinct from 'number'
      or not coalesce((body->>'qualitySignal')::numeric between 0 and 1,false)) then
      raise exception 'OPS_MEMORY_QUALITY_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['modelRevision','sourceCommit','configurationDigest','sourceDeploymentRef'] loop
      if body->k <> 'null'::jsonb and jsonb_typeof(body->k) is distinct from 'string' then
        raise exception 'OPS_MEMORY_IDENTITY_INVALID' using errcode = '22023';
      end if;
    end loop;
    if jsonb_typeof(body->'usage') is distinct from 'object'
      or (body->'usage') - array['inputTokens','outputTokens','totalTokens'] <> '{}'::jsonb
      or not((body->'usage') ?& array['inputTokens','outputTokens','totalTokens']) then
      raise exception 'OPS_MEMORY_USAGE_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['inputTokens','outputTokens','totalTokens'] loop
      if body#>array['usage',k] <> 'null'::jsonb and (jsonb_typeof(body#>array['usage',k]) is distinct from 'number'
        or not coalesce(body#>>array['usage',k] ~ '^[0-9]+$',false) or (body#>>array['usage',k])::numeric > 9007199254740991) then
        raise exception 'OPS_MEMORY_USAGE_INVALID' using errcode = '22023';
      end if;
    end loop;
    if jsonb_typeof(body->'retryCount') is distinct from 'number'
      or not coalesce(body->>'retryCount' ~ '^[0-9]+$',false)
      or not coalesce((body->>'retryCount')::numeric between 0 and 16,false) then
      raise exception 'OPS_MEMORY_RETRY_INVALID' using errcode = '22023';
    end if;
    if jsonb_typeof(body->'evidenceRefs') is distinct from 'array' then
      raise exception 'OPS_MEMORY_EVIDENCE_REQUIRED' using errcode = '22023';
    end if;
    if jsonb_array_length(body->'evidenceRefs') not between 1 and 32
      or exists(select 1 from jsonb_array_elements(body->'evidenceRefs') v
        where jsonb_typeof(v) <> 'string' or not coalesce(length(v#>>'{}') <= 500 and v#>>'{}' ~ '^[A-Za-z0-9][A-Za-z0-9:./_?#=&%-]*$',false)) then
      raise exception 'OPS_MEMORY_EVIDENCE_INVALID' using errcode = '22023';
    end if;
    refs := array(select jsonb_array_elements_text(body->'evidenceRefs'));
    if cardinality(refs) <> (select count(distinct v) from unnest(refs) v)
      or cardinality(refs) > 31
      or (body->'sourceDeploymentRef' <> 'null'::jsonb and not coalesce(length(body->>'sourceDeploymentRef') <= 500 and body->>'sourceDeploymentRef' ~ '^[A-Za-z0-9][A-Za-z0-9:./_?#=&%-]*$',false)) then
      raise exception 'OPS_MEMORY_EVIDENCE_INVALID' using errcode = '22023';
    end if;
    foreach k in array array['occurredAt','reviewDueAt'] loop
      if jsonb_typeof(body->k) is distinct from 'string'
        or not coalesce(body->>k ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$',false) then
        raise exception 'OPS_MEMORY_TIME_INVALID' using errcode = '22023';
      end if;
    end loop;
    observed := (body->>'occurredAt')::timestamptz;
    due := (body->>'reviewDueAt')::timestamptz;
    if observed > clock_timestamp() or due <= observed or due > observed + interval '366 days' then
      raise exception 'OPS_MEMORY_TIME_INVALID' using errcode = '22023';
    end if;
    if exists(select 1 from public.memory_capture_candidates where user_id = p_memory_user_id
      and namespace = p_namespace and project_id = p_project_id
      and source = 'pandora-model-outcome' and source_ref = 'model-run:'||source_id::text) then
      raise exception 'OPS_MEMORY_LEGACY_REPLAY_REQUIRES_RECONCILIATION' using errcode = '22023';
    end if;
    refs := refs || ('ops-memory-metadata-sha256:'||fingerprint);
    reply := public.memory_ingest_model_outcome_candidate_v1(
      p_memory_user_id,p_namespace,p_project_id,source_id,body->>'provider',body->>'model',
      coalesce(body->>'modelRevision','unreported'),body->>'taskClass',body->>'routingPolicyVersion',
      body->>'executionStatus',body->>'verificationStatus',body->>'downstreamOutcomeStatus',
      (body->>'qualitySignal')::numeric,(body->>'latencyMs')::bigint,
      (body->>'estimatedCostMicros')::bigint,(body->>'billedCostMicros')::bigint,
      observed,refs,'pandora-intelligence-router',body->>'sourceCommit',body->>'sourceDeploymentRef',due);
    if reply->'requiresReview' is distinct from 'true'::jsonb
      or reply->'canonicalMemoryWritten' is distinct from 'false'::jsonb
      or reply->>'candidateId' is null or reply->>'reviewItemId' is null then
      raise exception 'OPS_MEMORY_CANDIDATE_RECEIPT_INVALID' using errcode = '55000';
    end if;
    insert into private.pandora_ops_memory_receipts_v1(memory_user_id,namespace,project_id,
      source_run_id,principal_key,environment,payload_sha256,safe_metadata,candidate_id,review_item_id)
      values(p_memory_user_id,p_namespace,p_project_id,source_id,p_principal_key,p_environment,
        fingerprint,body,(reply->>'candidateId')::uuid,(reply->>'reviewItemId')::uuid)
      returning * into receipt;
  end if;
  -- Read the persisted candidate AND review lineage; response IDs alone are not proof.
  select * into item from public.memory_capture_candidates where id = receipt.candidate_id
    and user_id = p_memory_user_id and namespace = p_namespace and project_id = p_project_id
    and source = 'pandora-model-outcome' and source_ref = 'model-run:'||source_id::text;
  if not found or item.provider is distinct from body->>'provider'
    or item.model is distinct from body->>'model'
    or item.model_revision is distinct from coalesce(body->>'modelRevision','unreported')
    or item.task_class is distinct from body->>'taskClass'
    or item.source_commit is distinct from body->>'sourceCommit'
    or item.routing_policy_version is distinct from body->>'routingPolicyVersion'
    or item.execution_status is distinct from body->>'executionStatus'
    or item.verification_status is distinct from body->>'verificationStatus'
    or item.downstream_outcome_status is distinct from body->>'downstreamOutcomeStatus'
    or item.quality_signal is distinct from (body->>'qualitySignal')::numeric
    or item.latency_ms is distinct from (body->>'latencyMs')::bigint
    or item.estimated_cost_micros is distinct from (body->>'estimatedCostMicros')::bigint
    or item.billed_cost_micros is distinct from (body->>'billedCostMicros')::bigint
    or item.source_run_ids is distinct from array[source_id]
    or item.source_system is distinct from 'pandora-intelligence-router'
    or item.source_deployment_ref is distinct from body->>'sourceDeploymentRef'
    or item.evidence_window_start is distinct from (body->>'occurredAt')::timestamptz
    or item.evidence_window_end is distinct from (body->>'occurredAt')::timestamptz
    or item.review_due_at is distinct from (body->>'reviewDueAt')::timestamptz
    or item.evidence_refs is distinct from
      (array(select jsonb_array_elements_text(body->'evidenceRefs')) || ('ops-memory-metadata-sha256:'||fingerprint))
    or (select count(*) from public.memory_capture_candidates where user_id = p_memory_user_id
      and namespace = p_namespace and project_id = p_project_id and source = 'pandora-model-outcome'
      and source_ref = 'model-run:'||source_id::text) <> 1 then
    raise exception 'OPS_MEMORY_CANDIDATE_READBACK_FAILED' using errcode = '55000';
  end if;
  select * into review from public.memory_review_queue_items where id = receipt.review_item_id
    and user_id = p_memory_user_id and namespace = p_namespace
    and source_metadata->>'projectId' = p_project_id::text
    and source_metadata->>'candidateId' = item.id::text
    and candidate_type = 'model_outcome' and source_ref = 'model-run:'||source_id::text;
  if not found or review.source_metadata->>'provider' is distinct from item.provider
    or review.source_metadata->>'model' is distinct from item.model
    or review.source_metadata->>'modelRevision' is distinct from item.model_revision
    or review.source_metadata->>'taskClass' is distinct from item.task_class
    or review.source_metadata->>'routingPolicyVersion' is distinct from item.routing_policy_version
    or review.source_metadata->'sourceRunIds' is distinct from to_jsonb(item.source_run_ids)
    or review.source_metadata->'evidenceRefs' is distinct from to_jsonb(item.evidence_refs)
    or review.source_metadata->'latencyMs' is distinct from coalesce(to_jsonb(item.latency_ms),'null'::jsonb)
    or review.source_metadata->'billedCostMicros' is distinct from coalesce(to_jsonb(item.billed_cost_micros),'null'::jsonb)
    or review.source_metadata->'estimatedCostMicros' is distinct from coalesce(to_jsonb(item.estimated_cost_micros),'null'::jsonb)
    or review.evidence_snapshot->>'executionStatus' is distinct from item.execution_status
    or review.evidence_snapshot->>'verificationStatus' is distinct from item.verification_status
    or review.evidence_snapshot->>'downstreamOutcomeStatus' is distinct from item.downstream_outcome_status then
    raise exception 'OPS_MEMORY_REVIEW_READBACK_FAILED' using errcode = '55000';
  end if;
  return jsonb_build_object('kind','outcome_receipt','found',true,'readbackVerified',true,
    'projectId',p_project_id,'namespace',p_namespace,'sourceRunId',source_id,
    'receiptId',receipt.id,'candidateId',item.id,'reviewItemId',review.id,
    'payloadSha256',receipt.payload_sha256,'idempotentReplay',replayed,
    'currentReviewStatus',review.status,'requiresReview',true,'canonicalMemoryWritten',false,
    'modelRevisionKnown',body->'modelRevision' <> 'null'::jsonb);
end; $function$
;
commit;
