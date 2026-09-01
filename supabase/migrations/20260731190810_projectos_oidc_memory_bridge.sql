create table if not exists public.pandora_service_principals (
  id uuid primary key default gen_random_uuid(),
  principal_key text not null unique,
  provider text not null check (provider in ('vercel_oidc')),
  issuer text not null,
  audience text not null,
  subject text not null,
  owner_id text not null,
  project_id text not null,
  project_name text not null,
  environment text not null check (environment in ('production', 'preview', 'development')),
  memory_user_id uuid not null,
  allowed_namespaces text[] not null default array['real_life']::text[],
  scopes text[] not null default array['memory:health', 'memory:read']::text[],
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pandora_service_principals_namespaces_check check (allowed_namespaces <@ array['real_life', 'au']::text[]),
  constraint pandora_service_principals_scopes_check check (scopes <@ array['memory:health', 'memory:read']::text[])
);
alter table public.pandora_service_principals enable row level security;
revoke all on table public.pandora_service_principals from anon, authenticated;
grant select on table public.pandora_service_principals to service_role;
comment on table public.pandora_service_principals is 'Private allowlist for workload identities permitted to use narrowly scoped Pandora capability bridges.';
