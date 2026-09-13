-- Additional production-shaped objects for M5-002 disposable PostgreSQL verification.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.pandora_projects (
  id uuid primary key,
  project_key text not null,
  canonical_name text not null,
  memory_namespace text not null default 'real_life',
  lifecycle_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pandora_project_grants (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null,
  project_id uuid not null,
  environment text not null default 'production',
  allowed_record_types text[] not null default '{}'::text[],
  can_read boolean not null default true,
  can_propose boolean not null default false,
  can_approve boolean not null default false,
  is_active boolean not null default true,
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
