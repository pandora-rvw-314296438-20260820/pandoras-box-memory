-- M5-001: typed governed Memory records aligned to the frozen M0-005 contract.
-- Additive only. Existing rows and candidate -> review -> canonical authority remain intact.
-- No data backfill, canonical promotion, production deployment, or provider mutation is performed here.
-- Inference, prediction, repeated behavior, procedures, provider performance, and model output never create authorization.
-- Typed policy records preserve exact explicit authority references and still require runtime scope/validity/revocation validation.

alter table public.memory_review_queue_items
  add column if not exists proposed_record_type text,
  add column if not exists proposed_authority_kind text,
  add column if not exists proposed_authority_ref text,
  add column if not exists proposed_confidence numeric(5,4),
  add column if not exists proposed_observed_at timestamptz,
  add column if not exists proposed_effective_at timestamptz,
  add column if not exists proposed_provenance jsonb,
  add column if not exists proposed_evidence_refs jsonb,
  add column if not exists proposed_promotion_basis text,
  add column if not exists proposed_correction_of uuid,
  add column if not exists explicit_policy_authorization boolean not null default false;

alter table public.memory_items
  add column if not exists knowledge_schema_version text,
  add column if not exists authority_kind text,
  add column if not exists authority_ref text,
  add column if not exists provenance jsonb,
  add column if not exists evidence_refs jsonb,
  add column if not exists observed_at timestamptz,
  add column if not exists promotion_basis text,
  add column if not exists correction_of uuid,
  add column if not exists confidence_basis text,
  add column if not exists supersession_reason text;

