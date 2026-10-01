-- Register the generic verified-learning capability without activating it.
-- Applying this migration alone grants no principal access and does not enable writes.

insert into public.gateway_service_actions(
  service_key,
  action_key,
  capability_class,
  approval_required,
  enabled,
  provider_status,
  metadata
)
values (
  'pandora_memory',
  'verified_learning.propose',
  'write',
  false,
  false,
  'implemented',
  jsonb_build_object(
    'surface', 'machine_gateway',
    'canonicalWrite', false,
    'reviewRequired', true,
    'acceptedContract', 'pandora-continuous-execution-v2'
  )
)
on conflict(service_key, action_key) do update set
  capability_class = excluded.capability_class,
  approval_required = excluded.approval_required,
  enabled = false,
  provider_status = excluded.provider_status,
  metadata = excluded.metadata,
  updated_at = now();

-- Deliberately no gateway_grants mutation here.
