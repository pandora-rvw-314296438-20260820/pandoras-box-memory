-- Phase 5D: memory usefulness scoring, freshness/staleness, and review-first pruning.
-- Fully additive. No table is dropped, no column is removed, no row is deleted.
-- All score columns are nullable so existing rows keep working and the retrieval layer
-- falls back to dynamically computed scores when these are null.

-- Stored-memory scoring columns on memory_events.
alter table public.memory_events add column if not exists usefulness_score numeric(5,4) check (usefulness_score >= 0 and usefulness_score <= 1);
alter table public.memory_events add column if not exists confidence_score numeric(5,4) check (confidence_score >= 0 and confidence_score <= 1);
alter table public.memory_events add column if not exists freshness_score numeric(5,4) check (freshness_score >= 0 and freshness_score <= 1);
alter table public.memory_events add column if not exists contradiction_score numeric(5,4) check (contradiction_score >= 0 and contradiction_score <= 1);
alter table public.memory_events add column if not exists retrieval_weight numeric(5,4) check (retrieval_weight >= 0 and retrieval_weight <= 1);
alter table public.memory_events add column if not exists stale_status text check (stale_status in ('active','aging','stale','superseded','archived_candidate'));
alter table public.memory_events add column if not exists last_retrieved_at timestamptz;
alter table public.memory_events add column if not exists retrieval_count integer not null default 0;
alter table public.memory_events add column if not exists positive_feedback_count integer not null default 0;
alter table public.memory_events add column if not exists negative_feedback_count integer not null default 0;
alter table public.memory_events add column if not exists last_feedback_at timestamptz;
alter table public.memory_events add column if not exists superseded_by_memory_id uuid;
alter table public.memory_events add column if not exists pruning_reason text;
alter table public.memory_events add column if not exists scoring_version text;
alter table public.memory_events add column if not exists scored_at timestamptz;
create index if not exists memory_events_retrieval_weight_idx on public.memory_events(user_id, namespace, retrieval_weight desc);
create index if not exists memory_events_stale_status_idx on public.memory_events(user_id, namespace, stale_status);
-- Lightweight score display columns on review candidates (for the candidate review UI).
alter table public.memory_capture_candidates add column if not exists usefulness_score numeric(5,4) check (usefulness_score >= 0 and usefulness_score <= 1);
alter table public.memory_capture_candidates add column if not exists confidence_score numeric(5,4) check (confidence_score >= 0 and confidence_score <= 1);
alter table public.memory_capture_candidates add column if not exists freshness_score numeric(5,4) check (freshness_score >= 0 and freshness_score <= 1);
alter table public.memory_capture_candidates add column if not exists retrieval_weight numeric(5,4) check (retrieval_weight >= 0 and retrieval_weight <= 1);
alter table public.memory_capture_candidates add column if not exists stale_status text check (stale_status in ('active','aging','stale','superseded','archived_candidate'));
alter table public.memory_capture_candidates add column if not exists scoring_version text;
alter table public.memory_capture_candidates add column if not exists scored_at timestamptz;
-- Review-first pruning candidates. Recommendations only; nothing here deletes memory.
create table if not exists public.memory_pruning_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null check (namespace in ('real_life','au')),
  memory_id uuid,
  pruning_category text not null check (pruning_category in ('stale','superseded','low_value','unsafe','duplicate')),
  recommendation text not null check (recommendation in ('keep','archive','supersede','review')),
  reason text,
  stale_status text check (stale_status in ('active','aging','stale','superseded','archived_candidate')),
  retrieval_weight numeric(5,4),
  superseded_by_memory_id uuid,
  scoring_version text,
  status text not null default 'open' check (status in ('open','reviewed','dismissed','applied')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
alter table public.memory_pruning_candidates enable row level security;
do $$ begin
  create policy "memory_pruning_candidates_user_scoped" on public.memory_pruning_candidates for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
exception when duplicate_object then null; end $$;
create index if not exists memory_pruning_candidates_user_ns_idx on public.memory_pruning_candidates(user_id, namespace, status, created_at desc);
-- Keep at most one OPEN candidate per (user, namespace, memory, category) so repeated
-- maintenance runs cannot inflate the review queue with duplicate open rows.
create unique index if not exists memory_pruning_candidates_open_unique_idx on public.memory_pruning_candidates(user_id, namespace, memory_id, pruning_category) where status = 'open';
