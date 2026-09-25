-- PANDORA_SECURITY_ADJUDICATION: reviewed (engineering source-readiness; independent release review required).
-- PANDORA_SECURITY_ACCESS_PATH: Service-only read; exact active principal/user/project/namespace/environment and read/type grant; no new grants or canonical writes.
-- PANDORA_SECURITY_TEST_PLAN: Disposable native SQL isolation, malformed/overlapping evidence and missing-history tests; companion client negatives and exact-head CI.
-- PANDORA_SECURITY_ROLLBACK: Disable this new read consumer/RPC; preserve all canonical Memory and approval history.
-- PANDORA_SECURITY_OWNER: ChatGPT OPS-MEMORY-PERFORMANCE-20260926; Operations Room714 comment5838373571; no production activation claimed.
-- CLI-generated additive read surface. Memory evidence never approves a model or grants execution authority.
create function public.memory_operations_performance_v1(
  p_memory_user_id uuid, p_namespace text, p_project_id uuid,
  p_principal_key text, p_environment text, p_request jsonb
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  principal public.pandora_service_principals%rowtype;
  grant_row public.pandora_project_grants%rowtype;
  m record; d jsonb; item jsonb; candidates jsonb := '[]'; snapshots jsonb := '[]';
  result_rows jsonb := '[]'; result jsonb; k text; bad boolean;
  at_time timestamptz := clock_timestamp(); start_at timestamptz; end_at timestamptz;
  refs text[]; runs text[]; scanned integer := 0; invalid integer := 0;
  eligible integer := 0; max_records integer; truncated boolean := false;
  id_pattern constant text := '^[A-Za-z0-9][A-Za-z0-9._:/-]{0,179}$';
  uuid_pattern constant text := '^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$';
  time_pattern constant text := '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$';
  secret_pattern constant text := '(^|[^A-Za-z0-9])(github_pat_|gh[pousr]_[A-Za-z0-9_]{16,}|sb_secret_|AIza[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{16,}|Bearer[[:space:]]+[A-Za-z0-9._~-]{12,}|-----BEGIN [^-]*PRIVATE KEY)';
begin
  if p_memory_user_id is null or p_project_id is null or p_namespace is distinct from 'real_life'
    or p_environment is null or p_environment not in ('production','preview','development','test')
    or p_principal_key is null or p_principal_key !~ id_pattern
    or jsonb_typeof(p_request) is distinct from 'object' or octet_length(p_request::text)>4096 then
    raise exception 'OPS_MEMORY_PERFORMANCE_REQUEST_INVALID' using errcode='22023';
  end if;
  if not (p_request ?& array['requestId','taskClass','provider','model','modelRevision','configurationDigest','maxRecords'])
    or p_request-array['requestId','taskClass','provider','model','modelRevision','configurationDigest','maxRecords']<>'{}'::jsonb
    or not coalesce(p_request->>'requestId' ~ uuid_pattern,false)
    or not coalesce(p_request->>'taskClass'=any(array['deep_reasoning','complex_coding','fast_coding','vision',
      'long_context','research','structured_extraction','local_private','cheap_bulk','independent_verification']),false)
    or jsonb_typeof(p_request->'maxRecords') is distinct from 'number'
    or not coalesce(p_request->>'maxRecords' ~ '^[0-9]+$',false) then
    raise exception 'OPS_MEMORY_PERFORMANCE_REQUEST_INVALID' using errcode='22023';
  end if;
  if (p_request->>'maxRecords')::numeric not between 1 and 16 then
    raise exception 'OPS_MEMORY_PERFORMANCE_REQUEST_INVALID' using errcode='22023';
  end if;
  max_records := (p_request->>'maxRecords')::integer;
  foreach k in array array['provider','model','modelRevision','configurationDigest'] loop
    if p_request->k<>'null'::jsonb and (jsonb_typeof(p_request->k) is distinct from 'string'
      or not coalesce(p_request->>k ~ id_pattern,false)) then
      raise exception 'OPS_MEMORY_PERFORMANCE_FILTER_INVALID' using errcode='22023';
    end if;
  end loop;
  if (p_request->'provider'<>'null'::jsonb and not coalesce(p_request->>'provider' ~ '^[a-z][a-z0-9._-]{0,119}$',false))
    or (p_request->'configurationDigest'<>'null'::jsonb and not coalesce(p_request->>'configurationDigest' ~ '^[a-f0-9]{64}$',false))
    or p_request::text ~* secret_pattern then
    raise exception 'OPS_MEMORY_PERFORMANCE_FILTER_INVALID' using errcode='22023';
  end if;
  select * into principal from public.pandora_service_principals
    where principal_key=p_principal_key and memory_user_id=p_memory_user_id
      and environment=p_environment and is_active is true for share;
  if not found or not coalesce(p_namespace=any(principal.allowed_namespaces),false)
    or not coalesce('memory:read'=any(principal.scopes),false) then
    raise exception 'OPS_MEMORY_PERFORMANCE_PRINCIPAL_DENIED' using errcode='42501';
  end if;
  perform 1 from public.pandora_projects where id=p_project_id
    and memory_namespace=p_namespace and lifecycle_status='active' for share;
  if not found then raise exception 'OPS_MEMORY_PERFORMANCE_PROJECT_DENIED' using errcode='42501'; end if;
  select * into grant_row from public.pandora_project_grants
    where principal_key=p_principal_key and project_id=p_project_id and environment=p_environment
      and is_active is true and revoked_at is null for share;
  if not found or grant_row.can_read is distinct from true
    or not coalesce('provider_performance'=any(grant_row.allowed_record_types),false) then
    raise exception 'OPS_MEMORY_PERFORMANCE_GRANT_DENIED' using errcode='42501';
  end if;
  -- A bounded scan is reported as partial; it is never a claim of globally optimal model choice.
  for m in select id,metadata,approved_at,review_due_at from public.memory_items
    where user_id=p_memory_user_id and namespace::text=p_namespace and project_id=p_project_id
      and record_type='provider_performance' and canon_status::text='hard_canon'
      and is_active is true and revoked_at is null and superseded_at is null
      and nullif(btrim(approved_by),'') is not null and approved_at<=at_time
      and review_due_at>at_time and (effective_at is null or effective_at<=at_time)
      and metadata->>'taskClass'=p_request->>'taskClass'
      and (p_request->'provider'='null'::jsonb or metadata->>'provider'=p_request->>'provider')
      and (p_request->'model'='null'::jsonb or metadata->>'model'=p_request->>'model')
      and (p_request->'modelRevision'='null'::jsonb or metadata->>'modelRevision'=p_request->>'modelRevision')
      and (p_request->'configurationDigest'='null'::jsonb or metadata->>'configurationDigest'=p_request->>'configurationDigest')
    order by approved_at desc,id limit 129 for share
  loop
    if scanned=128 then truncated:=true; exit; end if;
    scanned:=scanned+1; d:=m.metadata; bad:=false;
    if jsonb_typeof(d) is distinct from 'object' or octet_length(d::text)>65536
      or d::text ~* secret_pattern then
      invalid:=invalid+1; continue;
    end if;
    foreach k in array array['provider','model','taskClass'] loop
      if jsonb_typeof(d->k) is distinct from 'string' or not coalesce(d->>k ~ id_pattern,false) then bad:=true; end if;
    end loop;
    if not coalesce(d->>'provider' ~ '^[a-z][a-z0-9._-]{0,119}$',false) then bad:=true; end if;
    if coalesce(d->'modelRevision','null')<>'null'::jsonb and
      (jsonb_typeof(d->'modelRevision')<>'string' or not coalesce(d->>'modelRevision' ~ id_pattern,false)) then bad:=true; end if;
    if coalesce(d->'configurationDigest','null')<>'null'::jsonb and
      (jsonb_typeof(d->'configurationDigest')<>'string' or not coalesce(d->>'configurationDigest' ~ '^[a-f0-9]{64}$',false)) then bad:=true; end if;
    foreach k in array array['sampleCount','verificationPassCount','negativeOutcomeCount'] loop
      if jsonb_typeof(d->k) is distinct from 'number' then bad:=true;
      elsif (d->>k)::numeric not between 0 and 9007199254740991
        or trunc((d->>k)::numeric)<>(d->>k)::numeric then bad:=true; end if;
    end loop;
    foreach k in array array['latencyMs','estimatedCostMicros','billedCostMicros'] loop
      if coalesce(d->k,'null')<>'null'::jsonb then
        if jsonb_typeof(d->k)<>'number' then bad:=true;
        elsif (d->>k)::numeric not between 0 and 9007199254740991
          or trunc((d->>k)::numeric)<>(d->>k)::numeric then bad:=true; end if;
      end if;
    end loop;
    if coalesce(d->'qualitySignal','null')<>'null'::jsonb then
      if jsonb_typeof(d->'qualitySignal')<>'number' then bad:=true;
      elsif (d->>'qualitySignal')::numeric not between 0 and 1 then bad:=true; end if;
    end if;
    if bad then invalid:=invalid+1; continue; end if;
    if (d->>'sampleCount')::numeric<1 or (d->>'verificationPassCount')::numeric>(d->>'sampleCount')::numeric
      or (d->>'negativeOutcomeCount')::numeric>(d->>'sampleCount')::numeric
      or jsonb_typeof(d->'sourceRunIds') is distinct from 'array'
      or jsonb_typeof(d->'evidenceRefs') is distinct from 'array' then
      invalid:=invalid+1; continue;
    end if;
    if jsonb_array_length(d->'sourceRunIds') not between 1 and 1500
      or jsonb_array_length(d->'evidenceRefs') not between 1 and 200
      or exists(select 1 from jsonb_array_elements(d->'sourceRunIds') a(v)
        where jsonb_typeof(v)<>'string' or not coalesce(v#>>'{}' ~ uuid_pattern,false))
      or exists(select 1 from jsonb_array_elements(d->'evidenceRefs') a(v)
        where jsonb_typeof(v)<>'string' or length(v#>>'{}')>500
          or not coalesce(v#>>'{}' ~ '^[A-Za-z0-9][A-Za-z0-9:./_?#=&%-]*$',false)) then
      invalid:=invalid+1; continue;
    end if;
    refs:=array(select jsonb_array_elements_text(d->'evidenceRefs'));
    runs:=array(select jsonb_array_elements_text(d->'sourceRunIds') order by 1);
    if cardinality(runs)<>(d->>'sampleCount')::bigint
      or (select count(distinct v) from unnest(runs) a(v))<>cardinality(runs)
      or (select count(distinct v) from unnest(refs) a(v))<>cardinality(refs) then
      invalid:=invalid+1; continue;
    end if;
    foreach k in array array['evidenceWindowStart','evidenceWindowEnd'] loop
      if jsonb_typeof(d->k) is distinct from 'string' or length(d->>k)>64
        or not coalesce(d->>k ~ time_pattern,false) then bad:=true; end if;
    end loop;
    if bad then invalid:=invalid+1; continue; end if;
    begin
      start_at:=(d->>'evidenceWindowStart')::timestamptz;
      end_at:=(d->>'evidenceWindowEnd')::timestamptz;
    exception when sqlstate '22007' or sqlstate '22008' or sqlstate '22009' then
      invalid:=invalid+1; continue;
    end;
    if start_at>end_at or end_at>m.approved_at or m.approved_at>at_time or m.review_due_at<=end_at then
      invalid:=invalid+1; continue;
    end if;
    item:=jsonb_build_object('memoryItemId',m.id,'recordType','provider_performance','canonStatus','hard_canon',
      'recordDigest',encode(extensions.digest(jsonb_build_object('id',m.id,'metadata',d,'approvedAt',m.approved_at,
        'reviewDueAt',m.review_due_at)::text,'sha256'),'hex'),
      'provider',d->>'provider','model',d->>'model','modelRevision',d->>'modelRevision',
      'modelRevisionKnown',(d->>'modelRevision' is not null and d->>'modelRevision'<>'unreported'),
      'configurationDigest',d->>'configurationDigest','configurationKnown',d->>'configurationDigest' is not null,
      'taskClass',p_request->>'taskClass','sampleCount',(d->>'sampleCount')::bigint,
      'verificationPassCount',(d->>'verificationPassCount')::bigint,'negativeOutcomeCount',(d->>'negativeOutcomeCount')::bigint,
      'qualitySignal',(d->>'qualitySignal')::numeric,'meanLatencyMs',(d->>'latencyMs')::bigint,
      'estimatedWindowCostMicros',(d->>'estimatedCostMicros')::bigint,'billedWindowCostMicros',(d->>'billedCostMicros')::bigint,
      'evidenceWindowStart',start_at,'evidenceWindowEnd',end_at,'reviewDueAt',m.review_due_at,'approvedAt',m.approved_at,
      'sourceRunCount',cardinality(runs),'sourceRunsDigest',encode(extensions.digest(array_to_json(runs)::text,'sha256'),'hex'),
      'evidenceRefs',to_jsonb(refs[1:4]),'evidenceRefCount',cardinality(refs),
      'evidenceDigest',encode(extensions.digest(array_to_json(refs)::text,'sha256'),'hex'));
    candidates:=candidates||jsonb_build_array(item);
  end loop;
  -- Select a single latest window per exact cohort. Never sum overlapping snapshots.
  select coalesce(jsonb_agg(s.body order by s.body->>'provider',s.body->>'model',s.body->>'modelRevision',
    s.body->>'configurationDigest'),'[]'::jsonb) into snapshots from (
    select distinct on (c.value->>'provider',c.value->>'model',coalesce(c.value->>'modelRevision',''),
      coalesce(c.value->>'configurationDigest','')) c.value as body
    from jsonb_array_elements(candidates) c(value)
    order by c.value->>'provider',c.value->>'model',coalesce(c.value->>'modelRevision',''),
      coalesce(c.value->>'configurationDigest',''),(c.value->>'evidenceWindowEnd')::timestamptz desc,
      (c.value->>'approvedAt')::timestamptz desc,c.value->>'memoryItemId'
  ) s;
  eligible:=jsonb_array_length(snapshots);
  for item in select c.value from jsonb_array_elements(snapshots) c(value) loop
    if jsonb_array_length(result_rows)>=max_records
      or octet_length((result_rows||jsonb_build_array(item))::text)>28000 then truncated:=true; exit; end if;
    result_rows:=result_rows||jsonb_build_array(item);
  end loop;
  result:=jsonb_build_object('schemaVersion','pandora-operations-performance-v1','requestId',p_request->>'requestId',
    'projectId',p_project_id,'namespace',p_namespace,'principalKey',p_principal_key,'environment',p_environment,
    'taskClass',p_request->>'taskClass','requested',p_request-array['requestId','taskClass'],'observedAt',at_time,
    'state',case when jsonb_array_length(result_rows)>0 then 'available' else 'insufficient_history' end,
    'records',result_rows,'statistics',jsonb_build_object('scannedRecords',scanned,'invalidRecords',invalid,'eligibleSnapshots',eligible),
    'truncated',truncated,'aggregation','latest_snapshot_per_model_revision_configuration','summingSamplesAllowed',false,
    'authorizationGranted',false,'providerApprovalGranted',false);
  if octet_length(result::text)>32768 then raise exception 'OPS_MEMORY_PERFORMANCE_RESPONSE_LIMIT' using errcode='22023'; end if;
  return result;
end $$;

revoke all on function public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb) to service_role;
comment on function public.memory_operations_performance_v1(uuid,text,uuid,text,text,jsonb) is
  'Read-only scoped approved performance evidence; latest snapshot per cohort, no invented metrics, no provider authorization, no canon mutation.';
