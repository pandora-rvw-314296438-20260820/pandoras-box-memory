\set ON_ERROR_STOP on

insert into public.pandora_projects(id,project_key,aliases,memory_namespace,lifecycle_status) values
('11111111-1111-4111-8111-111111111111','memory-alpha',array['source-alpha'],'real_life','active'),
('22222222-2222-4222-8222-222222222222','memory-beta',array['source-beta'],'real_life','active'),
('33333333-3333-4333-8333-333333333333','memory-no-grant',array['source-no-grant'],'real_life','active');

insert into public.pandora_project_grants(
  id,principal_key,project_id,environment,can_propose,is_active,revoked_at
) values
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1','projectos-mcpmaster-production','11111111-1111-4111-8111-111111111111','production',true,true,null),
('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2','projectos-mcpmaster-production','22222222-2222-4222-8222-222222222222','production',true,true,null);

insert into public.memory_capture_candidates(
  id,user_id,namespace,source,source_ref,requires_review,status,metadata
) values (
  'aaaaaaaa-0000-4000-8000-000000000001',
  '99999999-9999-4999-8999-999999999999',
  'real_life','projectos-post-task','projectos-plan:one',true,'pending',
  '{"review_policy":"projectos_selective_review_v2","project_key":"source-alpha","project_id":"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"}'::jsonb
);

do $$
declare v_project uuid; v_resolution text;
begin
  select project_id,metadata->>'memory_project_resolution'
    into v_project,v_resolution
  from public.memory_capture_candidates
  where id='aaaaaaaa-0000-4000-8000-000000000001';
  if v_project<>'11111111-1111-4111-8111-111111111111'::uuid
     or v_resolution<>'canonical_or_alias_v1' then
    raise exception 'selective-review project binding failed';
  end if;
end $$;

insert into public.memory_review_queue_items(
  id,user_id,namespace,candidate_type,status,source_ref,
  source_metadata,evidence_snapshot,audit_metadata
) values (
  'bbbbbbbb-0000-4000-8000-000000000001',
  '99999999-9999-4999-8999-999999999999',
  'real_life','projectos_outcome','pending_review','projectos-plan:one',
  '{"source":"projectos-post-task","projectKey":"source-alpha","reviewPolicy":"projectos_selective_review_v2"}'::jsonb,
  '{"hasEvidence":true}'::jsonb,
  '{"schemaVersion":1}'::jsonb
);

do $$
declare v_candidate uuid; v_project uuid; v_binding text;
begin
  select (source_metadata->>'candidateId')::uuid,
         (source_metadata->>'projectId')::uuid,
         source_metadata->>'lineageBinding'
    into v_candidate,v_project,v_binding
  from public.memory_review_queue_items
  where id='bbbbbbbb-0000-4000-8000-000000000001';
  if v_candidate<>'aaaaaaaa-0000-4000-8000-000000000001'::uuid
     or v_project<>'11111111-1111-4111-8111-111111111111'::uuid
     or v_binding<>'m5_projectos_scope_integrity_v1' then
    raise exception 'review lineage binding failed';
  end if;
end $$;

insert into public.memory_items(id,user_id,namespace,project_id,metadata) values (
  'cccccccc-0000-4000-8000-000000000001',
  '99999999-9999-4999-8999-999999999999',
  'real_life','11111111-1111-4111-8111-111111111111',
  '{"reviewItemId":"bbbbbbbb-0000-4000-8000-000000000001"}'::jsonb
);

insert into public.memory_capture_candidates(
  id,user_id,namespace,source,source_ref,requires_review,status,metadata
) values (
  'aaaaaaaa-0000-4000-8000-000000000002',
  '99999999-9999-4999-8999-999999999999',
  'real_life','projectos-post-task','projectos-evidence:two',true,'pending',
  '{"intake_kind":"projectos_evidence_candidate_v1","project_key":"memory-beta","project_id":"22222222-2222-4222-8222-222222222222"}'::jsonb
);

do $$
begin
  if (select project_id from public.memory_capture_candidates
      where id='aaaaaaaa-0000-4000-8000-000000000002')
     <> '22222222-2222-4222-8222-222222222222'::uuid then
    raise exception 'evidence-candidate project binding failed';
  end if;
end $$;

insert into public.memory_capture_candidates(
  id,user_id,namespace,source,source_ref,requires_review,status,metadata,project_id
) values (
  'aaaaaaaa-0000-4000-8000-000000000003',
  '99999999-9999-4999-8999-999999999999',
  'real_life','projectos-visible-creation','visible-creation:three',true,'pending',
  '{"intake_kind":"visible_creation_evidence_v1"}'::jsonb,
  '11111111-1111-4111-8111-111111111111'
);

