
begin;

do $block$
declare
  v_id uuid;
  v_allowed text[];
  v_can_read boolean;
  v_can_propose boolean;
  v_can_approve boolean;
begin
  select id, allowed_record_types, can_read, can_propose, can_approve
    into strict v_id, v_allowed, v_can_read, v_can_propose, v_can_approve
  from public.pandora_project_grants
  where id='11759bb1-2b9d-4b02-8c7a-6027df7999b2'::uuid
    and principal_key='pandora-mcpmaster-production'
    and project_id='7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
    and environment='production'
    and is_active=true
    and revoked_at is null
  for update;

  if v_can_read is distinct from true
     or v_can_propose is distinct from true
     or v_can_approve is distinct from false
     or not (v_allowed @> array['outcome','provider_performance']::text[]) then
    raise exception 'PANDORA_NATIVE_ADVISORY_LEARNING_READ_BASELINE_MISMATCH';
  end if;

  update public.pandora_project_grants
  set allowed_record_types = (
        select array_agg(distinct x order by x)
        from unnest(
          coalesce(allowed_record_types,'{}'::text[])
          || array['fact','pattern','procedure','failure_lesson']::text[]
        ) x
      ),
      updated_at = clock_timestamp()
  where id = v_id;
end
$block$;

do $block$
declare
  v_allowed text[];
  v_can_read boolean;
  v_can_propose boolean;
  v_can_approve boolean;
begin
  select allowed_record_types, can_read, can_propose, can_approve
    into strict v_allowed, v_can_read, v_can_propose, v_can_approve
  from public.pandora_project_grants
  where id='11759bb1-2b9d-4b02-8c7a-6027df7999b2'::uuid
    and principal_key='pandora-mcpmaster-production'
    and project_id='7c686cbd-d968-49d5-86cc-918f5e777bd2'::uuid
    and environment='production'
    and is_active=true
    and revoked_at is null;

  if not (v_allowed @> array[
       'fact','pattern','procedure','failure_lesson',
       'outcome','provider_performance'
     ]::text[])
     or v_can_read is distinct from true
     or v_can_propose is distinct from true
     or v_can_approve is distinct from false then
    raise exception 'PANDORA_NATIVE_ADVISORY_LEARNING_READ_COMPATIBILITY_FAILED';
  end if;
end
$block$;

commit;
