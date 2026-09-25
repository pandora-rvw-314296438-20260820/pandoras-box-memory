-- Synthetic fixture guard must precede every data-changing test.
do $$ begin
 if to_regclass('public.ops_performance_fixture_marker') is null then raise exception 'TEST_FIXTURE_REQUIRED'; end if;
end $$;
create temp table performance_assertions(name text primary key);
create function pg_temp.check(ok boolean,label text) returns void language plpgsql as $$ begin
 if ok is distinct from true then raise exception 'PERFORMANCE_ASSERTION_FAILED: %',label; end if;
 insert into performance_assertions values(label);
end $$;
create function pg_temp.call(q jsonb default pg_temp.performance_request()) returns jsonb language sql as $$
 select public.memory_operations_performance_v1('44444444-4444-4444-8444-444444444444','real_life',
  '33333333-3333-4333-8333-333333333333','ops-perf-test','test',q);
$$;
create function pg_temp.reject(q jsonb,label text) returns void language plpgsql as $$ begin
 begin perform pg_temp.call(q);
 exception when sqlstate '22023' or sqlstate '42501' then
  if sqlerrm not like 'OPS_MEMORY_%' then raise exception 'UNBOUNDED_ERROR: %',sqlerrm; end if;
  perform pg_temp.check(true,label); return;
 end;
 raise exception 'NOT_REJECTED: %',label;
end $$;
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','zero history is not invented');
insert into public.memory_items values('66666666-6666-4666-8666-666666666666','44444444-4444-4444-8444-444444444444',
 'real_life','33333333-3333-4333-8333-333333333333','provider_performance','hard_canon',true,null,null,
 'fixture-reviewer',clock_timestamp()-interval '30 minutes',clock_timestamp()+interval '30 days',null,pg_temp.performance_metadata());
create temp table performance_original as select * from public.memory_items;
update public.memory_items
 set metadata=metadata||jsonb_build_object(
   'model','risk-assessment-model-v12',
   'evidenceRefs',jsonb_build_array('task-verification-run-0001')
 );
