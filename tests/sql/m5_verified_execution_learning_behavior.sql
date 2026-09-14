\set ON_ERROR_STOP on

insert into public.pandora_projects(id,project_key,aliases,memory_namespace,lifecycle_status) values
('11111111-1111-4111-8111-111111111111','pandoras-box',array['box'],'real_life','active'),
('22222222-2222-4222-8222-222222222222','no-learning',array[]::text[],'real_life','active');

insert into public.pandora_project_grants(
  principal_key,project_id,environment,allowed_record_types,can_propose,is_active,revoked_at
) values
('pandora-runtime-production','11111111-1111-4111-8111-111111111111','production',
 array['fact','procedure','failure_lesson','outcome'],true,true,null),
('pandora-runtime-production','22222222-2222-4222-8222-222222222222','production',
 array['fact'],true,true,null);

select public.memory_ingest_verified_execution_learning_v1(
  '99999999-9999-4999-8999-999999999999','real_life',
  '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
  '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-success-1","status":"result","verified":true,"iterations":2,"summary":"Deployment verified.","evidence":[{"phase":"verify","iteration":2,"ref":"verification:job-success-1","actionId":null,"status":"verified"}],"observations":[],"actions":[],"blocker":null,"verification":{"verified":true,"verificationReceiptRef":"verification:job-success-1","summary":"Deployment verified.","progressMade":true,"retryable":false},"activityProjection":{"state":"result","jobId":"job-success-1","evidenceRefs":[{"type":"verification_receipt","relation":"verification","ref":"verification:job-success-1"}]}}'::jsonb,
  'procedure','Verified deploy then authoritative readback completes the job.',
  'A durable procedure is useful because the exact result and readback were independently verified.',
  0.95,null,array['provider-readback:deployment-1']
);

do $$
declare c record; r record;
begin
  select * into c from public.memory_capture_candidates
   where source_ref='m1-job:job-success-1:procedure';
  select * into r from public.memory_review_queue_items
   where source_ref='m1-job:job-success-1:procedure';
  if c.id is null or c.record_type<>'verified_execution_learning' then
    raise exception 'verified execution candidate missing';
  end if;
  if r.id is null or r.proposed_record_type<>'procedure'
     or r.proposed_authority_kind<>'verified_outcome'
     or r.proposed_authority_ref<>'verification:job-success-1'
     or r.explicit_policy_authorization is true then
    raise exception 'typed procedure review contract mismatch';
  end if;
  if r.audit_metadata->>'authorizationEffect'<>'none'
     or r.evidence_snapshot->>'hasEvidence'<>'true' then
    raise exception 'review evidence/authority boundary mismatch';
  end if;
  if (select count(*) from public.memory_items)<>0 then
    raise exception 'M5-003 must not write canonical Memory directly';
  end if;
end $$;

do $$
declare result jsonb;
begin
  result:=public.memory_ingest_verified_execution_learning_v1(
    '99999999-9999-4999-8999-999999999999','real_life',
    '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
    '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-success-1","status":"result","verified":true,"iterations":2,"summary":"Deployment verified.","evidence":[{"phase":"verify","iteration":2,"ref":"verification:job-success-1","actionId":null,"status":"verified"}],"observations":[],"actions":[],"blocker":null,"verification":{"verified":true,"verificationReceiptRef":"verification:job-success-1","summary":"Deployment verified.","progressMade":true,"retryable":false},"activityProjection":{"state":"result","jobId":"job-success-1","evidenceRefs":[{"type":"verification_receipt","relation":"verification","ref":"verification:job-success-1"}]}}'::jsonb,
    'procedure','Verified deploy then authoritative readback completes the job.',
    'A durable procedure is useful because the exact result and readback were independently verified.',
    0.95,null,array['provider-readback:deployment-1']);
  if result->>'idempotentReplay'<>'true'
     or (select count(*) from public.memory_capture_candidates where source_ref='m1-job:job-success-1:procedure')<>1
     or (select count(*) from public.memory_review_queue_items where source_ref='m1-job:job-success-1:procedure')<>1 then
    raise exception 'verified execution replay was not identity-safe';
  end if;
end $$;

select public.memory_ingest_verified_execution_learning_v1(
  '99999999-9999-4999-8999-999999999999','real_life',
  '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
  '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-failure-1","status":"blocked","verified":false,"iterations":3,"summary":"Provider write remained ambiguous.","evidence":[{"phase":"governed_execute","iteration":3,"ref":"provider-receipt:ambiguous-1","actionId":"deploy-1","status":"verification_required"}],"observations":[],"actions":[],"blocker":{"reasonCode":"ambiguous_effect_verification_required","summary":"Authoritative readback required.","evidenceRef":"provider-receipt:ambiguous-1","policyRef":"policy:deploy"},"verification":null,"activityProjection":null}'::jsonb,
  'failure_lesson','Ambiguous provider writes must be reconciled before retry.',
  'The blocked terminal result plus independent incident verification is a durable failure-prevention lesson.',
  0.98,'incident-verification:ambiguous-write-1',array['readback:ambiguous-write-1']
);

