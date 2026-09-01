-- Future response-cache storage contract for disabled memory ingest.
-- This migration defines schema only. The public route remains disabled and does not write here.

create table if not exists public.memory_ingest_response_cache (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace text not null check (namespace in ('real_life', 'au')),
  idempotency_key text not null check (char_length(idempotency_key) between 8 and 128),
  request_hash text not null check (char_length(request_hash) >= 16),
  response_status integer not null check (response_status between 200 and 599),
  response_body jsonb not null,
  warnings jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_replayed_at timestamptz,
  replay_count integer not null default 0 check (replay_count >= 0),
  constraint memory_ingest_response_cache_key_unique unique (user_id, namespace, idempotency_key)
);
alter table public.memory_ingest_response_cache enable row level security;
comment on table public.memory_ingest_response_cache is
  'Future contract table for memory ingest response caching. Disabled route does not read or write this table yet.';
comment on column public.memory_ingest_response_cache.request_hash is
  'Future normalized request hash used to detect idempotency conflicts before replay.';
comment on column public.memory_ingest_response_cache.response_body is
  'Future cached successful response body for safe idempotent replay.';
create index if not exists memory_ingest_response_cache_user_namespace_idx
  on public.memory_ingest_response_cache (user_id, namespace);
create index if not exists memory_ingest_response_cache_expires_at_idx
  on public.memory_ingest_response_cache (expires_at);
