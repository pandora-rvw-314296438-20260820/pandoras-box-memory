-- Phase 6A: Operating Brain Foundation
-- Additive-only migration. This creates the work-session anchor and operating cockpit data model.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create table if not exists public.work_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_key text,
  declared_goal text not null,
  proof_target text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'active',
  drift_score numeric,
  focus_score numeric,
  outcome_summary text,
  next_action text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.priority_locks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_key text not null,
  locked_outcome text not null,
  proof_target text,
  allowed_support text[],
  blocked_distractions text[],
  locked_until timestamptz,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.raw_movement_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  raw_text text not null,
  source text not null default 'manual',
  suggested_conversion jsonb,
  risk_level text not null default 'normal',
  status text not null default 'new',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.decision_gates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  action_considered text not null,
  desired_outcome text,
  facts text[],
  assumptions text[],
  risks text[],
  authority_check text,
  proof_required text,
  recommendation text,
  next_action text,
  status text not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.one_best_next_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  session_id uuid references public.work_sessions(id) on delete set null,
  priority_lock_id uuid references public.priority_locks(id) on delete set null,
  title text not null,
  reason text,
  proof_target text,
  timebox_minutes integer,
  steps text[],
  evidence_refs jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists work_sessions_user_namespace_created_idx
  on public.work_sessions (user_id, namespace, created_at desc);
create index if not exists work_sessions_user_status_idx
  on public.work_sessions (user_id, status);
create index if not exists work_sessions_user_project_idx
  on public.work_sessions (user_id, project_key)
  where project_key is not null;
create index if not exists work_sessions_active_lookup_idx
  on public.work_sessions (user_id, namespace, started_at desc)
  where status = 'active';
create index if not exists priority_locks_user_namespace_created_idx
  on public.priority_locks (user_id, namespace, created_at desc);
create index if not exists priority_locks_user_status_idx
  on public.priority_locks (user_id, status);
create index if not exists priority_locks_user_project_idx
  on public.priority_locks (user_id, project_key);
create index if not exists priority_locks_active_lookup_idx
  on public.priority_locks (user_id, namespace, created_at desc)
  where status = 'active';
create index if not exists raw_movement_items_user_namespace_created_idx
  on public.raw_movement_items (user_id, namespace, created_at desc);
create index if not exists raw_movement_items_user_status_idx
  on public.raw_movement_items (user_id, status);
create index if not exists decision_gates_user_namespace_created_idx
  on public.decision_gates (user_id, namespace, created_at desc);
create index if not exists decision_gates_user_status_idx
  on public.decision_gates (user_id, status);
create index if not exists one_best_next_actions_user_namespace_created_idx
  on public.one_best_next_actions (user_id, namespace, created_at desc);
create index if not exists one_best_next_actions_user_status_idx
  on public.one_best_next_actions (user_id, status);
create index if not exists one_best_next_actions_active_lookup_idx
  on public.one_best_next_actions (user_id, namespace, created_at desc)
  where status = 'active';
drop trigger if exists set_work_sessions_updated_at on public.work_sessions;
create trigger set_work_sessions_updated_at
before update on public.work_sessions
for each row execute function public.set_updated_at();
drop trigger if exists set_priority_locks_updated_at on public.priority_locks;
create trigger set_priority_locks_updated_at
before update on public.priority_locks
for each row execute function public.set_updated_at();
drop trigger if exists set_raw_movement_items_updated_at on public.raw_movement_items;
create trigger set_raw_movement_items_updated_at
before update on public.raw_movement_items
for each row execute function public.set_updated_at();
drop trigger if exists set_decision_gates_updated_at on public.decision_gates;
create trigger set_decision_gates_updated_at
before update on public.decision_gates
for each row execute function public.set_updated_at();
drop trigger if exists set_one_best_next_actions_updated_at on public.one_best_next_actions;
create trigger set_one_best_next_actions_updated_at
before update on public.one_best_next_actions
for each row execute function public.set_updated_at();
alter table public.work_sessions enable row level security;
alter table public.priority_locks enable row level security;
alter table public.raw_movement_items enable row level security;
alter table public.decision_gates enable row level security;
alter table public.one_best_next_actions enable row level security;
drop policy if exists "work_sessions_owner_all" on public.work_sessions;
create policy "work_sessions_owner_all"
on public.work_sessions
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
drop policy if exists "priority_locks_owner_all" on public.priority_locks;
create policy "priority_locks_owner_all"
on public.priority_locks
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
drop policy if exists "raw_movement_items_owner_all" on public.raw_movement_items;
create policy "raw_movement_items_owner_all"
on public.raw_movement_items
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
drop policy if exists "decision_gates_owner_all" on public.decision_gates;
create policy "decision_gates_owner_all"
on public.decision_gates
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
drop policy if exists "one_best_next_actions_owner_all" on public.one_best_next_actions;
create policy "one_best_next_actions_owner_all"
on public.one_best_next_actions
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
