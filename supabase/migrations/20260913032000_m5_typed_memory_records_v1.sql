-- M5-001: typed governed Memory records.
-- Additive only. Existing rows and candidate -> review -> canonical authority remain intact.
-- No data backfill, canonical promotion, production deployment, or provider mutation is performed here.
-- M0-005 compatibility: inference is never authorization; semantic corrections append + supersede.

alter table public.memory_review_queue_items
  add column if not exists proposed_record_type text,
  add column if not exists proposed_authority_kind text,
  add column if not exists proposed_authority_ref text,
  add column if not exists proposed_confidence numeric(5,4),
  add column if not exists proposed_effective_at timestamptz,
  add column if not exists proposed_provenance jsonb,
  add column if not exists explicit_policy_authorization boolean not null default false;

alter table public.memory_items
  add column if not exists knowledge_schema_version text,
  add column if not exists authority_kind text,
  add column if not exists authority_ref text,
  add column if not exists provenance jsonb,
  add column if not exists confidence_basis text,
  add column if not exists supersession_reason text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='memory_review_queue_items_m5_record_type_check' and conrelid='public.memory_review_queue_items'::regclass) then
    alter table public.memory_review_queue_items add constraint memory_review_queue_items_m5_record_type_check
      check (proposed_record_type is null or proposed_record_type in ('fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance')) not valid;
    alter table public.memory_review_queue_items validate constraint memory_review_queue_items_m5_record_type_check;
  end if;

  if not exists (select 1 from pg_constraint where conname='memory_review_queue_items_m5_shape_check' and conrelid='public.memory_review_queue_items'::regclass) then
    alter table public.memory_review_queue_items add constraint memory_review_queue_items_m5_shape_check
      check (proposed_record_type is null or (
        proposed_authority_kind is not null
        and proposed_confidence is not null and proposed_confidence >= 0 and proposed_confidence <= 1
        and proposed_effective_at is not null
        and proposed_provenance is not null and jsonb_typeof(proposed_provenance)='object'
        and proposed_provenance ? 'sourceType'
        and proposed_provenance ? 'sourceLocator'
        and proposed_provenance ? 'observedAt'
        and nullif(trim(proposed_provenance->>'sourceType'),'') is not null
        and nullif(trim(proposed_provenance->>'sourceLocator'),'') is not null
        and nullif(trim(proposed_provenance->>'observedAt'),'') is not null
        and octet_length(proposed_provenance::text) <= 16384
      )) not valid;
    alter table public.memory_review_queue_items validate constraint memory_review_queue_items_m5_shape_check;
  end if;

  if not exists (select 1 from pg_constraint where conname='memory_review_queue_items_m5_authority_check' and conrelid='public.memory_review_queue_items'::regclass) then
    alter table public.memory_review_queue_items add constraint memory_review_queue_items_m5_authority_check
      check (proposed_record_type is null or case proposed_record_type
        when 'fact' then proposed_authority_kind in ('verified_evidence','provider_truth','owner_statement') and nullif(trim(proposed_authority_ref),'') is not null
        when 'pattern' then proposed_authority_kind='inference' and nullif(trim(proposed_authority_ref),'') is not null and explicit_policy_authorization is false
        when 'policy' then proposed_authority_kind='owner_policy' and explicit_policy_authorization is true
        when 'procedure' then proposed_authority_kind='verified_outcome' and nullif(trim(proposed_authority_ref),'') is not null
        when 'failure_lesson' then proposed_authority_kind='verified_outcome' and nullif(trim(proposed_authority_ref),'') is not null
        when 'outcome' then proposed_authority_kind in ('runtime_truth','provider_truth','verified_evidence') and nullif(trim(proposed_authority_ref),'') is not null
        when 'provider_performance' then proposed_authority_kind='measured_evidence' and nullif(trim(proposed_authority_ref),'') is not null
        else false end) not valid;
    alter table public.memory_review_queue_items validate constraint memory_review_queue_items_m5_authority_check;
  end if;

  if not exists (select 1 from pg_constraint where conname='memory_items_m5_shape_check' and conrelid='public.memory_items'::regclass) then
    alter table public.memory_items add constraint memory_items_m5_shape_check
      check (knowledge_schema_version is null or (
        knowledge_schema_version='m5.v1'
        and record_type in ('fact','pattern','policy','procedure','failure_lesson','outcome','provider_performance')
        and authority_kind is not null and nullif(trim(authority_ref),'') is not null
        and confidence is not null and confidence >= 0 and confidence <= 1
        and effective_at is not null
        and provenance is not null and jsonb_typeof(provenance)='object'
        and provenance ? 'sourceType' and provenance ? 'sourceLocator' and provenance ? 'observedAt'
        and metadata ? 'reviewItemId' and metadata ? 'reviewDecisionId'
      )) not valid;
    alter table public.memory_items validate constraint memory_items_m5_shape_check;
  end if;

  if not exists (select 1 from pg_constraint where conname='memory_items_m5_authority_check' and conrelid='public.memory_items'::regclass) then
    alter table public.memory_items add constraint memory_items_m5_authority_check
      check (knowledge_schema_version is null or case record_type
        when 'fact' then authority_kind in ('verified_evidence','provider_truth','owner_statement')
        when 'pattern' then authority_kind='inference'
        when 'policy' then authority_kind='owner_policy'
        when 'procedure' then authority_kind='verified_outcome'
        when 'failure_lesson' then authority_kind='verified_outcome'
        when 'outcome' then authority_kind in ('runtime_truth','provider_truth','verified_evidence')
        when 'provider_performance' then authority_kind='measured_evidence'
        else false end) not valid;
    alter table public.memory_items validate constraint memory_items_m5_authority_check;
  end if;

  if not exists (select 1 from pg_constraint where conname='memory_items_m5_supersession_shape_check' and conrelid='public.memory_items'::regclass) then
    alter table public.memory_items add constraint memory_items_m5_supersession_shape_check
      check (knowledge_schema_version is null or (
        (superseded_by is null and superseded_at is null)
        or (superseded_by is not null and superseded_by<>id and superseded_at is not null and nullif(trim(supersession_reason),'') is not null)
      )) not valid;
    alter table public.memory_items validate constraint memory_items_m5_supersession_shape_check;
  end if;