select pg_temp.check(
  pg_temp.call(pg_temp.performance_request()||'{"model":"risk-assessment-model-v12"}'::jsonb)->>'state'='available',
  'ordinary sk substring in model filter is not a secret'
);
select pg_temp.check(
  pg_temp.call(pg_temp.performance_request()||'{"model":"risk-assessment-model-v12"}'::jsonb)#>>'{records,0,evidenceRefs,0}'='task-verification-run-0001',
  'ordinary sk substring in evidence ref is retained'
);
update public.memory_items set metadata=(select metadata from performance_original);
select pg_temp.check(pg_temp.call()->>'state'='available','approved evidence available');
select pg_temp.check(pg_temp.call()#>>'{records,0,sampleCount}'='3','sample count from canonical metadata');
select pg_temp.check(pg_temp.call()#>'{records,0,billedWindowCostMicros}'='null'::jsonb,'unknown billed cost remains null');
select pg_temp.check(pg_temp.call()#>>'{records,0,estimatedWindowCostMicros}'='100','window cost not relabeled as per-call cost');
select pg_temp.check(pg_temp.call()#>>'{records,0,meanLatencyMs}'='42','latency retains aggregate meaning');
select pg_temp.check(pg_temp.call()->'authorizationGranted'='false'::jsonb and pg_temp.call()->'providerApprovalGranted'='false'::jsonb,'history grants no authority');
select pg_temp.check(pg_temp.call()->'summingSamplesAllowed'='false'::jsonb,'overlapping counts may not be summed');
select pg_temp.check(not has_function_privilege('anon','public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb)','execute'),'anonymous denied');
select pg_temp.check(not has_function_privilege('authenticated','public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb)','execute'),'browser denied');
select pg_temp.check(has_function_privilege('service_role','public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb)','execute'),'trusted service read available');
select pg_temp.check(not has_table_privilege('service_role','public.memory_items','update'),'read RPC did not grant canon writes');
do $$ declare t record; r jsonb; begin
 for t in select * from (values
  ('numeric model','{"model":1}'::jsonb),('boolean provider','{"provider":true}'::jsonb),
  ('numeric revision','{"modelRevision":7}'::jsonb),('bad configuration','{"configurationDigest":"bad"}'::jsonb),
  ('zero sample','{"sampleCount":0}'::jsonb),('negative sample','{"sampleCount":-1}'::jsonb),
  ('sample string','{"sampleCount":"3"}'::jsonb),('sample fraction','{"sampleCount":3.1}'::jsonb),
  ('sample overflow','{"sampleCount":9007199254740992}'::jsonb),('run count mismatch','{"sampleCount":4}'::jsonb),
  ('pass exceeds sample','{"verificationPassCount":4}'::jsonb),('negative exceeds sample','{"negativeOutcomeCount":4}'::jsonb),
  ('quality string','{"qualitySignal":"1"}'::jsonb),('quality high','{"qualitySignal":1.1}'::jsonb),
  ('latency negative','{"latencyMs":-1}'::jsonb),('latency string','{"latencyMs":"42"}'::jsonb),
  ('latency fraction','{"latencyMs":1.5}'::jsonb),('unsafe cost','{"billedCostMicros":9007199254740992}'::jsonb),
  ('cost string','{"estimatedCostMicros":"100"}'::jsonb),('empty evidence','{"evidenceRefs":[]}'::jsonb),
  ('duplicate evidence','{"evidenceRefs":["v:1","v:1"]}'::jsonb),('credential URI','{"evidenceRefs":["https://a:b@host"]}'::jsonb),
  ('numeric evidence','{"evidenceRefs":[3]}'::jsonb),('empty run set','{"sourceRunIds":[]}'::jsonb),
  ('invalid run ID','{"sourceRunIds":["not-a-uuid"]}'::jsonb),
  ('duplicate run ID','{"sourceRunIds":["00000000-0000-4000-8000-000000000001","00000000-0000-4000-8000-000000000001","00000000-0000-4000-8000-000000000003"]}'::jsonb),
  ('nonarray run IDs','{"sourceRunIds":{}}'::jsonb),('nonarray evidence','{"evidenceRefs":true}'::jsonb),
  ('window lacks zone','{"evidenceWindowStart":"2026-01-01T00:00:00"}'::jsonb),
  ('bad calendar date','{"evidenceWindowStart":"2026-02-30T00:00:00Z"}'::jsonb),
  ('future window','{"evidenceWindowEnd":"2999-01-01T00:00:00Z"}'::jsonb),
  ('reversed window','{"evidenceWindowStart":"2999-01-01T00:00:00Z"}'::jsonb),
  ('missing timestamp','{"evidenceWindowEnd":null}'::jsonb),
  ('oversized evidence',jsonb_build_object('evidenceRefs',jsonb_build_array('v:'||repeat('x',501)))),
  ('secret canary',jsonb_build_object('model','github_pat_'||repeat('x',30)))
 ) cases(name,delta) loop
  update public.memory_items set metadata=(select metadata from performance_original)||t.delta;
  r:=pg_temp.call();
  perform pg_temp.check(jsonb_array_length(r->'records')=0 and r#>>'{statistics,invalidRecords}'='1','invalid metadata: '||t.name);
 end loop;
 update public.memory_items set metadata=(select metadata from performance_original);
end $$;
create function pg_temp.restore() returns void language sql as $$
 delete from public.memory_items;
 insert into public.memory_items select * from performance_original;
$$;
do $$ declare t record; begin
 for t in select * from (values ('zero','0'::jsonb),('over cap','17'::jsonb),('negative','-1'::jsonb),
  ('overflow','1e100'::jsonb),('string','"16"'::jsonb),('null','null'::jsonb),('fraction','1.5'::jsonb)) a(name,v) loop
  perform pg_temp.reject(pg_temp.performance_request()||jsonb_build_object('maxRecords',t.v),'request limit '||t.name);
 end loop;
end $$;
select pg_temp.reject(pg_temp.performance_request()||'{"sql":"select 1"}'::jsonb,'request raw SQL denied');
select pg_temp.reject(pg_temp.performance_request()||'{"taskClass":"anything"}'::jsonb,'unknown class denied');
select pg_temp.reject(pg_temp.performance_request()||'{"provider":"UPPER"}'::jsonb,'provider filter case denied');
select pg_temp.reject(pg_temp.performance_request()||'{"model":1}'::jsonb,'numeric model filter denied');
select pg_temp.reject(pg_temp.performance_request()||'{"requestId":"bad"}'::jsonb,'invalid request identity');
select pg_temp.reject(pg_temp.performance_request()-'modelRevision','missing nullable filter');
update public.pandora_service_principals set is_active=false;
select pg_temp.reject(pg_temp.performance_request(),'revoked principal denied');
update public.pandora_service_principals set is_active=true,scopes=array[]::text[];
select pg_temp.reject(pg_temp.performance_request(),'read scope required');
update public.pandora_service_principals set scopes=array['memory:read'],allowed_namespaces=array['au'];
select pg_temp.reject(pg_temp.performance_request(),'namespace mismatch denied');
update public.pandora_service_principals set allowed_namespaces=array['real_life'],environment='preview';
select pg_temp.reject(pg_temp.performance_request(),'environment mismatch denied');
update public.pandora_service_principals set environment='test',memory_user_id='99999999-9999-4999-8999-999999999999';
select pg_temp.reject(pg_temp.performance_request(),'principal user mismatch denied');
update public.pandora_service_principals set memory_user_id='44444444-4444-4444-8444-444444444444';
update public.pandora_projects set lifecycle_status='archived';
select pg_temp.reject(pg_temp.performance_request(),'inactive project denied');
update public.pandora_projects set lifecycle_status='active';
update public.pandora_project_grants set revoked_at=clock_timestamp();
select pg_temp.reject(pg_temp.performance_request(),'revoked read grant denied');
update public.pandora_project_grants set revoked_at=null,can_read=false;
select pg_temp.reject(pg_temp.performance_request(),'write-only grant cannot read');
update public.pandora_project_grants set can_read=true,allowed_record_types=array['fact'];
select pg_temp.reject(pg_temp.performance_request(),'performance type grant not inferred');
update public.pandora_project_grants set allowed_record_types=array['provider_performance'];
update public.memory_items set approved_by=null;
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','unapproved record excluded');
select pg_temp.restore(); update public.memory_items set canon_status='soft_canon';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','hard-canon-only policy enforced');
select pg_temp.restore(); update public.memory_items set approved_at=clock_timestamp()+interval '1 hour';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','future approval excluded');
select pg_temp.restore(); update public.memory_items set review_due_at=clock_timestamp()-interval '1 second';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','expired evidence excluded');
select pg_temp.restore(); update public.memory_items set revoked_at=clock_timestamp();
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','revoked evidence excluded');
select pg_temp.restore(); update public.memory_items set superseded_at=clock_timestamp();
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','superseded evidence excluded');
select pg_temp.restore(); update public.memory_items set effective_at=clock_timestamp()+interval '1 hour';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','future-effective evidence excluded');
select pg_temp.restore(); update public.memory_items set user_id='99999999-9999-4999-8999-999999999999';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','foreign user evidence excluded');
select pg_temp.restore(); update public.memory_items set project_id='99999999-9999-4999-8999-999999999999';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','foreign project evidence excluded');
select pg_temp.restore(); update public.memory_items set namespace='au';
select pg_temp.check(pg_temp.call()->>'state'='insufficient_history','foreign namespace evidence excluded');
select pg_temp.restore(); update public.memory_items set metadata=metadata-array['modelRevision','configurationDigest','latencyMs','billedCostMicros','estimatedCostMicros','qualitySignal'];
select pg_temp.check(pg_temp.call()#>'{records,0,meanLatencyMs}'='null'::jsonb,'missing latency remains unknown');
select pg_temp.check(pg_temp.call()#>'{records,0,estimatedWindowCostMicros}'='null'::jsonb,'missing window cost remains unknown');
select pg_temp.check(pg_temp.call()#>'{records,0,modelRevisionKnown}'='false'::jsonb,'missing model revision not invented');
select pg_temp.restore();
insert into public.memory_items select '77777777-7777-4777-8777-777777777777',user_id,namespace,project_id,record_type,
 canon_status,is_active,revoked_at,superseded_at,approved_by,approved_at-interval '1 minute',review_due_at,effective_at,
 metadata||jsonb_build_object('evidenceWindowEnd',clock_timestamp()-interval '40 minutes','qualitySignal',0.75)
 from performance_original;
select pg_temp.check(jsonb_array_length(pg_temp.call()->'records')=1,'overlapping snapshots not added');
select pg_temp.check(pg_temp.call()#>>'{records,0,memoryItemId}'='77777777-7777-4777-8777-777777777777','latest evidence window preferred');
select pg_temp.check(pg_temp.call()#>>'{records,0,sampleCount}'='3','overlap did not double sample count');
update public.memory_items set metadata=metadata||'{"modelRevision":"rev-2"}' where id='77777777-7777-4777-8777-777777777777';
select pg_temp.check(jsonb_array_length(pg_temp.call()->'records')=2,'different model revisions not conflated');
select pg_temp.check(jsonb_array_length(pg_temp.call(pg_temp.performance_request()||'{"modelRevision":"rev-2"}')->'records')=1,'exact revision filter');
select pg_temp.check(pg_temp.call(pg_temp.performance_request()||'{"provider":"missing"}')->>'state'='insufficient_history','missing provider not guessed');
update public.memory_items set metadata=metadata||jsonb_build_object('modelRevision','rev-1','configurationDigest',repeat('a',64)) where id='77777777-7777-4777-8777-777777777777';
select pg_temp.check(jsonb_array_length(pg_temp.call()->'records')=2,'different configurations not conflated');
select pg_temp.check(jsonb_array_length(pg_temp.call(pg_temp.performance_request()||jsonb_build_object('configurationDigest',repeat('a',64)))->'records')=1,'configuration filter');
select pg_temp.check(pg_temp.call(pg_temp.performance_request()||'{"maxRecords":1}')->'truncated'='true'::jsonb,'result cap is explicit');
select pg_temp.restore();
insert into public.memory_items select gen_random_uuid(),user_id,namespace,project_id,record_type,canon_status,is_active,
 revoked_at,superseded_at,approved_by,approved_at,review_due_at,effective_at,metadata||jsonb_build_object('model','fixture-model-'||s.n)
 from performance_original cross join generate_series(1,130) s(n);
select pg_temp.check(pg_temp.call()#>>'{statistics,scannedRecords}'='128','scan bounded at128');
select pg_temp.check(pg_temp.call()->'truncated'='true'::jsonb,'scan bound reported as partial');
select pg_temp.check(jsonb_array_length(pg_temp.call()->'records')=16,'record cap enforced');
select pg_temp.check(octet_length(pg_temp.call()::text)<=32768,'response byte budget enforced');
select pg_temp.restore();
select pg_temp.check((select count(*)=1 from public.memory_items),'reads created no canonical records');
select count(*)::integer as passed_assertions from performance_assertions;
