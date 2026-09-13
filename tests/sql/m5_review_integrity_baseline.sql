\set ON_ERROR_STOP on

create schema auth;
create schema extensions;
create extension if not exists pgcrypto with schema extensions;

do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;

grant usage on schema public,auth to authenticated;

create or replace function auth.uid()
returns uuid
language sql
stable
security invoker
set search_path='pg_catalog'
as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant execute on function auth.uid() to authenticated;

create type public.pandora_namespace as enum ('real_life','au');
create type public.memory_type as enum (
  'observation','user_preference','soft_canon','hard_canon','contradiction',
  'retcon_candidate','real_life_fact','business_fact','relationship_signal','risk_signal'
);
create type public.evidence_source_type as enum (
  'screenshot','email','document','user_statement','conversation_turn','url',
  'uploaded_file','manual_admin_entry','other'
);

create table public.memory_review_queue_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null check(namespace in ('real_life','au')),
  status text not null,
  candidate_type text not null,
  normalized_text text not null,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  sensitivity_snapshot jsonb not null default '{}'::jsonb,
  namespace_snapshot jsonb not null default '{}'::jsonb,
  source_metadata jsonb not null default '{}'::jsonb,
  audit_metadata jsonb not null default '{}'::jsonb,
  append_only boolean not null default true,
  proposed_operation text not null default 'append',
  requires_review boolean not null default true,
  source_ref text,
  request_hash text,
  fingerprint text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  persisted_at timestamptz,
  persistence_status text,
  persistence_execution_metadata jsonb not null default '{}'::jsonb,
  proposed_record_type text,
  proposed_authority_kind text,
  proposed_authority_ref text,
  proposed_confidence numeric(5,4),
  proposed_observed_at timestamptz,
  proposed_effective_at timestamptz,
  proposed_provenance jsonb,
  proposed_evidence_refs jsonb,
  proposed_promotion_basis text,
  proposed_correction_of uuid,
  explicit_policy_authorization boolean not null default false
);

create table public.memory_review_queue_decisions (
  id uuid primary key default gen_random_uuid(),
  review_item_id uuid not null references public.memory_review_queue_items(id),
  user_id uuid not null,
  namespace text not null,
  action text not null,
  from_status text not null,
  to_status text not null,
  reviewer_context jsonb not null,
  decision_metadata jsonb not null,
  created_at timestamptz not null default now()
);

create table public.memory_capture_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null,
  project_id uuid,
  source_ref text,
  record_type text not null default 'memory_candidate',
  status text not null default 'pending',
  reviewed_at timestamptz,
  stale_status text
);

create table public.memory_items (
  id uuid primary key,
  user_id uuid not null,
  namespace public.pandora_namespace not null,
  memory_type public.memory_type not null,
  title text not null,
  body text not null,
  source_summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  project_id uuid,
  record_type text,
  review_due_at timestamptz,
  is_active boolean not null default true
);

create table public.memory_sources (
  id uuid primary key,
  user_id uuid not null,
  namespace public.pandora_namespace not null,
  memory_item_id uuid references public.memory_items(id),
  source_type public.evidence_source_type not null,
  source_ref text,
  excerpt text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.memory_patches (
  id uuid primary key,
  user_id uuid not null,
  namespace public.pandora_namespace not null,
  memory_item_id uuid not null references public.memory_items(id),
  patch_type text not null,
  reason text,
  before_snapshot jsonb,
  after_snapshot jsonb not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key,
  user_id uuid not null,
  namespace public.pandora_namespace,
  action text not null,
  table_name text not null,
  record_id uuid,
  before_snapshot jsonb,
  after_snapshot jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index memory_review_queue_items_persistence_idempotency_idx
  on public.memory_review_queue_items((persistence_execution_metadata->>'idempotencyKey'))
  where persistence_execution_metadata ? 'idempotencyKey';

alter table public.memory_review_queue_items enable row level security;
alter table public.memory_review_queue_decisions enable row level security;
create policy memory_review_queue_items_select_own
  on public.memory_review_queue_items for select to authenticated
  using(user_id=auth.uid());
create policy memory_review_queue_items_insert_own
  on public.memory_review_queue_items for insert to authenticated
  with check(user_id=auth.uid());
create policy memory_review_queue_decisions_select_own
  on public.memory_review_queue_decisions for select to authenticated
  using(user_id=auth.uid());
create policy memory_review_queue_decisions_insert_own_item
  on public.memory_review_queue_decisions for insert to authenticated
  with check(
    user_id=auth.uid() and exists(
      select 1 from public.memory_review_queue_items i
      where i.id=review_item_id and i.user_id=auth.uid() and i.namespace=memory_review_queue_decisions.namespace
    )
  );

grant select,insert,update on public.memory_review_queue_items to authenticated;
grant select,insert on public.memory_review_queue_decisions to authenticated;
grant select,insert,update,delete on public.memory_review_queue_items to service_role;
grant select,insert,update,delete on public.memory_review_queue_decisions to service_role;
