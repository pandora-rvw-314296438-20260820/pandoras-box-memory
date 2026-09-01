-- Add explicit owner-scoped RLS policies for adaptive log tables.
-- These tables were created with RLS enabled in Phase 4C, but no authenticated
-- policies were attached, so user-scoped log writes/reads were blocked by
-- default. Service-role/admin clients continue to bypass RLS as before.

alter table public.memory_retrieval_logs enable row level security;
alter table public.memory_retrieval_logs force row level security;
alter table public.memory_model_call_logs enable row level security;
alter table public.memory_model_call_logs force row level security;
do $$
begin
  create policy "memory_retrieval_logs_select_own"
    on public.memory_retrieval_logs
    for select
    to authenticated
    using ((select auth.uid()) = user_id);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "memory_retrieval_logs_insert_own"
    on public.memory_retrieval_logs
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "memory_model_call_logs_select_own"
    on public.memory_model_call_logs
    for select
    to authenticated
    using ((select auth.uid()) = user_id);
exception when duplicate_object then null;
end $$;
do $$
begin
  create policy "memory_model_call_logs_insert_own"
    on public.memory_model_call_logs
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);
exception when duplicate_object then null;
end $$;