do $$ begin
  if not exists (
    select 1 from pg_constraint
    where conname='memory_review_queue_items_m5_record_type_check'
      and conrelid='public.memory_review_queue_items'::regclass
  ) then
    alter table public.memory_review_queue_items
      add constraint memory_review_queue_items_m5_record_type_check
      check (
        proposed_record_type is null
        or proposed_record_type in (
          'fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance'
        )
      ) not valid;
    alter table public.memory_review_queue_items
      validate constraint memory_review_queue_items_m5_record_type_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='memory_review_queue_items_m5_shape_check'
      and conrelid='public.memory_review_queue_items'::regclass
  ) then
    alter table public.memory_review_queue_items
      add constraint memory_review_queue_items_m5_shape_check
      check (
        proposed_record_type is null
        or (
          proposed_authority_kind is not null
          and nullif(trim(proposed_authority_ref),'') is not null
          and proposed_confidence is not null
          and proposed_confidence >= 0
          and proposed_confidence <= 1
          and proposed_observed_at is not null
          and proposed_effective_at is not null
          and proposed_provenance is not null
          and jsonb_typeof(proposed_provenance)='object'
          and proposed_provenance ? 'sourceType'
          and proposed_provenance ? 'sourceLocator'
          and proposed_provenance ? 'observedAt'
          and proposed_provenance ? 'semanticSource'
          and nullif(trim(proposed_provenance->>'sourceType'),'') is not null
          and nullif(trim(proposed_provenance->>'sourceLocator'),'') is not null
          and nullif(trim(proposed_provenance->>'observedAt'),'') is not null
          and nullif(trim(proposed_provenance->>'semanticSource'),'') is not null
          and octet_length(proposed_provenance::text) <= 16384
          and proposed_evidence_refs is not null
          and jsonb_typeof(proposed_evidence_refs)='array'
          and jsonb_array_length(proposed_evidence_refs) > 0
          and octet_length(proposed_evidence_refs::text) <= 32768
          and nullif(trim(proposed_promotion_basis),'') is not null
          and octet_length(proposed_promotion_basis) <= 4096
        )
      ) not valid;
    alter table public.memory_review_queue_items
      validate constraint memory_review_queue_items_m5_shape_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='memory_review_queue_items_m5_authority_check'
      and conrelid='public.memory_review_queue_items'::regclass
  ) then
    alter table public.memory_review_queue_items
      add constraint memory_review_queue_items_m5_authority_check
      check (
        proposed_record_type is null
        or case proposed_record_type
          when 'fact' then
            proposed_authority_kind in (
              'verified_evidence','provider_truth','runtime_truth','owner_statement'
            )
            and proposed_provenance->>'semanticSource' in ('observation','owner_decision')
            and explicit_policy_authorization is false
          when 'pattern' then
            proposed_authority_kind='inference'
            and proposed_provenance->>'semanticSource'='inference'
            and explicit_policy_authorization is false
          when 'policy' then
            (
              (
                proposed_authority_kind='explicit_current_user_instruction'
                and proposed_provenance->>'semanticSource'='owner_decision'
              )
              or
              (
                proposed_authority_kind='active_explicit_standing_policy'
                and proposed_provenance->>'semanticSource'='authoritative_policy'
              )
            )
            and explicit_policy_authorization is true
          when 'procedure' then
            proposed_authority_kind='verified_outcome'
            and proposed_provenance->>'semanticSource'='observation'
            and explicit_policy_authorization is false
          when 'failure_lesson' then
            proposed_authority_kind in ('verified_incident','verified_outcome')
            and proposed_provenance->>'semanticSource'='observation'
            and explicit_policy_authorization is false
          when 'outcome' then
            proposed_authority_kind in ('runtime_truth','provider_truth','verified_evidence')
            and proposed_provenance->>'semanticSource'='observation'
            and explicit_policy_authorization is false
          when 'provider_performance' then
            proposed_authority_kind='measured_evidence'
            and proposed_provenance->>'semanticSource'='observation'
            and explicit_policy_authorization is false
          else false
        end
      ) not valid;
    alter table public.memory_review_queue_items
      validate constraint memory_review_queue_items_m5_authority_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='memory_items_m5_shape_check'
      and conrelid='public.memory_items'::regclass
  ) then
    alter table public.memory_items
      add constraint memory_items_m5_shape_check
      check (
        knowledge_schema_version is null
        or (
          knowledge_schema_version='m5.v1'
          and record_type in (
            'fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance'
          )
          and authority_kind is not null
          and nullif(trim(authority_ref),'') is not null
          and confidence is not null
          and confidence >= 0
          and confidence <= 1
          and observed_at is not null
          and effective_at is not null
          and provenance is not null
          and jsonb_typeof(provenance)='object'
          and provenance ? 'sourceType'
          and provenance ? 'sourceLocator'
          and provenance ? 'observedAt'
          and provenance ? 'semanticSource'
          and evidence_refs is not null
          and jsonb_typeof(evidence_refs)='array'
          and jsonb_array_length(evidence_refs) > 0
          and nullif(trim(promotion_basis),'') is not null
          and (correction_of is null or correction_of<>id)
          and metadata ? 'reviewItemId'
          and metadata ? 'reviewDecisionId'
        )
      ) not valid;
    alter table public.memory_items
      validate constraint memory_items_m5_shape_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='memory_items_m5_authority_check'
      and conrelid='public.memory_items'::regclass
  ) then
    alter table public.memory_items
      add constraint memory_items_m5_authority_check
      check (
        knowledge_schema_version is null
        or case record_type
          when 'fact' then
            authority_kind in ('verified_evidence','provider_truth','runtime_truth','owner_statement')
            and provenance->>'semanticSource' in ('observation','owner_decision')
          when 'pattern' then
            authority_kind='inference'
            and provenance->>'semanticSource'='inference'
          when 'policy' then
            (
              (
                authority_kind='explicit_current_user_instruction'
                and provenance->>'semanticSource'='owner_decision'
              )
              or
              (
                authority_kind='active_explicit_standing_policy'
                and provenance->>'semanticSource'='authoritative_policy'
              )
            )
            and metadata->>'explicitPolicyAuthorization'='true'
          when 'procedure' then
            authority_kind='verified_outcome'
            and provenance->>'semanticSource'='observation'
          when 'failure_lesson' then
            authority_kind in ('verified_incident','verified_outcome')
            and provenance->>'semanticSource'='observation'
          when 'outcome' then
            authority_kind in ('runtime_truth','provider_truth','verified_evidence')
            and provenance->>'semanticSource'='observation'
          when 'provider_performance' then
            authority_kind='measured_evidence'
            and provenance->>'semanticSource'='observation'
          else false
        end
      ) not valid;
    alter table public.memory_items
      validate constraint memory_items_m5_authority_check;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='memory_items_m5_supersession_shape_check'
      and conrelid='public.memory_items'::regclass
  ) then
    alter table public.memory_items
      add constraint memory_items_m5_supersession_shape_check
      check (
        knowledge_schema_version is null
        or (
          (
            superseded_by is null
            and superseded_at is null
            and supersession_reason is null
          )
          or (
            superseded_by is not null
            and superseded_by<>id
            and superseded_at is not null
            and nullif(trim(supersession_reason),'') is not null
          )
        )
      ) not valid;
    alter table public.memory_items
      validate constraint memory_items_m5_supersession_shape_check;
  end if;
end $$;

create index if not exists memory_items_m5_scope_type_idx
  on public.memory_items(user_id,namespace,project_id,record_type,effective_at desc)
  where knowledge_schema_version='m5.v1';

create index if not exists memory_items_m5_current_scope_type_idx
  on public.memory_items(user_id,namespace,project_id,record_type,effective_at desc)
  where knowledge_schema_version='m5.v1'
    and superseded_by is null
    and revoked_at is null
    and is_active is true;

