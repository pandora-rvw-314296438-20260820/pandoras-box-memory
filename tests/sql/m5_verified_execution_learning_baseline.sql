-- Disposable PostgreSQL objects needed by the M5-003 verified-execution learning migration.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if not exists (select 1 from pg_roles where rolname='anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then
    create role service_role nologin;
  end if;
end $$;

create table public.pandora_projects (
  id uuid primary key,
  project_key text not null unique,
  aliases text[] not null default '{}'::text[],
  memory_namespace text not null,
  lifecycle_status text not null default 'active'
);

create table public.pandora_project_grants (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null,
  project_id uuid not null,
  environment text not null,
  allowed_record_types text[] not null default '{}'::text[],
  can_read boolean not null default false,
  can_propose boolean not null default false,
  can_approve boolean not null default false,
  is_active boolean not null default true,
  revoked_at timestamptz,
  unique(principal_key,project_id,environment)
);
create table public.memory_capture_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null,
  source text not null,
  source_ref text not null,
  raw_excerpt text,
  redacted_excerpt text,
  memory_type text,
  title text,
  summary text,
  importance integer,
  sensitivity text,
  confidence numeric,
  should_capture boolean not null default true,
  requires_review boolean not null default true,
  status text not null default 'pending',
  reason text,
  people jsonb not null default '[]'::jsonb,
  projects jsonb not null default '[]'::jsonb,
  risks jsonb not null default '[]'::jsonb,
  tags jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  project_id uuid,
  record_type text not null default 'memory_candidate',
  evidence_refs text[] not null default '{}'::text[],
  evidence_window_start timestamptz,
  evidence_window_end timestamptz,
  source_system text,
  created_at timestamptz not null default now()
);

create table public.memory_review_queue_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, namespace text not null,
  status text not null, candidate_type text not null, normalized_text text not null,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  sensitivity_snapshot jsonb not null default '{}'::jsonb,
  namespace_snapshot jsonb not null default '{}'::jsonb,
  source_metadata jsonb not null default '{}'::jsonb,
  audit_metadata jsonb not null default '{}'::jsonb,
  append_only boolean not null default true, proposed_operation text not null default 'append',
  requires_review boolean not null default true, source_ref text, request_hash text, fingerprint text,
  proposed_record_type text, proposed_authority_kind text, proposed_authority_ref text,
  proposed_confidence numeric(5,4), proposed_observed_at timestamptz, proposed_effective_at timestamptz,
  proposed_provenance jsonb, proposed_evidence_refs jsonb, proposed_promotion_basis text,
  proposed_correction_of uuid, explicit_policy_authorization boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.memory_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null, namespace text not null,
  project_id uuid, record_type text, body text, created_at timestamptz not null default now()
);
