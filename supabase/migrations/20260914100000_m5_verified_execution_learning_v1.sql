-- M5-003: promote verified continuous-execution outcomes into review-governed typed Memory proposals.
-- Source-only, additive, fail-closed. This migration never writes canonical Memory directly,
-- never upgrades inference into authority, and never expands a project grant.

create unique index if not exists memory_capture_candidates_verified_execution_learning_unique
  on public.memory_capture_candidates(user_id,namespace,project_id,source,source_ref)
  where source='pandora-verified-execution';

create or replace function public.memory_ingest_verified_execution_learning_v1(
  p_memory_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_principal_key text,
  p_execution jsonb,
  p_learning_kind text,
  p_learning_summary text,
  p_promotion_basis text,
  p_confidence numeric,
  p_incident_verification_ref text default null,
  p_additional_evidence_refs text[] default '{}'::text[]
) returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions'
as $function$
declare
  v_project public.pandora_projects%rowtype;
  v_grant public.pandora_project_grants%rowtype;
  v_job_id text;
  v_status text;
  v_summary text;
  v_verification_ref text;
  v_blocker_ref text;
  v_activity jsonb;
  v_evidence_refs text[] := '{}'::text[];
  v_all_evidence_refs text[] := '{}'::text[];
  v_authority_kind text;
  v_authority_ref text;
  v_source_ref text;
  v_fingerprint text;
  v_candidate_id uuid;
  v_review_item_id uuid;
  v_existing_candidate uuid;
  v_existing_review uuid;
  v_observed_at timestamptz := now();
