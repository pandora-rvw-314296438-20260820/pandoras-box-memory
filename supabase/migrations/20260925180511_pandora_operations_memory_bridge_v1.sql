-- PANDORA_SECURITY_ADJUDICATION: reviewed (engineering source-readiness only; independent release review pending).
-- PANDORA_SECURITY_ACCESS_PATH: Trusted server-only RPC checks current principal/user/project/namespace/environment grants; service-role EXECUTE only; private receipts deny direct client and service writes.
-- PANDORA_SECURITY_TEST_PLAN: Exact native SQL plus 66 disposable-database assertions, three independent PostgreSQL replay/revocation races, and 57 companion client cases; live provider/tenant proof remains a release gate.
-- PANDORA_SECURITY_ROLLBACK: Pause the consumer and preserve native candidates, review history and immutable delivery receipts; reconcile unknown outcomes; no destructive history deletion or privilege widening.
-- PANDORA_SECURITY_OWNER: ChatGPT OPS-MEMORY-INTEGRATION-20260926 under Operations Room issue714; current owner requested integration; independent ARTEMIS/repository release approval still required.
-- This source metadata is not independent approval or authorization to run production DDL.

-- Operations Room -> existing M5 Memory. CLI-generated source; no activation/seed.
-- The receipt is delivery evidence, never a second canonical Memory store.
create table private.pandora_ops_memory_receipts_v1 (
  id uuid primary key default gen_random_uuid(),
  memory_user_id uuid not null,
  namespace text not null check (namespace = 'real_life'),
  project_id uuid not null references public.pandora_projects(id),
  source_run_id uuid not null,
  principal_key text not null,
  environment text not null,
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  safe_metadata jsonb not null check (jsonb_typeof(safe_metadata) = 'object'),
  candidate_id uuid not null references public.memory_capture_candidates(id),
  review_item_id uuid not null references public.memory_review_queue_items(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (memory_user_id, namespace, project_id, source_run_id),
  unique (candidate_id), unique (review_item_id)
);
alter table private.pandora_ops_memory_receipts_v1 enable row level security;
revoke all on private.pandora_ops_memory_receipts_v1
  from public, anon, authenticated, service_role;

create function public.memory_operations_bridge_v1(
  p_operation text, p_memory_user_id uuid, p_namespace text,
  p_project_id uuid, p_principal_key text, p_environment text,
  p_payload jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
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
      array['hard_canon'],coalesce((p_payload->>'maxBytes')::integer,12288),clock_timestamp());
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
end; $$;
revoke all on function public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb)
  from public, anon, authenticated;
grant execute on function public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb)
  to service_role;

create function private.pandora_ops_memory_receipt_immutable_v1()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'OPS_MEMORY_RECEIPT_IMMUTABLE' using errcode = '55000';
end; $$;
revoke all on function private.pandora_ops_memory_receipt_immutable_v1()
  from public, anon, authenticated, service_role;
create trigger pandora_ops_memory_receipt_immutable_v1
  before update or delete on private.pandora_ops_memory_receipts_v1
  for each row execute function private.pandora_ops_memory_receipt_immutable_v1();
comment on function public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb) is
  'Service-only Operations Room Memory transport. Reuses M5 context and review-gated model outcome intake; current principal/project grant locks, exact replay identity, immutable receipt, candidate/review readback. No canonical promotion or execution authority.';
