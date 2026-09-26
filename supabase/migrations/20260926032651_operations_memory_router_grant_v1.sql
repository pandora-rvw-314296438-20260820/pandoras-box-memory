
-- Narrow Operations activation grant.
-- Does not grant approval, canon promotion, new principal identity, namespace, or project access.
do $$
declare
  g public.pandora_project_grants%rowtype;
begin
  select * into strict g
  from public.pandora_project_grants
  where id='11759bb1-2b9d-4b02-8c7a-6027df7999b2'::uuid
    and principal_key='pandora-mcpmaster-production'
    and project_id='7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
    and environment='production'
  for update;

  if g.is_active is distinct from true
     or g.revoked_at is not null
     or g.can_read is distinct from true
     or g.can_propose is distinct from true
     or g.can_approve is distinct from false
     or not (g.allowed_record_types @> array[
       'project_identity','repository','architecture','decision','roadmap',
       'governance_rule','authentication_model','integration_state',
       'deployment_rule','branding_requirement','source_of_truth'
     ]::text[])
  then
    raise exception 'OPS_MEMORY_GRANT_BASELINE_MISMATCH';
  end if;

  update public.pandora_project_grants
  set allowed_record_types = (
    select array_agg(distinct x order by x)
    from unnest(allowed_record_types || array['model_outcome','provider_performance']::text[]) x
  ),
  updated_at=clock_timestamp()
  where id=g.id;
end $$;
