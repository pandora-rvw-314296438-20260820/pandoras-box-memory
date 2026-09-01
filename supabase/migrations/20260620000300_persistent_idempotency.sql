-- Pandora Memory Engine persistent idempotency storage
-- Prompt 18: storage and RLS support only.
--
-- This migration creates durable idempotency records for future mutation routes.
-- It intentionally does not create public API routes, OpenAI calls, pgvector,
-- memory ingest behavior, GPT Actions, MCP tools, seed data, or fake rows.

create table public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  scope text not null,
  operation text not null,
  idempotency_key text not null check (char_length(idempotency_key) > 0 and char_length(idempotency_key) <= 200),
  key_source text not null check (key_source in ('client', 'request', 'payload')),
  fingerprint text not null,
  request_hash text,
  response_hash text,
  status text not null default 'started' check (status in ('started', 'completed', 'failed')),
  metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, namespace, fingerprint)
);
create index idempotency_records_owner_namespace_idx on public.idempotency_records (user_id, namespace, created_at desc);
create index idempotency_records_fingerprint_idx on public.idempotency_records (user_id, namespace, fingerprint);
create index idempotency_records_expires_at_idx on public.idempotency_records (expires_at) where expires_at is not null;
alter table public.idempotency_records enable row level security;
alter table public.idempotency_records force row level security;
create policy idempotency_records_select_own on public.idempotency_records for select to authenticated using (auth.uid() = user_id);
create policy idempotency_records_insert_own on public.idempotency_records for
insert to authenticated with check (auth.uid() = user_id);
create policy idempotency_records_update_own on public.idempotency_records for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
