-- Pandora Memory Engine idempotency RPC strategy
-- Prompt 20: database-backed coordination helpers only.
--
-- These functions provide a transaction-safe database boundary for claiming
-- and finishing idempotent operations. They do not create public API routes,
-- OpenAI calls, pgvector retrieval, memory ingest behavior, GPT Actions,
-- MCP tools, seed data, or fake rows.

create or replace function public.claim_idempotency_record(
  p_namespace public.pandora_namespace,
  p_scope text,
  p_operation text,
  p_idempotency_key text,
  p_key_source text,
  p_fingerprint text,
  p_request_hash text default null,
  p_expires_at timestamptz default null,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  record_id uuid,
  was_claimed boolean,
  existing_status text
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_record_id uuid;
  v_existing_status text;
begin
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  insert into public.idempotency_records (
    user_id,
    namespace,
    scope,
    operation,
    idempotency_key,
    key_source,
    fingerprint,
    request_hash,
    status,
    metadata,
    expires_at
  )
  values (
    v_user_id,
    p_namespace,
    p_scope,
    p_operation,
    p_idempotency_key,
    p_key_source,
    p_fingerprint,
    p_request_hash,
    'started',
    coalesce(p_metadata, '{}'::jsonb),
    p_expires_at
  )
  on conflict (user_id, namespace, fingerprint) do nothing
  returning id into v_record_id;

  if v_record_id is not null then
    return query select v_record_id, true, 'started'::text;
    return;
  end if;

  select id, status
  into v_record_id, v_existing_status
  from public.idempotency_records
  where user_id = v_user_id
    and namespace = p_namespace
    and fingerprint = p_fingerprint
  limit 1;

  return query select v_record_id, false, v_existing_status;
end;
$$;
create or replace function public.finish_idempotency_record(
  p_record_id uuid,
  p_namespace public.pandora_namespace,
  p_fingerprint text,
  p_status text,
  p_response_hash text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns table (
  record_id uuid,
  final_status text
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_status text;
begin
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if p_status not in ('completed', 'failed') then
    raise exception 'invalid_idempotency_status';
  end if;

  update public.idempotency_records
  set
    status = p_status,
    response_hash = p_response_hash,
    metadata = coalesce(metadata, '{}'::jsonb) || coalesce(p_metadata, '{}'::jsonb),
    updated_at = now()
  where id = p_record_id
    and user_id = v_user_id
    and namespace = p_namespace
    and fingerprint = p_fingerprint
  returning status into v_status;

  if v_status is null then
    raise exception 'idempotency_record_not_found';
  end if;

  return query select p_record_id, v_status;
end;
$$;
