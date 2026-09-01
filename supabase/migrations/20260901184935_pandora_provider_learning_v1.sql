-- Chat D — governed provider-performance learning for Pandora Memory.
-- Extends existing candidate/review/persistence primitives. No raw provider traffic,
-- prompts, responses, credentials, or automatic routing-policy mutation.

alter table public.memory_capture_candidates
  add column if not exists project_id uuid null,
  add column if not exists record_type text not null default 'memory_candidate',
  add column if not exists provider text null,
  add column if not exists model text null,
  add column if not exists model_revision text null,
  add column if not exists task_class text null,
  add column if not exists routing_policy_version text null,
  add column if not exists source_run_ids uuid[] not null default '{}'::uuid[],
  add column if not exists evidence_refs text[] not null default '{}'::text[],
  add column if not exists evidence_window_start timestamptz null,
  add column if not exists evidence_window_end timestamptz null,
  add column if not exists sample_count bigint null,
  add column if not exists verification_pass_count bigint not null default 0,
  add column if not exists negative_outcome_count bigint not null default 0,
  add column if not exists execution_status text null,
  add column if not exists verification_status text null,
  add column if not exists downstream_outcome_status text null,
  add column if not exists quality_signal numeric(8,7) null,
  add column if not exists latency_ms bigint null,
  add column if not exists estimated_cost_micros bigint null,
  add column if not exists billed_cost_micros bigint null,
  add column if not exists source_system text null,
  add column if not exists source_commit text null,
  add column if not exists source_deployment_ref text null,
  add column if not exists review_due_at timestamptz null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='memory_capture_candidates_provider_learning_shape_check' and conrelid='public.memory_capture_candidates'::regclass) then
    alter table public.memory_capture_candidates add constraint memory_capture_candidates_provider_learning_shape_check
      check (record_type not in ('model_outcome','provider_performance','routing_playbook_candidate') or (
        project_id is not null and nullif(trim(provider),'') is not null and nullif(trim(model),'') is not null
        and nullif(trim(model_revision),'') is not null and nullif(trim(task_class),'') is not null
        and cardinality(source_run_ids) >= 1 and nullif(trim(source_system),'') is not null
        and sample_count is not null and sample_count > 0 and verification_pass_count >= 0 and negative_outcome_count >= 0
        and verification_pass_count <= sample_count and negative_outcome_count <= sample_count
        and (quality_signal is null or (quality_signal >= 0 and quality_signal <= 1))
        and (latency_ms is null or latency_ms >= 0) and (estimated_cost_micros is null or estimated_cost_micros >= 0)
        and (billed_cost_micros is null or billed_cost_micros >= 0)
        and evidence_window_start is not null and evidence_window_end is not null and evidence_window_end >= evidence_window_start
        and review_due_at is not null));
  end if;
  if not exists (select 1 from pg_constraint where conname='memory_capture_candidates_provider_learning_status_check' and conrelid='public.memory_capture_candidates'::regclass) then
    alter table public.memory_capture_candidates add constraint memory_capture_candidates_provider_learning_status_check
      check (execution_status is null or execution_status in ('succeeded','failed','cancelled')) not valid;
    alter table public.memory_capture_candidates validate constraint memory_capture_candidates_provider_learning_status_check;
  end if;
  if not exists (select 1 from pg_constraint where conname='memory_capture_candidates_provider_verification_status_check' and conrelid='public.memory_capture_candidates'::regclass) then
    alter table public.memory_capture_candidates add constraint memory_capture_candidates_provider_verification_status_check
      check (verification_status is null or verification_status in ('pass','fail','disagree','remediated','skipped','unavailable')) not valid;
    alter table public.memory_capture_candidates validate constraint memory_capture_candidates_provider_verification_status_check;
  end if;
  if not exists (select 1 from pg_constraint where conname='memory_capture_candidates_downstream_status_check' and conrelid='public.memory_capture_candidates'::regclass) then
    alter table public.memory_capture_candidates add constraint memory_capture_candidates_downstream_status_check
      check (downstream_outcome_status is null or downstream_outcome_status in ('succeeded','failed','accepted','rejected','regressed','unknown')) not valid;
    alter table public.memory_capture_candidates validate constraint memory_capture_candidates_downstream_status_check;
  end if;
end $$;

create unique index if not exists memory_capture_candidates_model_learning_source_unique
  on public.memory_capture_candidates(user_id, namespace, project_id, source, source_ref)
  where record_type in ('model_outcome','provider_performance','routing_playbook_candidate');
create index if not exists memory_capture_candidates_provider_learning_scope_idx
  on public.memory_capture_candidates(user_id, namespace, project_id, record_type, task_class, provider, model, model_revision, created_at desc)
  where record_type in ('model_outcome','provider_performance','routing_playbook_candidate');

alter table public.memory_retrieval_logs
  add column if not exists project_id uuid null,
  add column if not exists memory_item_ids uuid[] not null default '{}'::uuid[],
  add column if not exists routing_decision_id uuid null,
  add column if not exists used_for_routing boolean not null default false,
  add column if not exists outcome_run_id uuid null,
  add column if not exists provider text null,
  add column if not exists model text null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='memory_retrieval_logs_routing_feedback_shape_check' and conrelid='public.memory_retrieval_logs'::regclass) then
    alter table public.memory_retrieval_logs add constraint memory_retrieval_logs_routing_feedback_shape_check
      check (used_for_routing is false or (project_id is not null and routing_decision_id is not null and cardinality(memory_item_ids) >= 1));
  end if;
end $$;
create index if not exists memory_retrieval_logs_provider_feedback_idx
  on public.memory_retrieval_logs(user_id, namespace, project_id, routing_decision_id, created_at desc)
  where used_for_routing is true;

