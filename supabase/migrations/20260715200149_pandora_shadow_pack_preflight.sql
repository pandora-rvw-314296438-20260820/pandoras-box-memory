create table if not exists public.pandora_shadow_pack_preflights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete cascade,
  namespace text not null check (namespace in ('real_life','au')),
  active_master_pack_id uuid null,
  request_id text not null,
  status text not null default 'draft' check (status in ('draft','ready_for_review','reviewed','approved_for_promotion','blocked','archived')),
  diff_summary jsonb not null default '{}'::jsonb,
  risk_summary jsonb not null default '{}'::jsonb,
  reviewer_notes text not null default '',
  reviewer_decision text null check (reviewer_decision is null or reviewer_decision in ('needs_changes','approved_for_promotion','blocked')),
  warnings text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_at timestamptz null,
  approved_for_promotion_at timestamptz null,
  blocked_at timestamptz null,
  unique (user_id, shadow_pack_id)
);
create index if not exists idx_pandora_shadow_pack_preflights_user_created on public.pandora_shadow_pack_preflights(user_id, created_at desc);
create index if not exists idx_pandora_shadow_pack_preflights_user_namespace_status on public.pandora_shadow_pack_preflights(user_id, namespace, status);
create index if not exists idx_pandora_shadow_pack_preflights_user_shadow on public.pandora_shadow_pack_preflights(user_id, shadow_pack_id);
alter table public.pandora_shadow_pack_preflights enable row level security;
create policy "shadow pack preflights select own" on public.pandora_shadow_pack_preflights for select to authenticated using (user_id = auth.uid());
create policy "shadow pack preflights insert own" on public.pandora_shadow_pack_preflights for insert to authenticated with check (user_id = auth.uid());
create policy "shadow pack preflights update own" on public.pandora_shadow_pack_preflights for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create table if not exists public.pandora_shadow_pack_preflight_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  preflight_id uuid not null references public.pandora_shadow_pack_preflights(id) on delete cascade,
  shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete cascade,
  event_type text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_pandora_shadow_pack_preflight_events_user_preflight_created on public.pandora_shadow_pack_preflight_events(user_id, preflight_id, created_at desc);
create index if not exists idx_pandora_shadow_pack_preflight_events_user_shadow_created on public.pandora_shadow_pack_preflight_events(user_id, shadow_pack_id, created_at desc);
alter table public.pandora_shadow_pack_preflight_events enable row level security;
create policy "shadow pack preflight events select own" on public.pandora_shadow_pack_preflight_events for select to authenticated using (user_id = auth.uid());
create policy "shadow pack preflight events insert own" on public.pandora_shadow_pack_preflight_events for insert to authenticated with check (user_id = auth.uid());
create policy "shadow pack preflight events update own" on public.pandora_shadow_pack_preflight_events for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
