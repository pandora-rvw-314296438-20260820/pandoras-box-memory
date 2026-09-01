create table if not exists public.pandora_source_snapshots (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.pandora_projects(id) on delete cascade,
  snapshot_label text not null,
  source_kind text not null,
  source_repository text,
  source_branch text,
  source_commit_sha text,
  source_deployment_id text,
  deployment_url text,
  completeness text not null default 'deployment_artifact',
  manifest jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(project_id, snapshot_label)
);

create table if not exists public.pandora_source_snapshot_files (
  id uuid primary key default gen_random_uuid(),
  snapshot_id uuid not null references public.pandora_source_snapshots(id) on delete cascade,
  path text not null,
  mime_type text,
  byte_size bigint,
  sha256 text,
  content_text text,
  content_base64 text,
  source_url text,
  recovery_status text not null default 'referenced',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(snapshot_id, path),
  check (content_text is null or content_base64 is null)
);

create index if not exists pandora_source_snapshots_project_idx on public.pandora_source_snapshots(project_id, created_at desc);
create index if not exists pandora_source_snapshot_files_snapshot_idx on public.pandora_source_snapshot_files(snapshot_id, path);
