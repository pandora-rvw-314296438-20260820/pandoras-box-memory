-- Disposable synthetic data; these are SQL behavior tests, not production acceptance.
create temp table ops_memory_assertions(name text primary key);
create function pg_temp.check(ok boolean, label text) returns void language plpgsql as $$
begin
 if ok is distinct from true then raise exception 'ASSERTION_FAILED: %',label; end if;
 insert into ops_memory_assertions values(label);
end $$;
insert into public.pandora_service_principals(principal_key,memory_user_id,environment,allowed_namespaces,scopes,is_active)
values('ops-test-principal','44444444-4444-4444-8444-444444444444','test',array['real_life'],array['memory:read','memory:write'],true);
insert into public.pandora_projects values('33333333-3333-4333-8333-333333333333','real_life','active','ops-fixture','Synthetic Operations project');
insert into public.pandora_project_grants(principal_key,project_id,environment,allowed_record_types,can_read,can_propose,is_active)
values('ops-test-principal','33333333-3333-4333-8333-333333333333','test',array['fact','policy','provider_performance','model_outcome'],true,true,true);
insert into public.memory_items(user_id,namespace,project_id,title,body,record_type,memory_type,canon_status,knowledge_schema_version,is_active,approved_by,approved_at,created_at,updated_at,provenance,confidence,authority_kind)
values('44444444-4444-4444-8444-444444444444','real_life','33333333-3333-4333-8333-333333333333','Router verified fixture','Synthetic approved context','fact','observation','hard_canon','m5.v1',true,'fixture-review',now(),now(),now(),'{"semanticSource":"observation"}',1,'verified_evidence'),
('44444444-4444-4444-8444-444444444444','real_life','33333333-3333-4333-8333-333333333333','Router soft fixture','Excluded by this hard-canon request','fact','observation','soft_canon','m5.v1',true,'fixture-review',now(),now(),now(),'{"semanticSource":"observation"}',1,'verified_evidence');
create function pg_temp.call(p jsonb, op text default 'propose_outcome') returns jsonb language sql as $$
 select public.memory_operations_bridge_v1(op,'44444444-4444-4444-8444-444444444444','real_life',
   '33333333-3333-4333-8333-333333333333','ops-test-principal','test',p);
$$;
create function pg_temp.reject(p jsonb, label text, op text default 'propose_outcome') returns void language plpgsql as $$
begin
 begin
  perform pg_temp.call(p,op);
 exception when others then
  if sqlstate in ('22023','42501','55000') and sqlerrm like 'OPS_MEMORY_%' then
   perform pg_temp.check(true,label); return;
  end if;
  raise exception 'UNEXPECTED_ERROR %: % %',label,sqlstate,sqlerrm;
 end;
 raise exception 'NOT_REJECTED: %',label;
