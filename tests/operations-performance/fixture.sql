-- Disposable synthetic empty database ONLY. Never load into a real Memory project.
do $$ begin
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','v','m','p')) then
   raise exception 'OPS_PERFORMANCE_TEST_REQUIRES_EMPTY_DATABASE';
 end if;
end $$;
create table public.ops_performance_fixture_marker(fixture boolean check(fixture));
insert into public.ops_performance_fixture_marker values(true);
create schema extensions;
create function extensions.digest(bytea,text) returns bytea language sql immutable as
 'select case when $2=''sha256'' then pg_catalog.sha256($1) else null end';
create function extensions.digest(text,text) returns bytea language sql immutable as
 'select extensions.digest(convert_to($1,''UTF8''),$2)';
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role; exception when duplicate_object then null; end $$;
create table public.pandora_service_principals(principal_key text primary key,memory_user_id uuid,
 environment text,allowed_namespaces text[],scopes text[],is_active boolean);
create table public.pandora_projects(id uuid primary key,memory_namespace text,lifecycle_status text);
create table public.pandora_project_grants(principal_key text,project_id uuid,environment text,
 allowed_record_types text[],can_read boolean,is_active boolean,revoked_at timestamptz,
 primary key(principal_key,project_id,environment));
create table public.memory_items(id uuid primary key default gen_random_uuid(),user_id uuid,namespace text,
 project_id uuid,record_type text,canon_status text,is_active boolean,revoked_at timestamptz,
 superseded_at timestamptz,approved_by text,approved_at timestamptz,review_due_at timestamptz,
 effective_at timestamptz,metadata jsonb);
alter table public.pandora_service_principals enable row level security;
alter table public.pandora_projects enable row level security;
alter table public.pandora_project_grants enable row level security;
alter table public.memory_items enable row level security;
insert into public.pandora_service_principals values('ops-perf-test','44444444-4444-4444-8444-444444444444',
 'test',array['real_life'],array['memory:read'],true);
insert into public.pandora_projects values('33333333-3333-4333-8333-333333333333','real_life','active');
insert into public.pandora_project_grants values('ops-perf-test','33333333-3333-4333-8333-333333333333',
 'test',array['provider_performance'],true,true,null);
create function pg_temp.performance_metadata(model_name text default 'fixture-model') returns jsonb language sql as $$
 select jsonb_build_object('provider','fixture','model',model_name,'modelRevision','rev-1','configurationDigest',null,
  'taskClass','complex_coding','sampleCount',3,'verificationPassCount',2,'negativeOutcomeCount',1,
  'qualitySignal',null,'latencyMs',42,'estimatedCostMicros',100,'billedCostMicros',null,
  'evidenceWindowStart',clock_timestamp()-interval '4 hours','evidenceWindowEnd',clock_timestamp()-interval '1 hour',
  'sourceRunIds',jsonb_build_array('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000003'),'evidenceRefs',jsonb_build_array('verification:fixture-1'));
$$;
create function pg_temp.performance_request() returns jsonb language sql as $$
 select jsonb_build_object('requestId','55555555-5555-4555-8555-555555555555','taskClass','complex_coding',
  'provider',null,'model',null,'modelRevision',null,'configurationDigest',null,'maxRecords',16);
$$;
