create table public.pandora_projects (
  id uuid primary key,
  project_key text not null unique,
  aliases text[] not null default '{}'::text[],
  memory_namespace text not null,
  lifecycle_status text not null
);

create table public.pandora_project_grants (
  id uuid primary key,
  principal_key text not null,
  project_id uuid not null references public.pandora_projects(id),
  environment text not null,
  can_propose boolean not null default false,
  is_active boolean not null default true,
  revoked_at timestamptz
);

create table public.memory_capture_candidates (
  id uuid primary key,
  user_id uuid not null,
  namespace text not null,
  source text not null,
  source_ref text not null,
  requires_review boolean not null default false,
  status text not null,
  metadata jsonb not null default '{}'::jsonb,
  project_id uuid references public.pandora_projects(id)
);

create table public.memory_review_queue_items (
  id uuid primary key,
  user_id uuid not null,
  namespace text not null,
  candidate_type text not null,
  status text not null,
  source_ref text not null,
  source_metadata jsonb not null default '{}'::jsonb,
  evidence_snapshot jsonb not null default '{}'::jsonb,
  audit_metadata jsonb not null default '{}'::jsonb
);

create table public.memory_items (
  id uuid primary key,
  user_id uuid not null,
  namespace text not null,
  project_id uuid references public.pandora_projects(id),
  metadata jsonb not null default '{}'::jsonb
);