end $$;
create temp table ops_memory_input(body jsonb);
insert into ops_memory_input values(jsonb_build_object(
 'contractVersion','pandora-operations-model-outcome-v1','sourceRunId','55555555-5555-4555-8555-555555555555',
 'provider','fixture','model','fixture-model','modelRevision',null,'taskClass','complex_coding','routingPolicyVersion','policy.v1',
 'executionStatus','succeeded','verificationStatus','pass','downstreamOutcomeStatus','accepted','qualitySignal',null,
 'latencyMs',42,'estimatedCostMicros',100,'billedCostMicros',null,
 'occurredAt',to_char(clock_timestamp() at time zone 'UTC' - interval '1 minute','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
 'reviewDueAt',to_char(clock_timestamp() at time zone 'UTC' + interval '30 days','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
 'evidenceRefs',jsonb_build_array('verification:fixture-result'),'sourceCommit',repeat('a',40),'sourceDeploymentRef',null,
 'usage',jsonb_build_object('inputTokens',null,'outputTokens',null,'totalTokens',null),'retryCount',0,'configurationDigest',null));
create temp table ops_memory_reply(body jsonb);
insert into ops_memory_reply select pg_temp.call(body) from ops_memory_input;
select pg_temp.check((select body->'canonicalMemoryWritten'='false'::jsonb and body->'requiresReview'='true'::jsonb and body->'readbackVerified'='true'::jsonb from ops_memory_reply),'native candidate plus review readback');
select pg_temp.check((select count(*)=1 from public.memory_capture_candidates),'one native capture candidate');
select pg_temp.check((select count(*)=1 from public.memory_review_queue_items),'one native review item');
select pg_temp.check((select model_revision='unreported' and billed_cost_micros is null and quality_signal is null from public.memory_capture_candidates),'unknown revision and cost remain explicit');
select pg_temp.check((select safe_metadata->'usage'='{"inputTokens":null,"outputTokens":null,"totalTokens":null}'::jsonb from private.pandora_ops_memory_receipts_v1),'nullable usage preserved in immutable metadata');
select pg_temp.check((select pg_temp.call(body)->'idempotentReplay'='true'::jsonb from ops_memory_input),'same payload replay');
select pg_temp.check((select count(*)=1 from public.memory_capture_candidates),'replay does not create another candidate');
select pg_temp.check((select pg_temp.call(jsonb_build_object('sourceRunId',body->>'sourceRunId','expectedPayload',body),'readback')->'readbackVerified'='true'::jsonb from ops_memory_input),'independent exact payload readback');
select pg_temp.reject((select body||'{"model":"other-model"}' from ops_memory_input),'changed model replay');
select pg_temp.reject((select body||'{"billedCostMicros":9}' from ops_memory_input),'changed metric replay');
select pg_temp.check(pg_temp.call('{"intent":"coding_building","actionMode":"state_change","consequential":true,"terms":["router"]}','context')#>>'{context,schemaVersion}'='m5.task-aware-retrieval.v1','actual M5 context RPC');
select pg_temp.check(jsonb_array_length(pg_temp.call('{"intent":"coding_building","actionMode":"read_only","terms":["router"]}','context')#>'{context,advisoryMemory}')=1,'soft canon excluded from scoped context');
select pg_temp.check(pg_temp.call('{"intent":"coding_building","actionMode":"read_only"}','context')->'authorizationGranted'='false'::jsonb,'retrieval grants no execution authority');
select pg_temp.reject('{"intent":"coding_building","actionMode":"read_only","sql":"select 1"}','context raw SQL blocked','context');
select pg_temp.reject('{"intent":"coding_building","actionMode":"read_only","maxBytes":"12000"}','context numeric string blocked','context');
select pg_temp.reject('{"intent":"coding_building","actionMode":"read_only","terms":[1]}','context nonstring term blocked','context');
select pg_temp.check(not has_function_privilege('anon','public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb)','EXECUTE'),'anonymous RPC denied');
select pg_temp.check(not has_function_privilege('authenticated','public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb)','EXECUTE'),'browser RPC denied');
select pg_temp.check(has_function_privilege('service_role','public.memory_operations_bridge_v1(text,uuid,text,uuid,text,text,jsonb)','EXECUTE'),'trusted service RPC available');
select pg_temp.check(not has_table_privilege('service_role','private.pandora_ops_memory_receipts_v1','INSERT'),'service cannot forge receipt rows');
select pg_temp.check((select relrowsecurity from pg_class where oid='private.pandora_ops_memory_receipts_v1'::regclass),'receipt RLS enabled');
update public.pandora_project_grants set is_active=false;
select pg_temp.reject((select body from ops_memory_input),'revoked grant denies replay');
update public.pandora_project_grants set is_active=true,can_propose=false;
select pg_temp.reject((select body from ops_memory_input),'read-only grant cannot propose');
update public.pandora_project_grants set can_propose=true,allowed_record_types=array['fact'];
select pg_temp.reject((select body from ops_memory_input),'record-type grant not widened');
update public.pandora_project_grants set allowed_record_types=array['fact','policy','provider_performance','model_outcome'];
update public.pandora_service_principals set allowed_namespaces=array[]::text[];
select pg_temp.reject((select body from ops_memory_input),'namespace grant not inferred');
update public.pandora_service_principals set allowed_namespaces=array['real_life'],scopes=array['memory:read'];
select pg_temp.reject((select body from ops_memory_input),'read scope cannot write');
update public.pandora_service_principals set scopes=array['memory:read','memory:write'],memory_user_id='99999999-9999-4999-8999-999999999999';
select pg_temp.reject((select body from ops_memory_input),'foreign user principal denied');
update public.pandora_service_principals set memory_user_id='44444444-4444-4444-8444-444444444444';
update public.pandora_projects set lifecycle_status='archived';
select pg_temp.reject((select body from ops_memory_input),'inactive project denied');
update public.pandora_projects set lifecycle_status='active';
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"output":"private text"}'::jsonb from ops_memory_input),'unknown output field');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"contractVersion":"other"}'::jsonb from ops_memory_input),'wrong version');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"provider":1}'::jsonb from ops_memory_input),'numeric provider');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"provider":"Fixture"}'::jsonb from ops_memory_input),'provider case');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"model":" a"}'::jsonb from ops_memory_input),'model whitespace');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"modelRevision":123}'::jsonb from ops_memory_input),'numeric revision');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"sourceCommit":"main"}'::jsonb from ops_memory_input),'source ref not SHA');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"sourceCommit":1111111111111111111111111111111111111111}'::jsonb from ops_memory_input),'numeric source SHA');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"configurationDigest":"x"}'::jsonb from ops_memory_input),'configuration invalid');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"verificationStatus":"unavailable"}'::jsonb from ops_memory_input),'missing verification');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"executionStatus":"ready"}'::jsonb from ops_memory_input),'execution invalid');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"downstreamOutcomeStatus":"complete"}'::jsonb from ops_memory_input),'downstream invalid');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"qualitySignal":2}'::jsonb from ops_memory_input),'quality invalid');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"qualitySignal":"1"}'::jsonb from ops_memory_input),'quality string');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"latencyMs":-1}'::jsonb from ops_memory_input),'negative latency');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"latencyMs":"42"}'::jsonb from ops_memory_input),'latency string');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"billedCostMicros":9007199254740992}'::jsonb from ops_memory_input),'unsafe cost');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"usage":{"inputTokens":null,"outputTokens":null}}'::jsonb from ops_memory_input),'missing usage member');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"usage":{"inputTokens":null,"outputTokens":"10","totalTokens":null}}'::jsonb from ops_memory_input),'usage nonnumber');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"usage":{"inputTokens":null,"outputTokens":null,"totalTokens":null,"raw":"content"}}'::jsonb from ops_memory_input),'usage extra field');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"retryCount":0.5}'::jsonb from ops_memory_input),'fractional retries');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"retryCount":17}'::jsonb from ops_memory_input),'too many retries');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"evidenceRefs":[]}'::jsonb from ops_memory_input),'no evidence');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"evidenceRefs":["v:1","v:1"]}'::jsonb from ops_memory_input),'duplicate evidence');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"evidenceRefs":["v:0","v:1","v:2","v:3","v:4","v:5","v:6","v:7","v:8","v:9","v:10","v:11","v:12","v:13","v:14","v:15","v:16","v:17","v:18","v:19","v:20","v:21","v:22","v:23","v:24","v:25","v:26","v:27","v:28","v:29","v:30","v:31"]}'::jsonb from ops_memory_input),'evidence overflow');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"sourceDeploymentRef":"https://x:y@host"}'::jsonb from ops_memory_input),'credential URL');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"occurredAt":"2026-09-25T17:00:00"}'::jsonb from ops_memory_input),'missing timestamp zone');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text)||'{"sourceDeploymentRef":2}'::jsonb from ops_memory_input),'unknown nullable type');

