
begin;

update public.pandora_project_grants
set allowed_record_types=(
      select array_agg(distinct x order by x)
      from unnest(coalesce(allowed_record_types,'{}'::text[]) || array['outcome']::text[]) x
    ),
    updated_at=clock_timestamp()
where principal_key='pandora-mcpmaster-production'
  and project_id='7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
  and environment='production'
  and is_active=true
  and revoked_at is null
  and can_read=true
  and can_approve=false;

do $block$
declare
  v_allowed text[];
  v_can_approve boolean;
begin
  select allowed_record_types,can_approve
  into strict v_allowed,v_can_approve
  from public.pandora_project_grants
  where principal_key='pandora-mcpmaster-production'
    and project_id='7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
    and environment='production'
    and is_active=true
    and revoked_at is null
  order by updated_at desc
  limit 1;

  if not ('outcome'=any(v_allowed)) or v_can_approve is not false then
    raise exception 'PANDORA_MEMORY_GROWTH_OUTCOME_READ_COMPATIBILITY_FAILED';
  end if;
end
$block$;

commit;
