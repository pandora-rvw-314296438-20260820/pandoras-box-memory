from pathlib import Path

root = Path(__file__).resolve().parents[1]
edge = (root / "supabase/functions/pandora-projectos-planning/index.ts").read_text()
migration = (root / "supabase/migrations/20260903032500_projectos_planning_memory_nonce_v1.sql").read_text()

required = [
    'const PURPOSE = "projectos-planning-context-v1"',
    'x-pandora-planning-timestamp',
    'x-pandora-planning-nonce',
    'x-pandora-planning-signature',
    'const purposeKey = await hmacHex(baseSecret, PURPOSE)',
    'memory_claim_planning_nonce_v1',
    'replay_detected',
    'MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2"',
    'MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box"',
    '.in("canon_status", ["hard_canon","soft_canon"])',
    'raw_query_persisted: false',
    'memory_retrieval_logs',
    'response_digest',
    'raw_source_fence',
    'prompt_transcript',
    'config_dump',
    'raw_source_dump',
]
for marker in required:
    assert marker in edge, marker

for forbidden in ['x-pandora-vercel-oidc', 'authorization: `Bearer', 'request.headers.get("authorization")']:
    assert forbidden not in edge, forbidden

assert 'nonce uuid primary key' in migration
assert "auth.role() <> 'service_role'" in migration
assert 'on conflict (nonce) do nothing' in migration
assert 'grant execute on function public.memory_claim_planning_nonce_v1' in migration
print('planning memory HMAC contract: PASS')
