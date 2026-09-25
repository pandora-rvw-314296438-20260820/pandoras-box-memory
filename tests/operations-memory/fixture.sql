-- Synthetic empty-database fixture ONLY. Never execute against a populated project.
do $$ begin
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','v','m','p')) then
   raise exception 'OPS_MEMORY_TEST_REQUIRES_EMPTY_DATABASE';
 end if;
end $$;
create schema if not exists private;
create schema if not exists extensions;
-- Test compatibility shim uses PostgreSQL's actual SHA-256, not a mocked digest.
create function extensions.digest(bytea,text) returns bytea language sql immutable as
 'select case when $2 = ''sha256'' then pg_catalog.sha256($1) else null end';
create function extensions.digest(text,text) returns bytea language sql immutable as
 'select extensions.digest(convert_to($1,''UTF8''),$2)';
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
do $$ begin create role service_role; exception when duplicate_object then null; end $$;
create table public.pandora_service_principals (
 id uuid primary key default gen_random_uuid(), principal_key text unique,
 memory_user_id uuid, environment text, allowed_namespaces text[], scopes text[], is_active boolean
);
create table public.pandora_projects (
 id uuid primary key, memory_namespace text, lifecycle_status text, project_key text, canonical_name text
);
create table public.pandora_project_grants (
 id uuid primary key default gen_random_uuid(), principal_key text, project_id uuid, environment text,
 allowed_record_types text[], can_read boolean, can_propose boolean, is_active boolean,
 revoked_at timestamptz, updated_at timestamptz default now(), unique(principal_key,project_id,environment)
);
create table public.memory_items (
 id uuid primary key default gen_random_uuid(), user_id uuid, namespace text, project_id uuid,
 title text, body text, source_summary text, record_type text, memory_type text, canon_status text,
 knowledge_schema_version text, is_active boolean, approved_by text, approved_at timestamptz,
 revoked_at timestamptz, superseded_at timestamptz, created_at timestamptz, updated_at timestamptz,
 effective_at timestamptz, observed_at timestamptz, provenance jsonb, evidence_refs jsonb,
 authority_kind text, authority_ref text, promotion_basis text, confidence numeric, correction_of uuid
);
create table public.memory_capture_candidates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  namespace text,
  source text,
  source_ref text,
  raw_excerpt text,
  redacted_excerpt text,
  memory_type text,
  title text,
  summary text,
  importance bigint,
  sensitivity text,
  confidence numeric,
  should_capture boolean,
  requires_review boolean,
  status text,
  reason text,
  people jsonb,
  projects jsonb,
  risks jsonb,
  tags jsonb,
  metadata jsonb,
  project_id uuid,
  record_type text,
  provider text,
  model text,
  model_revision text,
  task_class text,
  routing_policy_version text,
  source_run_ids uuid[],
  evidence_refs text[],
  evidence_window_start timestamptz,
  evidence_window_end timestamptz,
  sample_count bigint,
  verification_pass_count bigint,
  negative_outcome_count bigint,
  execution_status text,
  verification_status text,
  downstream_outcome_status text,
  quality_signal numeric,
  latency_ms bigint,
  estimated_cost_micros bigint,
  billed_cost_micros bigint,
  source_system text,
  source_commit text,
  source_deployment_ref text,
  review_due_at timestamptz,
  usefulness_score numeric,
  confidence_score numeric,
  freshness_score numeric,
  retrieval_weight numeric,
  stale_status text,
  scoring_version text,
  scored_at timestamptz
);
create table public.memory_review_queue_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  namespace text,
  status text,
  candidate_type text,
  normalized_text text,
  evidence_snapshot jsonb,
  sensitivity_snapshot jsonb,
  namespace_snapshot jsonb,
  source_metadata jsonb,
  audit_metadata jsonb,
  append_only boolean,
  proposed_operation text,
  requires_review boolean,
  source_ref text,
  request_hash text,
  fingerprint text
);
