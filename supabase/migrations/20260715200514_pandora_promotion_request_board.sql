create table if not exists public.pandora_promotion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  request_id text not null,
  namespace text not null check (namespace in ('real_life','au')),
  shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete restrict,
  preflight_id uuid not null references public.pandora_shadow_pack_preflights(id) on delete restrict,
  active_master_pack_id uuid null,
  status text not null default 'draft' check (status in ('draft','submitted','approved','blocked','archived')),
  title text not null,
  summary text not null,
  promotion_plan jsonb not null default '{}'::jsonb,
  rollback_plan jsonb not null default '{}'::jsonb,
  risk_snapshot jsonb not null default '{}'::jsonb,
  diff_snapshot jsonb not null default '{}'::jsonb,
  reviewer_notes text not null default '',
  reviewer_decision text null check (reviewer_decision is null or reviewer_decision in ('approved','blocked','needs_changes')),
  warnings text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  submitted_at timestamptz null,
  approved_at timestamptz null,
  blocked_at timestamptz null,
  archived_at timestamptz null,
  unique (user_id, preflight_id)
);
create index if not exists pandora_promotion_requests_user_created_idx on public.pandora_promotion_requests (user_id, created_at desc);
create index if not exists pandora_promotion_requests_user_namespace_status_idx on public.pandora_promotion_requests (user_id, namespace, status);
create index if not exists pandora_promotion_requests_user_shadow_idx on public.pandora_promotion_requests (user_id, shadow_pack_id);
create index if not exists pandora_promotion_requests_user_preflight_idx on public.pandora_promotion_requests (user_id, preflight_id);
create table if not exists public.pandora_promotion_request_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  promotion_request_id uuid not null references public.pandora_promotion_requests(id) on delete cascade,
  shadow_pack_id uuid not null references public.pandora_shadow_context_packs(id) on delete restrict,
  preflight_id uuid not null references public.pandora_shadow_pack_preflights(id) on delete restrict,
  event_type text not null,
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists pandora_promotion_request_events_user_request_created_idx on public.pandora_promotion_request_events (user_id, promotion_request_id, created_at desc);
create index if not exists pandora_promotion_request_events_user_shadow_created_idx on public.pandora_promotion_request_events (user_id, shadow_pack_id, created_at desc);
create index if not exists pandora_promotion_request_events_user_preflight_created_idx on public.pandora_promotion_request_events (user_id, preflight_id, created_at desc);
create or replace function public.set_pandora_promotion_requests_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists set_pandora_promotion_requests_updated_at on public.pandora_promotion_requests;
create trigger set_pandora_promotion_requests_updated_at
before update on public.pandora_promotion_requests
for each row execute function public.set_pandora_promotion_requests_updated_at();
alter table public.pandora_promotion_requests enable row level security;
alter table public.pandora_promotion_request_events enable row level security;
create policy "pandora_promotion_requests_select_own" on public.pandora_promotion_requests for select to authenticated using (user_id = auth.uid());
create policy "pandora_promotion_requests_insert_own" on public.pandora_promotion_requests for insert to authenticated with check (user_id = auth.uid());
create policy "pandora_promotion_requests_update_own" on public.pandora_promotion_requests for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "pandora_promotion_request_events_select_own" on public.pandora_promotion_request_events for select to authenticated using (user_id = auth.uid());
create policy "pandora_promotion_request_events_insert_own" on public.pandora_promotion_request_events for insert to authenticated with check (user_id = auth.uid());
create policy "pandora_promotion_request_events_update_own" on public.pandora_promotion_request_events for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
