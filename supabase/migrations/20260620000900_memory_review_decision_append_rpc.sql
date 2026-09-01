-- Memory review decision append RPC.
-- Authenticated review decisions are append-only records.
-- Approval changes review state only; it never persists candidate memory rows.

create or replace function public.memory_review_append_decision(
  p_item_id uuid,
  p_action text,
  p_decision_metadata jsonb default '{}'::jsonb,
  p_namespace text default null
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_item record;
  v_to_status text;
  v_decision_id uuid := gen_random_uuid();
begin
  if v_user_id is null then
    raise exception 'authenticated user required' using errcode = '28000';
  end if;

  select id, user_id, namespace, status into v_item
  from public.memory_review_queue_items
  where id = p_item_id and user_id = v_user_id
  for update;

  if not found then
    raise exception 'review item not found for authenticated user' using errcode = 'P0002';
  end if;

  if p_namespace is not null and p_namespace <> v_item.namespace then
    raise exception 'review namespace mismatch' using errcode = '22023';
  end if;

  v_to_status := case p_action
    when 'approve_append' then 'approved_for_append'
    when 'reject' then 'rejected'
    when 'request_clarification' then 'needs_clarification'
    when 'mark_sensitive' then 'blocked_sensitive'
    when 'mark_namespace_mismatch' then 'blocked_namespace_mismatch'
    when 'archive' then 'archived'
    else null
  end;

  if v_to_status is null then
    raise exception 'unsupported review action' using errcode = '22023';
  end if;

  if not (
    (v_item.status = 'pending_review' and v_to_status in ('approved_for_append','rejected','needs_clarification','blocked_sensitive','blocked_namespace_mismatch','archived'))
    or (v_item.status = 'needs_clarification' and v_to_status in ('rejected','archived'))
    or (v_item.status in ('approved_for_append','rejected','blocked_namespace_mismatch','blocked_sensitive','blocked_policy') and v_to_status = 'archived')
  ) then
    raise exception 'invalid review status transition' using errcode = '22023';
  end if;

  insert into public.memory_review_queue_decisions (
    id, review_item_id, user_id, namespace, action, from_status, to_status, reviewer_context, decision_metadata, created_at
  ) values (
    v_decision_id,
    p_item_id,
    v_user_id,
    v_item.namespace,
    p_action,
    v_item.status,
    v_to_status,
    jsonb_build_object('userId', v_user_id, 'namespace', v_item.namespace, 'source', 'server_auth_context_only'),
    p_decision_metadata || jsonb_build_object('appendOnly', true, 'wouldPersist', false),
    now()
  );

  update public.memory_review_queue_items
  set status = v_to_status,
      updated_at = now(),
      archived_at = case when v_to_status = 'archived' then now() else archived_at end
  where id = p_item_id and user_id = v_user_id;

  return jsonb_build_object(
    'id', v_decision_id::text,
    'itemId', p_item_id::text,
    'userId', v_user_id::text,
    'namespace', v_item.namespace,
    'action', p_action,
    'reason', p_decision_metadata->>'reason',
    'createdAt', now()::text,
    'audit', jsonb_build_object('appendOnly', true, 'wouldPersist', false, 'fromStatus', v_item.status, 'toStatus', v_to_status)
  );
end;
$$;
comment on function public.memory_review_append_decision(uuid, text, jsonb, text) is
'Authenticated append-only review decision boundary. Uses auth.uid(), verifies item ownership and namespace, appends a decision, updates only review status, never mutates candidate content/namespace, and never persists memory.';
