-- Bind PLP Enterprise production to verified-learning proposals in Pandora Memory.
-- The workload may propose review items only. It cannot approve canonical Memory.

do $$
declare
  v_memory_user_id uuid;
  v_gateway_principal_id uuid;
begin
  if (
    select count(distinct gp.user_id)
    from public.gateway_principals gp
    where gp.principal_type = 'oauth_user_client'
      and gp.is_active is true
      and gp.user_id is not null
  ) <> 1 then
    raise exception 'PLP Memory owner identity is not uniquely resolvable' using errcode='42501';
  end if;

  select gp.user_id
    into v_memory_user_id
  from public.gateway_principals gp
  where gp.principal_type = 'oauth_user_client'
    and gp.is_active is true
    and gp.user_id is not null
  limit 1;

  insert into public.gateway_principals(
    principal_key,
    principal_type,
    user_id,
    oidc_issuer,
    oidc_audience,
    oidc_subject,
    display_name,
    is_active
  )
  values (
    'plp-enterprise-production',
    'workload_oidc',
    v_memory_user_id,
    'https://oidc.vercel.com/mbanatao',
    'https://vercel.com/mbanatao',
    'owner:mbanatao:project:enterprise:environment:production',
    'PLP Enterprise production verified-learning workload',
    true
  )
  on conflict(principal_key) do update set
    principal_type=excluded.principal_type,
    user_id=excluded.user_id,
    oauth_client_id=null,
    oidc_issuer=excluded.oidc_issuer,
    oidc_audience=excluded.oidc_audience,
    oidc_subject=excluded.oidc_subject,
    display_name=excluded.display_name,
    is_active=true,
    updated_at=now()
  returning id into v_gateway_principal_id;

  insert into public.pandora_service_principals(
    principal_key,
    provider,
    issuer,
    audience,
    subject,
    owner_id,
    project_id,
    project_name,
    environment,
    memory_user_id,
    allowed_namespaces,
    scopes,
    is_active
  )
  values (
    'plp-enterprise-production',
    'vercel_oidc',
    'https://oidc.vercel.com/mbanatao',
    'https://vercel.com/mbanatao',
    'owner:mbanatao:project:enterprise:environment:production',
    'mbanatao',
    'prj_Aa4Dz7bWERhY88Iiav0m9oakeCXx',
    'enterprise',
    'production',
    v_memory_user_id,
    array['real_life']::text[],
    array['memory:health','memory:read','memory:write']::text[],
    true
  )
  on conflict(principal_key) do update set
    provider=excluded.provider,
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
    is_active=true,
    updated_at=now();

  insert into public.pandora_project_grants(
    principal_key,
    project_id,
    environment,
    allowed_record_types,
    can_read,
    can_propose,
    can_approve,
    is_active,
    revoked_at,
    revocation_reason
  )
  values (
    'plp-enterprise-production',
    '5536b0be-cd7b-454e-ab27-57574539699d'::uuid,
    'production',
    array['fact','procedure','failure_lesson','outcome']::text[],
    true,
    true,
    false,
    true,
    null,
    null
  )
  on conflict(principal_key,project_id,environment) do update set
    allowed_record_types=excluded.allowed_record_types,
    can_read=true,
    can_propose=true,
    can_approve=false,
    is_active=true,
    revoked_at=null,
    revocation_reason=null,
    updated_at=now();

  update public.gateway_service_actions
  set enabled=true,
      provider_status='production_verified',
      metadata=coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'surface','machine_gateway',
        'canonicalWrite',false,
        'reviewRequired',true,
        'acceptedContract','pandora-continuous-execution-v2',
        'plpEnterpriseEnabled',true
      ),
      updated_at=now()
  where service_key='pandora_memory'
    and action_key='verified_learning.propose';

  if not found then
    raise exception 'verified-learning capability is not registered' using errcode='55000';
  end if;

  select gp.id into v_gateway_principal_id
  from public.gateway_principals gp
  where gp.principal_key='plp-enterprise-production'
    and gp.is_active is true
  limit 1;

  insert into public.gateway_grants(
    principal_id,
    service_key,
    action_pattern,
    environment,
    resource_pattern,
    is_active
  )
  values (
    v_gateway_principal_id,
    'pandora_memory',
    'verified_learning.propose',
    'production',
    'project:5536b0be-cd7b-454e-ab27-57574539699d',
    true
  )
  on conflict(principal_id,service_key,action_pattern,environment,resource_pattern)
  do update set is_active=true,updated_at=now();

  insert into public.gateway_grants(
    principal_id,
    service_key,
    action_pattern,
    environment,
    resource_pattern,
    is_active
  )
  values (
    v_gateway_principal_id,
    'pandora_memory',
    'search',
    'production',
    'namespace:real_life',
    true
  )
  on conflict(principal_id,service_key,action_pattern,environment,resource_pattern)
  do update set is_active=true,updated_at=now();
end;
$$;
