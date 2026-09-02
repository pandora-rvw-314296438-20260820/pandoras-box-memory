#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDGE = ROOT / "supabase/functions/pandora-projectos-planning-context/index.ts"
MIGRATION = ROOT / "supabase/migrations/20260903040500_memory_projectos_planning_nonce_v1.sql"
EVIDENCE = ROOT / "docs/capabilities/evidence/MEMORY_HARDENING_READINESS_2026-09-01.json"


def require(path: Path, markers: list[str]) -> None:
    source = path.read_text(encoding="utf-8")
    missing = [marker for marker in markers if marker not in source]
    if missing:
        raise SystemExit(f"{path.relative_to(ROOT)} missing required markers: {missing}")

require(EDGE, [
    'const PURPOSE = "projectos-planning-context-v1";',
    'const PRINCIPAL_KEY = "projectos-mcpmaster-production";',
    'const MAX_ITEMS = 6;',
    'const APPROVED_CANON = ["hard_canon", "soft_canon"]',
    'admin.rpc("pandora_integration_credential"',
    'admin.rpc("memory_claim_projectos_planning_nonce_v1"',
    '.from("pandora_projects")',
    '.from("pandora_project_grants")',
    '.eq("principal_key", PRINCIPAL_KEY)',
    '.eq("can_read", true)',
    '.from("memory_items")',
    '.select("id,title,source_summary,confidence,canon_status,memory_type,updated_at")',
    '.from("memory_retrieval_logs")',
    'used_for_routing: false',
    'raw_memory_body_returned: false',
    'raw_prompt_returned: false',
    'canonical_memory_written: false',
    'planning_request_replayed',
    'invalid_signature',
])
require(MIGRATION, [
    'create table if not exists private.memory_projectos_planning_nonces',
    'request_id uuid primary key',
    'create or replace function public.memory_claim_projectos_planning_nonce_v1',
    'on conflict (request_id) do nothing',
    'grant execute on function public.memory_claim_projectos_planning_nonce_v1',
])
require(EVIDENCE, [
    '"slug": "pandora-projectos-planning-context"',
    '"crossProjectGeneralizationAuthorized": false',
    '"sourceOnlyGate": true',
])
source = EDGE.read_text(encoding="utf-8")
for forbidden in (
    'request.headers.get("authorization")', '"authorization"', '.select("id,title,body',
    'canonical_records', 'memory_capture_candidates',
):
    if forbidden in source:
        raise SystemExit(f"planning Edge violates bounded HMAC-only read contract: {forbidden}")
print("ProjectOS HMAC planning context contract verified.")
