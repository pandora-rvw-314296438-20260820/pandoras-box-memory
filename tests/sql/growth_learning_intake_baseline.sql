create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

do $$
begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin; end if;
end $$;

create table public.pandora_service_principals (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null unique,
  memory_user_id uuid not null,
  environment text not null,
  allowed_namespaces text[] not null,
  scopes text[] not null,
  is_active boolean not null default true
);

create table public.pandora_projects (
  id uuid primary key,
  project_key text not null unique,
  aliases text[] not null default '{}'::text[],
  memory_namespace text not null,
  lifecycle_status text not null
);

create table public.pandora_project_grants (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null,
  project_id uuid not null references public.pandora_projects(id),
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
  project_id uuid references public.pandora_projects(id),
  record_type text not null default 'memory_candidate',
  source_run_ids uuid[] not null default '{}'::uuid[],
  evidence_refs text[] not null default '{}'::text[],
  evidence_window_start timestamptz,
  evidence_window_end timestamptz,
  source_system text,
  review_due_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.memory_review_queue_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null,
  status text not null,
  candidate_type text not null,
  normalized_text text not null,
  evidence_snapshot jsonb not null,
  sensitivity_snapshot jsonb not null,
  namespace_snapshot jsonb not null,
  source_metadata jsonb not null,
  audit_metadata jsonb not null,
  append_only boolean not null default true,
  proposed_operation text not null default 'append',
  requires_review boolean not null default true,
  source_ref text,
  request_hash text,
  fingerprint text,
  persistence_execution_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.memory_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null,
  project_id uuid,
  body text,
  created_at timestamptz not null default now()
);

-- Production trigger behavior relevant to ProjectOS lineage.
create function public.test_bind_projectos_candidate_scope()
returns trigger language plpgsql as $$
begin
  if new.source='projectos-post-task' and new.requires_review and new.status='pending' then
    if new.project_id is distinct from '7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
      or new.metadata->>'project_id' is distinct from '7c686cbd-d968-49d5-86cc-918f5e777bd2'
      or new.metadata->>'project_key' is distinct from 'mcpmaster-pandoras-box' then
      raise exception 'candidate scope trigger mismatch';
    end if;
  end if;
  return new;
end $$;
create trigger test_bind_projectos_candidate_scope
before insert on public.memory_capture_candidates
for each row execute function public.test_bind_projectos_candidate_scope();

create function public.test_bind_projectos_review_lineage()
returns trigger language plpgsql as $$
declare v_candidate uuid;
begin
  if new.candidate_type='projectos_outcome' then
    select id into v_candidate from public.memory_capture_candidates
      where user_id=new.user_id and namespace=new.namespace
        and source_ref=new.source_ref and source='projectos-post-task';
    if v_candidate is null or new.source_metadata->>'candidateId' is distinct from v_candidate::text then
      raise exception 'review lineage trigger mismatch';
    end if;
  end if;
  return new;
end $$;
create trigger test_bind_projectos_review_lineage
before insert on public.memory_review_queue_items
for each row execute function public.test_bind_projectos_review_lineage();