begin
  if p_memory_user_id is null or p_project_id is null then
    raise exception 'verified execution learning requires memory user and project' using errcode='22023';
  end if;
  if p_namespace not in ('real_life','au') then
    raise exception 'invalid memory namespace' using errcode='22023';
  end if;
  if nullif(trim(coalesce(p_principal_key,'')),'') is null or length(p_principal_key)>180 then
    raise exception 'exact proposing principal required' using errcode='22023';
  end if;
  if p_execution is null or jsonb_typeof(p_execution)<>'object'
     or p_execution->>'contractVersion'<>'pandora-continuous-execution-v2' then
    raise exception 'verified execution learning requires M1 continuous-execution v2' using errcode='22023';
  end if;
  if octet_length(p_execution::text)>131072 then
    raise exception 'execution evidence envelope too large' using errcode='22023';
  end if;
  if p_execution::text ~* '(authorization[[:space:]]*:[[:space:]]*(bearer|basic)|github_pat_|gh[pousr]_[a-z0-9_]{20,}|sk-[a-z0-9_-]{20,}|private key)' then
    raise exception 'credential-like execution evidence rejected' using errcode='22023';
  end if;
  if p_learning_kind not in ('fact','procedure','failure_lesson','outcome') then
    raise exception 'unsupported M5 verified-execution learning kind' using errcode='22023';
  end if;
  if nullif(trim(coalesce(p_learning_summary,'')),'') is null or length(p_learning_summary)>2000
     or nullif(trim(coalesce(p_promotion_basis,'')),'') is null or length(p_promotion_basis)>4096 then
    raise exception 'bounded learning summary and promotion basis required' using errcode='22023';
  end if;
  if p_confidence is null or p_confidence<0 or p_confidence>1 then
    raise exception 'learning confidence out of range' using errcode='22023';
  end if;
  if concat_ws(' ',p_learning_summary,p_promotion_basis) ~* '(authorization[[:space:]]*:[[:space:]]*(bearer|basic)|github_pat_|gh[pousr]_[a-z0-9_]{20,}|sk-[a-z0-9_-]{20,}|private key)' then
    raise exception 'credential-like learning material rejected' using errcode='22023';
  end if;
  v_job_id:=nullif(trim(p_execution->>'jobId'),'');
  v_status:=nullif(trim(p_execution->>'status'),'');
  v_summary:=nullif(trim(p_execution->>'summary'),'');
  if v_job_id is null or length(v_job_id)>200 or v_job_id!~'^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$' then
    raise exception 'invalid continuous execution job identity' using errcode='22023';
  end if;
  if v_status not in ('result','blocked','failed','cancelled','needs_you')
     or v_summary is null or length(v_summary)>1000 then
    raise exception 'invalid continuous execution terminal shape' using errcode='22023';
  end if;
  if coalesce(jsonb_typeof(p_execution->'evidence'),'')<>'array' then
    raise exception 'bounded continuous execution evidence required' using errcode='22023';
  end if;
  if jsonb_array_length(p_execution->'evidence')=0
     or jsonb_array_length(p_execution->'evidence')>500 then
    raise exception 'bounded continuous execution evidence required' using errcode='22023';
  end if;

  select coalesce(array_agg(distinct btrim(e->>'ref') order by btrim(e->>'ref')),'{}'::text[])
    into v_evidence_refs
  from jsonb_array_elements(p_execution->'evidence') e
  where jsonb_typeof(e)='object' and nullif(btrim(e->>'ref'),'') is not null;
  if cardinality(v_evidence_refs)<>jsonb_array_length(p_execution->'evidence') then
    raise exception 'every continuous execution evidence item requires an exact ref' using errcode='22023';
  end if;
  if exists(select 1 from unnest(v_evidence_refs) r where length(r)>500 or r~*'(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])') then
    raise exception 'unsafe execution evidence reference' using errcode='22023';
  end if;
  if p_learning_kind in ('fact','procedure','outcome') then
    if v_status<>'result' or coalesce((p_execution->>'verified')::boolean,false) is not true then
      raise exception 'successful learning requires a verified M1 result' using errcode='22023';
    end if;
    v_verification_ref:=nullif(trim(p_execution->'verification'->>'verificationReceiptRef'),'');
    v_activity:=p_execution->'activityProjection';
    if v_verification_ref is null or coalesce(jsonb_typeof(v_activity),'')<>'object' then
      raise exception 'verified result requires exact verification evidence' using errcode='22023';
    end if;
    if v_activity->>'state'<>'result' or v_activity->>'jobId'<>v_job_id then
      raise exception 'verified result requires matching Activity Theatre result' using errcode='22023';
    end if;
    if not (v_verification_ref=any(v_evidence_refs)) then
      raise exception 'verification receipt must be present in M1 execution evidence' using errcode='22023';
    end if;
    if not exists(
      select 1 from jsonb_array_elements(coalesce(v_activity->'evidenceRefs','[]'::jsonb)) x
      where x->>'type'='verification_receipt'
        and x->>'relation'='verification'
        and x->>'ref'=v_verification_ref
    ) then
      raise exception 'Activity Theatre result must bind exact verification receipt' using errcode='22023';
    end if;
  elsif p_learning_kind='failure_lesson' then
    if v_status not in ('failed','blocked') or coalesce((p_execution->>'verified')::boolean,false) is true then
      raise exception 'failure lesson requires a non-success terminal incident' using errcode='22023';
    end if;
    v_blocker_ref:=nullif(trim(p_execution->'blocker'->>'evidenceRef'),'');
    if v_blocker_ref is null or not (v_blocker_ref=any(v_evidence_refs)) then
      raise exception 'failure lesson requires exact blocker evidence from the M1 result' using errcode='22023';
    end if;
    if nullif(trim(coalesce(p_incident_verification_ref,'')),'') is null
       or length(p_incident_verification_ref)>500
       or p_incident_verification_ref~*'(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])' then
      raise exception 'failure lesson requires independent incident verification evidence' using errcode='22023';
    end if;
  end if;

  if exists(
    select 1 from unnest(coalesce(p_additional_evidence_refs,'{}'::text[])) r
    where nullif(trim(r),'') is null or length(r)>500
       or r~*'(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])'
  ) then
    raise exception 'unsafe additional evidence reference' using errcode='22023';
  end if;
  v_all_evidence_refs:=array(
    select distinct r from unnest(
      v_evidence_refs||coalesce(p_additional_evidence_refs,'{}'::text[])||
      case when p_learning_kind='failure_lesson' then array[trim(p_incident_verification_ref)] else '{}'::text[] end
    ) r order by r
  );
  select * into v_project
  from public.pandora_projects p
  where p.id=p_project_id
    and p.lifecycle_status='active'
    and p.memory_namespace=p_namespace;
  if not found then
    raise exception 'verified execution learning project is not active in namespace' using errcode='42501';
  end if;

  select * into v_grant
  from public.pandora_project_grants g
  where g.principal_key=trim(p_principal_key)
    and g.project_id=p_project_id
    and g.environment='production'
    and g.is_active is true
    and g.can_propose is true
    and g.revoked_at is null
    and p_learning_kind=any(coalesce(g.allowed_record_types,'{}'::text[]))
  limit 1;
  if not found then
    raise exception 'verified execution learning not allowed by exact project grant' using errcode='42501';
  end if;

  v_authority_kind:=case p_learning_kind
    when 'procedure' then 'verified_outcome'
    when 'failure_lesson' then 'verified_incident'
    else 'verified_evidence'
  end;
  v_authority_ref:=case when p_learning_kind='failure_lesson'
    then trim(p_incident_verification_ref) else v_verification_ref end;
  v_source_ref:=format('m1-job:%s:%s',v_job_id,p_learning_kind);
  v_fingerprint:=encode(extensions.digest(convert_to(concat_ws('|',
    p_memory_user_id::text,p_namespace,p_project_id::text,trim(p_principal_key),
    v_job_id,v_status,p_learning_kind,p_learning_summary,p_promotion_basis,
    v_authority_kind,v_authority_ref,array_to_string(v_all_evidence_refs,',')), 'utf8'),'sha256'),'hex');

  select c.id into v_existing_candidate
  from public.memory_capture_candidates c
  where c.user_id=p_memory_user_id
    and c.namespace::text=p_namespace
    and c.project_id=p_project_id
    and c.source='pandora-verified-execution'
    and c.source_ref=v_source_ref
  limit 1;
  if found then
    select r.id into v_existing_review
    from public.memory_review_queue_items r
    where r.user_id=p_memory_user_id and r.namespace=p_namespace
      and r.candidate_type='verified_execution_learning'
      and r.source_ref=v_source_ref
      and (r.source_metadata->>'candidateId')::uuid=v_existing_candidate
    order by r.created_at desc limit 1;
    if v_existing_review is null then
      raise exception 'verified execution learning lineage is incomplete' using errcode='23514';
    end if;
    return jsonb_build_object('candidateId',v_existing_candidate,'reviewItemId',v_existing_review,
      'idempotentReplay',true,'requiresReview',true,'canonicalMemoryWritten',false);
  end if;
  insert into public.memory_capture_candidates(
    user_id,namespace,source,source_ref,raw_excerpt,redacted_excerpt,memory_type,title,summary,
    importance,sensitivity,confidence,should_capture,requires_review,status,reason,people,projects,risks,tags,
    metadata,project_id,record_type,evidence_refs,evidence_window_start,evidence_window_end,source_system
  ) values (
    p_memory_user_id,p_namespace,'pandora-verified-execution',v_source_ref,null,p_learning_summary,
    'observation','Verified execution learning',p_learning_summary,
    case when p_learning_kind in ('procedure','failure_lesson') then 9 else 8 end,
    'internal',p_confidence,true,true,'pending','verified M1 execution learning proposal',
    '[]'::jsonb,jsonb_build_array(p_project_id::text),'[]'::jsonb,
    jsonb_build_array('m5-003','verified-execution',p_learning_kind),
    jsonb_build_object(
      'schemaVersion','m5.verified-execution-learning.v1','fingerprint',v_fingerprint,
      'principalKey',trim(p_principal_key),'jobId',v_job_id,'terminalStatus',v_status,
      'learningKind',p_learning_kind,'sourceContract','pandora-continuous-execution-v2',
      'verificationRef',v_verification_ref,'blockerRef',v_blocker_ref,'rawExecutionStored',false
    ),
    p_project_id,'verified_execution_learning',v_all_evidence_refs,v_observed_at,v_observed_at,
    'pandora-continuous-executor-v2'
  ) returning id into v_candidate_id;
  insert into public.memory_review_queue_items(
    user_id,namespace,status,candidate_type,normalized_text,evidence_snapshot,sensitivity_snapshot,
    namespace_snapshot,source_metadata,audit_metadata,append_only,proposed_operation,requires_review,
    source_ref,request_hash,fingerprint,proposed_record_type,proposed_authority_kind,proposed_authority_ref,
    proposed_confidence,proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
    proposed_promotion_basis,explicit_policy_authorization
  ) values (
    p_memory_user_id,p_namespace,'pending_review','verified_execution_learning',p_learning_summary,
    jsonb_build_object('hasEvidence',true,'jobId',v_job_id,'terminalStatus',v_status,
      'evidenceRefs',to_jsonb(v_all_evidence_refs),'verificationRef',v_verification_ref,
      'incidentVerificationRef',case when p_learning_kind='failure_lesson' then trim(p_incident_verification_ref) else null end),
    jsonb_build_object('sensitivity','internal','rawExecutionStored',false,'containsSecrets',false),
    jsonb_build_object('namespace',p_namespace,'projectId',p_project_id,'namespaceMatch',true),
    jsonb_build_object('candidateId',v_candidate_id,'projectId',p_project_id,'projectKey',v_project.project_key,
      'principalKey',trim(p_principal_key),'jobId',v_job_id,'terminalStatus',v_status,'learningKind',p_learning_kind,
      'sourceContract','pandora-continuous-execution-v2','fingerprint',v_fingerprint),
    jsonb_build_object('schemaVersion',1,'candidateId',v_candidate_id,'appendOnly',true,
      'reviewRequired',true,'authorizationEffect','none','canonicalMemoryWritten',false),
    true,'append',true,v_source_ref,v_fingerprint,v_fingerprint,p_learning_kind,v_authority_kind,v_authority_ref,
    p_confidence,v_observed_at,v_observed_at,
    jsonb_build_object(
      'sourceType','pandora_continuous_execution','sourceLocator',v_source_ref,
      'observedAt',v_observed_at,'semanticSource','observation',
      'jobId',v_job_id,'terminalStatus',v_status,'rawExecutionStored',false
    ),
    to_jsonb(v_all_evidence_refs),p_promotion_basis,false
  ) returning id into v_review_item_id;

  return jsonb_build_object(
    'candidateId',v_candidate_id,'reviewItemId',v_review_item_id,
    'recordType',p_learning_kind,'authorityKind',v_authority_kind,
    'idempotentReplay',false,'requiresReview',true,'canonicalMemoryWritten',false,
    'authorizationEffect','none','rawExecutionStored',false
  );
end;
$function$;

revoke all on function public.memory_ingest_verified_execution_learning_v1(
  uuid,text,uuid,text,jsonb,text,text,text,numeric,text,text[]
) from public,anon,authenticated;
grant execute on function public.memory_ingest_verified_execution_learning_v1(
  uuid,text,uuid,text,jsonb,text,text,text,numeric,text,text[]
) to service_role;

comment on function public.memory_ingest_verified_execution_learning_v1(
  uuid,text,uuid,text,jsonb,text,text,text,numeric,text,text[]
) is 'M5-003 service-only intake: validates final M1 continuous-execution truth and creates an append-only review-governed typed Memory proposal. No canonical Memory or authorization is created directly.';
