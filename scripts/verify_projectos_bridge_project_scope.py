#!/usr/bin/env python3
from pathlib import Path

bridge_path = Path("supabase/functions/pandora-projectos-bridge/index.ts")
route_path = Path("app/api/projectos/memory/search/route.ts")
migration_path = Path("supabase/migrations/20260907051800_memory_projectos_indexed_search_v1.sql")
bridge = bridge_path.read_text(encoding="utf-8")
route = route_path.read_text(encoding="utf-8")
migration = migration_path.read_text(encoding="utf-8")

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
    '"memory_projectos_search_scoped_v1"',
    'p_user_id: principal.memory_user_id',
    'p_namespace: namespace',
    'p_project_id: canonicalProjectId',
    'p_principal_key: PRINCIPAL_KEY',
    'p_environment: principal.environment',
    'p_terms: terms',
    'p_canon_statuses: canonStatuses',
    'project_id: canonicalProjectId',
    'project_key: canonicalProjectKey',
    'unscoped_components_omitted: true',
    '${namespace}:${canonicalProjectId}:${query}',
    'retrieval_mode: "project_scoped_keyword_recency"',
    'error: "project_identity_invalid"',
    'error: "project_not_allowed"',
    '"memory_context_pack_v2"',
    'p_project_id: canonicalProjectId',
    'p_principal_key: PRINCIPAL_KEY',
    'error: "context_pack_unavailable"',
    'error: "context_pack_invalid"',
    'packDegradation?.legacyUnscopedPackUsed === false',
    'latest_context_pack: contextPack',
    'open_loops: packOpenLoops',
]
for token in required:
    if token not in search and token not in bridge[:start]:
        raise SystemExit(f"missing project-isolation contract token: {token}")

forbidden = [
    '.from("memory_profiles")',
    '.from("memory_open_loops")',
    '.from("memory_events")',
    '.from("memory_context_packs")',
    '.ilike.',
]
for token in forbidden:
    if token in search:
        raise SystemExit(f"unsafe/unindexed retrieval remains in searchMemory: {token}")

for token in ['"project_id"', '"project_key"']:
    if token not in route:
        raise SystemExit(f"search route does not forward project identity: {token}")

strict_required = [
    '.select("project_id,allowed_record_types")',
    'const allowedRecordTypes = Array.isArray(projectGrant.allowed_record_types)',
    '"memory_projectos_search_scoped_v1"',
    'p_principal_key: PRINCIPAL_KEY',
    'p_environment: principal.environment',
    'memory_item_ids: approvedMemoryItemIds',
]
for token in strict_required:
    if token not in search:
        raise SystemExit(f"missing strict bridge eligibility token: {token}")

canon_start = bridge.index("const RETRIEVABLE_CANON_STATUSES")
canon_end = bridge.index("const APPROVED_CANON_STATUSES")
if '"draft"' in bridge[canon_start:canon_end]:
    raise SystemExit("ProjectOS bridge normal retrieval still permits draft canon status")

migration_required = [
    'memory_items_projectos_approved_search_fts_idx',
    'using gin',
    'to_tsvector(',
    'memory_projectos_search_scoped_v1',
    'security definer',
    "set search_path = pg_catalog, public",
    'g.principal_key = p_principal_key',
    'g.environment = p_environment',
    'g.can_read = true',
    'g.revoked_at is null',
    'm.user_id = p_user_id',
    'm.namespace::text = p_namespace',
    'm.project_id = p_project_id',
    'm.approved_by is not null',
    'm.approved_at is not null',
    'm.superseded_at is null',
    'm.revoked_at is null',
    'm.record_type = any(v_allowed)',
    "m.canon_status::text = any(p_canon_statuses)",
    '@@ v_tsquery',
    'to service_role',
]
for token in migration_required:
    if token not in migration:
        raise SystemExit(f"indexed ProjectOS search migration missing security/performance token: {token}")

if 'to authenticated' in migration.lower() or 'to anon' in migration.lower():
    raise SystemExit("indexed ProjectOS search RPC must remain service-role only")

if 'latest_context_pack: null' in search:
    raise SystemExit("ProjectOS bridge still omits governed MemoryContextPack v2")

print("PASS: ProjectOS bridge uses indexed exact-project search with independent project/environment/read-grant/user/approved-canon/current-head/record-type enforcement, exposes governed MemoryContextPack v2, and omits legacy unscoped component tables.")
