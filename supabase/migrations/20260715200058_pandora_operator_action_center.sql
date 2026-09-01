create table if not exists public.pandora_operator_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  request_id text not null,
  idempotency_key text not null,
  action_type text not null check (action_type in ('verify_namespace_invariants','verify_pack_supersession','check_retrieval_eval_status','refresh_dashboard_snapshot','prepare_distill_smoke_plan')),
  namespace text null check (namespace is null or namespace in ('real_life','au')),
  mode text not null default 'dry_run' check (mode in ('dry_run','queued_only')),
  status text not null default 'proposed' check (status in ('proposed','dry_ran','queued','blocked','completed','failed','cancelled')),
  title text not null,
  description text not null,
  payload jsonb not null default '{}'::jsonb,
  result jsonb not null default '{}'::jsonb,
  warnings text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz null,
  completed_at timestamptz null,
  failed_at timestamptz null,
  unique (user_id, idempotency_key)
);
create index if not exists pandora_operator_actions_user_created_idx on public.pandora_operator_actions (user_id, created_at desc);
create index if not exists pandora_operator_actions_user_status_idx on public.pandora_operator_actions (user_id, status);
create index if not exists pandora_operator_actions_user_type_idx on public.pandora_operator_actions (user_id, action_type);
create index if not exists pandora_operator_actions_user_namespace_idx on public.pandora_operator_actions (user_id, namespace);
alter table public.pandora_operator_actions enable row level security;
drop policy if exists "pandora_operator_actions_select_own" on public.pandora_operator_actions;
create policy "pandora_operator_actions_select_own" on public.pandora_operator_actions for select to authenticated using (user_id = auth.uid());
drop policy if exists "pandora_operator_actions_insert_own" on public.pandora_operator_actions;
create policy "pandora_operator_actions_insert_own" on public.pandora_operator_actions for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "pandora_operator_actions_update_own_bookkeeping" on public.pandora_operator_actions;
create policy "pandora_operator_actions_update_own_bookkeeping" on public.pandora_operator_actions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke update on public.pandora_operator_actions from authenticated;
grant update (status, result, warnings, updated_at, approved_at, completed_at, failed_at) on public.pandora_operator_actions to authenticated;
create table if not exists public.pandora_operator_action_events (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references public.pandora_operator_actions(id) on delete cascade,
  user_id uuid not null,
  event_type text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists pandora_operator_action_events_action_created_idx on public.pandora_operator_action_events (action_id, created_at desc);
create index if not exists pandora_operator_action_events_user_created_idx on public.pandora_operator_action_events (user_id, created_at desc);
alter table public.pandora_operator_action_events enable row level security;
drop policy if exists "pandora_operator_action_events_select_own" on public.pandora_operator_action_events;
create policy "pandora_operator_action_events_select_own" on public.pandora_operator_action_events for select to authenticated using (user_id = auth.uid());
drop policy if exists "pandora_operator_action_events_insert_own" on public.pandora_operator_action_events;
create policy "pandora_operator_action_events_insert_own" on public.pandora_operator_action_events for insert to authenticated with check (user_id = auth.uid());
