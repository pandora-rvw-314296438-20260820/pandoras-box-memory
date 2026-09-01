#!/usr/bin/env python3
from pathlib import Path
import sys

bridge_path = Path("supabase/functions/pandora-projectos-bridge/index.ts")
route_path = Path("app/api/projectos/memory/search/route.ts")
bridge = bridge_path.read_text(encoding="utf-8")
route = route_path.read_text(encoding="utf-8")

start = bridge.index("const searchMemory = async (")
end = bridge.index("const EVIDENCE_PROOF_STAGES")
search = bridge[start:end]
fragment_start = bridge.index("const PROJECT_SEARCH_KEY_PATTERN")
format_fragment = bridge[fragment_start:end]

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

args = sys.argv[1:]
if args:
    if len(args) != 2 or args[0] != "--emit-format-fragment":
        raise SystemExit("usage: verify_projectos_bridge_project_scope.py [--emit-format-fragment PATH]")
    Path(args[1]).write_text(format_fragment, encoding="utf-8")

print("PASS: ProjectOS bridge search is exact-project scoped and omits unscoped component tables.")