alter table public.memory_feedback_events
  add column if not exists project_id uuid null,
  add column if not exists memory_item_id uuid null,
  add column if not exists routing_decision_id uuid null,
  add column if not exists source_run_id uuid null,
  add column if not exists outcome_status text null,
  add column if not exists usefulness_delta numeric(8,7) null,
  add column if not exists evidence_ref text null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='memory_feedback_events_provider_outcome_check' and conrelid='public.memory_feedback_events'::regclass) then
    alter table public.memory_feedback_events add constraint memory_feedback_events_provider_outcome_check
      check (outcome_status is null or outcome_status in ('succeeded','failed','accepted','rejected','regressed','unknown'));
  end if;
  if not exists (select 1 from pg_constraint where conname='memory_feedback_events_usefulness_delta_check' and conrelid='public.memory_feedback_events'::regclass) then
    alter table public.memory_feedback_events add constraint memory_feedback_events_usefulness_delta_check
      check (usefulness_delta is null or (usefulness_delta >= -1 and usefulness_delta <= 1));
  end if;
end $$;
create index if not exists memory_feedback_events_provider_guidance_idx
  on public.memory_feedback_events(user_id, namespace, project_id, memory_item_id, created_at desc)
  where memory_item_id is not null;
create index if not exists memory_model_call_logs_provider_model_idx
  on public.memory_model_call_logs(user_id, namespace, provider, model, created_at desc);

create or replace function public.memory_log_model_call_metadata_v1(p_namespace text,p_provider text,p_model text,p_task text,p_input_char_count integer default null,p_project_id uuid default null,p_metadata jsonb default '{}'::jsonb)
returns uuid language plpgsql security invoker set search_path='pg_catalog','public' as $$
declare v_user_id uuid:=auth.uid(); v_id uuid; v_metadata jsonb:=coalesce(p_metadata,'{}'::jsonb);
begin
  if v_user_id is null then raise exception 'authenticated user required' using errcode='28000'; end if;
  if p_namespace not in ('real_life','au') then raise exception 'invalid namespace' using errcode='22023'; end if;
  if nullif(trim(p_provider),'') is null or length(p_provider)>120 or nullif(trim(p_model),'') is null or length(p_model)>180 or nullif(trim(p_task),'') is null or length(p_task)>180 then raise exception 'invalid model call identity' using errcode='22023'; end if;
  if p_input_char_count is not null and p_input_char_count<0 then raise exception 'invalid input char count' using errcode='22023'; end if;
  if octet_length(v_metadata::text)>16384 then raise exception 'model call metadata too large' using errcode='22023'; end if;
  if v_metadata::text ~* '\"(authorization|api[_-]?key|secret(_value)?|raw[_-]?(request|response)|prompt|request[_-]?body|response[_-]?body)\"[[:space:]]*:' or v_metadata::text ~* 'bearer[[:space:]]+[a-z0-9._~+/-]{8,}' then raise exception 'sensitive model call metadata rejected' using errcode='22023'; end if;
  insert into public.memory_model_call_logs(user_id,namespace,provider,model,task,input_char_count,redacted,metadata)
  values(v_user_id,p_namespace,lower(trim(p_provider)),trim(p_model),trim(p_task),p_input_char_count,true,v_metadata||jsonb_build_object('projectId',p_project_id,'metadataPolicy','redacted_operational_v1')) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.memory_log_model_call_metadata_v1(text,text,text,text,integer,uuid,jsonb) from public,anon;
grant execute on function public.memory_log_model_call_metadata_v1(text,text,text,text,integer,uuid,jsonb) to authenticated,service_role;

create or replace function public.memory_ingest_model_outcome_candidate_v1(
 p_memory_user_id uuid,p_namespace text,p_project_id uuid,p_source_run_id uuid,p_provider text,p_model text,p_model_revision text,p_task_class text,p_routing_policy_version text,
 p_execution_status text,p_verification_status text,p_downstream_outcome_status text,p_quality_signal numeric,p_latency_ms bigint,p_estimated_cost_micros bigint,p_billed_cost_micros bigint,
 p_occurred_at timestamptz,p_evidence_refs text[],p_source_system text,p_source_commit text,p_source_deployment_ref text,p_review_due_at timestamptz)
