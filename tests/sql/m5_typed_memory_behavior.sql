-- Behavioral checks for M5-001 in disposable PostgreSQL CI.
\set ON_ERROR_STOP on

insert into public.memory_review_queue_items (
  id,user_id,namespace,status,append_only,proposed_operation,requires_review,
  proposed_record_type,proposed_authority_kind,proposed_authority_ref,
  proposed_confidence,proposed_observed_at,proposed_effective_at,
  proposed_provenance,proposed_evidence_refs,proposed_promotion_basis,
  explicit_policy_authorization
) values (
  '10000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append',true,'append',true,
  'pattern','inference','pattern:evidence:1',0.8000,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
  '{"sourceType":"verified_outcome","sourceLocator":"test:pattern","observedAt":"2026-09-13T14:00:00Z","semanticSource":"inference"}',
  '["evidence:pattern:1"]','Repeated verified behavior justifies advisory retrieval',false
);
insert into public.memory_review_queue_decisions (id,review_item_id,user_id,namespace,to_status)
values ('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append');
insert into public.memory_items (
  id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata
) values (
  '30000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','learning','Pattern','Pattern body','soft_canon',
  '{"reviewItemId":"10000000-0000-0000-0000-000000000001","reviewDecisionId":"20000000-0000-0000-0000-000000000001"}'
);

do $$
declare r public.memory_items%rowtype;
begin
  select * into r from public.memory_items where id='30000000-0000-0000-0000-000000000001';
  if r.knowledge_schema_version <> 'm5.v1'
     or r.record_type <> 'pattern'
     or r.authority_kind <> 'inference'
     or r.authority_ref <> 'pattern:evidence:1'
     or r.provenance->>'semanticSource' <> 'inference'
     or jsonb_array_length(r.evidence_refs) <> 1
     or r.observed_at is null
     or r.effective_at is null
     or r.promotion_basis is null
     or r.metadata->>'authorizationEffect' <> 'none' then
    raise exception 'pattern canonicalization contract failed';
  end if;
end $$;

-- Inference can never be promoted as policy authorization.
do $$
begin
  begin
    insert into public.memory_review_queue_items (
      id,user_id,namespace,status,append_only,proposed_operation,requires_review,
      proposed_record_type,proposed_authority_kind,proposed_authority_ref,
      proposed_confidence,proposed_observed_at,proposed_effective_at,
      proposed_provenance,proposed_evidence_refs,proposed_promotion_basis,
      explicit_policy_authorization
    ) values (
      '10000000-0000-0000-0000-000000000002','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append',true,'append',true,
      'policy','inference','bad:policy',0.9900,now(),now(),
      '{"sourceType":"model_output","sourceLocator":"test:bad-policy","observedAt":"2026-09-13T14:00:00Z","semanticSource":"inference"}',
      '["evidence:bad-policy"]','Must be rejected',true
    );
    raise exception 'invalid inferred policy unexpectedly accepted';
  exception when check_violation then
    null;
  end;
end $$;

-- Valid standing policy preserves the exact authority reference; review lineage is separate.
insert into public.memory_review_queue_items (
  id,user_id,namespace,status,append_only,proposed_operation,requires_review,
  proposed_record_type,proposed_authority_kind,proposed_authority_ref,
  proposed_confidence,proposed_observed_at,proposed_effective_at,
  proposed_provenance,proposed_evidence_refs,proposed_promotion_basis,
  explicit_policy_authorization
) values (
  '10000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append',true,'append',true,
  'policy','active_explicit_standing_policy','policy:fingerprint:abc',1.0000,now(),now(),
  '{"sourceType":"owner_policy","sourceLocator":"policy:fingerprint:abc","observedAt":"2026-09-13T14:00:00Z","semanticSource":"authoritative_policy"}',
  '["owner-decision:123"]','Explicit bounded standing policy',true
);
insert into public.memory_review_queue_decisions (id,review_item_id,user_id,namespace,to_status)
values ('20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append');
insert into public.memory_items (
  id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata
) values (
  '30000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','governance','Policy','Policy body','hard_canon',
  '{"reviewItemId":"10000000-0000-0000-0000-000000000003","reviewDecisionId":"20000000-0000-0000-0000-000000000003"}'
);
do $$
declare r public.memory_items%rowtype;
begin
  select * into r from public.memory_items where id='30000000-0000-0000-0000-000000000003';
  if r.authority_ref <> 'policy:fingerprint:abc'
     or r.authority_kind <> 'active_explicit_standing_policy'
     or r.metadata->>'authorizationEffect' <> 'requires_exact_runtime_scope_validity_revocation_validation' then
    raise exception 'policy authority/reference separation failed';
  end if;
end $$;

-- Build a fact predecessor and correction successor, then supersede append-only.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '10000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append',true,'append',true,
 'fact','provider_truth','provider:fact:old',1,now(),now(),
 '{"sourceType":"provider","sourceLocator":"provider:fact:old","observedAt":"2026-09-13T14:00:00Z","semanticSource":"observation"}',
 '["provider:receipt:old"]','Verified material fact',false
);
insert into public.memory_review_queue_decisions (id,review_item_id,user_id,namespace,to_status)
values ('20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append');
insert into public.memory_items (id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values ('30000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','fact','Fact old','old','hard_canon','{"reviewItemId":"10000000-0000-0000-0000-000000000004","reviewDecisionId":"20000000-0000-0000-0000-000000000004"}');

insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,proposed_correction_of,explicit_policy_authorization
) values (
 '10000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append',true,'append',true,
 'fact','provider_truth','provider:fact:new',1,now(),now(),
 '{"sourceType":"provider","sourceLocator":"provider:fact:new","observedAt":"2026-09-13T14:05:00Z","semanticSource":"observation"}',
 '["provider:receipt:new"]','Authoritative correction','30000000-0000-0000-0000-000000000004',false
);
insert into public.memory_review_queue_decisions (id,review_item_id,user_id,namespace,to_status)
values ('20000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','approved_for_append');
insert into public.memory_items (id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values ('30000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','project','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','fact','Fact corrected','new','hard_canon','{"reviewItemId":"10000000-0000-0000-0000-000000000005","reviewDecisionId":"20000000-0000-0000-0000-000000000005"}');

update public.memory_items
set superseded_by='30000000-0000-0000-0000-000000000005', superseded_at=now(), supersession_reason='Corrected by newer provider truth'
where id='30000000-0000-0000-0000-000000000004';

do $$
begin
  begin
    update public.memory_items set body='mutated' where id='30000000-0000-0000-0000-000000000005';
    raise exception 'semantic mutation unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;
  begin
    update public.memory_items set supersession_reason='rewritten reason' where id='30000000-0000-0000-0000-000000000004';
    raise exception 'supersession rewrite unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;
end $$;

select 'M5-001 disposable PostgreSQL behavior verification: PASS' as result;
