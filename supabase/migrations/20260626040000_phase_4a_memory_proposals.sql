-- Phase 4A controlled operator-approved memory persistence proposals.
-- Authenticated, namespace-scoped, RLS protected; no public/anon writes.

create table if not exists public.memory_proposals (
  id uuid primary key default gen_random_uuid(),
  namespace public.pandora_namespace not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text,
  memory_text text not null check (length(btrim(memory_text)) > 0),
  memory_type text,
  confidence numeric(5,4) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  source_type text,
  source_ref text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','needs_revision','persisted','disabled')),
  proposed_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  persisted_memory_id uuid references public.memory_items(id),
  rejection_reason text,
  revision_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists memory_proposals_user_namespace_status_idx on public.memory_proposals (user_id, namespace, status, created_at desc);
alter table public.memory_proposals enable row level security;
create policy "memory_proposals_authenticated_select_own_namespace"
  on public.memory_proposals for select to authenticated
  using (auth.uid() = user_id and namespace in ('real_life','au'));
create policy "memory_proposals_authenticated_insert_own_namespace"
  on public.memory_proposals for insert to authenticated
  with check (auth.uid() = user_id and auth.uid() = proposed_by and status = 'pending' and reviewed_by is null and persisted_memory_id is null);
create policy "memory_proposals_authenticated_update_own_namespace"
  on public.memory_proposals for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and namespace in ('real_life','au'));
create or replace function public.memory_persist_approved_proposal(p_proposal_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_proposal record;
  v_memory_item_id uuid := gen_random_uuid();
  v_source_id uuid := gen_random_uuid();
  v_patch_id uuid := gen_random_uuid();
  v_audit_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_memory_type public.memory_type := 'observation';
  v_source_type public.evidence_source_type := 'manual_admin_entry';
begin
  if v_user_id is null then raise exception 'authenticated user required' using errcode = '28000'; end if;

  select * into v_proposal from public.memory_proposals
  where id = p_proposal_id and user_id = v_user_id for update;
  if not found then raise exception 'proposal not found for authenticated user' using errcode = 'P0002'; end if;
  if v_proposal.status <> 'approved' then raise exception 'only approved proposals can be persisted' using errcode = '22023'; end if;
  if v_proposal.persisted_memory_id is not null then raise exception 'proposal already persisted' using errcode = '23505'; end if;

  if v_proposal.memory_type in ('observation','user_preference','soft_canon','hard_canon','contradiction','retcon_candidate','real_life_fact','business_fact','relationship_signal','risk_signal') then
    v_memory_type := v_proposal.memory_type::public.memory_type;
  end if;
  if v_proposal.source_type in ('screenshot','email','document','user_statement','conversation_turn','url','uploaded_file','manual_admin_entry','other') then
    v_source_type := v_proposal.source_type::public.evidence_source_type;
  end if;

  insert into public.memory_items (id,user_id,namespace,memory_type,title,body,confidence,source_summary,metadata,created_at,updated_at)
  values (v_memory_item_id,v_user_id,v_proposal.namespace::public.pandora_namespace,v_memory_type,coalesce(v_proposal.title,left(v_proposal.memory_text,120)),v_proposal.memory_text,coalesce(v_proposal.confidence,0.5),v_proposal.source_ref,jsonb_build_object('proposalId',v_proposal.id,'proposedBy',v_proposal.proposed_by,'reviewedBy',v_proposal.reviewed_by,'reviewedAt',v_proposal.reviewed_at,'phase','4A','appendOnly',true),v_now,v_now);
  insert into public.memory_sources (id,user_id,namespace,memory_item_id,source_type,source_ref,excerpt,confidence,metadata,created_at)
  values (v_source_id,v_user_id,v_proposal.namespace::public.pandora_namespace,v_memory_item_id,v_source_type,v_proposal.source_ref,v_proposal.memory_text,coalesce(v_proposal.confidence,0.5),jsonb_build_object('proposalId',v_proposal.id,'appendOnly',true),v_now);
  insert into public.memory_patches (id,user_id,namespace,memory_item_id,patch_type,reason,before_snapshot,after_snapshot,metadata,created_at)
  values (v_patch_id,v_user_id,v_proposal.namespace::public.pandora_namespace,v_memory_item_id,'append','phase_4a_approved_proposal',null,jsonb_build_object('body',v_proposal.memory_text,'namespace',v_proposal.namespace),jsonb_build_object('proposalId',v_proposal.id,'appendOnly',true),v_now);
  insert into public.audit_logs (id,user_id,namespace,action,table_name,record_id,before_snapshot,after_snapshot,metadata,created_at)
  values (v_audit_id,v_user_id,v_proposal.namespace::public.pandora_namespace,'proposal_persisted','memory_proposals',v_proposal.id,null,jsonb_build_object('memoryItemId',v_memory_item_id),jsonb_build_object('proposalId',v_proposal.id,'sourceId',v_source_id,'patchId',v_patch_id,'appendOnly',true),v_now);
  update public.memory_proposals set status='persisted', persisted_memory_id=v_memory_item_id, reviewed_by=coalesce(reviewed_by,v_user_id), reviewed_at=coalesce(reviewed_at,v_now), updated_at=v_now where id=v_proposal.id;
  return jsonb_build_object('proposalId', v_proposal.id, 'memoryItemId', v_memory_item_id, 'sourceId', v_source_id, 'patchId', v_patch_id, 'auditId', v_audit_id, 'appendOnly', true);
end;
$$;