returns jsonb language plpgsql security definer set search_path='pg_catalog','public' as $$
declare v_candidate_id uuid;v_review_item_id uuid;v_source_ref text;v_summary text;v_negative integer;v_verification_pass integer;v_fingerprint text;v_existing record;
begin
 if p_memory_user_id is null or p_project_id is null or p_source_run_id is null then raise exception 'memory user, project and source run are required' using errcode='22023'; end if;
 if p_namespace not in ('real_life','au') then raise exception 'invalid namespace' using errcode='22023'; end if;
 if p_execution_status not in ('succeeded','failed','cancelled') or p_verification_status not in ('pass','fail','disagree','remediated','skipped','unavailable') or p_downstream_outcome_status not in ('succeeded','failed','accepted','rejected','regressed','unknown') then raise exception 'invalid outcome status' using errcode='22023'; end if;
 if nullif(trim(p_provider),'') is null or length(p_provider)>120 or nullif(trim(p_model),'') is null or length(p_model)>180 or nullif(trim(p_model_revision),'') is null or length(p_model_revision)>180 or nullif(trim(p_task_class),'') is null or length(p_task_class)>180 or nullif(trim(p_source_system),'') is null or length(p_source_system)>180 then raise exception 'invalid model outcome identity' using errcode='22023'; end if;
 if p_quality_signal is not null and (p_quality_signal<0 or p_quality_signal>1) then raise exception 'quality signal out of range' using errcode='22023'; end if;
 if (p_latency_ms is not null and p_latency_ms<0) or (p_estimated_cost_micros is not null and p_estimated_cost_micros<0) or (p_billed_cost_micros is not null and p_billed_cost_micros<0) then raise exception 'negative outcome metric' using errcode='22023'; end if;
 if p_occurred_at is null or p_review_due_at is null or p_review_due_at<=p_occurred_at then raise exception 'invalid freshness window' using errcode='22023'; end if;
 if cardinality(coalesce(p_evidence_refs,'{}'::text[]))=0 then raise exception 'evidence references required' using errcode='22023'; end if;
 if exists(select 1 from unnest(coalesce(p_evidence_refs,'{}'::text[])) x where nullif(trim(x),'') is null or length(x)>500 or x ~* '(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])') then raise exception 'unsafe evidence reference' using errcode='22023'; end if;
 v_source_ref:='model-run:'||p_source_run_id::text;
 select id,status into v_existing from public.memory_capture_candidates where user_id=p_memory_user_id and namespace=p_namespace and project_id=p_project_id and source='pandora-model-outcome' and source_ref=v_source_ref limit 1;
 if found then return jsonb_build_object('candidateId',v_existing.id,'status',v_existing.status,'idempotentReplay',true,'requiresReview',true); end if;
 v_negative:=case when p_execution_status<>'succeeded' or p_verification_status in('fail','disagree') or p_downstream_outcome_status in('failed','rejected','regressed') then 1 else 0 end;
 v_verification_pass:=case when p_verification_status='pass' then 1 else 0 end;
 v_summary:=format('Model outcome: %s/%s@%s task=%s execution=%s verification=%s downstream=%s.',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),p_execution_status,p_verification_status,p_downstream_outcome_status);
 v_fingerprint:=encode(extensions.digest(concat_ws('|',p_memory_user_id::text,p_namespace,p_project_id::text,p_source_run_id::text,lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),p_execution_status,p_verification_status,p_downstream_outcome_status),'sha256'),'hex');
 insert into public.memory_capture_candidates(user_id,namespace,source,source_ref,raw_excerpt,redacted_excerpt,memory_type,title,summary,importance,sensitivity,confidence,should_capture,requires_review,status,reason,people,projects,risks,tags,metadata,project_id,record_type,provider,model,model_revision,task_class,routing_policy_version,source_run_ids,evidence_refs,evidence_window_start,evidence_window_end,sample_count,verification_pass_count,negative_outcome_count,execution_status,verification_status,downstream_outcome_status,quality_signal,latency_ms,estimated_cost_micros,billed_cost_micros,source_system,source_commit,source_deployment_ref,review_due_at,usefulness_score,confidence_score,freshness_score,retrieval_weight,stale_status,scoring_version,scored_at)
 values(p_memory_user_id,p_namespace,'pandora-model-outcome',v_source_ref,null,v_summary,'observation','Provider outcome evidence',v_summary,7,'internal',coalesce(p_quality_signal,0.5),true,true,'pending','verified downstream outcome candidate','[]'::jsonb,jsonb_build_array(p_project_id::text),'[]'::jsonb,jsonb_build_array('model-outcome','provider-performance'),jsonb_build_object('metadataPolicy','sanitized_outcome_v1','fingerprint',v_fingerprint),p_project_id,'model_outcome',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),nullif(trim(p_routing_policy_version),''),array[p_source_run_id],coalesce(p_evidence_refs,'{}'::text[]),p_occurred_at,p_occurred_at,1,v_verification_pass,v_negative,p_execution_status,p_verification_status,p_downstream_outcome_status,p_quality_signal,p_latency_ms,p_estimated_cost_micros,p_billed_cost_micros,trim(p_source_system),nullif(trim(p_source_commit),''),nullif(trim(p_source_deployment_ref),''),p_review_due_at,coalesce(p_quality_signal,0.5),coalesce(p_quality_signal,0.5),1,0.5,'active','provider-learning-v1',now()) returning id into v_candidate_id;
 insert into public.memory_review_queue_items(user_id,namespace,status,candidate_type,normalized_text,evidence_snapshot,sensitivity_snapshot,namespace_snapshot,source_metadata,audit_metadata,append_only,proposed_operation,requires_review,source_ref,request_hash,fingerprint)
 values(p_memory_user_id,p_namespace,'pending_review','model_outcome',v_summary,jsonb_build_object('hasEvidence',true,'sourceRunIds',array[p_source_run_id],'evidenceRefs',coalesce(p_evidence_refs,'{}'::text[]),'executionStatus',p_execution_status,'verificationStatus',p_verification_status,'downstreamOutcomeStatus',p_downstream_outcome_status),jsonb_build_object('sensitivity','internal','rawContentStored',false),jsonb_build_object('namespace',p_namespace,'projectId',p_project_id),jsonb_build_object('candidateId',v_candidate_id,'projectId',p_project_id,'recordType','model_outcome','provider',lower(trim(p_provider)),'model',trim(p_model),'modelRevision',trim(p_model_revision),'taskClass',trim(p_task_class),'routingPolicyVersion',nullif(trim(p_routing_policy_version),''),'sourceRunIds',array[p_source_run_id],'evidenceRefs',coalesce(p_evidence_refs,'{}'::text[]),'evidenceWindowStart',p_occurred_at,'evidenceWindowEnd',p_occurred_at,'sampleCount',1,'verificationPassCount',v_verification_pass,'negativeOutcomeCount',v_negative,'qualitySignal',p_quality_signal,'latencyMs',p_latency_ms,'estimatedCostMicros',p_estimated_cost_micros,'billedCostMicros',p_billed_cost_micros,'sourceSystem',trim(p_source_system),'sourceCommit',nullif(trim(p_source_commit),''),'sourceDeploymentRef',nullif(trim(p_source_deployment_ref),''),'reviewDueAt',p_review_due_at,'metadataPolicy','sanitized_outcome_v1'),jsonb_build_object('source','pandora-model-outcome','sourceRef',v_source_ref,'fingerprint',v_fingerprint),true,'append',true,v_source_ref,v_fingerprint,v_fingerprint) returning id into v_review_item_id;
 return jsonb_build_object('candidateId',v_candidate_id,'reviewItemId',v_review_item_id,'idempotentReplay',false,'requiresReview',true,'canonicalMemoryWritten',false);
