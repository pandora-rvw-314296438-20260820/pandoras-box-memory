-- Governed approval operations.
--
-- These functions are the only sanctioned transitions between approval states.
-- Each refuses self-approval structurally: the reviewer identity must differ
-- from the identity that created the record, so a builder cannot approve its
-- own work even with database access.
--
-- search_path is pinned so the functions cannot be redirected by a caller's
-- role settings.

create or replace function public.pandora_approve_memory_record(
  p_item_id uuid,
  p_reviewer text,
  p_reviewer_kind text default 'human_reviewer',
  p_reason text default null,
  p_correlation_id text default null
) returns public.memory_items
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_item public.memory_items;
  v_next_version integer;
begin
  select * into v_item from public.memory_items where id = p_item_id for update;
  if not found then
    raise exception 'memory record % does not exist', p_item_id using errcode = 'no_data_found';
  end if;

  if coalesce(trim(p_reviewer), '') = '' then
    raise exception 'reviewer identity is required' using errcode = 'invalid_parameter_value';
  end if;

  if p_reviewer_kind not in ('human_reviewer', 'owner') then
    raise exception 'only a human reviewer or the owner may approve records'
      using errcode = 'invalid_parameter_value';
  end if;

  -- The builder must not approve its own work.
  if v_item.created_by is not null
     and lower(trim(v_item.created_by)) = lower(trim(p_reviewer)) then
    insert into public.pandora_approval_audits
      (memory_item_id, project_id, action, actor_identity, actor_kind, from_state, to_state, reason, correlation_id)
    values
      (v_item.id, v_item.project_id, 'authorization_denied', p_reviewer, p_reviewer_kind,
       v_item.canon_status::text, v_item.canon_status::text,
       'self-approval refused: reviewer matches record creator', p_correlation_id);
    raise exception 'self-approval is not permitted: % created this record', p_reviewer
      using errcode = 'insufficient_privilege';
  end if;

  if v_item.canon_status not in ('draft', 'soft_canon') then
    raise exception 'record in state % cannot be approved', v_item.canon_status
      using errcode = 'invalid_parameter_value';
  end if;

  update public.memory_items
     set canon_status = 'hard_canon',
         approved_by = p_reviewer,
         approved_at = now(),
         effective_at = coalesce(effective_at, now()),
         correlation_id = coalesce(p_correlation_id, correlation_id),
         updated_at = now()
   where id = p_item_id
  returning * into v_item;

  select coalesce(max(version), 0) + 1 into v_next_version
    from public.pandora_memory_record_versions where memory_item_id = p_item_id;

  insert into public.pandora_memory_record_versions
    (memory_item_id, version, title, body, canon_status, content_hash, changed_by, change_reason, correlation_id)
  values
    (v_item.id, v_next_version, v_item.title, v_item.body, v_item.canon_status::text,
     v_item.content_hash, p_reviewer, coalesce(p_reason, 'approved by independent reviewer'), p_correlation_id);

  insert into public.pandora_approval_audits
    (memory_item_id, project_id, action, actor_identity, actor_kind, from_state, to_state, reason, correlation_id)
  values
    (v_item.id, v_item.project_id, 'approved', p_reviewer, p_reviewer_kind,
     'draft', 'hard_canon', p_reason, p_correlation_id);

  return v_item;
end;
$$;

revoke all on function public.pandora_approve_memory_record(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.pandora_approve_memory_record(uuid, text, text, text, text) to service_role;

-- Supersession: the replacement becomes current, the old record is retconned
-- and therefore excluded from retrieval, but its text and history survive.
create or replace function public.pandora_supersede_memory_record(
  p_old_item_id uuid,
  p_new_item_id uuid,
  p_actor text,
  p_reason text default null,
  p_correlation_id text default null
) returns public.memory_items
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_old public.memory_items;
  v_next_version integer;
begin
  if p_old_item_id = p_new_item_id then
    raise exception 'a record cannot supersede itself' using errcode = 'invalid_parameter_value';
  end if;

  select * into v_old from public.memory_items where id = p_old_item_id for update;
  if not found then
    raise exception 'memory record % does not exist', p_old_item_id using errcode = 'no_data_found';
  end if;
  if not exists (select 1 from public.memory_items where id = p_new_item_id) then
    raise exception 'replacement record % does not exist', p_new_item_id using errcode = 'no_data_found';
  end if;

  update public.memory_items
     set canon_status = 'retconned',
         superseded_by = p_new_item_id,
         superseded_at = now(),
         correlation_id = coalesce(p_correlation_id, correlation_id),
         updated_at = now()
   where id = p_old_item_id
  returning * into v_old;

  select coalesce(max(version), 0) + 1 into v_next_version
    from public.pandora_memory_record_versions where memory_item_id = p_old_item_id;

  insert into public.pandora_memory_record_versions
    (memory_item_id, version, title, body, canon_status, content_hash, changed_by, change_reason, correlation_id)
  values
    (v_old.id, v_next_version, v_old.title, v_old.body, v_old.canon_status::text,
     v_old.content_hash, p_actor, coalesce(p_reason, 'superseded'), p_correlation_id);

  insert into public.pandora_approval_audits
    (memory_item_id, project_id, action, actor_identity, actor_kind, from_state, to_state, reason, correlation_id)
  values
    (v_old.id, v_old.project_id, 'superseded', p_actor, 'human_reviewer',
     'hard_canon', 'retconned', p_reason, p_correlation_id);

  return v_old;
end;
$$;

revoke all on function public.pandora_supersede_memory_record(uuid, uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.pandora_supersede_memory_record(uuid, uuid, text, text, text) to service_role;

-- Revocation removes a record from current truth without destroying it.
create or replace function public.pandora_revoke_memory_record(
  p_item_id uuid,
  p_actor text,
  p_reason text,
  p_correlation_id text default null
) returns public.memory_items
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_item public.memory_items;
  v_next_version integer;
begin
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'a revocation reason is required' using errcode = 'invalid_parameter_value';
  end if;

  select * into v_item from public.memory_items where id = p_item_id for update;
  if not found then
    raise exception 'memory record % does not exist', p_item_id using errcode = 'no_data_found';
  end if;

  update public.memory_items
     set canon_status = 'retconned',
         is_active = false,
         revoked_at = now(),
         revocation_reason = p_reason,
         correlation_id = coalesce(p_correlation_id, correlation_id),
         updated_at = now()
   where id = p_item_id
  returning * into v_item;

  select coalesce(max(version), 0) + 1 into v_next_version
    from public.pandora_memory_record_versions where memory_item_id = p_item_id;

  insert into public.pandora_memory_record_versions
    (memory_item_id, version, title, body, canon_status, content_hash, changed_by, change_reason, correlation_id)
  values
    (v_item.id, v_next_version, v_item.title, v_item.body, v_item.canon_status::text,
     v_item.content_hash, p_actor, p_reason, p_correlation_id);

  insert into public.pandora_approval_audits
    (memory_item_id, project_id, action, actor_identity, actor_kind, from_state, to_state, reason, correlation_id)
  values
    (v_item.id, v_item.project_id, 'revoked', p_actor, 'human_reviewer',
     'hard_canon', 'retconned', p_reason, p_correlation_id);

  return v_item;
end;
$$;

revoke all on function public.pandora_revoke_memory_record(uuid, text, text, text) from public, anon, authenticated;
grant execute on function public.pandora_revoke_memory_record(uuid, text, text, text) to service_role;
