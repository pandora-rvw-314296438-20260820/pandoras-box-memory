
create table if not exists private.memory_pandora_planning_nonces (
  request_id uuid primary key,
  organization_id uuid not null,
  visible_project_id uuid not null,
  memory_project_id uuid not null,
  project_key text not null,
  decision_type text not null check (decision_type in ('project_spec','build','repair')),
  query_hash text not null check (query_hash ~ '^[0-9a-f]{64}$'),
  claimed_at timestamptz not null default now()
);

insert into private.memory_pandora_planning_nonces(
  request_id,organization_id,visible_project_id,memory_project_id,project_key,decision_type,query_hash,claimed_at
)
select request_id,organization_id,visible_project_id,memory_project_id,project_key,decision_type,query_hash,claimed_at
from private.memory_projectos_planning_nonces
on conflict (request_id) do nothing;

create or replace function public.memory_claim_pandora_planning_nonce_v1(
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

  insert into private.memory_pandora_planning_nonces(
    request_id,organization_id,visible_project_id,memory_project_id,project_key,decision_type,query_hash
  ) values (
    p_request_id,p_organization_id,p_visible_project_id,p_memory_project_id,p_project_key,p_decision_type,p_query_hash
  ) on conflict (request_id) do nothing
  returning request_id into v_inserted;

  return v_inserted is not null;
end;
$$;

revoke all on function public.memory_claim_pandora_planning_nonce_v1(uuid,uuid,uuid,uuid,text,text,text)
  from public,anon,authenticated;
grant execute on function public.memory_claim_pandora_planning_nonce_v1(uuid,uuid,uuid,uuid,text,text,text)
  to service_role;

insert into public.pandora_service_principals(
  id,principal_key,provider,issuer,audience,subject,owner_id,project_id,project_name,
  environment,memory_user_id,allowed_namespaces,scopes,is_active,created_at,updated_at
)
select
  gen_random_uuid(),'pandora-production',provider,issuer,audience,subject,owner_id,project_id,project_name,
  environment,memory_user_id,allowed_namespaces,scopes,is_active,now(),now()
from public.pandora_service_principals
where principal_key='projectos-mcpmaster-production'
on conflict (principal_key) do update
set provider=excluded.provider,
    issuer=excluded.issuer,
    audience=excluded.audience,
    subject=excluded.subject,
    owner_id=excluded.owner_id,
    project_id=excluded.project_id,
    project_name=excluded.project_name,
    environment=excluded.environment,
    memory_user_id=excluded.memory_user_id,
    allowed_namespaces=excluded.allowed_namespaces,
    scopes=excluded.scopes,
    is_active=excluded.is_active,
    updated_at=now();

insert into public.pandora_project_grants(
  principal_key,project_id,environment,allowed_record_types,can_read,can_propose,can_approve,
  is_active,revoked_at,revocation_reason,created_at,updated_at
)
select
  'pandora-production',project_id,environment,allowed_record_types,can_read,can_propose,can_approve,
  is_active,revoked_at,revocation_reason,now(),now()
from public.pandora_project_grants
where principal_key='projectos-mcpmaster-production'
on conflict (principal_key,project_id,environment) do update
set allowed_record_types=excluded.allowed_record_types,
    can_read=excluded.can_read,
    can_propose=excluded.can_propose,
    can_approve=excluded.can_approve,
    is_active=excluded.is_active,
    revoked_at=excluded.revoked_at,
    revocation_reason=excluded.revocation_reason,
    updated_at=now();

insert into private.pandora_integration_credentials(
  integration_key,secret_value,memory_user_id,allowed_product_keys,is_active,created_at,updated_at,vault_secret_id
)
select
  'pandora-planning-bridge',null,memory_user_id,
  (select array_agg(distinct v order by v) from unnest(allowed_product_keys || array['pandora']::text[]) v),
  is_active,now(),now(),vault_secret_id
from private.pandora_integration_credentials
where integration_key='projectos-learning-bridge'
on conflict (integration_key) do update
set memory_user_id=excluded.memory_user_id,
    allowed_product_keys=excluded.allowed_product_keys,
    is_active=excluded.is_active,
    updated_at=now(),
    vault_secret_id=excluded.vault_secret_id;