end $$;
revoke all on function public.memory_ingest_model_outcome_candidate_v1(uuid,text,uuid,uuid,text,text,text,text,text,text,text,text,numeric,bigint,bigint,bigint,timestamptz,text[],text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.memory_ingest_model_outcome_candidate_v1(uuid,text,uuid,uuid,text,text,text,text,text,text,text,text,numeric,bigint,bigint,bigint,timestamptz,text[],text,text,text,timestamptz) to service_role;

create or replace function public.memory_execute_approved_provider_learning_v1(p_review_item_id uuid,p_approved_decision_id uuid,p_idempotency_key text)
returns jsonb language plpgsql security invoker set search_path='pg_catalog','public' as $$
declare v_user_id uuid:=auth.uid();v_item record;v_decision record;v_existing record;v_candidate_id uuid;v_project_id uuid;v_review_due_at timestamptz;v_memory_item_id uuid:=gen_random_uuid();v_source_id uuid:=gen_random_uuid();v_patch_id uuid:=gen_random_uuid();v_audit_id uuid:=gen_random_uuid();v_now timestamptz:=now();v_record_type text;
begin
 if v_user_id is null then raise exception 'authenticated user required' using errcode='28000'; end if;
 if nullif(trim(p_idempotency_key),'') is null then raise exception 'idempotency key required' using errcode='22023'; end if;
 select * into v_existing from public.memory_review_queue_items where user_id=v_user_id and persistence_execution_metadata->>'idempotencyKey'=p_idempotency_key limit 1;
 if found then return jsonb_build_object('executed',true,'idempotentReplay',true,'reviewItemId',v_existing.id,'canonicalPolicyChanged',false,'appendOnly',true); end if;
 select * into v_item from public.memory_review_queue_items where id=p_review_item_id and user_id=v_user_id for update;
 if not found then raise exception 'review item not found for authenticated user' using errcode='P0002'; end if;
 if v_item.candidate_type not in('model_outcome','provider_performance','routing_playbook_candidate') then raise exception 'review item is not a provider learning candidate' using errcode='22023'; end if;
 if v_item.status<>'approved_for_append' or v_item.requires_review is not true or v_item.append_only is not true or v_item.proposed_operation<>'append' or v_item.archived_at is not null or v_item.persisted_at is not null then raise exception 'approved append-only review state required' using errcode='22023'; end if;
 if v_item.evidence_snapshot is null or coalesce((v_item.evidence_snapshot->>'hasEvidence')::boolean,false) is not true then raise exception 'evidence snapshot required' using errcode='22023'; end if;
 select * into v_decision from public.memory_review_queue_decisions where id=p_approved_decision_id and review_item_id=p_review_item_id and user_id=v_user_id and namespace=v_item.namespace and to_status='approved_for_append' order by created_at desc limit 1;
 if not found then raise exception 'valid approved append decision required' using errcode='22023'; end if;
 begin v_candidate_id:=nullif(v_item.source_metadata->>'candidateId','')::uuid;v_project_id:=nullif(v_item.source_metadata->>'projectId','')::uuid;v_review_due_at:=nullif(v_item.source_metadata->>'reviewDueAt','')::timestamptz;exception when others then raise exception 'invalid typed provider-learning metadata' using errcode='22023';end;
 if v_candidate_id is null or v_project_id is null or v_review_due_at is null then raise exception 'project, candidate and freshness metadata required' using errcode='22023'; end if;
 select record_type into v_record_type from public.memory_capture_candidates where id=v_candidate_id and user_id=v_user_id and namespace=v_item.namespace and project_id=v_project_id and source_ref=v_item.source_ref for update;
 if not found or v_record_type<>v_item.candidate_type then raise exception 'candidate/review lineage mismatch' using errcode='22023'; end if;
 insert into public.memory_items(id,user_id,namespace,memory_type,title,body,source_summary,metadata,created_at,updated_at,project_id,record_type,review_due_at,is_active)
 values(v_memory_item_id,v_user_id,v_item.namespace::public.pandora_namespace,'observation'::public.memory_type,left(v_item.normalized_text,120),v_item.normalized_text,v_item.source_ref,jsonb_build_object('reviewItemId',v_item.id,'reviewDecisionId',p_approved_decision_id,'candidateId',v_candidate_id,'appendOnly',true,'governedProviderLearning',true)||v_item.source_metadata,v_now,v_now,v_project_id,v_item.candidate_type,v_review_due_at,true);
 insert into public.memory_sources(id,user_id,namespace,memory_item_id,source_type,source_ref,excerpt,metadata,created_at)
 values(v_source_id,v_user_id,v_item.namespace::public.pandora_namespace,v_memory_item_id,'other'::public.evidence_source_type,v_item.source_ref,v_item.normalized_text,jsonb_build_object('reviewItemId',v_item.id,'evidenceSnapshot',v_item.evidence_snapshot,'sourceMetadata',v_item.source_metadata,'appendOnly',true,'rawProviderContentStored',false),v_now);
 insert into public.memory_patches(id,user_id,namespace,memory_item_id,patch_type,reason,before_snapshot,after_snapshot,metadata,created_at)
 values(v_patch_id,v_user_id,v_item.namespace::public.pandora_namespace,v_memory_item_id,'append','approved_provider_learning_persistence',null,jsonb_build_object('body',v_item.normalized_text,'namespace',v_item.namespace,'recordType',v_item.candidate_type),jsonb_build_object('reviewItemId',v_item.id,'appendOnly',true),v_now);
 insert into public.audit_logs(id,user_id,namespace,action,table_name,record_id,before_snapshot,after_snapshot,metadata,created_at)
 values(v_audit_id,v_user_id,v_item.namespace::public.pandora_namespace,'approved_provider_learning_persistence_executed','memory_review_queue_items',v_item.id,null,jsonb_build_object('memoryItemId',v_memory_item_id,'sourceId',v_source_id,'patchId',v_patch_id),jsonb_build_object('reviewItemId',v_item.id,'reviewDecisionId',p_approved_decision_id,'candidateId',v_candidate_id,'idempotencyKey',p_idempotency_key,'appendOnly',true,'canonicalPolicyChanged',false),v_now);
 update public.memory_review_queue_items set persisted_at=v_now,persistence_status='persisted',updated_at=v_now,persistence_execution_metadata=persistence_execution_metadata||jsonb_build_object('idempotencyKey',p_idempotency_key,'memoryItemId',v_memory_item_id,'sourceId',v_source_id,'patchId',v_patch_id,'auditLogId',v_audit_id) where id=v_item.id and user_id=v_user_id;
 update public.memory_capture_candidates set status='captured',reviewed_at=v_now,stale_status='active' where id=v_candidate_id and user_id=v_user_id and namespace=v_item.namespace and project_id=v_project_id;
 return jsonb_build_object('executed',true,'idempotentReplay',false,'appendOnly',true,'candidateId',v_candidate_id,'reviewItemId',v_item.id,'memoryItemId',v_memory_item_id,'recordType',v_item.candidate_type,'projectId',v_project_id,'canonicalPolicyChanged',false,'requiresFurtherCanonPromotion',true);
end $$;
revoke all on function public.memory_execute_approved_provider_learning_v1(uuid,uuid,text) from public,anon;
grant execute on function public.memory_execute_approved_provider_learning_v1(uuid,uuid,text) to authenticated,service_role;

create or replace function public.memory_propose_provider_performance_v1(p_namespace text,p_project_id uuid,p_provider text,p_model text,p_model_revision text,p_task_class text,p_window_start timestamptz,p_window_end timestamptz,p_review_due_at timestamptz)
returns jsonb language plpgsql security invoker set search_path='pg_catalog','public' as $$
declare v_user_id uuid:=auth.uid();v_sample_count bigint;v_verified_pass bigint;v_negative bigint;v_avg_quality numeric;v_avg_latency numeric;v_estimated_cost bigint;v_billed_cost bigint;v_runs uuid[];v_evidence_refs text[];v_candidate_id uuid;v_review_item_id uuid;v_source_ref text;v_summary text;v_fingerprint text;
begin
 if v_user_id is null then raise exception 'authenticated user required' using errcode='28000'; end if;
 if p_namespace not in('real_life','au') or p_project_id is null or p_window_start is null or p_window_end is null or p_window_end<p_window_start or p_review_due_at is null or p_review_due_at<=p_window_end then raise exception 'invalid provider performance scope/window' using errcode='22023'; end if;
 select count(*)::bigint,coalesce(sum(verification_pass_count),0)::bigint,coalesce(sum(negative_outcome_count),0)::bigint,avg(quality_signal),avg(latency_ms),case when count(*) filter(where estimated_cost_micros is null)>0 then null else coalesce(sum(estimated_cost_micros),0)::bigint end,case when count(*) filter(where billed_cost_micros is null)>0 then null else coalesce(sum(billed_cost_micros),0)::bigint end,array_agg(distinct source_run_ids[1] order by source_run_ids[1]),array(select distinct e from public.memory_capture_candidates c2 cross join lateral unnest(c2.evidence_refs)e where c2.user_id=v_user_id and c2.namespace=p_namespace and c2.project_id=p_project_id and c2.record_type='model_outcome' and c2.status='captured' and c2.provider=lower(trim(p_provider)) and c2.model=trim(p_model) and c2.model_revision=trim(p_model_revision) and c2.task_class=trim(p_task_class) and c2.evidence_window_start>=p_window_start and c2.evidence_window_end<=p_window_end order by e limit 200)
 into v_sample_count,v_verified_pass,v_negative,v_avg_quality,v_avg_latency,v_estimated_cost,v_billed_cost,v_runs,v_evidence_refs from public.memory_capture_candidates c where c.user_id=v_user_id and c.namespace=p_namespace and c.project_id=p_project_id and c.record_type='model_outcome' and c.status='captured' and c.provider=lower(trim(p_provider)) and c.model=trim(p_model) and c.model_revision=trim(p_model_revision) and c.task_class=trim(p_task_class) and c.evidence_window_start>=p_window_start and c.evidence_window_end<=p_window_end;
 if v_sample_count<3 or v_verified_pass<2 then return jsonb_build_object('created',false,'reason','insufficient_governed_evidence','sampleCount',v_sample_count,'verificationPassCount',v_verified_pass,'minimumSampleCount',3,'minimumVerificationPassCount',2); end if;
 v_source_ref:=format('provider-performance:%s:%s:%s:%s:%s:%s',p_project_id,lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),to_char(p_window_end at time zone 'UTC','YYYYMMDDHH24MISS'));
 v_summary:=format('Provider performance: %s/%s@%s task=%s sample=%s verified_pass=%s negative=%s window=%s..%s.',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),v_sample_count,v_verified_pass,v_negative,p_window_start,p_window_end);
 v_fingerprint:=encode(extensions.digest(concat_ws('|',v_user_id::text,p_namespace,p_project_id::text,v_source_ref,v_sample_count::text,v_verified_pass::text,v_negative::text),'sha256'),'hex');
 insert into public.memory_capture_candidates(user_id,namespace,source,source_ref,raw_excerpt,redacted_excerpt,memory_type,title,summary,importance,sensitivity,confidence,should_capture,requires_review,status,reason,people,projects,risks,tags,metadata,project_id,record_type,provider,model,model_revision,task_class,source_run_ids,evidence_refs,evidence_window_start,evidence_window_end,sample_count,verification_pass_count,negative_outcome_count,quality_signal,latency_ms,estimated_cost_micros,billed_cost_micros,source_system,review_due_at,usefulness_score,confidence_score,freshness_score,retrieval_weight,stale_status,scoring_version,scored_at)
 values(v_user_id,p_namespace,'pandora-provider-performance',v_source_ref,null,v_summary,'observation','Provider performance candidate',v_summary,8,'internal',least(1::numeric,greatest(0::numeric,v_sample_count::numeric/20)),true,true,'pending','aggregated governed model outcomes','[]'::jsonb,jsonb_build_array(p_project_id::text),'[]'::jsonb,jsonb_build_array('provider-performance','routing-evidence'),jsonb_build_object('metadataPolicy','sanitized_provider_performance_v1'),p_project_id,'provider_performance',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),v_runs,coalesce(v_evidence_refs,'{}'::text[]),p_window_start,p_window_end,v_sample_count,v_verified_pass,v_negative,v_avg_quality,case when v_avg_latency is null then null else round(v_avg_latency)::bigint end,v_estimated_cost,v_billed_cost,'pandora-memory-aggregate-v1',p_review_due_at,least(1::numeric,greatest(0::numeric,coalesce(v_avg_quality,0))),least(1::numeric,greatest(0::numeric,v_sample_count::numeric/20)),1,0.5,'active','provider-learning-v1',now())
 on conflict(user_id,namespace,project_id,source,source_ref) where record_type in('model_outcome','provider_performance','routing_playbook_candidate') do update set source_run_ids=excluded.source_run_ids,evidence_refs=excluded.evidence_refs,sample_count=excluded.sample_count,verification_pass_count=excluded.verification_pass_count,negative_outcome_count=excluded.negative_outcome_count,quality_signal=excluded.quality_signal,latency_ms=excluded.latency_ms,estimated_cost_micros=excluded.estimated_cost_micros,billed_cost_micros=excluded.billed_cost_micros,review_due_at=excluded.review_due_at,summary=excluded.summary,redacted_excerpt=excluded.redacted_excerpt,confidence=excluded.confidence,confidence_score=excluded.confidence_score,scored_at=now() returning id into v_candidate_id;
 select id into v_review_item_id from public.memory_review_queue_items where user_id=v_user_id and namespace=p_namespace and source_ref=v_source_ref and candidate_type='provider_performance' and archived_at is null order by created_at desc limit 1;
 if v_review_item_id is null then insert into public.memory_review_queue_items(user_id,namespace,status,candidate_type,normalized_text,evidence_snapshot,sensitivity_snapshot,namespace_snapshot,source_metadata,audit_metadata,append_only,proposed_operation,requires_review,source_ref,request_hash,fingerprint)
 values(v_user_id,p_namespace,'pending_review','provider_performance',v_summary,jsonb_build_object('hasEvidence',true,'sourceRunIds',v_runs,'evidenceRefs',coalesce(v_evidence_refs,'{}'::text[]),'sampleCount',v_sample_count,'verificationPassCount',v_verified_pass,'negativeOutcomeCount',v_negative),jsonb_build_object('sensitivity','internal','rawContentStored',false),jsonb_build_object('namespace',p_namespace,'projectId',p_project_id),jsonb_build_object('candidateId',v_candidate_id,'projectId',p_project_id,'recordType','provider_performance','provider',lower(trim(p_provider)),'model',trim(p_model),'modelRevision',trim(p_model_revision),'taskClass',trim(p_task_class),'sourceRunIds',v_runs,'evidenceRefs',coalesce(v_evidence_refs,'{}'::text[]),'evidenceWindowStart',p_window_start,'evidenceWindowEnd',p_window_end,'sampleCount',v_sample_count,'verificationPassCount',v_verified_pass,'negativeOutcomeCount',v_negative,'qualitySignal',v_avg_quality,'latencyMs',case when v_avg_latency is null then null else round(v_avg_latency)::bigint end,'estimatedCostMicros',v_estimated_cost,'billedCostMicros',v_billed_cost,'sourceSystem','pandora-memory-aggregate-v1','reviewDueAt',p_review_due_at,'metadataPolicy','sanitized_provider_performance_v1'),jsonb_build_object('source','pandora-provider-performance','sourceRef',v_source_ref,'fingerprint',v_fingerprint),true,'append',true,v_source_ref,v_fingerprint,v_fingerprint) returning id into v_review_item_id; end if;
 return jsonb_build_object('created',true,'candidateId',v_candidate_id,'reviewItemId',v_review_item_id,'sampleCount',v_sample_count,'verificationPassCount',v_verified_pass,'negativeOutcomeCount',v_negative,'requiresReview',true,'canonicalPolicyChanged',false);
