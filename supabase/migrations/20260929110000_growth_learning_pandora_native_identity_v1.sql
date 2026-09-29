-- Replace the temporary ProjectOS growth-learning identity with the canonical Pandora service principal.
-- Review remains mandatory; can_approve remains false; no canonical Memory record is written here.
begin;

create or replace function public.memory_ingest_growth_learning_v1(
  p_memory_user_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','extensions'
as $function$
declare
  v_binding jsonb;
  v_source_scope jsonb;
  v_target jsonb;
  v_candidate jsonb;
  v_project public.pandora_projects%rowtype;
  v_principal public.pandora_service_principals%rowtype;
  v_grant public.pandora_project_grants%rowtype;
  v_source_ref text;
  v_evidence_refs text[];
  v_candidate_id uuid;
  v_review_item_id uuid;
  v_existing public.memory_capture_candidates%rowtype;
  v_existing_review public.memory_review_queue_items%rowtype;
  v_deduplicated boolean := false;
  v_expected_context_hash text;
  v_expected_content_hash text;
  v_request_hash text;
  v_request_bytes bytea;
  v_expected_request_id text;
begin
  if p_memory_user_id is null or jsonb_typeof(p_payload) is distinct from 'object'
    or octet_length(p_payload::text)>131072
    or not (p_payload ?& array[
      'schema_version','product_key','source_event_id','source_request_id',
      'organization_id','intake_id','project_id','project_key','tool','risk',
      'outcome_status','duration_ms','completed_at','context_status','context_hash',
      'result_fingerprint','error_fingerprint','privacy_policy','learning_kind',
      'growth_learning'
    ])
    or p_payload - array[
      'schema_version','product_key','source_event_id','source_request_id',
      'organization_id','intake_id','project_id','project_key','tool','risk',
      'outcome_status','duration_ms','completed_at','context_status','context_hash',
      'result_fingerprint','error_fingerprint','privacy_policy','learning_kind',
      'growth_learning'
    ] <> '{}'::jsonb then
    raise exception 'GROWTH_LEARNING_PAYLOAD_INVALID' using errcode='22023';
  end if;

  v_binding:=p_payload->'growth_learning';
  if jsonb_typeof(v_binding) is distinct from 'object'
    or not (v_binding ?& array['schema_version','source_scope','target_memory','candidate'])
    or v_binding-array['schema_version','source_scope','target_memory','candidate']<>'{}'::jsonb then
    raise exception 'GROWTH_LEARNING_BINDING_INVALID' using errcode='22023';
  end if;
  if v_binding::text ~* '(authorization[[:space:]]*[:=][[:space:]]*(bearer|basic)|github_pat_|gh[pousr]_[a-z0-9_]{16,}|sb_secret_|AIza[a-z0-9_-]{20,}|sk-[a-z0-9_-]{16,}|-----BEGIN [^-]*PRIVATE KEY)' then
    raise exception 'GROWTH_LEARNING_SENSITIVE_MATERIAL_REJECTED' using errcode='22023';
  end if;
  v_source_scope:=v_binding->'source_scope';
  v_target:=v_binding->'target_memory';
  v_candidate:=v_binding->'candidate';
  if jsonb_typeof(v_source_scope) is distinct from 'object'
    or not (v_source_scope ?& array['organization_id','project_id'])
    or v_source_scope-array['organization_id','project_id']<>'{}'::jsonb
    or jsonb_typeof(v_target) is distinct from 'object'
    or not (v_target ?& array['project_id','project_key','namespace','principal_key','environment'])
    or v_target-array['project_id','project_key','namespace','principal_key','environment']<>'{}'::jsonb
    or jsonb_typeof(v_candidate) is distinct from 'object'
    or not (v_candidate ?& array[
      'schema_version','learning_kind','source_event_id','organization_id','project_id',
      'subject_key','claim_kind','claim','observed_at','effective_at','review_due_at',
      'expires_at','confidence','confidence_basis','authority_kind','authority_ref',
      'provenance','evidence_refs','supersession','content_hash','review_required',
      'canonical_memory_written'
    ])
    or v_candidate-array[
      'schema_version','learning_kind','source_event_id','organization_id','project_id',
      'subject_key','claim_kind','claim','observed_at','effective_at','review_due_at',
      'expires_at','confidence','confidence_basis','authority_kind','authority_ref',
      'provenance','evidence_refs','supersession','content_hash','review_required',
      'canonical_memory_written'
    ]<>'{}'::jsonb then
    raise exception 'GROWTH_LEARNING_BINDING_INVALID' using errcode='22023';
  end if;

  if p_payload->'schema_version' is distinct from '1'::jsonb
    or p_payload->>'product_key' is distinct from 'pandora'
    or p_payload->>'learning_kind' is distinct from 'growth_learning_v1'
    or p_payload->>'tool' is distinct from 'facebook.growth_learning'
    or p_payload->>'risk' is distinct from 'write'
    or p_payload->>'outcome_status' is distinct from 'completed'
    or p_payload->'duration_ms' is distinct from '0'::jsonb
    or p_payload->>'context_status' is distinct from 'available'
    or p_payload->>'privacy_policy' is distinct from 'metadata_only_v1'
    or p_payload->'intake_id' is distinct from 'null'::jsonb
    or p_payload->'error_fingerprint' is distinct from 'null'::jsonb
    or p_payload->>'source_event_id' is distinct from p_payload->>'source_request_id'
    or not coalesce(p_payload->>'source_event_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',false)
    or not coalesce(p_payload->>'context_hash' ~ '^[0-9a-f]{64}$',false)
    or not coalesce(p_payload->>'result_fingerprint' ~ '^[0-9a-f]{64}$',false)
    or p_payload->>'completed_at' is distinct from v_candidate->>'observed_at'
    or p_payload->>'result_fingerprint' is distinct from v_candidate->>'content_hash'
    or p_payload->>'organization_id' is distinct from v_candidate->>'organization_id'
    or p_payload->>'project_id' is distinct from '7c686cbd-d968-49d5-86cc-918f5e777bd2'
    or p_payload->>'project_key' is distinct from 'mcpmaster-pandoras-box'
    or v_binding->>'schema_version' is distinct from 'growth-learning-outbox-binding-v1'
    or v_source_scope->>'organization_id' is distinct from v_candidate->>'organization_id'
    or v_source_scope->>'project_id' is distinct from v_candidate->>'project_id'
    or v_target->>'project_id' is distinct from '7c686cbd-d968-49d5-86cc-918f5e777bd2'
    or v_target->>'project_key' is distinct from 'mcpmaster-pandoras-box'
    or v_target->>'namespace' is distinct from 'real_life'
    or v_target->>'principal_key' is distinct from 'pandora-mcpmaster-production'
    or v_target->>'environment' is distinct from 'production'
    or v_candidate->>'schema_version' is distinct from 'growth-learning-candidate-v1'
    or v_candidate->>'learning_kind' is distinct from 'growth_learning_v1'
    or v_candidate->'review_required' is distinct from 'true'::jsonb
    or v_candidate->'canonical_memory_written' is distinct from 'false'::jsonb
    or not coalesce(v_candidate->>'organization_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',false)
    or not coalesce(v_candidate->>'project_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',false)
    or not coalesce(v_candidate->>'source_event_id' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false)
    or not coalesce(v_candidate->>'subject_key' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false)
    or not coalesce(length(trim(v_candidate->>'claim')) between 1 and 1800,false)
    or v_candidate->>'claim' is distinct from btrim(v_candidate->>'claim')
    or not coalesce(length(trim(v_candidate->>'confidence_basis')) between 1 and 1000,false)
    or v_candidate->>'confidence_basis' is distinct from btrim(v_candidate->>'confidence_basis')
    or not coalesce(v_candidate->>'claim_kind' in ('verified_fact','user_decision','provider_evidence','inference','assumption','superseded'),false)
    or jsonb_typeof(v_candidate->'confidence') is distinct from 'number'
    or (v_candidate->>'confidence')::numeric not between 0 and 1
    or (v_candidate->>'claim_kind'='assumption' and (v_candidate->>'confidence')::numeric>0.5)
    or jsonb_typeof(v_candidate->'provenance') is distinct from 'object'
    or jsonb_typeof(v_candidate->'evidence_refs') is distinct from 'array'
    or jsonb_array_length(v_candidate->'evidence_refs')>32
    or not coalesce(v_candidate->>'content_hash' ~ '^[0-9a-f]{64}$',false) then
    raise exception 'GROWTH_LEARNING_CONTRACT_INVALID' using errcode='22023';
  end if;

  if not coalesce(v_candidate->>'observed_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false)
    or not coalesce(v_candidate->>'effective_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false)
    or not coalesce(v_candidate->>'review_due_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false)
    or not (
      v_candidate->'expires_at'='null'::jsonb
      or coalesce(v_candidate->>'expires_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false)
    )
    or not coalesce(v_candidate->>'authority_ref' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false)
    or jsonb_typeof(v_candidate->'provenance') is distinct from 'object'
    or not ((v_candidate->'provenance') ?& array['source_type','source_locator','source_sha','observed_at'])
    or (v_candidate->'provenance')-array['source_type','source_locator','source_sha','observed_at']<>'{}'::jsonb
    or not coalesce(v_candidate#>>'{provenance,source_type}' in ('provider','document','repository','owner','verification','model'),false)
    or not coalesce(length(trim(v_candidate#>>'{provenance,source_locator}')) between 1 and 1000,false)
    or v_candidate#>>'{provenance,source_locator}' is distinct from
      btrim(v_candidate#>>'{provenance,source_locator}')
    or not (
      v_candidate#>'{provenance,source_sha}'='null'::jsonb
      or (coalesce(v_candidate#>>'{provenance,source_sha}' ~ '^[0-9a-fA-F]{7,64}$',false)
        and v_candidate#>>'{provenance,source_sha}' is not distinct from
          btrim(v_candidate#>>'{provenance,source_sha}'))
    )
    or not coalesce(v_candidate#>>'{provenance,observed_at}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false)
    or exists (
      select 1 from jsonb_array_elements(v_candidate->'evidence_refs') e(value)
      where jsonb_typeof(value) is distinct from 'object'
        or not (value ?& array['type','ref'])
        or value-array['type','ref','sha256','artifact_class','observed_at']<>'{}'::jsonb
        or not coalesce(value->>'type' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false)
        or not coalesce(length(trim(value->>'ref')) between 1 and 1000,false)
        or value->>'ref' is distinct from btrim(value->>'ref')
        or (value ? 'sha256' and not coalesce(value->>'sha256' ~ '^[0-9a-fA-F]{64}$',false))
        or (value ? 'sha256' and value->>'sha256' is distinct from lower(value->>'sha256'))
        or (value ? 'artifact_class' and not coalesce(value->>'artifact_class' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false))
        or (value ? 'observed_at' and not coalesce(value->>'observed_at' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$',false))
    ) then
    raise exception 'GROWTH_LEARNING_NESTED_CONTRACT_INVALID' using errcode='22023';
  end if;

  -- Phase A is authorized only for the D004 Pandora source tenant/project.
  -- Reject any other internally consistent source scope before querying durable
  -- project, principal, grant, candidate, or review state.
  if p_payload->>'organization_id' is distinct from '2270b266-59da-4c39-bfd9-9f8d08352af0'
    or v_source_scope->>'organization_id' is distinct from '2270b266-59da-4c39-bfd9-9f8d08352af0'
    or v_candidate->>'organization_id' is distinct from '2270b266-59da-4c39-bfd9-9f8d08352af0'
    or v_source_scope->>'project_id' is distinct from 'ee282126-3f61-4058-8c92-2fedbfcecf1f'
    or v_candidate->>'project_id' is distinct from 'ee282126-3f61-4058-8c92-2fedbfcecf1f' then
    raise exception 'GROWTH_LEARNING_SOURCE_SCOPE_DENIED' using errcode='42501';
  end if;

  if not coalesce(case v_candidate->>'claim_kind'
      when 'verified_fact' then v_candidate->>'authority_kind' in ('provider_readback','independent_verification','authoritative_record')
      when 'user_decision' then v_candidate->>'authority_kind' in ('owner_decision','authorized_user_decision')
      when 'provider_evidence' then v_candidate->>'authority_kind'='provider_readback'
      when 'inference' then v_candidate->>'authority_kind'='model_inference'
      when 'assumption' then v_candidate->>'authority_kind'='assumption'
      when 'superseded' then v_candidate->>'authority_kind'='supersession'
      else false
    end,false) then
    raise exception 'GROWTH_LEARNING_AUTHORITY_INVALID' using errcode='22023';
  end if;

  v_expected_context_hash:=encode(extensions.digest(
    convert_to(private.pandora_canonical_json_v1(v_binding),'UTF8'),'sha256'
  ),'hex');
  v_request_hash:=encode(extensions.digest(
    convert_to('growth-learning-request-v1'||chr(10)||v_expected_context_hash,'UTF8'),
    'sha256'
  ),'hex');
  v_request_bytes:=decode(substr(v_request_hash,1,32),'hex');
  v_request_bytes:=set_byte(v_request_bytes,6,(get_byte(v_request_bytes,6)&15)|80);
  v_request_bytes:=set_byte(v_request_bytes,8,(get_byte(v_request_bytes,8)&63)|128);
  v_request_hash:=encode(v_request_bytes,'hex');
  v_expected_request_id:=substr(v_request_hash,1,8)||'-'||substr(v_request_hash,9,4)||'-'||
    substr(v_request_hash,13,4)||'-'||substr(v_request_hash,17,4)||'-'||substr(v_request_hash,21,12);
  if p_payload->>'context_hash' is distinct from v_expected_context_hash
    or p_payload->>'source_event_id' is distinct from v_expected_request_id then
    raise exception 'GROWTH_LEARNING_HASH_BINDING_INVALID' using errcode='22023';
  end if;

  begin
    if (v_candidate->>'effective_at')::timestamptz>(v_candidate->>'review_due_at')::timestamptz
      or (v_candidate->'expires_at'<>'null'::jsonb
        and (v_candidate->>'review_due_at')::timestamptz>(v_candidate->>'expires_at')::timestamptz) then
      raise exception 'GROWTH_LEARNING_VALIDITY_INVALID' using errcode='22023';
    end if;
  exception when invalid_datetime_format then
    raise exception 'GROWTH_LEARNING_VALIDITY_INVALID' using errcode='22023';
  end;

  if (v_candidate->>'claim_kind' in ('verified_fact','provider_evidence','superseded')
      and jsonb_array_length(v_candidate->'evidence_refs')=0)
    or (v_candidate->>'claim_kind'='assumption' and jsonb_array_length(v_candidate->'evidence_refs')<>0)
    or (v_candidate->>'claim_kind'='provider_evidence' and v_candidate#>>'{provenance,source_type}'<>'provider')
    or (v_candidate->>'claim_kind'='user_decision' and v_candidate#>>'{provenance,source_type}' not in ('owner','document'))
    or (v_candidate->>'claim_kind'='inference' and v_candidate#>>'{provenance,source_type}'<>'model')
    or (v_candidate->>'claim_kind'='superseded' and (
      jsonb_typeof(v_candidate->'supersession') is distinct from 'object'
      or not ((v_candidate->'supersession') ?& array['supersedes_ref','reason'])
      or (v_candidate->'supersession')-array['supersedes_ref','reason']<>'{}'::jsonb
      or not coalesce(v_candidate#>>'{supersession,supersedes_ref}' ~ '^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$',false)
      or not coalesce(length(trim(v_candidate#>>'{supersession,reason}')) between 3 and 1000,false)
      or v_candidate#>>'{supersession,reason}' is distinct from
        btrim(v_candidate#>>'{supersession,reason}')
    ))
    or (v_candidate->>'claim_kind'<>'superseded' and v_candidate->'supersession'<>'null'::jsonb) then
    raise exception 'GROWTH_LEARNING_EPISTEMIC_CLASS_INVALID' using errcode='22023';
  end if;

  v_expected_content_hash:=encode(extensions.digest(
    convert_to(private.pandora_growth_learning_content_json_v1(v_candidate),'UTF8'),
    'sha256'
  ),'hex');
  if v_candidate->>'content_hash' is distinct from v_expected_content_hash
    or p_payload->>'result_fingerprint' is distinct from v_expected_content_hash then
    raise exception 'GROWTH_LEARNING_CONTENT_HASH_INVALID' using errcode='22023';
  end if;

  select * into v_principal from public.pandora_service_principals
    where principal_key='pandora-mcpmaster-production'
      and memory_user_id=p_memory_user_id
      and environment='production'
      and is_active is true
      and 'real_life'=any(allowed_namespaces)
      and 'memory:write'=any(scopes)
    for share;
  if not found then
    raise exception 'GROWTH_LEARNING_SCOPE_DENIED' using errcode='42501';
  end if;

  select * into v_project from public.pandora_projects
    where id='7c686cbd-d968-49d5-86cc-918f5e777bd2'
      and project_key='mcpmaster-pandoras-box'
      and memory_namespace='real_life'
      and lifecycle_status='active'
    for share;
  if not found then
    raise exception 'GROWTH_LEARNING_SCOPE_DENIED' using errcode='42501';
  end if;

  select * into v_grant from public.pandora_project_grants
    where principal_key='pandora-mcpmaster-production'
      and project_id=v_project.id
      and environment='production'
      and is_active is true
      and revoked_at is null
    for share;
  if not found or v_grant.can_propose is distinct from true
    or v_grant.can_approve is distinct from false then
    raise exception 'GROWTH_LEARNING_GRANT_DENIED' using errcode='42501';
  end if;

  v_source_ref:='growth-learning:'||encode(extensions.digest(
    convert_to(concat_ws('|',v_candidate->>'organization_id',v_candidate->>'project_id',v_candidate->>'source_event_id'),'UTF8'),
    'sha256'
  ),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_source_ref,0));

  select * into v_existing from public.memory_capture_candidates
    where user_id=p_memory_user_id and namespace='real_life'
      and project_id=v_project.id and source='pandora-post-task'
      and source_ref=v_source_ref;
  if found then
    if v_existing.metadata->>'intake_kind'<>'growth_learning_v1'
      or v_existing.metadata->>'context_hash' is distinct from p_payload->>'context_hash'
      or v_existing.metadata->>'content_hash' is distinct from v_candidate->>'content_hash'
      or v_existing.metadata->'growth_learning' is distinct from v_binding then
      raise exception 'GROWTH_LEARNING_IDEMPOTENCY_CONFLICT' using errcode='22023';
    end if;
    v_candidate_id:=v_existing.id;
    select * into v_existing_review from public.memory_review_queue_items
      where user_id=p_memory_user_id and namespace='real_life'
        and candidate_type='pandora_outcome' and source_ref=v_source_ref;
    if not found
      or v_existing_review.source_metadata->>'candidateId' is distinct from v_candidate_id::text
      or v_existing_review.audit_metadata->>'contentHash' is distinct from v_candidate->>'content_hash'
      or v_existing_review.status<>'pending_review' then
      raise exception 'GROWTH_LEARNING_REPLAY_LINEAGE_INVALID' using errcode='55000';
    end if;
    v_review_item_id:=v_existing_review.id;
    v_deduplicated:=true;
  else
    select coalesce(array_agg(value->>'ref' order by ordinal),'{}'::text[])
      into v_evidence_refs
    from jsonb_array_elements(v_candidate->'evidence_refs') with ordinality as e(value,ordinal);

    insert into public.memory_capture_candidates(
      user_id,namespace,source,source_ref,raw_excerpt,redacted_excerpt,memory_type,
      title,summary,importance,sensitivity,confidence,should_capture,requires_review,
      status,reason,people,projects,risks,tags,metadata,project_id,record_type,
      source_run_ids,evidence_refs,evidence_window_start,evidence_window_end,
      source_system,review_due_at
    ) values (
      p_memory_user_id,'real_life','pandora-post-task',v_source_ref,null,
      v_candidate->>'claim','business_fact',
      left('Growth learning: '||(v_candidate->>'subject_key'),240),
      v_candidate->>'claim',8,'low',(v_candidate->>'confidence')::numeric,
      true,true,'pending',
      'Growth learning remains a review candidate until separately approved and promoted.',
      '[]'::jsonb,jsonb_build_array('mcpmaster-pandoras-box'),'[]'::jsonb,
      jsonb_build_array('pandora','growth_learning',v_candidate->>'claim_kind'),
      jsonb_build_object(
        'schema_version',1,'intake_kind','growth_learning_v1',
        'project_id',v_project.id,'project_key',v_project.project_key,
        'principal_key','pandora-mcpmaster-production','environment','production',
        'source_event_id',p_payload->>'source_event_id',
        'context_hash',p_payload->>'context_hash',
        'content_hash',v_candidate->>'content_hash',
        'growth_learning',v_binding,
        'review_required',true,'canonical_memory_written',false,
        'promotion_status','not_promoted','retrieval_status','not_retrievable'
      ),
      v_project.id,'memory_candidate',array[(p_payload->>'source_event_id')::uuid],
      v_evidence_refs,(v_candidate->>'observed_at')::timestamptz,
      (v_candidate->>'observed_at')::timestamptz,'pandora-growth-learning',
      (v_candidate->>'review_due_at')::timestamptz
    ) returning id into v_candidate_id;

    insert into public.memory_review_queue_items(
      user_id,namespace,status,candidate_type,normalized_text,evidence_snapshot,
      sensitivity_snapshot,namespace_snapshot,source_metadata,audit_metadata,
      append_only,proposed_operation,requires_review,source_ref,request_hash,
      fingerprint,persistence_execution_metadata
    ) values (
      p_memory_user_id,'real_life','pending_review','pandora_outcome',
      v_candidate->>'claim',
      jsonb_build_object(
        'hasEvidence',jsonb_array_length(v_candidate->'evidence_refs')>0,
        'candidateId',v_candidate_id,'claimKind',v_candidate->>'claim_kind',
        'authorityKind',v_candidate->>'authority_kind',
        'authorityRef',v_candidate->>'authority_ref',
        'provenance',v_candidate->'provenance',
        'evidenceRefs',v_candidate->'evidence_refs',
        'supersession',v_candidate->'supersession',
        'validity',jsonb_build_object(
          'effectiveAt',v_candidate->>'effective_at',
          'reviewDueAt',v_candidate->>'review_due_at',
          'expiresAt',v_candidate->'expires_at'
        )
      ),
      jsonb_build_object(
        'classification','low','containsSecrets',false,'containsPersonalData',false,
        'containsRawArguments',false,'containsRawResults',false,'containsRawErrors',false
      ),
      jsonb_build_object(
        'sourceNamespace','real_life','targetNamespace','real_life','namespaceMatch',true,
        'sourceOrganizationId',v_candidate->>'organization_id',
        'sourceProjectId',v_candidate->>'project_id'
      ),
      jsonb_build_object(
        'source','pandora-post-task','sourceKind','growth_learning_v1',
        'sourceRef',v_source_ref,'candidateId',v_candidate_id,
        'projectId',v_project.id,'projectKey',v_project.project_key,
        'sourceEventId',p_payload->>'source_event_id',
        'learningId',v_candidate->>'source_event_id'
      ),
      jsonb_build_object(
        'schemaVersion',1,'candidateId',v_candidate_id,'appendOnly',true,
        'reviewRequired',true,'contextHash',p_payload->>'context_hash',
        'contentHash',v_candidate->>'content_hash',
        'canonicalMemoryWritten',false,'promotionStatus','not_promoted',
        'retrievalStatus','not_retrievable','atomicIntake','growth_learning_v1'
      ),
      true,'append',true,v_source_ref,p_payload->>'context_hash',
      v_candidate->>'content_hash','{}'::jsonb
    ) returning id into v_review_item_id;
  end if;

  if (select count(*) from public.memory_capture_candidates
      where user_id=p_memory_user_id and namespace='real_life'
        and project_id=v_project.id and source='pandora-post-task'
        and source_ref=v_source_ref)<>1
    or (select count(*) from public.memory_review_queue_items
      where user_id=p_memory_user_id and namespace='real_life'
        and candidate_type='pandora_outcome' and source_ref=v_source_ref)<>1 then
    raise exception 'GROWTH_LEARNING_LINEAGE_INVALID' using errcode='55000';
  end if;

  return jsonb_build_object(
    'ok',true,'status','pending_review',
    'source_event_id',p_payload->>'source_event_id',
    'learning_id',v_candidate->>'source_event_id',
    'content_hash',v_candidate->>'content_hash',
    'candidate_id',v_candidate_id,'review_item_id',v_review_item_id,
    'review_required',true,'canonical_memory_written',false,
    'promotion_status','not_promoted','retrieval_status','not_retrievable',
    'deduplicated',v_deduplicated
  );
end;
$function$;

revoke all on function public.memory_ingest_growth_learning_v1(uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.memory_ingest_growth_learning_v1(uuid,jsonb)
  to service_role;

comment on function public.memory_ingest_growth_learning_v1(uuid,jsonb) is
  'Service-only FB026 Phase A growth_learning_v1 intake. Atomically creates one review-required candidate and review item;

commit;