select pg_temp.reject((select body-'usage'||jsonb_build_object('sourceRunId',gen_random_uuid()::text) from ops_memory_input),'required field missing');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text,'model','github_pat_'||repeat('x',30)) from ops_memory_input),'credential canary rejected');
select pg_temp.reject((select body||jsonb_build_object('sourceRunId',gen_random_uuid()::text,'reviewDueAt',body->>'occurredAt') from ops_memory_input),'reversed freshness rejected');
select pg_temp.check((select count(*)=1 from public.memory_capture_candidates),'invalid inputs created no candidates');
do $$ begin
 begin
  update private.pandora_ops_memory_receipts_v1 set payload_sha256=repeat('c',64);
  raise exception 'receipt update unexpectedly accepted';
 exception when sqlstate '55000' then perform pg_temp.check(true,'delivery receipt immutable'); end;
 begin
  delete from private.pandora_ops_memory_receipts_v1;
  raise exception 'receipt deletion unexpectedly accepted';
 exception when sqlstate '55000' then perform pg_temp.check(true,'delivery receipt append-only'); end;
end $$;
update public.memory_capture_candidates set model='corrupted-model';
select pg_temp.reject((select jsonb_build_object('sourceRunId',body->>'sourceRunId','expectedPayload',body) from ops_memory_input),'candidate model drift detected','readback');
update public.memory_capture_candidates set model='fixture-model';
update public.memory_capture_candidates set billed_cost_micros=999;
select pg_temp.reject((select jsonb_build_object('sourceRunId',body->>'sourceRunId','expectedPayload',body) from ops_memory_input),'candidate metric drift detected','readback');
update public.memory_capture_candidates set billed_cost_micros=null;
update public.memory_review_queue_items set source_metadata=source_metadata||'{"projectId":"99999999-9999-4999-8999-999999999999"}';
select pg_temp.reject((select jsonb_build_object('sourceRunId',body->>'sourceRunId','expectedPayload',body) from ops_memory_input),'review project drift detected','readback');
update public.memory_review_queue_items set source_metadata=source_metadata||'{"projectId":"33333333-3333-4333-8333-333333333333"}';
select pg_temp.check((select count(*)=2 from public.memory_items),'no canonical memory rows written');

