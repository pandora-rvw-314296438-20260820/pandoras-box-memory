-- Visible Creation Wave 6 — bind approved Memory retrieval to planning/build/repair decisions
-- and later verified outcomes without creating a second analytics authority.

alter table public.memory_retrieval_logs
  add column if not exists used_for_decision boolean not null default false,
  add column if not exists decision_type text null,
  add column if not exists decision_id uuid null,
  add column if not exists decision_run_id uuid null,
  add column if not exists outcome_status text null,
  add column if not exists outcome_evidence_ref text null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'memory_retrieval_logs_decision_shape_check'
      and conrelid = 'public.memory_retrieval_logs'::regclass
  ) then
    alter table public.memory_retrieval_logs
      add constraint memory_retrieval_logs_decision_shape_check
      check (
        used_for_decision is false or (
          project_id is not null
          and cardinality(memory_item_ids) >= 1
          and decision_type in ('project_spec','build','repair')
          and decision_id is not null
        )
      );
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'memory_retrieval_logs_decision_outcome_check'
      and conrelid = 'public.memory_retrieval_logs'::regclass
  ) then
    alter table public.memory_retrieval_logs
      add constraint memory_retrieval_logs_decision_outcome_check
      check (
        outcome_status is null or outcome_status in
          ('succeeded','failed','accepted','rejected','regressed','unknown')
      );
  end if;
end $$;

create index if not exists memory_retrieval_logs_decision_lineage_idx
  on public.memory_retrieval_logs(
    user_id, namespace, project_id, decision_type, decision_id, created_at desc
  ) where used_for_decision is true;

alter table public.memory_feedback_events
  add column if not exists retrieval_log_id uuid null,
  add column if not exists decision_type text null,
  add column if not exists decision_id uuid null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'memory_feedback_events_decision_type_check'
      and conrelid = 'public.memory_feedback_events'::regclass
  ) then
    alter table public.memory_feedback_events
      add constraint memory_feedback_events_decision_type_check
      check (
        decision_type is null or decision_type in ('project_spec','build','repair')
      );
  end if;
end $$;

create unique index if not exists memory_feedback_events_decision_outcome_unique
  on public.memory_feedback_events(retrieval_log_id, memory_item_id, source_run_id)
  where action = 'decision_memory_outcome'
    and retrieval_log_id is not null
    and memory_item_id is not null
    and source_run_id is not null;