end $$;
revoke all on function public.memory_propose_provider_performance_v1(text,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz) from public,anon;
grant execute on function public.memory_propose_provider_performance_v1(text,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz) to authenticated,service_role;

create or replace function public.memory_propose_routing_playbook_v1(p_namespace text,p_project_id uuid,p_provider text,p_model text,p_model_revision text,p_task_class text,p_review_due_at timestamptz)
returns jsonb language plpgsql security invoker set search_path='pg_catalog','public' as $$
declare v_user_id uuid:=auth.uid();v_records bigint;v_samples bigint;v_verified bigint;v_negative bigint;v_source_items uuid[];v_candidate_id uuid;v_review_item_id uuid;v_source_ref text;v_summary text;v_fingerprint text;
begin
 if v_user_id is null then raise exception 'authenticated user required' using errcode='28000'; end if;
 if p_namespace not in('real_life','au') or p_project_id is null or p_review_due_at<=now() then raise exception 'invalid routing playbook scope/freshness' using errcode='22023'; end if;
 select count(*)::bigint,coalesce(sum((metadata->>'sampleCount')::bigint),0)::bigint,coalesce(sum((metadata->>'verificationPassCount')::bigint),0)::bigint,coalesce(sum((metadata->>'negativeOutcomeCount')::bigint),0)::bigint,array_agg(id order by created_at)
 into v_records,v_samples,v_verified,v_negative,v_source_items from public.memory_items where user_id=v_user_id and namespace=p_namespace::public.pandora_namespace and project_id=p_project_id and record_type='provider_performance' and is_active is true and revoked_at is null and superseded_at is null and canon_status in('soft_canon'::public.canon_status,'hard_canon'::public.canon_status) and review_due_at is not null and review_due_at>now() and metadata->>'provider'=lower(trim(p_provider)) and metadata->>'model'=trim(p_model) and metadata->>'modelRevision'=trim(p_model_revision) and metadata->>'taskClass'=trim(p_task_class);
 if v_records<1 or v_samples<3 or v_verified<2 then return jsonb_build_object('created',false,'reason','insufficient_fresh_approved_provider_performance','providerPerformanceRecords',v_records,'sampleCount',v_samples,'verificationPassCount',v_verified); end if;
 v_source_ref:=format('routing-playbook:%s:%s:%s:%s:%s:%s',p_project_id,lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),to_char(now() at time zone 'UTC','YYYYMMDDHH24MISS'));
 v_summary:=format('Routing playbook candidate: prefer %s/%s@%s for task=%s within project scope; evidence sample=%s verified_pass=%s negative=%s. Candidate only; no routing policy mutation.',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),v_samples,v_verified,v_negative);
 v_fingerprint:=encode(extensions.digest(concat_ws('|',v_user_id::text,p_namespace,p_project_id::text,v_source_ref,v_samples::text,v_verified::text,v_negative::text),'sha256'),'hex');
 insert into public.memory_capture_candidates(user_id,namespace,source,source_ref,raw_excerpt,redacted_excerpt,memory_type,title,summary,importance,sensitivity,confidence,should_capture,requires_review,status,reason,people,projects,risks,tags,metadata,project_id,record_type,provider,model,model_revision,task_class,source_run_ids,evidence_refs,evidence_window_start,evidence_window_end,sample_count,verification_pass_count,negative_outcome_count,source_system,review_due_at,usefulness_score,confidence_score,freshness_score,retrieval_weight,stale_status,scoring_version,scored_at)
 values(v_user_id,p_namespace,'pandora-routing-playbook',v_source_ref,null,v_summary,'observation','Routing playbook candidate',v_summary,9,'internal',least(1::numeric,v_samples::numeric/20),true,true,'pending','candidate from fresh approved provider performance','[]'::jsonb,jsonb_build_array(p_project_id::text),'[]'::jsonb,jsonb_build_array('routing-playbook-candidate'),jsonb_build_object('providerPerformanceMemoryItemIds',v_source_items,'canonicalPolicyChanged',false),p_project_id,'routing_playbook_candidate',lower(trim(p_provider)),trim(p_model),trim(p_model_revision),trim(p_task_class),array(select distinct (jsonb_array_elements_text(metadata->'sourceRunIds'))::uuid from public.memory_items where id=any(v_source_items)),array['memory-items:'||array_to_string(v_source_items,',')],now(),now(),v_samples,v_verified,v_negative,'pandora-memory-routing-playbook-v1',p_review_due_at,least(1::numeric,v_verified::numeric/greatest(v_samples,1)),least(1::numeric,v_samples::numeric/20),1,0.5,'active','provider-learning-v1',now()) returning id into v_candidate_id;
 insert into public.memory_review_queue_items(user_id,namespace,status,candidate_type,normalized_text,evidence_snapshot,sensitivity_snapshot,namespace_snapshot,source_metadata,audit_metadata,append_only,proposed_operation,requires_review,source_ref,request_hash,fingerprint)
 values(v_user_id,p_namespace,'pending_review','routing_playbook_candidate',v_summary,jsonb_build_object('hasEvidence',true,'providerPerformanceMemoryItemIds',v_source_items,'sampleCount',v_samples,'verificationPassCount',v_verified,'negativeOutcomeCount',v_negative),jsonb_build_object('sensitivity','internal','rawContentStored',false),jsonb_build_object('namespace',p_namespace,'projectId',p_project_id),jsonb_build_object('candidateId',v_candidate_id,'projectId',p_project_id,'recordType','routing_playbook_candidate','provider',lower(trim(p_provider)),'model',trim(p_model),'modelRevision',trim(p_model_revision),'taskClass',trim(p_task_class),'sourceRunIds',(select source_run_ids from public.memory_capture_candidates where id=v_candidate_id),'evidenceRefs',(select evidence_refs from public.memory_capture_candidates where id=v_candidate_id),'evidenceWindowStart',now(),'evidenceWindowEnd',now(),'sampleCount',v_samples,'verificationPassCount',v_verified,'negativeOutcomeCount',v_negative,'sourceSystem','pandora-memory-routing-playbook-v1','reviewDueAt',p_review_due_at,'canonicalPolicyChanged',false,'metadataPolicy','sanitized_routing_playbook_v1'),jsonb_build_object('source','pandora-routing-playbook','sourceRef',v_source_ref,'fingerprint',v_fingerprint),true,'append',true,v_source_ref,v_fingerprint,v_fingerprint) returning id into v_review_item_id;
 return jsonb_build_object('created',true,'candidateId',v_candidate_id,'reviewItemId',v_review_item_id,'requiresReview',true,'canonicalPolicyChanged',false,'productionRoutingChanged',false);
