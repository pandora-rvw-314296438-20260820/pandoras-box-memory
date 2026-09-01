-- Phase 4A daily ChatGPT memory bridge and learning loop.
-- Adds authenticated, namespace-scoped memory event capture and deterministic context packs.

create table if not exists public.memory_events (
  id uuid primary key default gen_random_uuid(),
  namespace public.pandora_namespace not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null,
  source_ref text,
  raw_text text not null check (length(btrim(raw_text)) > 0),
  extracted_summary text,
  importance integer check (importance is null or (importance >= 0 and importance <= 10)),
  sensitivity text check (sensitivity is null or sensitivity in ('low','medium','high','private')),
  status text not null default 'captured' check (status in ('captured','reviewed','promoted','ignored','archived')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.memory_context_packs (
  id uuid primary key default gen_random_uuid(),
  namespace public.pandora_namespace not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  pack_type text not null check (pack_type in ('daily','weekly','master','project','people','risk','operating_rules')),
  title text not null,
  summary text not null,
  key_points jsonb not null default '[]'::jsonb,
  active_projects jsonb,
  people_map jsonb,
  decisions jsonb,
  risks jsonb,
  open_loops jsonb,
  generated_from_event_ids jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (status in ('active','superseded','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists memory_events_user_namespace_status_created_idx on public.memory_events (user_id, namespace, status, created_at desc);
create index if not exists memory_context_packs_user_namespace_type_created_idx on public.memory_context_packs (user_id, namespace, pack_type, created_at desc);
alter table public.memory_events enable row level security;
alter table public.memory_context_packs enable row level security;
create policy "memory_events_authenticated_select_own_namespace"
  on public.memory_events for select to authenticated
  using (auth.uid() = user_id and namespace in ('real_life','au'));
create policy "memory_events_authenticated_insert_own_namespace"
  on public.memory_events for insert to authenticated
  with check (auth.uid() = user_id and auth.uid() = created_by and namespace in ('real_life','au'));
create policy "memory_events_authenticated_update_own_namespace"
  on public.memory_events for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and namespace in ('real_life','au'));
create policy "memory_context_packs_authenticated_select_own_namespace"
  on public.memory_context_packs for select to authenticated
  using (auth.uid() = user_id and namespace in ('real_life','au'));
create policy "memory_context_packs_authenticated_insert_own_namespace"
  on public.memory_context_packs for insert to authenticated
  with check (auth.uid() = user_id and namespace in ('real_life','au'));
create policy "memory_context_packs_authenticated_update_own_namespace"
  on public.memory_context_packs for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and namespace in ('real_life','au'));