do $$
declare r record;
begin
  select * into r from public.memory_review_queue_items
   where source_ref='m1-job:job-failure-1:failure_lesson';
  if r.proposed_record_type<>'failure_lesson'
     or r.proposed_authority_kind<>'verified_incident'
     or r.proposed_authority_ref<>'incident-verification:ambiguous-write-1'
     or not (r.proposed_evidence_refs ? 'provider-receipt:ambiguous-1')
     or not (r.proposed_evidence_refs ? 'incident-verification:ambiguous-write-1') then
    raise exception 'failure lesson evidence binding mismatch';
  end if;
end $$;

do $$
begin
  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-unverified-1","status":"result","verified":false,"summary":"Claimed done.","evidence":[{"ref":"verification:missing"}]}'::jsonb,
      'procedure','Do not learn this.','No verified terminal truth exists.',0.9,null,'{}'::text[]);
    raise exception 'expected unverified result rejection';
  exception when sqlstate '22023' then null;
  end;

  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v1","jobId":"job-old-contract","status":"result","verified":true,"summary":"Old contract.","evidence":[{"ref":"verification:old"}]}'::jsonb,
      'fact','Do not learn old contracts.','Only the frozen M1 v2 terminal contract is accepted.',0.9,null,'{}'::text[]);
    raise exception 'expected old contract rejection';
  exception when sqlstate '22023' then null;
  end;
end $$;

do $$
begin
  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-failure-no-incident","status":"failed","verified":false,"summary":"Failed.","evidence":[{"ref":"failure:one"}],"blocker":{"evidenceRef":"failure:one"}}'::jsonb,
      'failure_lesson','Missing independent incident verification.','Must not promote from runtime failure alone.',0.9,null,'{}'::text[]);
    raise exception 'expected missing incident verification rejection';
  exception when sqlstate '22023' then null;
  end;

  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '22222222-2222-4222-8222-222222222222','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-disallowed-procedure","status":"result","verified":true,"summary":"Verified.","evidence":[{"ref":"verification:no-procedure"}],"verification":{"verificationReceiptRef":"verification:no-procedure"},"activityProjection":{"state":"result","jobId":"job-disallowed-procedure","evidenceRefs":[{"type":"verification_receipt","relation":"verification","ref":"verification:no-procedure"}]}}'::jsonb,
      'procedure','Grant does not allow procedure.','Exact project grant must bound proposal classes.',0.9,null,'{}'::text[]);
    raise exception 'expected disallowed record type rejection';
  exception when sqlstate '42501' then null;
  end;
end $$;

update public.pandora_project_grants
set revoked_at=now()
where principal_key='pandora-runtime-production'
  and project_id='11111111-1111-4111-8111-111111111111';

do $$
begin
  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-revoked","status":"result","verified":true,"summary":"Verified.","evidence":[{"ref":"verification:revoked"}],"verification":{"verificationReceiptRef":"verification:revoked"},"activityProjection":{"state":"result","jobId":"job-revoked","evidenceRefs":[{"type":"verification_receipt","relation":"verification","ref":"verification:revoked"}]}}'::jsonb,
      'fact','Revoked grant must block proposal.','Revocation must override prior successful evidence.',0.9,null,'{}'::text[]);
    raise exception 'expected revoked grant rejection';
  exception when sqlstate '42501' then null;
  end;
  if (select count(*) from public.memory_items)<>0 then
    raise exception 'canonical Memory was mutated by M5-003 intake';
  end if;
end $$;

select 'm5_verified_execution_learning_v1 PASS' as result;

do $$
begin
  begin
    perform public.memory_ingest_verified_execution_learning_v1(
      '99999999-9999-4999-8999-999999999999','real_life',
      '11111111-1111-4111-8111-111111111111','pandora-runtime-production',
      '{"contractVersion":"pandora-continuous-execution-v2","jobId":"job-no-evidence","status":"result","verified":true,"summary":"No evidence envelope."}'::jsonb,
      'fact','Missing evidence must fail closed.','No durable learning without exact execution evidence.',0.8,null,'{}'::text[]);
    raise exception 'expected missing evidence rejection';
  exception when sqlstate '22023' then null;
  end;
end $$;
