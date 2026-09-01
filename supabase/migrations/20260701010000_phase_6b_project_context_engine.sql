create table if not exists public.operating_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_key text not null,
  title text not null,
  purpose text,
  status text not null default 'active' check (status in ('active', 'paused', 'completed', 'archived')),
  proof_target text,
  current_phase text,
  priority integer not null default 50,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, namespace, project_key)
);
create table if not exists public.operating_project_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_id uuid not null references public.operating_projects(id),
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open', 'doing', 'blocked', 'done', 'parked')),
  proof_required text,
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.operating_project_decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_id uuid not null references public.operating_projects(id),
  decision text not null,
  reason text,
  status text not null default 'active' check (status in ('active', 'superseded', 'reversed')),
  source_decision_gate_id uuid references public.decision_gates(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.operating_project_constraints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_id uuid not null references public.operating_projects(id),
  constraint_text text not null,
  severity text not null default 'normal' check (severity in ('low', 'normal', 'high', 'critical')),
  status text not null default 'active' check (status in ('active', 'resolved', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.operating_project_artifacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_id uuid not null references public.operating_projects(id),
  title text not null,
  artifact_type text not null default 'note',
  uri text,
  description text,
  proof_value text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.operating_project_open_loops (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id),
  namespace text not null default 'real_life' check (namespace in ('real_life', 'au')),
  project_id uuid not null references public.operating_projects(id),
  loop_text text not null,
  status text not null default 'open' check (status in ('open', 'waiting', 'resolved', 'parked')),
  next_action text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists operating_projects_owner_status_idx on public.operating_projects (user_id, namespace, status, priority desc, updated_at desc);
create index if not exists operating_project_tasks_project_status_idx on public.operating_project_tasks (project_id, status, updated_at desc);
create index if not exists operating_project_decisions_project_status_idx on public.operating_project_decisions (project_id, status, updated_at desc);
create index if not exists operating_project_constraints_project_status_idx on public.operating_project_constraints (project_id, status, updated_at desc);
create index if not exists operating_project_artifacts_project_created_idx on public.operating_project_artifacts (project_id, created_at desc);
create index if not exists operating_project_open_loops_project_status_idx on public.operating_project_open_loops (project_id, status, updated_at desc);
alter table public.operating_projects enable row level security;
alter table public.operating_project_tasks enable row level security;
alter table public.operating_project_decisions enable row level security;
alter table public.operating_project_constraints enable row level security;
alter table public.operating_project_artifacts enable row level security;
alter table public.operating_project_open_loops enable row level security;
create policy operating_projects_owner on public.operating_projects for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy operating_project_tasks_owner on public.operating_project_tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy operating_project_decisions_owner on public.operating_project_decisions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy operating_project_constraints_owner on public.operating_project_constraints for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy operating_project_artifacts_owner on public.operating_project_artifacts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy operating_project_open_loops_owner on public.operating_project_open_loops for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create trigger set_operating_projects_updated_at before update on public.operating_projects for each row execute function public.set_updated_at();
create trigger set_operating_project_tasks_updated_at before update on public.operating_project_tasks for each row execute function public.set_updated_at();
create trigger set_operating_project_decisions_updated_at before update on public.operating_project_decisions for each row execute function public.set_updated_at();
create trigger set_operating_project_constraints_updated_at before update on public.operating_project_constraints for each row execute function public.set_updated_at();
create trigger set_operating_project_artifacts_updated_at before update on public.operating_project_artifacts for each row execute function public.set_updated_at();
create trigger set_operating_project_open_loops_updated_at before update on public.operating_project_open_loops for each row execute function public.set_updated_at();
