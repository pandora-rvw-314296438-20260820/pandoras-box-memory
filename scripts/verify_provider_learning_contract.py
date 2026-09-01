from pathlib import Path

migration = Path('supabase/migrations/20260901184935_pandora_provider_learning_v1.sql')
assert migration.exists(), 'provider-learning migration source is missing'
s = migration.read_text(encoding='utf-8')
required = [
    'memory_ingest_model_outcome_candidate_v1',
    "canonicalMemoryWritten',false",
    'memory_execute_approved_provider_learning_v1',
    "canonicalPolicyChanged',false",
    'memory_propose_provider_performance_v1',
    "v_sample_count<3 or v_verified_pass<2",
    'memory_propose_routing_playbook_v1',
    "productionRoutingChanged',false",
    'memory_provider_performance_state_v1',
    'memory_get_provider_performance_v1',
    'memory_record_provider_guidance_feedback_v1',
    'memory_log_model_call_metadata_v1',
    "revoke all on function public.memory_ingest_model_outcome_candidate_v1",
    'to service_role;',
    "record_type='provider_performance'",
    'm.project_id=p_project_id',
    "rawProviderContentStored',false",
]
for needle in required:
    assert needle in s, f'missing provider-learning invariant: {needle}'
for forbidden in ['raw_prompt', 'raw_response', 'authorization_header', 'provider_api_key']:
    assert forbidden not in s.lower(), f'forbidden raw provider field in migration: {forbidden}'
print('provider-learning source contract: PASS')
