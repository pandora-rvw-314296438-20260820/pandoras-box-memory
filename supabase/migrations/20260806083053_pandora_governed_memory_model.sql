-- Governed durable memory model for Pandora's-Box / ProjectOS.
-- Strictly additive. No existing table is dropped, renamed, or rewritten.
-- Every object uses IF NOT EXISTS so re-running is a no-op.
-- Access follows the pandora_service_principals precedent: RLS enabled, no
-- policies, anon/authenticated revoked, service_role only.

create table if not exists public.pandora_projects (
  id uuid primary key default gen_random_uuid(),
  project_key text not null unique,
  canonical_name text not null,
  aliases text[] not null default array[]::text[],
  github_owner text,
  github_repository text,
  supabase_project_ref text,
  vercel_project_id text,
  production_url text,
  memory_namespace text not null default 'real_life'
    check (memory_namespace in ('real_life', 'au')),
  lifecycle_status text not null default 'active'
    check (lifecycle_status in ('active', 'paused', 'archived')),
  confidentiality text not null default 'internal'
    check (confidentiality in ('public', 'internal', 'restricted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pandora_projects enable row level security;
revoke all on table public.pandora_projects from anon, authenticated;
grant select on table public.pandora_projects to service_role;
comment on table public.pandora_projects is
  'Canonical project identities that scope governed memory retrieval.';

create table if not exists public.pandora_project_grants (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null
    references public.pandora_service_principals (principal_key) on delete cascade,
  project_id uuid not null
    references public.pandora_projects (id) on delete cascade,
  environment text not null default 'production'
    check (environment in ('production', 'preview', 'development')),
  allowed_record_types text[] not null default array[]::text[],
  can_read boolean not null default true,
  can_propose boolean not null default false,
  can_approve boolean not null default false,
  is_active boolean not null default true,
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (principal_key, project_id, environment)
);
alter table public.pandora_project_grants enable row level security;
revoke all on table public.pandora_project_grants from anon, authenticated;
grant select on table public.pandora_project_grants to service_role;
create index if not exists pandora_project_grants_principal_idx
  on public.pandora_project_grants (principal_key, is_active);
comment on table public.pandora_project_grants is
  'Explicit per-project, per-environment capability grants. Absence of a grant denies access.';

alter table public.memory_items
  add column if not exists project_id uuid references public.pandora_projects (id),
  add column if not exists record_type text,
  add column if not exists content_hash text,
  add column if not exists idempotency_key text,
  add column if not exists ingestion_version integer not null default 1,
  add column if not exists source_type text,
  add column if not exists source_url text,
  add column if not exists source_repository text,
  add column if not exists source_branch text,
  add column if not exists source_commit_sha text,
  add column if not exists source_path text,
  add column if not exists source_issue_number integer,
  add column if not exists effective_at timestamptz,
  add column if not exists review_due_at timestamptz,
  add column if not exists superseded_by uuid references public.memory_items (id),
  add column if not exists superseded_at timestamptz,
  add column if not exists revoked_at timestamptz,
  add column if not exists revocation_reason text,
  add column if not exists created_by text,
  add column if not exists approved_by text,
  add column if not exists approved_at timestamptz,
  add column if not exists correlation_id text;

create unique index if not exists memory_items_idempotency_key_uidx
  on public.memory_items (idempotency_key)
  where idempotency_key is not null;
create index if not exists memory_items_project_canon_idx
  on public.memory_items (project_id, canon_status, is_active);
create index if not exists memory_items_correlation_idx
  on public.memory_items (correlation_id)
  where correlation_id is not null;

create table if not exists public.pandora_memory_record_versions (
  id uuid primary key default gen_random_uuid(),
  memory_item_id uuid not null references public.memory_items (id) on delete cascade,
  version integer not null,
  title text,
  body text,
  canon_status text not null,
  content_hash text,
  changed_by text,
  change_reason text,
  correlation_id text,
  created_at timestamptz not null default now(),
  unique (memory_item_id, version)
);
alter table public.pandora_memory_record_versions enable row level security;
revoke all on table public.pandora_memory_record_versions from anon, authenticated;
grant select on table public.pandora_memory_record_versions to service_role;
comment on table public.pandora_memory_record_versions is
  'Append-only version history for governed memory records. No update or delete policy is defined.';

create table if not exists public.pandora_memory_conflicts (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.pandora_projects (id) on delete cascade,
  subject_key text not null,
  conflict_type text not null default 'contradictory_values'
    check (conflict_type in ('contradictory_values','stale_supersession','evidence_mismatch','source_reverted','policy_violation')),
  record_ids uuid[] not null default array[]::uuid[],
  detail text,
  status text not null default 'open'
    check (status in ('open', 'resolved', 'dismissed')),
  resolved_by text,
  resolved_at timestamptz,
  resolution_note text,
  correlation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pandora_memory_conflicts enable row level security;
revoke all on table public.pandora_memory_conflicts from anon, authenticated;
grant select on table public.pandora_memory_conflicts to service_role;
create index if not exists pandora_memory_conflicts_open_idx
  on public.pandora_memory_conflicts (project_id, status);
comment on table public.pandora_memory_conflicts is
  'Unresolved contradictions between approved records. Open conflicts block autonomous execution.';

create table if not exists public.pandora_sync_runs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.pandora_projects (id) on delete cascade,
  source_type text not null,
  mode text not null default 'incremental'
    check (mode in ('incremental', 'full', 'dry_run', 'retry', 'reconcile')),
  status text not null default 'running'
    check (status in ('running', 'succeeded', 'failed', 'partial')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  cursor_before text,
  cursor_after text,
  examined_count integer not null default 0,
  inserted_count integer not null default 0,
  updated_count integer not null default 0,
  skipped_count integer not null default 0,
  failed_count integer not null default 0,
  conflict_count integer not null default 0,
  correlation_id text,
  detail text
);
alter table public.pandora_sync_runs enable row level security;
revoke all on table public.pandora_sync_runs from anon, authenticated;
grant select on table public.pandora_sync_runs to service_role;
create index if not exists pandora_sync_runs_project_idx
  on public.pandora_sync_runs (project_id, started_at desc);
comment on table public.pandora_sync_runs is
  'Synchronization history. A dry run records what would change without writing records.';

create table if not exists public.pandora_ingestion_failures (
  id uuid primary key default gen_random_uuid(),
  sync_run_id uuid references public.pandora_sync_runs (id) on delete cascade,
  project_id uuid references public.pandora_projects (id) on delete cascade,
  source_type text not null,
  source_identifier text not null,
  failure_reason text not null,
  attempt_count integer not null default 1,
  resolved_at timestamptz,
  correlation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pandora_ingestion_failures enable row level security;
revoke all on table public.pandora_ingestion_failures from anon, authenticated;
grant select on table public.pandora_ingestion_failures to service_role;
create index if not exists pandora_ingestion_failures_open_idx
  on public.pandora_ingestion_failures (project_id, resolved_at);
comment on table public.pandora_ingestion_failures is
  'Per-source ingestion failures retained for retry and honest failed-record counts.';

create table if not exists public.pandora_approval_audits (
  id uuid primary key default gen_random_uuid(),
  memory_item_id uuid references public.memory_items (id) on delete set null,
  project_id uuid references public.pandora_projects (id) on delete set null,
  action text not null check (action in (
    'created','ingested','updated','submitted_for_review','approved','rejected',
    'changes_requested','superseded','revoked','conflict_detected','conflict_resolved',
    'retrieval_denied','authorization_denied','indexed','processing_failed'
  )),
  actor_identity text not null,
  actor_kind text not null default 'service_principal'
    check (actor_kind in ('service_principal', 'human_reviewer', 'owner', 'worker')),
  from_state text,
  to_state text,
  reason text,
  correlation_id text,
  created_at timestamptz not null default now()
);
alter table public.pandora_approval_audits enable row level security;
revoke all on table public.pandora_approval_audits from anon, authenticated;
grant select on table public.pandora_approval_audits to service_role;
create index if not exists pandora_approval_audits_item_idx
  on public.pandora_approval_audits (memory_item_id, created_at desc);
create index if not exists pandora_approval_audits_correlation_idx
  on public.pandora_approval_audits (correlation_id)
  where correlation_id is not null;
comment on table public.pandora_approval_audits is
  'Append-only governance audit. Record bodies are not duplicated here; version history holds the text.';
