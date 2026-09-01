create table if not exists public.memory_feedback_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null check(namespace in ('real_life','au')),
  candidate_id uuid,
  action text not null,
  old_status text,
  new_status text,
  old_memory_type text,
  new_memory_type text,
  old_sensitivity text,
  new_sensitivity text,
  review_note text,
  reason text,
  metadata jsonb default '{}',
  created_at timestamptz default now()
);
alter table public.memory_feedback_events enable row level security;
do $$ begin
  create policy "memory_feedback_events_user_scoped" on public.memory_feedback_events for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;
create index if not exists memory_feedback_events_user_ns_idx on public.memory_feedback_events(user_id, namespace, created_at desc);
