-- Pandora promotion executor v1.
-- Additive: widens the promotion request status set with 'promoted' and adds
-- execution/audit tables. Execution itself stays disabled unless
-- PANDORA_ENABLE_CONTEXT_PACK_PROMOTION=true AND the request is human-approved.
-- Promotion is status-only on memory_context_packs (archive old master, insert
-- new master from the reviewed shadow candidate); nothing is ever deleted and
-- memory_events / memory_items / memory_profiles are never touched.

alter table public.pandora_promotion_requests drop constraint if exists pandora_promotion_requests_status_check;
alter table public.pandora_promotion_requests add constraint pandora_promotion_requests_status_check
  check (status in ('draft','submitted','approved','blocked','archived','promoted'));
create table if not exists public.pandora_promotion_executions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  request_id text not null,
  namespace text not null check (namespace in ('real_life','au')),
  promotion_request_id uuid not null references public.pandora_promotion_requests(id) on delete restrict,
  preflight_id uuid not null references public.pandora_shadow_pack_preflights(id) on delete restrict,
  shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete restrict,
  previous_master_pack_id uuid null,
  promoted_pack_id uuid null,
  mode text not null check (mode in ('execute','rollback')),
  status text not null check (status in ('executed','rolled_back','blocked','failed')),
  plan jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  warnings text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  executed_at timestamptz null,
  rolled_back_at timestamptz null
);
create index if not exists pandora_promotion_executions_user_created_idx on public.pandora_promotion_executions (user_id, created_at desc);
create index if not exists pandora_promotion_executions_user_request_idx on public.pandora_promotion_executions (user_id, promotion_request_id);
create index if not exists pandora_promotion_executions_user_namespace_status_idx on public.pandora_promotion_executions (user_id, namespace, status);
create table if not exists public.pandora_promotion_execution_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  execution_id uuid not null references public.pandora_promotion_executions(id) on delete cascade,
  promotion_request_id uuid not null references public.pandora_promotion_requests(id) on delete restrict,
  event_type text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists pandora_promotion_execution_events_user_execution_created_idx on public.pandora_promotion_execution_events (user_id, execution_id, created_at desc);
create or replace function public.set_pandora_promotion_executions_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists set_pandora_promotion_executions_updated_at on public.pandora_promotion_executions;
create trigger set_pandora_promotion_executions_updated_at
before update on public.pandora_promotion_executions
for each row execute function public.set_pandora_promotion_executions_updated_at();
alter table public.pandora_promotion_executions enable row level security;
alter table public.pandora_promotion_execution_events enable row level security;
create policy "pandora_promotion_executions_select_own" on public.pandora_promotion_executions for select to authenticated using (user_id = auth.uid());
create policy "pandora_promotion_executions_insert_own" on public.pandora_promotion_executions for insert to authenticated with check (user_id = auth.uid());
create policy "pandora_promotion_executions_update_own" on public.pandora_promotion_executions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "pandora_promotion_execution_events_select_own" on public.pandora_promotion_execution_events for select to authenticated using (user_id = auth.uid());
create policy "pandora_promotion_execution_events_insert_own" on public.pandora_promotion_execution_events for insert to authenticated with check (user_id = auth.uid());