create or replace function public.memory_bind_decision_context_v1(
  p_memory_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_retrieval_log_id uuid,
  p_decision_type text,
  p_decision_id uuid,
  p_decision_run_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog','public'
as $$
declare
  v_log record;
  v_approved_count bigint;
begin
  if p_memory_user_id is null or p_project_id is null or p_retrieval_log_id is null
     or p_decision_id is null then
    raise exception 'complete decision lineage required' using errcode='22023';
  end if;
  if p_namespace not in ('real_life','au') then
    raise exception 'invalid namespace' using errcode='22023';
  end if;
  if p_decision_type not in ('project_spec','build','repair') then
    raise exception 'invalid decision type' using errcode='22023';
  end if;

  select id, memory_item_ids, used_for_decision, decision_type, decision_id,
         decision_run_id
  into v_log
  from public.memory_retrieval_logs
  where id = p_retrieval_log_id
    and user_id = p_memory_user_id
    and namespace = p_namespace
    and project_id = p_project_id
  for update;

  if not found then
    raise exception 'retrieval log not found in project scope' using errcode='P0002';
  end if;
  if cardinality(coalesce(v_log.memory_item_ids, '{}'::uuid[])) < 1 then
    raise exception 'approved memory references required' using errcode='22023';
  end if;

  select count(distinct mi.id)::bigint
  into v_approved_count
  from public.memory_items mi
  where mi.id = any(v_log.memory_item_ids)
    and mi.user_id = p_memory_user_id
    and mi.namespace = p_namespace::public.pandora_namespace
    and mi.project_id = p_project_id
    and mi.is_active is true
    and mi.canon_status in (
      'soft_canon'::public.canon_status,
      'hard_canon'::public.canon_status
    )
    and mi.revoked_at is null
    and mi.superseded_at is null;

  if v_approved_count <> cardinality(v_log.memory_item_ids) then
    raise exception 'retrieval contains non-approved memory reference' using errcode='22023';
  end if;

  if v_log.used_for_decision then
    if v_log.decision_type <> p_decision_type
       or v_log.decision_id <> p_decision_id
       or v_log.decision_run_id is distinct from p_decision_run_id then
      raise exception 'memory decision lineage conflict' using errcode='23505';
    end if;
    return jsonb_build_object(
      'retrievalLogId', v_log.id,
      'decisionType', v_log.decision_type,
      'decisionId', v_log.decision_id,
      'memoryItemIds', v_log.memory_item_ids,
      'idempotentReplay', true
    );
  end if;

  update public.memory_retrieval_logs
  set used_for_decision = true,
      decision_type = p_decision_type,
      decision_id = p_decision_id,
      decision_run_id = p_decision_run_id
  where id = p_retrieval_log_id;

  return jsonb_build_object(
    'retrievalLogId', p_retrieval_log_id,
    'decisionType', p_decision_type,
    'decisionId', p_decision_id,
    'decisionRunId', p_decision_run_id,
    'memoryItemIds', v_log.memory_item_ids,
    'idempotentReplay', false
  );
end $$;

revoke all on function public.memory_bind_decision_context_v1(
  uuid,text,uuid,uuid,text,uuid,uuid
) from public,anon,authenticated;
grant execute on function public.memory_bind_decision_context_v1(
  uuid,text,uuid,uuid,text,uuid,uuid
) to service_role;

create or replace function public.memory_record_decision_outcome_v1(
  p_memory_user_id uuid,
  p_namespace text,
  p_project_id uuid,
  p_retrieval_log_id uuid,
  p_decision_type text,
  p_decision_id uuid,
  p_outcome_run_id uuid,
  p_outcome_status text,
  p_usefulness_delta numeric,
  p_evidence_ref text
)
returns jsonb
language plpgsql
security definer
set search_path = 'pg_catalog','public'
as $$
declare
  v_log record;
  v_inserted bigint := 0;
begin
  if p_memory_user_id is null or p_project_id is null or p_retrieval_log_id is null
     or p_decision_id is null or p_outcome_run_id is null then
    raise exception 'complete outcome lineage required' using errcode='22023';
  end if;
  if p_namespace not in ('real_life','au') then
    raise exception 'invalid namespace' using errcode='22023';
  end if;
  if p_decision_type not in ('project_spec','build','repair') then
    raise exception 'invalid decision type' using errcode='22023';
  end if;
  if p_outcome_status not in
    ('succeeded','failed','accepted','rejected','regressed','unknown') then
    raise exception 'invalid outcome status' using errcode='22023';
  end if;
  if p_usefulness_delta is null or p_usefulness_delta < -1 or p_usefulness_delta > 1 then
    raise exception 'usefulness delta out of range' using errcode='22023';
  end if;
  if nullif(trim(p_evidence_ref),'') is null or length(p_evidence_ref) > 500
     or p_evidence_ref ~* '(authorization|api[_-]?key|secret[_-]?value|bearer[[:space:]])' then
    raise exception 'invalid outcome evidence reference' using errcode='22023';
  end if;

  select id, memory_item_ids, used_for_decision, decision_type, decision_id,
         outcome_run_id, outcome_status, outcome_evidence_ref
  into v_log
  from public.memory_retrieval_logs
  where id = p_retrieval_log_id
    and user_id = p_memory_user_id
    and namespace = p_namespace
    and project_id = p_project_id
  for update;

  if not found or v_log.used_for_decision is not true
     or v_log.decision_type <> p_decision_type
     or v_log.decision_id <> p_decision_id then
    raise exception 'bound decision context not found' using errcode='P0002';
  end if;

  if v_log.outcome_run_id is not null and (
    v_log.outcome_run_id <> p_outcome_run_id
    or v_log.outcome_status <> p_outcome_status
    or v_log.outcome_evidence_ref <> trim(p_evidence_ref)
  ) then
    raise exception 'memory outcome lineage conflict' using errcode='23505';
  end if;

  update public.memory_retrieval_logs
  set outcome_run_id = p_outcome_run_id,
      outcome_status = p_outcome_status,
      outcome_evidence_ref = trim(p_evidence_ref)
  where id = p_retrieval_log_id;

  insert into public.memory_feedback_events(
    user_id, namespace, candidate_id, action, review_note, reason, metadata,
    project_id, memory_item_id, routing_decision_id, source_run_id,
    outcome_status, usefulness_delta, evidence_ref,
    retrieval_log_id, decision_type, decision_id
  )
  select
    p_memory_user_id,
    p_namespace,
    null,
    'decision_memory_outcome',
    null,
    'reviewable verified-outcome feedback for approved decision context',
    jsonb_build_object(
      'retrievalLogId', p_retrieval_log_id,
      'decisionType', p_decision_type,
      'decisionId', p_decision_id,
      'canonicalPolicyChanged', false,
      'metadataPolicy', 'decision_outcome_lineage_v1'
    ),
    p_project_id,
    item_id,
    null,
    p_outcome_run_id,
    p_outcome_status,
    p_usefulness_delta,
    trim(p_evidence_ref),
    p_retrieval_log_id,
    p_decision_type,
    p_decision_id
  from unnest(v_log.memory_item_ids) as item_id
  on conflict (retrieval_log_id, memory_item_id, source_run_id)
    where action = 'decision_memory_outcome'
      and retrieval_log_id is not null
      and memory_item_id is not null
      and source_run_id is not null
  do nothing;

  get diagnostics v_inserted = row_count;

  return jsonb_build_object(
    'retrievalLogId', p_retrieval_log_id,
    'decisionType', p_decision_type,
    'decisionId', p_decision_id,
    'outcomeRunId', p_outcome_run_id,
    'outcomeStatus', p_outcome_status,
    'memoryItemIds', v_log.memory_item_ids,
    'feedbackRowsInserted', v_inserted,
    'idempotentReplay', v_inserted = 0
  );
end $$;

revoke all on function public.memory_record_decision_outcome_v1(
  uuid,text,uuid,uuid,text,uuid,uuid,text,numeric,text
) from public,anon,authenticated;
grant execute on function public.memory_record_decision_outcome_v1(
  uuid,text,uuid,uuid,text,uuid,uuid,text,numeric,text
) to service_role;
