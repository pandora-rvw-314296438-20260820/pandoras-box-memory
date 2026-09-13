-- M5-002 task-aware retrieval behavior checks in disposable PostgreSQL.
\set ON_ERROR_STOP on

insert into public.pandora_projects(id,project_key,canonical_name,memory_namespace,lifecycle_status)
values
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','pandora','Pandora','real_life','active'),
 ('cccccccc-cccc-cccc-cccc-cccccccccccc','other','Other','real_life','active');

insert into public.pandora_project_grants(
  principal_key,project_id,environment,allowed_record_types,can_read,is_active
) values
 ('projectos-mcpmaster-production','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','production',
  array['fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance'],true,true),
 ('projectos-mcpmaster-production','cccccccc-cccc-cccc-cccc-cccccccccccc','production',
  array['fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance'],true,true);

-- Helper fixture: failure lesson relevant to deploy/retry.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '11000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append',true,'append',true,
 'failure_lesson','verified_incident','incident:ambiguous-write',0.95,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
 '{"sourceType":"provider_readback","sourceLocator":"github:write:ambiguous","observedAt":"2026-09-13T14:00:00Z","semanticSource":"observation"}',
 '["github:write:ambiguous","github:readback:confirmed"]',
 'When a consequential write response is ambiguous, read provider state before retrying.',false
);
insert into public.memory_review_queue_decisions(id,review_item_id,user_id,namespace,to_status)
values ('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append');
insert into public.memory_items(id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values (
 '31000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life',
 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','learning','Ambiguous write retry lesson',
 'For GitHub deploy writes, verify provider readback before retrying an ambiguous response.','hard_canon',
 '{"reviewItemId":"11000000-0000-0000-0000-000000000001","reviewDecisionId":"21000000-0000-0000-0000-000000000001"}'
);

-- Procedure relevant to deployment.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '11000000-0000-0000-0000-000000000002','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append',true,'append',true,
 'procedure','verified_outcome','procedure:deploy-readback',0.90,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
 '{"sourceType":"verified_outcome","sourceLocator":"procedure:deploy-readback","observedAt":"2026-09-13T14:00:00Z","semanticSource":"observation"}',
 '["test:deploy","provider:readback"]','Verified deployment procedure with rollback/readback evidence',false
);
insert into public.memory_review_queue_decisions(id,review_item_id,user_id,namespace,to_status)
values ('21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000002','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append');
insert into public.memory_items(id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values (
 '31000000-0000-0000-0000-000000000002','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life',
 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','learning','Deployment readback procedure',
 'Deploy, independently read provider state, and retain rollback evidence.','hard_canon',
 '{"reviewItemId":"11000000-0000-0000-0000-000000000002","reviewDecisionId":"21000000-0000-0000-0000-000000000002"}'
);

-- Explicit standing policy, kept separate from advisory Memory.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '11000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append',true,'append',true,
 'policy','active_explicit_standing_policy','policy:github-write-route',1,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
 '{"sourceType":"owner_policy","sourceLocator":"policy:github-write-route","observedAt":"2026-09-13T14:00:00Z","semanticSource":"authoritative_policy"}',
 '["owner:instruction:github-app-vault"]','Owner-approved bounded GitHub write-route policy',true
);
insert into public.memory_review_queue_decisions(id,review_item_id,user_id,namespace,to_status)
values ('21000000-0000-0000-0000-000000000003','11000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append');
insert into public.memory_items(id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values (
 '31000000-0000-0000-0000-000000000003','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life',
 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','governance','GitHub write route',
 'Use the governed GitHub App or Supabase Vault-backed credential path for GitHub writes.','hard_canon',
 '{"reviewItemId":"11000000-0000-0000-0000-000000000003","reviewDecisionId":"21000000-0000-0000-0000-000000000003"}'
);

-- Irrelevant fact should not be returned for deploy/retry task terms.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '11000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append',true,'append',true,
 'fact','verified_evidence','fact:restaurant-hours',1,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
 '{"sourceType":"verified_document","sourceLocator":"fact:restaurant-hours","observedAt":"2026-09-13T14:00:00Z","semanticSource":"observation"}',
 '["doc:restaurant-hours"]','Stable unrelated business fact',false
);
insert into public.memory_review_queue_decisions(id,review_item_id,user_id,namespace,to_status)
values ('21000000-0000-0000-0000-000000000004','11000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append');
insert into public.memory_items(id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values (
 '31000000-0000-0000-0000-000000000004','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life',
 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','fact','Restaurant hours','Restaurant closes at 10pm.','hard_canon',
 '{"reviewItemId":"11000000-0000-0000-0000-000000000004","reviewDecisionId":"21000000-0000-0000-0000-000000000004"}'
);

-- Cross-project relevant-looking lesson must never leak.
insert into public.memory_review_queue_items (
 id,user_id,namespace,status,append_only,proposed_operation,requires_review,
 proposed_record_type,proposed_authority_kind,proposed_authority_ref,proposed_confidence,
 proposed_observed_at,proposed_effective_at,proposed_provenance,proposed_evidence_refs,
 proposed_promotion_basis,explicit_policy_authorization
) values (
 '11000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append',true,'append',true,
 'failure_lesson','verified_incident','incident:other-project',1,'2026-09-13T14:00:00Z','2026-09-13T14:00:00Z',
 '{"sourceType":"incident","sourceLocator":"other:deploy","observedAt":"2026-09-13T14:00:00Z","semanticSource":"observation"}',
 '["other:deploy"]','Other project deployment retry lesson',false
);
insert into public.memory_review_queue_decisions(id,review_item_id,user_id,namespace,to_status)
values ('21000000-0000-0000-0000-000000000005','11000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life','approved_for_append');
insert into public.memory_items(id,user_id,namespace,project_id,memory_type,title,body,canon_status,metadata)
values (
 '31000000-0000-0000-0000-000000000005','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','real_life',
 'cccccccc-cccc-cccc-cccc-cccccccccccc','learning','Other deployment retry lesson',
 'Deploy retry information for another project.','hard_canon',
 '{"reviewItemId":"11000000-0000-0000-0000-000000000005","reviewDecisionId":"21000000-0000-0000-0000-000000000005"}'
);

do $$
declare
  pack jsonb;
  first_type text;
begin
  pack := public.memory_task_context_v1(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'real_life',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbb',
    'projectos-mcpmaster-production',
    'production',
    'coding_building',
    'state_change',
    true,
    array['deploy','retry','write'],
    array['coding.repository_change'],
    array['hard_canon'],
    8192,
    '2026-09-13T15:00:00Z'
  );

  if pack->>'schemaVersion' <> 'm5.task-aware-retrieval.v1'
     or pack#>>'{task,intent}' <> 'coding_building'
     or pack#>>'{task,actionMode}' <> 'state_change'
     or pack#>>'{invariants,advisoryMemoryNeverAuthorizes}' <> 'true'
     or pack#>>'{invariants,policiesSeparatedFromAdvisoryMemory}' <> 'true'
     or pack#>>'{authorization,retrievalDoesNotGrantExecutionAuthority}' <> 'true'
     or (pack->>'byteSize')::integer > 8192 then
    raise exception 'task-aware pack contract failed: %',pack;
  end if;

  first_type := pack#>>'{advisoryMemory,0,recordType}';
  if first_type <> 'failure_lesson' then
    raise exception 'failure lesson not prioritized: %',pack->'advisoryMemory';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(pack->'policyMemory') x
    where x->>'recordType'='policy'
      and x->>'authorizationEffect'='requires_exact_runtime_scope_validity_revocation_validation'
      and x->>'requiresRuntimeAuthorizationValidation'='true'
  ) then
    raise exception 'policy separation/runtime validation marker missing';
  end if;

  if exists (
    select 1 from jsonb_array_elements(pack->'advisoryMemory') x
    where x->>'recordType'='policy'
       or x->>'authorizationEffect'<>'none'
       or x->>'id'='31000000-0000-0000-0000-000000000004'
       or x->>'id'='31000000-0000-0000-0000-000000000005'
  ) then
    raise exception 'irrelevant/cross-project/authorizing advisory item leaked: %',pack->'advisoryMemory';
  end if;
