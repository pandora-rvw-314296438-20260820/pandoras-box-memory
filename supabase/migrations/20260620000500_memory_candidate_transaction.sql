-- Pandora Memory Engine memory candidate transaction RPC
-- Prompt 22: internal database-backed transaction path for validated memory candidates only.
--
-- This function does not create public API routes, OpenAI calls, pgvector retrieval,
-- memory ingest endpoints, GPT Actions, MCP tools, seed data, or fake rows.

create or replace function public.save_validated_memory_candidate_transaction(
  p_namespace public.pandora_namespace,
  p_memory_type public.memory_type,
  p_title text,
  p_body text,
  p_strength public.memory_strength,
  p_confidence numeric,
  p_canon_status public.canon_status,
  p_source_summary text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_sources jsonb default '[]'::jsonb,
  p_scope text default 'memory_candidate',
  p_operation text default 'saveMemoryCandidate',
  p_idempotency_key text default null,
  p_key_source text default 'payload',
  p_fingerprint text default null,
  p_request_hash text default null,
  p_response_hash text default null,
  p_expires_at timestamptz default null
)
returns table (
  memory_item_id uuid,
  source_ids uuid[],
  idempotency_record_id uuid,
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
  v_memory_item_id uuid;
  v_source_ids uuid[] := '{}'::uuid[];
  v_source jsonb;
  v_source_id uuid;
begin
  if v_user_id is null then
    raise exception 'auth_required';
  end if;

  if p_idempotency_key is null or length(p_idempotency_key) = 0 then
    raise exception 'idempotency_key_required';
  end if;

  if p_fingerprint is null or length(p_fingerprint) = 0 then
    raise exception 'idempotency_fingerprint_required';
  end if;

  if p_confidence < 0 or p_confidence > 1 then
    raise exception 'confidence_out_of_range';
  end if;

  if jsonb_typeof(coalesce(p_sources, '[]'::jsonb)) <> 'array' then
    raise exception 'sources_must_be_array';
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
    jsonb_build_object('transaction_rpc', 'memory_candidate') || coalesce(p_metadata, '{}'::jsonb),
    p_expires_at
  )
  on conflict (user_id, namespace, fingerprint) do nothing
  returning id into v_record_id;

  if v_record_id is null then
    select id, status
      into v_record_id, v_existing_status
    from public.idempotency_records
    where user_id = v_user_id
      and namespace = p_namespace
      and fingerprint = p_fingerprint
    limit 1;

    return query select null::uuid, '{}'::uuid[], v_record_id, false, v_existing_status;
    return;
  end if;

  insert into public.memory_items (
    user_id,
    namespace,
    memory_type,
    title,
    body,
    strength,
    confidence,
    canon_status,
    source_summary,
    metadata,
    is_active
  )
  values (
    v_user_id,
    p_namespace,
    p_memory_type,
    p_title,
    p_body,
    p_strength,
    p_confidence,
    p_canon_status,
    p_source_summary,
    coalesce(p_metadata, '{}'::jsonb),
    true
  )
  returning id into v_memory_item_id;

  for v_source in select value from jsonb_array_elements(coalesce(p_sources, '[]'::jsonb)) loop
    insert into public.memory_sources (
      user_id,
      namespace,
      memory_item_id,
      source_type,
      source_ref,
      excerpt,
      confidence,
      metadata
    )
    values (
      v_user_id,
      p_namespace,
      v_memory_item_id,
      (v_source ->> 'source_type')::public.evidence_source_type,
      v_source ->> 'source_ref',
      v_source ->> 'excerpt',
      coalesce((v_source ->> 'confidence')::numeric, p_confidence),
      coalesce(v_source -> 'metadata', '{}'::jsonb)
    )
    returning id into v_source_id;

    v_source_ids := array_append(v_source_ids, v_source_id);
  end loop;

  update public.idempotency_records
  set
    status = 'completed',
    response_hash = p_response_hash,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('memory_item_id', v_memory_item_id),
    updated_at = now()
  where id = v_record_id
    and user_id = v_user_id
    and namespace = p_namespace
    and fingerprint = p_fingerprint;

  return query select v_memory_item_id, v_source_ids, v_record_id, true, 'completed'::text;
end;
$$