end $$;
revoke all on function public.memory_propose_routing_playbook_v1(text,uuid,text,text,text,text,timestamptz) from public,anon;
grant execute on function public.memory_propose_routing_playbook_v1(text,uuid,text,text,text,text,timestamptz) to authenticated,service_role;

create or replace function public.memory_provider_performance_state_v1(p_memory_item_id uuid,p_as_of timestamptz default now()) returns jsonb language sql stable security invoker set search_path='pg_catalog','public' as $$
 select jsonb_build_object('memoryItemId',m.id,'projectId',m.project_id,'recordType',m.record_type,'state',case when m.revoked_at is not null or m.is_active is false then 'revoked' when m.superseded_at is not null then 'superseded' when m.canon_status not in('soft_canon'::public.canon_status,'hard_canon'::public.canon_status) then 'unapproved' when m.review_due_at is null then 'freshness_unknown' when p_as_of>=m.review_due_at then 'stale' else 'fresh' end,'reviewDueAt',m.review_due_at,'provider',m.metadata->>'provider','model',m.metadata->>'model','modelRevision',m.metadata->>'modelRevision','taskClass',m.metadata->>'taskClass','sampleCount',m.metadata->>'sampleCount','verificationPassCount',m.metadata->>'verificationPassCount','negativeOutcomeCount',m.metadata->>'negativeOutcomeCount') from public.memory_items m where m.id=p_memory_item_id and m.user_id=auth.uid() and m.record_type in('provider_performance','routing_playbook_candidate');
