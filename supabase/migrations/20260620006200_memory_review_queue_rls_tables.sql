-- Active RLS-safe memory review queue tables.
-- Review queue persistence is separate from memory persistence: approvals do not write memories.
-- No seed rows, unsafe grants, service-role shortcuts, embeddings, pgvector, model calls, GPT Actions, or MCP.

create table if not exists public.memory_review_queue_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  namespace text not null check (namespace in ('real_life','au')),
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint memory_review_queue_items_status_check check (status in ('pending_review','needs_clarification','blocked_namespace_mismatch','blocked_sensitive','blocked_policy','approved_for_append','rejected','archived')),
  constraint memory_review_queue_items_append_only_check check (append_only is true),
  constraint memory_review_queue_items_operation_check check (proposed_operation = 'append')
);
create table if not exists public.memory_review_queue_decisions (
  id uuid primary key default gen_random_uuid(),
  review_item_id uuid not null references public.memory_review_queue_items(id),
  user_id uuid not null,
  namespace text not null check (namespace in ('real_life','au')),
  action text not null,
  from_status text not null,
  to_status text not null,
  reviewer_context jsonb not null,
  decision_metadata jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists memory_review_queue_items_user_id_idx on public.memory_review_queue_items(user_id);
create index if not exists memory_review_queue_items_namespace_idx on public.memory_review_queue_items(namespace);
create index if not exists memory_review_queue_items_status_idx on public.memory_review_queue_items(status);
create index if not exists memory_review_queue_items_created_at_idx on public.memory_review_queue_items(created_at);
create index if not exists memory_review_queue_decisions_user_id_idx on public.memory_review_queue_decisions(user_id);
create index if not exists memory_review_queue_decisions_namespace_idx on public.memory_review_queue_decisions(namespace);
create index if not exists memory_review_queue_decisions_review_item_id_idx on public.memory_review_queue_decisions(review_item_id);
create index if not exists memory_review_queue_decisions_created_at_idx on public.memory_review_queue_decisions(created_at);
alter table public.memory_review_queue_items enable row level security;
alter table public.memory_review_queue_decisions enable row level security;
create policy "memory_review_queue_items_select_own" on public.memory_review_queue_items for select to authenticated using (user_id = auth.uid());
create policy "memory_review_queue_items_insert_own" on public.memory_review_queue_items for insert to authenticated with check (user_id = auth.uid());
create policy "memory_review_queue_decisions_select_own" on public.memory_review_queue_decisions for select to authenticated using (user_id = auth.uid());
create policy "memory_review_queue_decisions_insert_own_item" on public.memory_review_queue_decisions for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.memory_review_queue_items item
    where item.id = review_item_id and item.user_id = auth.uid() and item.namespace = memory_review_queue_decisions.namespace
  )
);
comment on table public.memory_review_queue_items is 'RLS-owned memory review candidates. Candidate content and namespace must not be silently mutated; archive only, no delete policy.';
comment on column public.memory_review_queue_items.namespace is 'Explicit real_life/au namespace boundary. AU/story data is not real-life evidence; real-life data enters AU only if fictionalized and reviewed.';
comment on column public.memory_review_queue_items.normalized_text is 'Immutable candidate content snapshot; create a new review item rather than mutating content.';
comment on table public.memory_review_queue_decisions is 'Append-only review decision history. Decisions do not persist approved memories and no update/delete policies are defined.';