-- The bridge owns input errors, including overflow before native helper delegation.
create function pg_temp.reject_context_size(v jsonb, label text) returns void language plpgsql as $size_test$
begin
 begin
  perform pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',v),'context');
 exception when sqlstate '22023' then
  if sqlerrm <> 'OPS_MEMORY_CONTEXT_INVALID' then
   raise exception 'WRONG_CONTEXT_SIZE_ERROR: % %',sqlstate,sqlerrm;
  end if;
  perform pg_temp.check(true,label); return;
 end;
 raise exception 'CONTEXT_SIZE_NOT_REJECTED: %',label;
end $size_test$;
select pg_temp.reject_context_size('-1'::jsonb,'maxBytes negative');
select pg_temp.reject_context_size('0'::jsonb,'maxBytes zero');
select pg_temp.reject_context_size('1'::jsonb,'maxBytes one');
select pg_temp.reject_context_size('4095'::jsonb,'maxBytes below minimum');
select pg_temp.reject_context_size('16385'::jsonb,'maxBytes above maximum');
select pg_temp.reject_context_size('2147483647'::jsonb,'maxBytes int maximum');
select pg_temp.reject_context_size('2147483648'::jsonb,'maxBytes int overflow');
select pg_temp.reject_context_size('9007199254740992'::jsonb,'maxBytes unsafe integer');
select pg_temp.reject_context_size('1e100'::jsonb,'maxBytes huge exponent');
select pg_temp.reject_context_size('4096.5'::jsonb,'maxBytes fraction');
select pg_temp.reject_context_size('"4096"'::jsonb,'maxBytes numeric string');
select pg_temp.reject_context_size('null'::jsonb,'maxBytes null');
select pg_temp.reject_context_size('true'::jsonb,'maxBytes boolean');
select pg_temp.reject_context_size('{}'::jsonb,'maxBytes object');
select pg_temp.reject_context_size('[]'::jsonb,'maxBytes array');
select pg_temp.check(pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',4096),'context')->>'kind'='task_context','maxBytes accepted 4096');
select pg_temp.check(pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',4097),'context')->>'kind'='task_context','maxBytes accepted 4097');
select pg_temp.check(pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',12288),'context')->>'kind'='task_context','maxBytes accepted 12288');
select pg_temp.check(pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',16383),'context')->>'kind'='task_context','maxBytes accepted 16383');
select pg_temp.check(pg_temp.call(jsonb_build_object('intent','coding_building','actionMode','read_only','maxBytes',16384),'context')->>'kind'='task_context','maxBytes accepted 16384');

select count(*)::integer as passed_assertions from ops_memory_assertions;
