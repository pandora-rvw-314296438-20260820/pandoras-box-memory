create table if not exists public.env_managed_projects (
  id uuid primary key default gen_random_uuid(), provider text not null, provider_project_id text not null, provider_project_name text not null, provider_team_id text, production_url text, display_name text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(provider, provider_project_id)
);
create table if not exists public.env_managed_keys (
  id uuid primary key default gen_random_uuid(), project_id uuid not null references public.env_managed_projects(id), key text not null, classification text not null, target text not null, required boolean not null default false, managed boolean not null default false, generator text, allowed_values jsonb, safe_default text, description text, discovered_sources jsonb not null default '[]'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(project_id, key)
);
create table if not exists public.env_key_versions (
  id uuid primary key default gen_random_uuid(), project_id uuid not null references public.env_managed_projects(id), key_id uuid not null references public.env_managed_keys(id), version integer not null, fingerprint text not null, status text not null, provider_env_id text, created_by uuid, created_at timestamptz not null default now(), pushed_at timestamptz, error_code text, error_message_redacted text, unique(key_id, version)
);
create table if not exists public.env_audit_events (
  id uuid primary key default gen_random_uuid(), project_id uuid references public.env_managed_projects(id), key_id uuid references public.env_managed_keys(id), action text not null, actor_user_id uuid, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table public.env_managed_projects enable row level security;
alter table public.env_managed_keys enable row level security;
alter table public.env_key_versions enable row level security;
alter table public.env_audit_events enable row level security;
insert into public.env_managed_projects(provider, provider_project_id, provider_project_name, provider_team_id, production_url, display_name) values ('vercel','prj_yUjuF1XBbTR6f89vkEhn1xtN5I4F','memory','team_szQXqABERd5jcUrAZGmIa8Hg','pandorasmemory.vercel.app','Pandora Memory') on conflict do nothing;
