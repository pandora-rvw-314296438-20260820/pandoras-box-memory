\set ON_ERROR_STOP on

insert into public.pandora_service_principals(
  principal_key,memory_user_id,environment,allowed_namespaces,scopes,is_active
) values (
  'projectos-mcpmaster-production','99999999-9999-4999-8999-999999999999',
  'production',array['real_life'],array['memory:read','memory:write'],true
);
insert into public.pandora_projects(id,project_key,aliases,memory_namespace,lifecycle_status)
values (
  '7c686cbd-d968-49d5-86cc-918f5e777bd2','mcpmaster-pandoras-box',
  array['pandoras-box-memory'],'real_life','active'
);
insert into public.pandora_project_grants(
  principal_key,project_id,environment,allowed_record_types,
  can_read,can_propose,can_approve,is_active,revoked_at
) values (
  'projectos-mcpmaster-production','7c686cbd-d968-49d5-86cc-918f5e777bd2',
  'production','{}',true,true,false,true,null
);

create function public.test_growth_payload(
  p_kind text,
  p_learning_id text,
  p_content_hash text default null,
  p_claim text default 'A bounded growth learning candidate requires review.',
  p_source_organization_id uuid default '2270b266-59da-4c39-bfd9-9f8d08352af0',
  p_source_project_id uuid default 'ee282126-3f61-4058-8c92-2fedbfcecf1f'
) returns jsonb language plpgsql immutable as $$
declare
  authority_kind text;
  source_type text;
  refs jsonb;
  supersession jsonb;
  candidate jsonb;
  binding jsonb;
  context_hash text;
  request_hash text;
  request_bytes bytea;
  request_id uuid;
  computed_content_hash text;
begin
  authority_kind:=case p_kind
    when 'verified_fact' then 'independent_verification'
    when 'user_decision' then 'owner_decision'
    when 'provider_evidence' then 'provider_readback'
    when 'inference' then 'model_inference'
    when 'assumption' then 'assumption'
    when 'superseded' then 'supersession'
  end;
  source_type:=case p_kind
    when 'user_decision' then 'owner'
    when 'provider_evidence' then 'provider'
    when 'inference' then 'model'
    when 'assumption' then 'model'
    else 'verification'
  end;
  refs:=case when p_kind='assumption' then '[]'::jsonb else
    jsonb_build_array(jsonb_build_object(
      'type','provider_receipt','ref','provider:receipt:123',
      'sha256',repeat('c',64),'artifact_class','provider_readback',
      'observed_at','2026-09-29T00:00:00.000Z'
    )) end;
  supersession:=case when p_kind='superseded' then
    jsonb_build_object('supersedes_ref','growth:prior','reason','Newer evidence replaced the prior claim.')
    else 'null'::jsonb end;
  candidate:=jsonb_build_object(
    'schema_version','growth-learning-candidate-v1',
    'learning_kind','growth_learning_v1','source_event_id',p_learning_id,
    'organization_id',p_source_organization_id,
    'project_id',p_source_project_id,
    'subject_key','facebook.campaign.learning','claim_kind',p_kind,'claim',p_claim,
    'observed_at','2026-09-29T00:00:00.000Z',
    'effective_at','2026-09-29T00:00:00.000Z',
    'review_due_at','2026-10-29T00:00:00.000Z',
    'expires_at','2026-12-29T00:00:00.000Z',
    'confidence',case when p_kind='assumption' then 0.4 else 0.9 end,
    'confidence_basis','Bounded evidence classification retained from ProjectOS.',
    'authority_kind',authority_kind,'authority_ref','authority:receipt:123',
    'provenance',jsonb_build_object(
      'source_type',source_type,'source_locator','provider:source:123',
      'source_sha',repeat('d',40),'observed_at','2026-09-29T00:00:00.000Z'
    ),
    'evidence_refs',refs,'supersession',supersession,
    'content_hash',coalesce(p_content_hash,repeat('0',64)),'review_required',true,
    'canonical_memory_written',false
  );
  if p_content_hash is null then
    computed_content_hash:=encode(extensions.digest(
      convert_to(private.pandora_growth_learning_content_json_v1(candidate),'UTF8'),
      'sha256'
    ),'hex');
    candidate:=jsonb_set(candidate,'{content_hash}',to_jsonb(computed_content_hash));
  else
    computed_content_hash:=p_content_hash;
  end if;
  binding:=jsonb_build_object(
    'schema_version','growth-learning-outbox-binding-v1',
    'source_scope',jsonb_build_object(
      'organization_id',p_source_organization_id,
      'project_id',p_source_project_id
    ),
    'target_memory',jsonb_build_object(
      'project_id','7c686cbd-d968-49d5-86cc-918f5e777bd2',
      'project_key','mcpmaster-pandoras-box','namespace','real_life',
      'principal_key','projectos-mcpmaster-production','environment','production'
    ),
    'candidate',candidate
  );
  context_hash:=encode(extensions.digest(
    convert_to(private.pandora_canonical_json_v1(binding),'UTF8'),'sha256'
  ),'hex');
  request_hash:=encode(extensions.digest(
    convert_to('growth-learning-request-v1'||chr(10)||context_hash,'UTF8'),'sha256'
  ),'hex');
  request_bytes:=decode(substr(request_hash,1,32),'hex');
  request_bytes:=set_byte(request_bytes,6,(get_byte(request_bytes,6)&15)|80);
  request_bytes:=set_byte(request_bytes,8,(get_byte(request_bytes,8)&63)|128);
  request_hash:=encode(request_bytes,'hex');
  request_id:=(substr(request_hash,1,8)||'-'||substr(request_hash,9,4)||'-'||
    substr(request_hash,13,4)||'-'||substr(request_hash,17,4)||'-'||substr(request_hash,21,12))::uuid;
  return jsonb_build_object(
    'schema_version',1,'product_key','projectos','source_event_id',request_id,
    'source_request_id',request_id,
    'organization_id',p_source_organization_id,'intake_id',null,
    'project_id','7c686cbd-d968-49d5-86cc-918f5e777bd2',
    'project_key','mcpmaster-pandoras-box','tool','facebook.growth_learning',
    'risk','write','outcome_status','completed','duration_ms',0,
    'completed_at','2026-09-29T00:00:00.000Z','context_status','available',
    'context_hash',context_hash,'result_fingerprint',computed_content_hash,
    'error_fingerprint',null,'privacy_policy','metadata_only_v1',
    'learning_kind','growth_learning_v1','growth_learning',binding
  );