end $$;

create index if not exists memory_items_m5_scope_type_idx
  on public.memory_items(user_id,namespace,project_id,record_type,effective_at desc)
  where knowledge_schema_version='m5.v1';

create index if not exists memory_review_queue_items_m5_pending_idx
  on public.memory_review_queue_items(user_id,namespace,proposed_record_type,created_at desc)
  where proposed_record_type is not null and status='pending_review';

create or replace function public.memory_apply_reviewed_m5_record_v1()
returns trigger language plpgsql security invoker set search_path='pg_catalog','public' as $function$
declare
  v_review_id uuid;
  v_decision_id uuid;
  v_review public.memory_review_queue_items%rowtype;
  v_decision public.memory_review_queue_decisions%rowtype;
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
  where id=v_review_id and user_id=new.user_id and namespace=new.namespace::text;

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
    if v_review.proposed_authority_kind<>'owner_policy'
       or v_review.explicit_policy_authorization is not true then
      raise exception 'inference cannot become policy authorization' using errcode='22023';
    end if;
    new.authority_ref:='review-decision:'||v_decision.id::text;
  else
    new.authority_ref:=v_review.proposed_authority_ref;
  end if;

  new.knowledge_schema_version:='m5.v1';
  new.record_type:=v_review.proposed_record_type;
  new.authority_kind:=v_review.proposed_authority_kind;
  new.provenance:=v_review.proposed_provenance;
  new.confidence:=v_review.proposed_confidence;
  new.effective_at:=v_review.proposed_effective_at;
  new.confidence_basis:=case
    when v_review.proposed_record_type='pattern' then 'confidence_weighted_inference'
    when v_review.proposed_record_type='provider_performance' then 'measured_verified_samples'
    else 'approved_evidence'
  end;
  new.approved_by:=coalesce(new.approved_by,'review-decision:'||v_decision.id::text);
  new.approved_at:=coalesce(new.approved_at,v_decision.created_at);
  new.metadata:=new.metadata||jsonb_build_object(
    'knowledgeSchemaVersion','m5.v1',
    'recordType',v_review.proposed_record_type,
    'authorityKind',v_review.proposed_authority_kind,
    'explicitPolicyAuthorization',v_review.explicit_policy_authorization
  );
  return new;
end;
$function$;

drop trigger if exists memory_apply_reviewed_m5_record_v1 on public.memory_items;
create trigger memory_apply_reviewed_m5_record_v1
before insert on public.memory_items
for each row execute function public.memory_apply_reviewed_m5_record_v1();

create or replace function public.memory_guard_m5_record_update_v1()
returns trigger language plpgsql security invoker set search_path='pg_catalog','public' as $function$
declare
  v_successor public.memory_items%rowtype;
begin
  if old.knowledge_schema_version is distinct from 'm5.v1' then
    return new;
  end if;

  if new.user_id is distinct from old.user_id
     or new.namespace is distinct from old.namespace
     or new.project_id is distinct from old.project_id
     or new.record_type is distinct from old.record_type
     or new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.confidence is distinct from old.confidence
     or new.effective_at is distinct from old.effective_at
     or new.authority_kind is distinct from old.authority_kind
     or new.authority_ref is distinct from old.authority_ref
     or new.provenance is distinct from old.provenance
     or new.knowledge_schema_version is distinct from old.knowledge_schema_version then
    raise exception 'M5 typed record semantics are immutable; append a successor instead' using errcode='22023';
  end if;

  if new.superseded_by is distinct from old.superseded_by then
    if old.superseded_by is not null then
      raise exception 'M5 supersession is immutable once recorded' using errcode='22023';
    end if;
    if new.superseded_by is null then
      raise exception 'M5 supersession target required' using errcode='22023';
    end if;

    select * into v_successor from public.memory_items where id=new.superseded_by;

    if not found
       or v_successor.id=old.id
       or v_successor.user_id is distinct from old.user_id
       or v_successor.namespace is distinct from old.namespace
       or v_successor.project_id is distinct from old.project_id
       or v_succcessor.memory_type is distinct from old.memory_type
       or v_successor.knowledge_schema_version is distinct from 'm5.v1'
       or v_successor.record_type is distinct from old.record_type
       or v_successor.is_active is not true
       or v_successor.revoked_at is not null
       or v_successor.canon_status not in ('soft_canon','hard_canon')
       or v_successor.superseded_by is not null then
      raise exception 'invalid M5 supersession successor' using errcode='22023';
    end if;

    if new.superseded_at is null or nullif(trim(new.supersession_reason),'') is null then
      raise exception 'M5 supersession timestamp and reason required' using errcode='22023';
    end if;
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
  'Authority classification for typed Memory; inference never grants permission.';
comment on column public.memory_items.provenance is
  'Bounded provenance: sourceType, sourceLocator, observedAt, plus optional exact evidence identifiers.';
comment on column public.memory_review_queue_items.explicit_policy_authorization is
  'True only for explicitly reviewed policy proposals; patterns/inference cannot set standing permission.';
