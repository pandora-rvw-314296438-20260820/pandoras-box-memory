-- PLP ProjectOS Memory authorization bootstrap.
-- Source-tracked, idempotent, and fail-closed.
-- Grants ProjectOS the same record-type read scope as the canonical Pandora control project,
-- but only for the exact PLP project. No Memory records are copied across projects.

begin;

do $$
declare
  v_project_id uuid;
  v_allowed_record_types text[];
begin
  select grant_row.allowed_record_types
    into v_allowed_record_types
  from public.pandora_project_grants grant_row
  join public.pandora_projects project_row
    on project_row.id = grant_row.project_id
  where grant_row.principal_key = 'projectos-mcpmaster-production'
    and grant_row.environment = 'production'
    and grant_row.is_active is true
    and grant_row.can_read is true
    and grant_row.revoked_at is null
    and project_row.project_key = 'mcpmaster-pandoras-box'
    and project_row.lifecycle_status = 'active'
  order by grant_row.updated_at desc
  limit 1;

  if coalesce(cardinality(v_allowed_record_types), 0) = 0 then
    raise exception 'PLP_MEMORY_BOOTSTRAP_CANONICAL_GRANT_MISSING'
      using errcode = '42501';
  end if;

  insert into public.pandora_projects (
    project_key,
    canonical_name,
    aliases,
    github_owner,
    github_repository,
    supabase_project_ref,
    vercel_project_id,
    production_url,
    memory_namespace,
    lifecycle_status,
    confidentiality
  ) values (
    'plp-boracay',
    'PLP Boracay',
    array['plp','pueblo-la-perla','plp-boracay']::text[],
    'pandora-rvw-314296438-20260820',
    'plp',
    'kywmbyekwgtghkhhurof',
    'prj_4W4GcwFJ3BPA4TnsEfHkmAm7HYeV',
    'https://pandora-plp-boracay-73b1afe9.vercel.app',
    'real_life',
    'active',
    'internal'
  )
  on conflict (project_key) do update
    set canonical_name = excluded.canonical_name,
        aliases = excluded.aliases,
        github_owner = excluded.github_owner,
        github_repository = excluded.github_repository,
        supabase_project_ref = excluded.supabase_project_ref,
        vercel_project_id = excluded.vercel_project_id,
        production_url = excluded.production_url,
        memory_namespace = excluded.memory_namespace,
        lifecycle_status = excluded.lifecycle_status,
        confidentiality = excluded.confidentiality,
        updated_at = now()
  returning id into v_project_id;

  insert into public.pandora_project_grants (
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
  ) values (
    'projectos-mcpmaster-production',
    v_project_id,
    'production',
    v_allowed_record_types,
    true,
    false,
    false,
    true,
    null,
    null
  )
  on conflict (principal_key, project_id, environment) do update
    set allowed_record_types = excluded.allowed_record_types,
        can_read = true,
        can_propose = false,
        can_approve = false,
        is_active = true,
        revoked_at = null,
        revocation_reason = null,
        updated_at = now();
end
$$;

commit;