end $$;

do $$
declare
  kinds text[]:=array['verified_fact','user_decision','provider_evidence','inference','assumption','superseded'];
  kind text;
  result jsonb;
  ordinal integer:=0;
begin
  foreach kind in array kinds loop
    ordinal:=ordinal+1;
    result:=public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',
      public.test_growth_payload(
        kind,'learning-'||kind,null
      )
    );
    if result->>'status'<>'pending_review'
      or result->>'learning_id'<>'learning-'||kind
      or result->>'review_required'<>'true'
      or result->>'canonical_memory_written'<>'false'
      or result->>'promotion_status'<>'not_promoted'
      or result->>'retrieval_status'<>'not_retrievable'
      or result->>'deduplicated'<>'false'
      or (select count(*) from jsonb_object_keys(result))<>12 then
      raise exception 'exact response contract failed for %: %',kind,result;
    end if;
  end loop;
  if (select count(*) from public.memory_capture_candidates)<>6
    or (select count(*) from public.memory_review_queue_items)<>6
    or (select count(*) from public.memory_items)<>0 then
    raise exception 'six-class review-only intake count mismatch';
  end if;
  if exists(
    select 1 from public.memory_capture_candidates
    where metadata#>>'{growth_learning,candidate,claim_kind}' not in
      ('verified_fact','user_decision','provider_evidence','inference','assumption','superseded')
      or metadata->>'canonical_memory_written'<>'false'
      or metadata->>'promotion_status'<>'not_promoted'
      or metadata->>'retrieval_status'<>'not_retrievable'
  ) then raise exception 'epistemic class or lifecycle was not preserved'; end if;
end $$;

