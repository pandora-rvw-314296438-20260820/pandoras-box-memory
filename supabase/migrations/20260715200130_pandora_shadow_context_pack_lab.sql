alter table public.pandora_operator_actions drop constraint if exists pandora_operator_actions_action_type_check;
alter table public.pandora_operator_actions add constraint pandora_operator_actions_action_type_check check (action_type in ('verify_namespace_invariants','verify_pack_supersession','check_retrieval_eval_status','refresh_dashboard_snapshot','prepare_distill_smoke_plan','prepare_shadow_context_pack'));
create table if not exists public.pandora_shadow_context_packs (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, request_id text not null,
  operator_action_id uuid null references public.pandora_operator_actions(id) on delete set null,
  namespace text not null check (namespace in ('real_life','au')), pack_type text not null default 'master_candidate',
  status text not null default 'draft' check (status in ('draft','ready_for_review','reviewed','rejected','archived')),
  title text not null, summary text not null, source_window jsonb not null default '{}'::jsonb,
  candidate_payload jsonb not null default '{}'::jsonb, evidence jsonb not null default '{}'::jsonb,
  warnings text[] not null default '{}'::text[], created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  reviewed_at timestamptz null, rejected_at timestamptz null, archived_at timestamptz null
);
create table if not exists public.pandora_shadow_context_pack_events (
  id uuid primary key default gen_random_uuid(), shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete cascade,
  user_id uuid not null, event_type text not null, message text not null, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create index if not exists pandora_shadow_context_packs_user_created_idx on public.pandora_shadow_context_packs(user_id, created_at desc);
create index if not exists pandora_shadow_context_packs_user_namespace_status_idx on public.pandora_shadow_context_packs(user_id, namespace, status);
create index if not exists pandora_shadow_context_packs_user_action_idx on public.pandora_shadow_context_packs(user_id, operator_action_id);
create index if not exists pandora_shadow_context_pack_events_user_pack_created_idx on public.pandora_shadow_context_pack_events(user_id, shadow_pack_id, created_at desc);
alter table public.pandora_shadow_context_packs enable row level security;
alter table public.pandora_shadow_context_pack_events enable row level security;
create policy "pandora_shadow_context_packs_select_own" on public.pandora_shadow_context_packs for select to authenticated using (user_id = auth.uid());
create policy "pandora_shadow_context_packs_insert_own" on public.pandora_shadow_context_packs for insert to authenticated with check (user_id = auth.uid());
create policy "pandora_shadow_context_packs_update_own" on public.pandora_shadow_context_packs for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "pandora_shadow_context_pack_events_select_own" on public.pandora_shadow_context_pack_events for select to authenticated using (user_id = auth.uid());
create policy "pandora_shadow_context_pack_events_insert_own" on public.pandora_shadow_context_pack_events for insert to authenticated with check (user_id = auth.uid());
create or replace function public.set_pandora_shadow_context_pack_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists set_pandora_shadow_context_pack_updated_at on public.pandora_shadow_context_packs;
create trigger set_pandora_shadow_context_pack_updated_at before update on public.pandora_shadow_context_packs for each row execute function public.set_pandora_shadow_context_pack_updated_at();