do $$
begin
  begin
    insert into public.memory_capture_candidates(
      id,user_id,namespace,source,source_ref,requires_review,status,metadata
    ) values (
      'aaaaaaaa-0000-4000-8000-000000000010',
      '99999999-9999-4999-8999-999999999999',
      'real_life','projectos-post-task','projectos-plan:unresolved',true,'pending',
      '{"review_policy":"projectos_selective_review_v2","project_key":"missing-project"}'::jsonb
    );
    raise exception 'expected unresolved scope rejection';
  exception when check_violation then
    null;
  end;
end $$;

update public.pandora_projects
set aliases=array_append(aliases,'shared-alias')
where id in (
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222'
);
do $$
begin
  begin
    insert into public.memory_capture_candidates(
      id,user_id,namespace,source,source_ref,requires_review,status,metadata
    ) values (
      'aaaaaaaa-0000-4000-8000-000000000011',
      '99999999-9999-4999-8999-999999999999',
      'real_life','projectos-post-task','projectos-plan:ambiguous',true,'pending',
      '{"review_policy":"projectos_selective_review_v2","project_key":"shared-alias"}'::jsonb
    );
    raise exception 'expected ambiguous scope rejection';
  exception when check_violation then
    null;
  end;
end $$;

do $$
begin
  begin
    insert into public.memory_capture_candidates(
      id,user_id,namespace,source,source_ref,requires_review,status,metadata
    ) values (
      'aaaaaaaa-0000-4000-8000-000000000012',
      '99999999-9999-4999-8999-999999999999',
      'real_life','projectos-post-task','projectos-plan:no-grant',true,'pending',
      '{"review_policy":"projectos_selective_review_v2","project_key":"source-no-grant"}'::jsonb
    );
    raise exception 'expected grant rejection';
  exception when check_violation then
    null;
  end;
end $$;

do $$
begin
  begin
    insert into public.memory_review_queue_items(
      id,user_id,namespace,candidate_type,status,source_ref,
      source_metadata,evidence_snapshot,audit_metadata
    ) values (
      'bbbbbbbb-0000-4000-8000-000000000010',
      '99999999-9999-4999-8999-999999999999',
      'real_life','projectos_outcome','pending_review','projectos-plan:one',
      '{"source":"projectos-post-task","candidateId":"aaaaaaaa-0000-4000-8000-000000000099"}'::jsonb,
      '{}'::jsonb,'{}'::jsonb
    );
    raise exception 'expected candidate lineage mismatch';
  exception when check_violation then
    null;
  end;
end $$;

alter table public.memory_review_queue_items disable trigger trg_memory_bind_projectos_review_lineage_v1;
insert into public.memory_review_queue_items(
  id,user_id,namespace,candidate_type,status,source_ref,
  source_metadata,evidence_snapshot,audit_metadata
) values (
  'bbbbbbbb-0000-4000-8000-000000000020',
  '99999999-9999-4999-8999-999999999999',
  'real_life','projectos_outcome','approved_for_append','legacy:one',
  '{"source":"projectos-post-task"}'::jsonb,'{}'::jsonb,'{}'::jsonb
);
alter table public.memory_review_queue_items enable trigger trg_memory_bind_projectos_review_lineage_v1;

do $$
begin
  begin
    insert into public.memory_items(id,user_id,namespace,project_id,metadata) values (
      'cccccccc-0000-4000-8000-000000000020',
      '99999999-9999-4999-8999-999999999999',
      'real_life',null,
      '{"reviewItemId":"bbbbbbbb-0000-4000-8000-000000000020"}'::jsonb
    );
    raise exception 'expected legacy canonical rejection';
  exception when check_violation then
    null;
  end;
end $$;

update public.pandora_project_grants
set revoked_at=now()
where project_id='11111111-1111-4111-8111-111111111111'
  and principal_key='projectos-mcpmaster-production';

do $$
begin
  begin
    insert into public.memory_items(id,user_id,namespace,project_id,metadata) values (
      'cccccccc-0000-4000-8000-000000000030',
      '99999999-9999-4999-8999-999999999999',
      'real_life','11111111-1111-4111-8111-111111111111',
      '{"reviewItemId":"bbbbbbbb-0000-4000-8000-000000000001"}'::jsonb
    );
    raise exception 'expected revoked grant rejection';
  exception when check_violation then
    null;
  end;
end $$;

select 'm5_projectos_learning_scope_integrity_v1 PASS' as result;