-- The valid fixture below is byte-for-byte equivalent to the canonical PR804
-- producer projection for this learning. Changing only its content digest and
-- then recomputing the enclosing context/request binding must still fail.
do $$
declare
  payload jsonb;
  context_hash text;
  request_hash text;
  request_bytes bytea;
  request_id text;
  before_candidates bigint;
  before_reviews bigint;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  payload:=public.test_growth_payload(
    'verified_fact','learning-content-digest-source',null
  );
  if encode(extensions.digest(convert_to('abc','UTF8'),'sha256'),'hex')=
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    and payload#>>'{growth_learning,candidate,content_hash}' is distinct from
      'cb7b1a97889cac11ec4883a8b304cce828e2a5a0ab97e6f784449dc3f98b4008' then
    raise exception 'SQL content projection diverged from canonical PR804 producer';
  end if;

  payload:=jsonb_set(
    payload,'{growth_learning,candidate,content_hash}',
    to_jsonb(repeat('f',64))
  );
  payload:=jsonb_set(payload,'{result_fingerprint}',to_jsonb(repeat('f',64)));
  context_hash:=encode(extensions.digest(
    convert_to(private.pandora_canonical_json_v1(payload->'growth_learning'),'UTF8'),
    'sha256'
  ),'hex');
  request_hash:=encode(extensions.digest(
    convert_to('growth-learning-request-v1'||chr(10)||context_hash,'UTF8'),
    'sha256'
  ),'hex');
  request_bytes:=decode(substr(request_hash,1,32),'hex');
  request_bytes:=set_byte(request_bytes,6,(get_byte(request_bytes,6)&15)|80);
  request_bytes:=set_byte(request_bytes,8,(get_byte(request_bytes,8)&63)|128);
  request_hash:=encode(request_bytes,'hex');
  request_id:=substr(request_hash,1,8)||'-'||substr(request_hash,9,4)||'-'||
    substr(request_hash,13,4)||'-'||substr(request_hash,17,4)||'-'||
    substr(request_hash,21,12);
  payload:=jsonb_set(payload,'{context_hash}',to_jsonb(context_hash));
  payload:=jsonb_set(payload,'{source_event_id}',to_jsonb(request_id));
  payload:=jsonb_set(payload,'{source_request_id}',to_jsonb(request_id));

  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected normalized content digest rejection';
  exception when sqlstate '22023' then
    if sqlerrm not like '%GROWTH_LEARNING_CONTENT_HASH_INVALID%' then raise; end if;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'content digest rejection changed persisted state';
  end if;
end $$;

do $$
declare first_result jsonb; replay_result jsonb; payload jsonb;
begin
  payload:=public.test_growth_payload(
    'verified_fact','learning-verified_fact',null
  );
  select jsonb_build_object(
    'candidate_id',c.id,'review_item_id',r.id
  ) into first_result
  from public.memory_capture_candidates c
  join public.memory_review_queue_items r on r.source_ref=c.source_ref
  where c.metadata#>>'{growth_learning,candidate,source_event_id}'='learning-verified_fact';
  replay_result:=public.memory_ingest_growth_learning_v1(
    '99999999-9999-4999-8999-999999999999',payload
  );
  if replay_result->>'deduplicated'<>'true'
    or replay_result->>'candidate_id'<>first_result->>'candidate_id'
    or replay_result->>'review_item_id'<>first_result->>'review_item_id'
    or (select count(*) from public.memory_capture_candidates)<>6
    or (select count(*) from public.memory_review_queue_items)<>6 then
    raise exception 'exact replay was not identity-safe';
  end if;
end $$;

do $$
declare payload jsonb; before_candidates bigint; before_reviews bigint;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  payload:=public.test_growth_payload(
    'verified_fact','learning-verified_fact',null,
    'Changed content for the same stable learning identity.'
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected idempotency conflict';
  exception when sqlstate '22023' then
    if sqlerrm not like '%GROWTH_LEARNING_IDEMPOTENCY_CONFLICT%' then raise; end if;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'conflict changed persisted row counts';
  end if;
end $$;

create function public.test_force_growth_review_failure()
returns trigger language plpgsql as $$
begin
  if new.source_metadata->>'learningId'='learning-atomic-fail' then
    raise exception 'forced review failure';
  end if;
  return new;
end $$;
create trigger test_force_growth_review_failure
before insert on public.memory_review_queue_items
for each row execute function public.test_force_growth_review_failure();

do $$
declare before_candidates bigint; before_reviews bigint;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',
      public.test_growth_payload(
        'verified_fact','learning-atomic-fail',null
      )
    );
    raise exception 'expected forced review failure';
  exception when others then
    if sqlerrm not like '%forced review failure%' then raise; end if;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'review failure left a partial candidate';
  end if;
end $$;

do $$
declare before_candidates bigint; before_reviews bigint; payload jsonb;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  payload:=public.test_growth_payload(
    'assumption','learning-bad-assumption',null
  );
  payload:=jsonb_set(payload,'{growth_learning,candidate,evidence_refs}',
    '[{"type":"provider_receipt","ref":"provider:bad"}]'::jsonb);
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected assumption evidence rejection';
  exception when sqlstate '22023' then null;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'invalid epistemic class changed state';
  end if;