end $$;

-- Grant expansion must never be inferred. Legacy-only grants return an empty typed pack.
update public.pandora_project_grants
set allowed_record_types=array['architecture','decision']
where project_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  and principal_key='projectos-mcpmaster-production';

do $$
declare pack jsonb;
begin
  pack := public.memory_task_context_v1(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'real_life',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'projectos-mcpmaster-production',
    'production',
    'research',
    'read_only',
    false,
    array['deploy'],
    array['research.web_search'],
    array['hard_canon'],
    4096,
    '2026-09-13T15:00:00Z'
  );
  if jsonb_array_length(pack->'policyMemory') <> 0
     or jsonb_array_length(pack->'advisoryMemory') <> 0
     or jsonb_array_length(pack#>'{authorization,allowedTypedClasses}') <> 0
     or pack#>>'{invariants,grantExpansionPerformed}' <> 'false' then
    raise exception 'legacy grant was silently expanded: %',pack;
  end if;
end $$;

-- Revoked grants fail closed.
update public.pandora_project_grants
set is_active=false,revoked_at=now()
where project_id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  and principal_key='projectos-mcpmaster-production';

do $$
begin
  begin
    perform public.memory_task_context_v1(
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'real_life',
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'projectos-mcpmaster-production',
      'production',
      'research',
      'read_only',
      false,
      array['deploy'],
      array['research.web_search'],
      array['hard_canon'],
      4096,
      '2026-09-13T15:00:00Z'
    );
    raise exception 'revoked grant unexpectedly retrieved Memory';
  exception when insufficient_privilege then
    null;
  end;
end $$;

select 'M5-002 task-aware bounded retrieval verification: PASS' as result;