$$;
revoke all on function public.memory_provider_performance_state_v1(uuid,timestamptz) from public,anon;
grant execute on function public.memory_provider_performance_state_v1(uuid,timestamptz) to authenticated,service_role;

create or replace function public.memory_get_provider_performance_v1(p_namespace text,p_project_id uuid,p_task_class text default null,p_provider text default null,p_as_of timestamptz default now())
returns table(memory_item_id uuid,record_type text,provider text,model text,model_revision text,task_class text,sample_count bigint,verification_pass_count bigint,negative_outcome_count bigint,quality_signal numeric,review_due_at timestamptz,evidence_refs jsonb)
language sql stable security invoker set search_path='pg_catalog','public' as $$
 select m.id,m.record_type,m.metadata->>'provider',m.metadata->>'model',m.metadata->>'modelRevision',m.metadata->>'taskClass',nullif(m.metadata->>'sampleCount','')::bigint,nullif(m.metadata->>'verificationPassCount','')::bigint,nullif(m.metadata->>'negativeOutcomeCount','')::bigint,nullif(m.metadata->>'qualitySignal','')::numeric,m.review_due_at,coalesce(m.metadata->'evidenceRefs','[]'::jsonb) from public.memory_items m where m.user_id=auth.uid() and m.namespace=p_namespace::public.pandora_namespace and m.project_id=p_project_id and m.record_type='provider_performance' and m.is_active is true and m.revoked_at is null and m.superseded_at is null and m.canon_status in('soft_canon'::public.canon_status,'hard_canon'::public.canon_status) and m.review_due_at is not null and p_as_of<m.review_due_at and (p_task_class is null or m.metadata->>'taskClass'=p_task_class) and (p_provider is null or m.metadata->>'provider'=lower(trim(p_provider))) order by m.review_due_at asc,m.created_at desc;