create index if not exists memory_review_queue_items_m5_pending_idx
  on public.memory_review_queue_items(user_id,namespace,proposed_record_type,created_at desc)
  where proposed_record_type is not null and status='pending_review';

create or replace function public.memory_apply_reviewed_m5_record_v1()
returns trigger
language plpgsql
security invoker
set search_path='pg_catalog','public'
as $function$
declare
  v_review_id uuid;
  v_decision_id uuid;
  v_review public.memory_review_queue_items%rowtype;
  v_decision public.memory_review_queue_decisions%rowtype;
  v_predecessor public.memory_items%rowtype;
begin
  begin
    v_review_id:=nullif(new.metadata->>'reviewItemId','')::uuid;
    v_decision_id:=nullif(new.metadata->>'reviewDecisionId','')::uuid;
  exception when others then
    raise exception 'invalid M5 review lineage metadata' using errcode='22023';
  end;

  if v_review_id is null then
    if new.knowledge_schema_version='m5.v1' then
      raise exception 'M5 typed record requires approved review lineage' using errcode='22023';
    end if;
    return new;
  end if;

  select * into v_review
  from public.memory_review_queue_items
  where id=v_review_id
    and user_id=new.user_id
    and namespace=new.namespace::text;

  if not found or v_review.proposed_record_type is null then
    if new.knowledge_schema_version='m5.v1' then
      raise exception 'M5 typed record proposal not found' using errcode='22023';
    end if;
    return new;
  end if;

  if v_review.status<>'approved_for_append'
     or v_review.append_only is not true
     or v_review.proposed_operation<>'append'
     or v_review.requires_review is not true then
    raise exception 'M5 typed record requires approved append review' using errcode='22023';
  end if;

  if v_decision_id is null then
    raise exception 'M5 typed record requires exact approved decision' using errcode='22023';
  end if;

  select * into v_decision
  from public.memory_review_queue_decisions
  where id=v_decision_id
    and review_item_id=v_review.id
    and user_id=new.user_id
    and namespace=new.namespace::text
    and to_status='approved_for_append'
  order by created_at desc
  limit 1;

  if not found then
    raise exception 'M5 typed record approval decision mismatch' using errcode='22023';
  end if;

  if v_review.proposed_record_type='policy' then
    if v_review.proposed_authority_kind not in (
         'explicit_current_user_instruction',
         'active_explicit_standing_policy'
       )
       or v_review.explicit_policy_authorization is not true then
      raise exception 'inference, prediction, pattern, procedure, provider performance, prior success, and model output cannot become policy authorization'
        using errcode='22023';
    end if;
  elsif v_review.explicit_policy_authorization is true then
    raise exception 'non-policy M5 record cannot carry policy authorization'
      using errcode='22023';
  end if;

  if v_review.proposed_correction_of is not null then
    select * into v_predecessor
    from public.memory_items
    where id=v_review.proposed_correction_of
      and user_id=new.user_id
      and namespace=new.namespace
      and project_id is not distinct from new.project_id
      and knowledge_schema_version='m5.v1'
      and record_type=v_review.proposed_record_type;

    if not found or v_predecessor.id=new.id then
      raise exception 'M5 correction target must be an existing same-scope same-type typed record'
        using errcode='22023';
    end if;
  end if;

  new.knowledge_schema_version:='m5.v1';
  new.record_type:=v_review.proposed_record_type;
  new.authority_kind:=v_review.proposed_authority_kind;
  new.authority_ref:=v_review.proposed_authority_ref;
  new.provenance:=v_review.proposed_provenance;
  new.evidence_refs:=v_review.proposed_evidence_refs;
  new.observed_at:=v_review.proposed_observed_at;
  new.effective_at:=v_review.proposed_effective_at;
  new.confidence:=v_review.proposed_confidence;
  new.promotion_basis:=v_review.proposed_promotion_basis;
  new.correction_of:=v_review.proposed_correction_of;
  new.confidence_basis:=case
    when v_review.proposed_record_type='pattern' then 'confidence_weighted_inference'
    when v_review.proposed_record_type='provider_performance' then 'measured_verified_samples'
    when v_review.proposed_record_type='policy' then 'explicit_authority_not_confidence'
    else 'approved_evidence'
  end;
  new.approved_by:=coalesce(new.approved_by,'review-decision:'||v_decision.id::text);
  new.approved_at:=coalesce(new.approved_at,v_decision.created_at);
  new.metadata:=new.metadata||jsonb_build_object(
    'knowledgeSchemaVersion','m5.v1',
    'recordType',v_review.proposed_record_type,
    'authorityKind',v_review.proposed_authority_kind,
    'semanticSource',v_review.proposed_provenance->>'semanticSource',
    'explicitPolicyAuthorization',v_review.explicit_policy_authorization,
    'authorizationEffect',case
      when v_review.proposed_record_type='policy'
        then 'requires_exact_runtime_scope_validity_revocation_validation'
      else 'none'
    end
  );
  return new;
