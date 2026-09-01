-- Pandora Memory Engine core database schema
-- Prompt 7: schema foundation only.
--
-- This migration creates the durable table structure required by future memory,
-- real-life, and AU/story workflows. It intentionally does not create RLS
-- policies, pgvector objects, OpenAI integration, seed data, API routes, or fake
-- operational rows. RLS is enabled with no policies so user-owned tables remain
-- locked down until the next security migration adds explicit policies.

create extension if not exists pgcrypto;
create type public.pandora_namespace as enum ('real_life', 'au');
create type public.memory_type as enum (
  'observation',
  'user_preference',
  'soft_canon',
  'hard_canon',
  'contradiction',
  'retcon_candidate',
  'real_life_fact',
  'business_fact',
  'relationship_signal',
  'risk_signal'
);
create type public.memory_strength as enum ('low', 'medium', 'high', 'locked');
create type public.canon_status as enum ('draft', 'soft_canon', 'hard_canon', 'retconned', 'disputed');
create type public.evidence_source_type as enum ('screenshot', 'email', 'document', 'user_statement', 'conversation_turn', 'url', 'uploaded_file', 'manual_admin_entry', 'other');
create type public.risk_severity as enum ('low', 'medium', 'high', 'critical');
create table public.memory_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  memory_type public.memory_type not null,
  title text not null,
  body text not null,
  strength public.memory_strength not null default 'medium',
  confidence numeric(5,4) not null default 0.5000 check (confidence >= 0 and confidence <= 1),
  canon_status public.canon_status not null default 'draft',
  source_summary text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.memory_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  memory_item_id uuid references public.memory_items(id) on delete cascade,
  source_type public.evidence_source_type not null,
  source_ref text,
  excerpt text,
  confidence numeric(5,4) not null default 0.5000 check (confidence >= 0 and confidence <= 1),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.memory_patches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  memory_item_id uuid not null references public.memory_items(id) on delete cascade,
  patch_type text not null,
  reason text,
  before_snapshot jsonb,
  after_snapshot jsonb not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.retrieval_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  query_text text not null,
  filters jsonb not null default '{}'::jsonb,
  requested_limit integer check (requested_limit is null or requested_limit > 0),
  returned_item_ids uuid[] not null default '{}'::uuid[],
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.prompt_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null,
  route_name text,
  model_name text,
  request_hash text,
  response_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace,
  action text not null,
  table_name text not null,
  record_id uuid,
  before_snapshot jsonb,
  after_snapshot jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  display_name text not null,
  aliases text[] not null default '{}'::text[],
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  person_a_id uuid references public.people(id) on delete set null,
  person_b_id uuid references public.people(id) on delete set null,
  relationship_type text not null,
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.relationship_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  relationship_id uuid references public.relationships(id) on delete cascade,
  occurred_at timestamptz,
  event_type text not null,
  summary text not null,
  source_id uuid references public.memory_sources(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.business_entities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  name text not null,
  entity_type text,
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.business_deals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  business_entity_id uuid references public.business_entities(id) on delete set null,
  title text not null,
  stage text,
  value_estimate numeric(18,2),
  currency text,
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.promises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  person_id uuid references public.people(id) on delete set null,
  business_deal_id uuid references public.business_deals(id) on delete set null,
  promise_text text not null,
  due_at timestamptz,
  status text not null default 'open',
  source_id uuid references public.memory_sources(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  title text not null,
  decision_text text not null,
  decided_at timestamptz not null default now(),
  source_id uuid references public.memory_sources(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.risks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  title text not null,
  severity public.risk_severity not null default 'medium',
  summary text not null,
  status text not null default 'open',
  source_id uuid references public.memory_sources(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'real_life' check (namespace = 'real_life'),
  source_type public.evidence_source_type not null,
  title text not null,
  source_ref text,
  summary text,
  confidence numeric(5,4) not null default 0.5000 check (confidence >= 0 and confidence <= 1),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table public.au_worlds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  name text not null,
  premise text,
  canon_status public.canon_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_characters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  name text not null,
  role text,
  profile text,
  canon_status public.canon_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  character_a_id uuid references public.au_characters(id) on delete set null,
  character_b_id uuid references public.au_characters(id) on delete set null,
  relationship_type text not null,
  summary text,
  canon_status public.canon_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_scenes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  sequence_number integer,
  title text not null,
  summary text not null,
  scene_text text,
  occurred_at timestamptz,
  canon_status public.canon_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_consequences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  scene_id uuid references public.au_scenes(id) on delete set null,
  summary text not null,
  status text not null default 'open',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_open_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  title text not null,
  summary text not null,
  status text not null default 'open',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  rule_text text not null,
  canon_status public.canon_status not null default 'soft_canon',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_character_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  character_id uuid not null references public.au_characters(id) on delete cascade,
  current_state jsonb not null default '{}'::jsonb,
  derived_from_scene_id uuid references public.au_scenes(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_relationship_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  relationship_id uuid not null references public.au_relationships(id) on delete cascade,
  current_state jsonb not null default '{}'::jsonb,
  derived_from_scene_id uuid references public.au_scenes(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_retcons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  world_id uuid not null references public.au_worlds(id) on delete cascade,
  target_table text not null,
  target_id uuid,
  reason text not null,
  before_snapshot jsonb,
  after_snapshot jsonb not null,
  status text not null default 'proposed',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.au_quality_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  namespace public.pandora_namespace not null default 'au' check (namespace = 'au'),
  scene_id uuid references public.au_scenes(id) on delete cascade,
  continuity_score numeric(5,4) check (continuity_score is null or (continuity_score >= 0 and continuity_score <= 1)),
  character_consistency_score numeric(5,4) check (character_consistency_score is null or (character_consistency_score >= 0 and character_consistency_score <= 1)),
  consequence_progression_score numeric(5,4) check (consequence_progression_score is null or (consequence_progression_score >= 0 and consequence_progression_score <= 1)),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
-- Indexes for future namespace/user-isolated access patterns.
create index memory_items_user_namespace_idx on public.memory_items(user_id, namespace, created_at desc);
create index memory_sources_user_namespace_idx on public.memory_sources(user_id, namespace, created_at desc);
create index memory_patches_user_namespace_idx on public.memory_patches(user_id, namespace, created_at desc);
create index retrieval_logs_user_namespace_idx on public.retrieval_logs(user_id, namespace, created_at desc);
create index prompt_logs_user_namespace_idx on public.prompt_logs(user_id, namespace, created_at desc);
create index audit_logs_user_namespace_idx on public.audit_logs(user_id, namespace, created_at desc);
create index people_user_idx on public.people(user_id, created_at desc);
create index relationships_user_idx on public.relationships(user_id, created_at desc);
create index relationship_events_user_idx on public.relationship_events(user_id, created_at desc);
create index business_entities_user_idx on public.business_entities(user_id, created_at desc);
create index business_deals_user_idx on public.business_deals(user_id, created_at desc);
create index promises_user_idx on public.promises(user_id, created_at desc);
create index decisions_user_idx on public.decisions(user_id, created_at desc);
create index risks_user_idx on public.risks(user_id, created_at desc);
create index evidence_items_user_idx on public.evidence_items(user_id, created_at desc);
create index au_worlds_user_idx on public.au_worlds(user_id, created_at desc);
create index au_characters_world_idx on public.au_characters(user_id, world_id);
create index au_relationships_world_idx on public.au_relationships(user_id, world_id);
create index au_scenes_world_idx on public.au_scenes(user_id, world_id, sequence_number);
create index au_consequences_world_idx on public.au_consequences(user_id, world_id);
create index au_open_threads_world_idx on public.au_open_threads(user_id, world_id);
create index au_rules_world_idx on public.au_rules(user_id, world_id);
create index au_character_states_character_idx on public.au_character_states(user_id, character_id);
create index au_relationship_states_relationship_idx on public.au_relationship_states(user_id, relationship_id);
create index au_retcons_world_idx on public.au_retcons(user_id, world_id);
create index au_quality_reviews_scene_idx on public.au_quality_reviews(user_id, scene_id);
-- Lock down user-owned tables until explicit RLS policies are added in the next
-- security migration. No create policy statements are intentionally included here.
alter table public.memory_items enable row level security;
alter table public.memory_sources enable row level security;
alter table public.memory_patches enable row level security;
alter table public.retrieval_logs enable row level security;
alter table public.prompt_logs enable row level security;
alter table public.audit_logs enable row level security;
alter table public.people enable row level security;
alter table public.relationships enable row level security;
alter table public.relationship_events enable row level security;
alter table public.business_entities enable row level security;
alter table public.business_deals enable row level security;
alter table public.promises enable row level security;
alter table public.decisions enable row level security;
alter table public.risks enable row level security;
alter table public.evidence_items enable row level security;
alter table public.au_worlds enable row level security;
alter table public.au_characters enable row level security;
alter table public.au_relationships enable row level security;
alter table public.au_scenes enable row level security;
alter table public.au_consequences enable row level security;
alter table public.au_open_threads enable row level security;
alter table public.au_rules enable row level security;
alter table public.au_character_states enable row level security;
alter table public.au_relationship_states enable row level security;
alter table public.au_retcons enable row level security;
alter table public.au_quality_reviews enable row level security;