$$;
revoke all on function public.memory_get_provider_performance_v1(text,uuid,text,text,timestamptz) from public,anon;
grant execute on function public.memory_get_provider_performance_v1(text,uuid,text,text,timestamptz) to authenticated,service_role;

create or replace function public.memory_record_provider_guidance_feedback_v1(p_namespace text,p_project_id uuid,p_memory_item_id uuid,p_routing_decision_id uuid,p_source_run_id uuid,p_outcome_status text,p_usefulness_delta numeric,p_evidence_ref text)
returns uuid language plpgsql security invoker set search_path='pg_catalog','public' as $$
declare v_user_id uuid:=auth.uid();v_item record;v_id uuid;
begin
 if v_user_id is null then raise exception 'authenticated user required' using errcode='28000'; end if;
 if p_namespace not in('real_life','au') or p_project_id is null or p_memory_item_id is null or p_routing_decision_id is null or p_source_run_id is null then raise exception 'complete feedback lineage required' using errcode='22023'; end if;
 if p_outcome_status not in('succeeded','failed','accepted','rejected','regressed','unknown') then raise exception 'invalid feedback outcome' using errcode='22023'; end if;
 if p_usefulness_delta is null or p_usefulness_delta< -1 or p_usefulness_delta>1 then raise exception 'usefulness delta out of range' using errcode='22023'; end if;
 if nullif(trim(p_evidence_ref),'') is null or length(p_evidence_ref)>500 or p_evidence_ref ~* '(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])' then raise exception 'invalid feedback evidence reference' using errcode='22023'; end if;
 select id,record_type,review_due_at,revoked_at,superseded_at,is_active into v_item from public.memory_items where id=p_memory_item_id and user_id=v_user_id and namespace=p_namespace::public.pandora_namespace and project_id=p_project_id and record_type in('provider_performance','routing_playbook_candidate');
 if not found then raise exception 'provider guidance not found in project scope' using errcode='P0002'; end if;
 insert into public.memory_feedback_events(user_id,namespace,candidate_id,action,review_note,reason,metadata,project_id,memory_item_id,routing_decision_id,source_run_id,outcome_status,usefulness_delta,evidence_ref)
 values(v_user_id,p_namespace,null,'provider_guidance_outcome',null,'routing guidance feedback evidence only',jsonb_build_object('recordType',v_item.record_type,'canonicalPolicyChanged',false,'wasStale',v_item.review_due_at is null or now()>=v_item.review_due_at,'wasRevoked',v_item.revoked_at is not null or v_item.is_active is false,'wasSuperseded',v_item.superseded_at is not null),p_project_id,p_memory_item_id,p_routing_decision_id,p_source_run_id,p_outcome_status,p_usefulness_delta,trim(p_evidence_ref)) returning id into v_id;
 return v_id;
end $$;
revoke all on function public.memory_record_provider_guidance_feedback_v1(text,uuid,uuid,uuid,uuid,text,numeric,text) from public,anon;
grant execute on function public.memory_record_provider_guidance_feedback_v1(text,uuid,uuid,uuid,uuid,text,numeric,text) to authenticated,service_role;

comment on function public.memory_ingest_model_outcome_candidate_v1(uuid,text,uuid,uuid,text,text,text,text,text,text,text,text,numeric,bigint,bigint,bigint,timestamptz,text[],text,text,text,timestamptz) is 'Service-only sanitized model outcome intake. Creates review-governed candidate evidence; never canonical Memory directly.';
comment on function public.memory_execute_approved_provider_learning_v1(uuid,uuid,text) is 'Authenticated, review-decision-gated append-only persistence for typed provider learning. Does not mutate routing policy.';
comment on function public.memory_propose_provider_performance_v1(text,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz) is 'Creates a provider-performance review candidate only from at least 3 captured outcomes with at least 2 verification passes.';
comment on function public.memory_propose_routing_playbook_v1(text,uuid,text,text,text,text,timestamptz) is 'Creates a review-required routing playbook candidate from fresh canonical provider-performance evidence. Never changes production routing.';
comment on function public.memory_get_provider_performance_v1(text,uuid,text,text,timestamptz) is 'Exact user/namespace/project-scoped retrieval of fresh canonical provider-performance knowledge only.';
comment on function public.memory_record_provider_guidance_feedback_v1(text,uuid,uuid,uuid,uuid,text,numeric,text) is 'Records evidence about whether retrieved provider guidance remained useful; does not auto-adjust canonical policy or confidence.';