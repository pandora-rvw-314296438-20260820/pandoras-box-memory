
#!/usr/bin/env python3
from pathlib import Path

bridge_path = Path("supabase/functions/pandora-projectos-bridge/index.ts")
route_path = Path("app/api/projectos/memory/search/route.ts")
bridge = bridge_path.read_text(encoding="utf-8")
route = route_path.read_text(encoding="utf-8")

start = bridge.index("const searchMemory = async (")
end = bridge.index("const EVIDENCE_PROOF_STAGES")
search = bridge[start:end]

required = [
    'const PROJECT_SEARCH_KEY_PATTERN',
    '.from("pandora_projects")',
    '.eq("project_key", projectKey)',
    '.from("pandora_project_grants")',
    '.eq("can_read", true)',
    '.is("revoked_at", null)',
    '.from("memory_items")',
    '.eq("project_id", canonicalProjectId)',
    'project_id: canonicalProjectId',
    'project_key: canonicalProjectKey',
    'unscoped_components_omitted: true',
    '`${namespace}:${canonicalProjectId}:${query}`',
    'retrieval_mode: "project_scoped_keyword_recency"',
    'error: "project_identity_invalid"',
    'error: "project_not_allowed"',
]
for token in required:
    if token not in search and token not in bridge[:start]:
        raise SystemExit(f"missing project-isolation contract token: {token}")

forbidden = [
    '.from("memory_profiles")',
    '.from("memory_open_loops")',
    '.from("memory_events")',
    '.from("memory_context_packs")',
]
for token in forbidden:
    if token in search:
        raise SystemExit(f"unscoped retrieval remains in searchMemory: {token}")

for token in ['"project_id"', '"project_key"']:
    if token not in route:
        raise SystemExit(f"search route does not forward project identity: {token}")

strict_required = [
    '.select("project_id,allowed_record_types")',
    'const allowedRecordTypes = Array.isArray(projectGrant.allowed_record_types)',
    '.in("record_type", allowedRecordTypes)',
    '.is("superseded_at", null)',
    'memory_item_ids: approvedMemoryItemIds',
]
for token in strict_required:
    if token not in search:
        raise SystemExit(f"missing strict bridge eligibility token: {token}")

canon_start = bridge.index("const RETRIEVABLE_CANON_STATUSES")
canon_end = bridge.index("const APPROVED_CANON_STATUSES")
if '"draft"' in bridge[canon_start:canon_end]:
    raise SystemExit("ProjectOS bridge normal retrieval still permits draft canon status")

item_start = search.index('let itemQuery = supabase')
item_end = search.index('const itemsResult = await itemQuery')
item_query = search[item_start:item_end]
for token in ['.is("superseded_at", null)', '.is("revoked_at", null)', '.in("record_type", allowedRecordTypes)']:
    if token not in item_query:
        raise SystemExit(f"memory item query missing strict eligibility predicate: {token}")

print("PASS: ProjectOS bridge search is exact-project scoped, approved-only, grant-type restricted, current-head only, and omits unscoped component tables.")
