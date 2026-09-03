-- P5 customer-continuity hardening: bind approved-review persistence to exact project lineage when present
-- and make idempotent replay identity-safe. Forward-only function replacement; no data rewrite.

create or replace function public.memory_execute_approved_review_persistence(
  p_review_item_id uuid,
  p_namespace text,
  p_approved_decision_id uuid,
  p_idempotency_key text,
  p_preview_fingerprint text,
  p_planned_operation jsonb
) returns jsonb
language plpgsql
set search_path to 'pg_catalog', 'public', 'extensions'
as $function$
declare
  v_user_id uuid := auth.uid();
  v_item record;
  v_decision record;
  v_existing record;
  v_memory_item_id uuid := gen_random_uuid();
  v_source_id uuid := gen_random_uuid();
  v_patch_id uuid := gen_random_uuid();
  v_audit_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_project_id uuid := null;
  v_candidate_id uuid := null;
  v_planned_operation_sha256 text;
begin
  if v_user_id is null then raise exception 'authenticated user required' using errcode = '28000'; end if;
  if nullif(trim(coalesce(p_idempotency_key, '')), '') is null then raise exception 'idempotency key required' using errcode = '22023'; end if;
  if nullif(trim(coalesce(p_preview_fingerprint, '')), '') is null then raise exception 'preview fingerprint required' using errcode = '22023'; end if;
  if p_planned_operation is null or jsonb_typeof(p_planned_operation) <> 'object' then raise exception 'planned operation object required' using errcode = '22023'; end if;
  if p_planned_operation ? 'user_id' or p_planned_operation ? 'userId' then raise exception 'client user id is not accepted' using errcode = '22023'; end if;

  v_planned_operation_sha256 := encode(extensions.digest(convert_to(p_planned_operation::text, 'utf8'), 'sha256'), 'hex');

  select * into v_existing
  from public.memory_review_queue_items
  where user_id = v_user_id
    and persistence_execution_metadata->>'idempotencyKey' = p_idempotency_key
  limit 1;

  if found then
    if v_existing.id is distinct from p_review_item_id
       or coalesce(v_existing.persistence_execution_metadata->>'previewFingerprint', '') is distinct from p_preview_fingerprint
       or coalesce(v_existing.persistence_execution_metadata->>'plannedOperationSha256', '') is distinct from v_planned_operation_sha256 then
      raise exception 'idempotency_conflict' using errcode = '23505';
    end if;
    return jsonb_build_object(
      'executed', true, 'idempotentReplay', true, 'productionRouteEnabled', false, 'publicRouteEnabled', false, 'appendOnly', true,
      'namespace', v_existing.namespace, 'userId', v_user_id::text, 'reviewItemId', v_existing.id::text,
      'fingerprint', v_existing.persistence_execution_metadata->>'previewFingerprint', 'idempotencyKey', p_idempotency_key,
      'projectId', v_existing.persistence_execution_metadata->>'projectId',
      'counts', jsonb_build_object('sources',0,'items',0,'patches',0,'auditLogs',0,'markedReviewItems',0,'blocked',0,'failed',0),
      'blockers', '[]'::jsonb, 'warnings', jsonb_build_array('idempotent_replay')
    );
  end if;

  select * into v_item
  from public.memory_review_queue_items
  where id = p_review_item_id and user_id = v_user_id
  for update;
  if not found then raise exception 'review item not found for authenticated user' using errcode = 'P0002'; end if;
  if v_item.namespace <> p_namespace then raise exception 'review namespace mismatch' using errcode = '22023'; end if;
  if v_item.status <> 'approved_for_append' then raise exception 'review item is not approved_for_append' using errcode = '22023'; end if;
  if v_item.archived_at is not null or v_item.status = 'archived' then raise exception 'archived review item cannot be persisted' using errcode = '22023'; end if;
  if v_item.persisted_at is not null or v_item.persistence_status = 'persisted' then raise exception 'review item has already been persisted' using errcode = '23505'; end if;
  if v_item.append_only is not true or v_item.proposed_operation <> 'append' then raise exception 'only append operation is allowed' using errcode = '22023'; end if;
  if v_item.evidence_snapshot is null or coalesce((v_item.evidence_snapshot->>'hasEvidence')::boolean, false) is not true then raise exception 'evidence snapshot required' using errcode = '22023'; end if;
  if p_planned_operation->'patch'->>'operation' <> 'append' then raise exception 'update/delete/overwrite operations are rejected' using errcode = '22023'; end if;
  if coalesce((p_planned_operation->'source'->>'appendOnly')::boolean, false) is not true
    or coalesce((p_planned_operation->'item'->>'appendOnly')::boolean, false) is not true
    or coalesce((p_planned_operation->'patch'->>'appendOnly')::boolean, false) is not true
    or coalesce((p_planned_operation->'auditLog'->>'appendOnly')::boolean, false) is not true then
    raise exception 'append-only planned operation required' using errcode = '22023';
  end if;
  if p_planned_operation->'source'->>'namespace' <> v_item.namespace or p_planned_operation->'item'->>'namespace' <> v_item.namespace or p_planned_operation->'patch'->>'namespace' <> v_item.namespace then
    raise exception 'planned operation namespace mismatch' using errcode = '22023';
  end if;
  if p_planned_operation->'item'->>'content' <> v_item.normalized_text then raise exception 'candidate text mutation rejected' using errcode = '22023'; end if;
  if v_item.namespace = 'au' and coalesce(p_planned_operation->'namespaceSafety'->>'targetNamespace', v_item.namespace) = 'real_life' then raise exception 'AU story memory cannot become real-life evidence' using errcode = '22023'; end if;
  if v_item.namespace = 'real_life' and coalesce(p_planned_operation->'namespaceSafety'->>'targetNamespace', v_item.namespace) = 'au' then raise exception 'real-life memory cannot enter AU without fictionalized review' using errcode = '22023'; end if;

  begin
    v_project_id := nullif(v_item.source_metadata->>'projectId','')::uuid;
    v_candidate_id := nullif(v_item.source_metadata->>'candidateId','')::uuid;
  exception when others then
    raise exception 'invalid typed review lineage metadata' using errcode = '22023';
  end;

  if v_candidate_id is not null and v_project_id is null then
    raise exception 'candidate project lineage required' using errcode = '22023';
  end if;

  if v_candidate_id is not null then
    perform 1
    from public.memory_capture_candidates c
    where c.id = v_candidate_id
      and c.user_id = v_user_id
      and c.namespace = v_item.namespace
      and c.project_id = v_project_id
      and c.source_ref = v_item.source_ref;
    if not found then raise exception 'candidate/review lineage mismatch' using errcode = '22023'; end if;
  end if;

  select * into v_decision
  from public.memory_review_queue_decisions
  where id = p_approved_decision_id and review_item_id = p_review_item_id and user_id = v_user_id and namespace = v_item.namespace and to_status = 'approved_for_append'
  order by created_at desc limit 1;
  if not found then raise exception 'valid approved append decision required' using errcode = '22023'; end if;

  insert into public.memory_items (id, user_id, namespace, memory_type, title, body, source_summary, metadata, created_at, updated_at, project_id)
  values (v_memory_item_id, v_user_id, v_item.namespace::public.pandora_namespace, 'observation'::public.memory_type, left(v_item.normalized_text, 120), v_item.normalized_text, v_item.source_ref,
    jsonb_strip_nulls(jsonb_build_object('reviewItemId', v_item.id, 'reviewDecisionId', p_approved_decision_id, 'previewFingerprint', p_preview_fingerprint, 'idempotencyKey', p_idempotency_key, 'plannedOperationSha256', v_planned_operation_sha256, 'projectId', v_project_id, 'candidateId', v_candidate_id, 'appendOnly', true)), v_now, v_now, v_project_id);
  insert into public.memory_sources (id, user_id, namespace, memory_item_id, source_type, source_ref, excerpt, metadata, created_at)
  values (v_source_id, v_user_id, v_item.namespace::public.pandora_namespace, v_memory_item_id, 'user_statement'::public.evidence_source_type, v_item.source_ref, v_item.normalized_text,
    jsonb_build_object('reviewItemId', v_item.id, 'evidenceSnapshot', v_item.evidence_snapshot, 'sourceMetadata', v_item.source_metadata, 'appendOnly', true), v_now);
  insert into public.memory_patches (id, user_id, namespace, memory_item_id, patch_type, reason, before_snapshot, after_snapshot, metadata, created_at)
  values (v_patch_id, v_user_id, v_item.namespace::public.pandora_namespace, v_memory_item_id, 'append', 'approved_review_memory_persistence', null,
    jsonb_build_object('body', v_item.normalized_text, 'namespace', v_item.namespace), jsonb_build_object('reviewItemId', v_item.id, 'appendOnly', true), v_now);
  insert into public.audit_logs (id, user_id, namespace, action, table_name, record_id, before_snapshot, after_snapshot, metadata, created_at)
  values (v_audit_id, v_user_id, v_item.namespace::public.pandora_namespace, 'approved_review_memory_persistence_executed', 'memory_review_queue_items', v_item.id, null,
    jsonb_build_object('memoryItemId', v_memory_item_id, 'sourceId', v_source_id, 'patchId', v_patch_id), jsonb_strip_nulls(jsonb_build_object('reviewItemId', v_item.id, 'reviewDecisionId', p_approved_decision_id, 'idempotencyKey', p_idempotency_key, 'plannedOperationSha256', v_planned_operation_sha256, 'projectId', v_project_id, 'appendOnly', true)), v_now);

  update public.memory_review_queue_items
  set persisted_at = v_now, persistence_status = 'persisted', updated_at = v_now,
      persistence_execution_metadata = persistence_execution_metadata || jsonb_strip_nulls(jsonb_build_object('idempotencyKey', p_idempotency_key, 'previewFingerprint', p_preview_fingerprint, 'plannedOperationSha256', v_planned_operation_sha256, 'projectId', v_project_id, 'memoryItemId', v_memory_item_id, 'sourceId', v_source_id, 'patchId', v_patch_id, 'auditLogId', v_audit_id))
  where id = v_item.id and user_id = v_user_id;

  return jsonb_build_object('executed', true, 'idempotentReplay', false, 'productionRouteEnabled', false, 'publicRouteEnabled', false, 'appendOnly', true, 'namespace', v_item.namespace, 'userId', v_user_id::text,
    'reviewItemId', v_item.id::text, 'fingerprint', p_preview_fingerprint, 'idempotencyKey', p_idempotency_key, 'projectId', v_project_id,
    'counts', jsonb_build_object('sources',1,'items',1,'patches',1,'auditLogs',1,'markedReviewItems',1,'blocked',0,'failed',0), 'blockers', '[]'::jsonb, 'warnings', '[]'::jsonb,
    'source', jsonb_build_object('kind','memory_source_append','id',v_source_id::text,'appendOnly',true),
    'item', jsonb_build_object('kind','memory_item_append','id',v_memory_item_id::text,'appendOnly',true),
    'patch', jsonb_build_object('kind','memory_patch_append','id',v_patch_id::text,'appendOnly',true),
    'auditLog', jsonb_build_object('kind','audit_log_append','id',v_audit_id::text,'appendOnly',true));
end;
$function$;