end $$;

do $$
declare before_candidates bigint; before_reviews bigint; payload jsonb;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  payload:=public.test_growth_payload(
    'verified_fact','learning-wrong-org',null,
    'A fully rehashed but unauthorized organization must be denied.',
    '11111111-1111-4111-8111-111111111111',
    'ee282126-3f61-4058-8c92-2fedbfcecf1f'
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected wrong organization denial';
  exception when sqlstate '42501' then
    if sqlerrm not like '%GROWTH_LEARNING_SOURCE_SCOPE_DENIED%' then raise; end if;
  end;
  payload:=public.test_growth_payload(
    'verified_fact','learning-wrong-project',null,
    'A fully rehashed but unauthorized source project must be denied.',
    '2270b266-59da-4c39-bfd9-9f8d08352af0',
    '22222222-2222-4222-8222-222222222222'
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected wrong source project denial';
  exception when sqlstate '42501' then
    if sqlerrm not like '%GROWTH_LEARNING_SOURCE_SCOPE_DENIED%' then raise; end if;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'unauthorized source scope changed state';
  end if;
end $$;

do $$
declare before_candidates bigint; before_reviews bigint; payload jsonb;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  payload:=public.test_growth_payload(
    'verified_fact','learning-null-envelope',null
  );
  payload:=jsonb_set(payload,'{product_key}','null'::jsonb);
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected null envelope rejection';
  exception when sqlstate '22023' then null;
  end;
  payload:=public.test_growth_payload(
    'verified_fact','learning-authority-mismatch',null
  );
  payload:=jsonb_set(
    payload,'{growth_learning,candidate,authority_kind}',
    '"owner_decision"'::jsonb
  );
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',payload
    );
    raise exception 'expected authority mismatch rejection';
  exception when sqlstate '22023' then null;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'exact-envelope rejection changed state';
  end if;
end $$;

do $$
declare before_candidates bigint; before_reviews bigint;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',
      public.test_growth_payload(
        'verified_fact','learning-sensitive',null,
        'Authorization: Bearer synthetic-credential-shaped-material'
      )
    );
    raise exception 'expected sensitive material rejection';
  exception when sqlstate '22023' then
    if sqlerrm not like '%GROWTH_LEARNING_SENSITIVE_MATERIAL_REJECTED%' then raise; end if;
  end;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'sensitive material rejection changed state';
  end if;
end $$;

do $$
declare before_candidates bigint; before_reviews bigint;
begin
  select count(*) into before_candidates from public.memory_capture_candidates;
  select count(*) into before_reviews from public.memory_review_queue_items;
  update public.pandora_project_grants set can_approve=true;
  begin
    perform public.memory_ingest_growth_learning_v1(
      '99999999-9999-4999-8999-999999999999',
      public.test_growth_payload(
        'verified_fact','learning-grant-denied',null
      )
    );
    raise exception 'expected grant boundary rejection';
  exception when sqlstate '42501' then null;
  end;
  update public.pandora_project_grants set can_approve=false;
  if (select count(*) from public.memory_capture_candidates)<>before_candidates
    or (select count(*) from public.memory_review_queue_items)<>before_reviews then
    raise exception 'denied grant changed state';
  end if;
end $$;

do $$
begin
  if has_function_privilege('public','public.memory_ingest_growth_learning_v1(uuid,jsonb)','execute')
    or has_function_privilege('anon','public.memory_ingest_growth_learning_v1(uuid,jsonb)','execute')
    or has_function_privilege('authenticated','public.memory_ingest_growth_learning_v1(uuid,jsonb)','execute')
    or not has_function_privilege('service_role','public.memory_ingest_growth_learning_v1(uuid,jsonb)','execute') then
    raise exception 'growth learning RPC ACL mismatch';
  end if;
  if has_function_privilege('public','private.pandora_growth_learning_content_json_v1(jsonb)','execute')
    or has_function_privilege('anon','private.pandora_growth_learning_content_json_v1(jsonb)','execute')
    or has_function_privilege('authenticated','private.pandora_growth_learning_content_json_v1(jsonb)','execute')
    or has_function_privilege('service_role','private.pandora_growth_learning_content_json_v1(jsonb)','execute') then
    raise exception 'private content projection helper ACL mismatch';
  end if;
  if (select count(*) from public.memory_items)<>0 then
    raise exception 'Phase A wrote canonical Memory';
  end if;
end $$;

select 'growth_learning_intake_v1 PASS' as result;
