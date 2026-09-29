
-- FB-030..FB-032: bounded approved-current growth Memory retrieval.
-- This is a read-only evidence projection. It cannot approve candidates,
-- persist pending learning, mutate provider state, or authorize spend.
begin;

create or replace function public.memory_growth_approved_context_v1(
  p_user_id uuid,
  p_project_id uuid,
  p_principal_key text,
  p_terms text[] default array['facebook','marketing','growth']::text[],
  p_max_bytes integer default 8192,
  p_as_of timestamptz default now()
) returns jsonb
language plpgsql
stable
security definer
set search_path='pg_catalog','public','extensions'
as $function$
declare
  v_inner jsonb;
  v_raw_records jsonb;
  v_records jsonb;
  v_query_sha256 text;
  v_inner_max integer;
begin
  if p_user_id is null
     or p_project_id is null
     or nullif(btrim(coalesce(p_principal_key,'')),'') is null
     or p_max_bytes not between 6144 and 16384 then
    raise exception 'memory_growth_context_invalid_request' using errcode='22023';
  end if;
  if coalesce(cardinality(p_terms),0)>12 then
    raise exception 'memory_growth_context_invalid_terms' using errcode='22023';
  end if;

  v_inner_max:=least(14336,greatest(4096,p_max_bytes-1024));

  v_inner:=public.memory_task_context_v1(
    p_user_id,
    'real_life',
    p_project_id,
    p_principal_key,
    'production',
    'business',
    'read_only',
    false,
    coalesce(p_terms,'{}'::text[]),
    '{}'::text[],
    array['hard_canon','soft_canon']::text[],
    v_inner_max,
    coalesce(p_as_of,now())
  );

  if v_inner->>'status'<>'available'
     or coalesce((v_inner#>>'{authorization,retrievalDoesNotGrantExecutionAuthority}')::boolean,false) is not true
     or coalesce((v_inner#>>'{invariants,advisoryMemoryNeverAuthorizes}')::boolean,false) is not true
     or coalesce((v_inner#>>'{invariants,revokedAndSupersededExcludedByDefault}')::boolean,false) is not true then
    raise exception 'memory_growth_context_invariant_failed' using errcode='55000';
  end if;

  v_raw_records:=
    coalesce(v_inner->'policyMemory','[]'::jsonb)
    || coalesce(v_inner->'advisoryMemory','[]'::jsonb);

  select coalesce(jsonb_agg(
    e.item || jsonb_strip_nulls(jsonb_build_object(
      'memoryRecordId',m.id,
      'memoryVersionId',m.id::text||'@'||coalesce(m.effective_at,m.updated_at,m.created_at)::text,
      'reviewItemId',m.metadata->>'reviewItemId',
      'recordSha256',encode(extensions.digest(convert_to(e.item::text,'utf8'),'sha256'),'hex'),
      'status','approved_current'
    ))
    order by e.ord
  ),'[]'::jsonb)
  into v_records
  from jsonb_array_elements(v_raw_records) with ordinality as e(item,ord)
  join public.memory_items m
    on m.id=(e.item->>'id')::uuid
   and m.user_id=p_user_id
   and m.project_id=p_project_id
   and m.namespace::text='real_life'
   and m.knowledge_schema_version='m5.v1'
   and m.is_active is true
   and m.approved_by is not null
   and m.approved_at is not null
   and m.revoked_at is null
   and m.superseded_at is null
   and m.canon_status in ('soft_canon','hard_canon');

  v_query_sha256:=encode(extensions.digest(convert_to(
    jsonb_build_object(
      'projectId',p_project_id,
      'principalKey',p_principal_key,
      'terms',to_jsonb(coalesce(p_terms,'{}'::text[])),
      'contextSha256',v_inner->>'contextSha256'
    )::text,
    'utf8'
  ),'sha256'),'hex');

  return jsonb_build_object(
    'schemaVersion','growth.approved-memory-context.v1',
    'status','available',
    'namespace','real_life',
    'project',v_inner->'project',
    'querySha256',v_query_sha256,
    'contextSha256',v_inner->>'contextSha256',
    'records',v_records,
    'counts',jsonb_build_object(
      'returned',jsonb_array_length(v_records),
      'policy',coalesce((v_inner#>>'{counts,returnedPolicy}')::integer,0),
      'advisory',coalesce((v_inner#>>'{counts,returnedAdvisory}')::integer,0)
    ),
    'invariants',jsonb_build_object(
      'approvedCurrentOnly',true,
      'pendingExcluded',true,
      'rejectedExcluded',true,
      'revokedExcluded',true,
      'supersededExcluded',true,
      'retrievalDoesNotGrantExecutionAuthority',true,
      'canAuthorizeSpend',false,
      'canMutateCampaigns',false,
      'canPublish',false,
      'operationsRoomRequired',false,
      'grantExpansionPerformed',false
    ),
    'asOf',v_inner->'asOf'
  );
end;
$function$;

revoke all on function public.memory_growth_approved_context_v1(
  uuid,uuid,text,text[],integer,timestamptz
) from public,anon,authenticated;
grant execute on function public.memory_growth_approved_context_v1(
  uuid,uuid,text,text[],integer,timestamptz
) to service_role;

comment on function public.memory_growth_approved_context_v1(
  uuid,uuid,text,text[],integer,timestamptz
) is
  'Growth-specific wrapper over governed M5 task-aware retrieval. Returns only approved, active, non-revoked, non-superseded real-life Memory with record/version/review/hash receipts. Retrieval never grants execution, provider mutation, publishing or spend authority and has no Operations Room dependency.';

commit;
