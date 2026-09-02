begin;

create table if not exists private.memory_projectos_planning_nonces (
  request_id uuid primary key,
  organization_id uuid not null,
  visible_project_id uuid not null,
  memory_project_id uuid not null,
  project_key text not null,
  decision_type text not null check (decision_type in ('project_spec','build','repair')),
  query_hash text not null check (query_hash ~ '^[0-9a-f]{64}$'),
  claimed_at timestamptz not null default now()
);

revoke all on private.memory_projectos_planning_nonces from public, anon, authenticated;
grant select, insert on private.memory_projectos_planning_nonces to service_role;

create or replace function public.memory_claim_projectos_planning_nonce_v1(
  p_request_id uuid,
  p_organization_id uuid,
  p_visible_project_id uuid,
  p_memory_project_id uuid,
  p_project_key text,
  p_decision_type text,
  p_query_hash text
) returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_inserted uuid;
begin
  if p_request_id is null or p_organization_id is null or p_visible_project_id is null
     or p_memory_project_id is null or p_project_key is null
     or p_decision_type not in ('project_spec','build','repair')
     or p_query_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'planning nonce identity invalid' using errcode='22023';
  end if;

  insert into private.memory_projectos_planning_nonces(
    request_id,organization_id,visible_project_id,memory_project_id,project_key,decision_type,query_hash
  ) values (
    p_request_id,p_organization_id,p_visible_project_id,p_memory_project_id,p_project_key,p_decision_type,p_query_hash
  ) on conflict (request_id) do nothing
  returning request_id into v_inserted;

  return v_inserted is not null;
end;
$$;

revoke all on function public.memory_claim_projectos_planning_nonce_v1(uuid,uuid,uuid,uuid,text,text,text)
  from public,anon,authenticated;
grant execute on function public.memory_claim_projectos_planning_nonce_v1(uuid,uuid,uuid,uuid,text,text,text)
  to service_role;

commit;