end;
$function$;

drop trigger if exists memory_apply_reviewed_m5_record_v1 on public.memory_items;
create trigger memory_apply_reviewed_m5_record_v1
before insert on public.memory_items
for each row execute function public.memory_apply_reviewed_m5_record_v1();

create or replace function public.memory_guard_m5_record_update_v1()
returns trigger
language plpgsql
security invoker
set search_path='pg_catalog','public'
as $function$
declare
  v_successor public.memory_items%rowtype;
begin
  if old.knowledge_schema_version is distinct from 'm5.v1' then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.namespace is distinct from old.namespace
     or new.project_id is distinct from old.project_id
     or new.memory_type is distinct from old.memory_type
     or new.record_type is distinct from old.record_type
     or new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.confidence is distinct from old.confidence
     or new.observed_at is distinct from old.observed_at
     or new.effective_at is distinct from old.effective_at
     or new.authority_kind is distinct from old.authority_kind
     or new.authority_ref is distinct from old.authority_ref
     or new.provenance is distinct from old.provenance
     or new.evidence_refs is distinct from old.evidence_refs
     or new.promotion_basis is distinct from old.promotion_basis
     or new.correction_of is distinct from old.correction_of
     or new.confidence_basis is distinct from old.confidence_basis
     or new.knowledge_schema_version is distinct from old.knowledge_schema_version then
    raise exception 'M5 typed record semantics are immutable; append a successor instead'
      using errcode='22023';
  end if;

  if old.superseded_by is not null then
    if new.superseded_by is distinct from old.superseded_by
       or new.superseded_at is distinct from old.superseded_at
       or new.supersession_reason is distinct from old.supersession_reason then
      raise exception 'M5 supersession is immutable once recorded'
        using errcode='22023';
    end if;
    return new;
  end if;

  if new.superseded_by is null then
    if new.superseded_at is distinct from old.superseded_at
       or new.supersession_reason is distinct from old.supersession_reason then
      raise exception 'M5 supersession timestamp/reason cannot exist without a successor'
        using errcode='22023';
    end if;
    return new;
  end if;

  if new.superseded_by is not distinct from old.superseded_by then
    return new;
  end if;

  select * into v_successor
  from public.memory_items
  where id=new.superseded_by;

  if not found
     or v_successor.id=old.id
     or v_successor.user_id is distinct from old.user_id
     or v_successor.namespace is distinct from old.namespace
     or v_successor.project_id is distinct from old.project_id
     or v_successor.memory_type is distinct from old.memory_type
     or v_successor.knowledge_schema_version is distinct from 'm5.v1'
     or v_successor.record_type is distinct from old.record_type
     or v_successor.is_active is not true
     or v_successor.revoked_at is not null
     or v_successor.canon_status not in ('soft_canon','hard_canon')
     or v_successor.superseded_by is not null
     or (
       v_successor.correction_of is not null
       and v_successor.correction_of is distinct from old.id
     ) then
    raise exception 'invalid M5 supersession successor'
      using errcode='22023';
  end if;

  if new.superseded_at is null
     or nullif(trim(new.supersession_reason),'') is null then
    raise exception 'M5 supersession timestamp and reason required'
      using errcode='22023';
  end if;

  return new;
end;
$function$;

drop trigger if exists memory_guard_m5_record_update_v1 on public.memory_items;
create trigger memory_guard_m5_record_update_v1
before update on public.memory_items
for each row execute function public.memory_guard_m5_record_update_v1();

comment on column public.memory_items.knowledge_schema_version is
  'M5 typed-memory contract version. Null preserves legacy records; m5.v1 enables strict typed invariants.';
comment on column public.memory_items.authority_kind is
  'M0-005 authority classification. Confidence, inference, prediction, repeated behavior, and model output never upgrade authority.';
comment on column public.memory_items.authority_ref is
  'Exact evidence/instruction/standing-policy authority reference. Policy rows still require runtime scope, validity, principal, capability, provider/resource, environment, sensitivity, cost, and revocation validation.';
comment on column public.memory_items.provenance is
  'Bounded provenance containing sourceType, sourceLocator, observedAt and semanticSource.';
comment on column public.memory_items.evidence_refs is
  'Durable evidence references supporting promotion into canonical Memory.';
comment on column public.memory_items.promotion_basis is
  'Human/machine-auditable reason this high-signal record was promoted rather than retained as raw telemetry.';
comment on column public.memory_items.correction_of is
  'Optional prior same-scope same-type typed Memory record corrected by this append-only successor.';
comment on column public.memory_review_queue_items.explicit_policy_authorization is
  'True only for explicit current-user instruction or active explicit standing-policy proposals; advisory Memory never sets this implicitly.';
