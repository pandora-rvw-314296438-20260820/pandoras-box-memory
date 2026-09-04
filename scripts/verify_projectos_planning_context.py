#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDGE = ROOT / "supabase/functions/pandora-projectos-planning-context/index.ts"
source = EDGE.read_text(encoding="utf-8")

required = [
    'const INTEGRATION_KEY = "projectos-learning-bridge";',
    'const PRINCIPAL_KEY = "projectos-mcpmaster-production";',
    'const PURPOSE = "projectos-planning-context-v2";',
    'const MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";',
    '"projectos-planning-query-v2"',
    '"projectos-planning-context-response-v2"',
    'admin.rpc("pandora_integration_credential"',
    'admin.rpc("memory_context_pack_v2"',
    '.in("canon_status",CANON)',
    'query_hash:queryHash',
    'query_persisted:false',
    'canonical_memory_written:false',
    'x-pandora-timestamp',
    'x-pandora-signature',
    'constantTimeEqual',
]
missing = [marker for marker in required if marker not in source]
if missing:
    raise SystemExit(f"planning-context Edge missing required markers: {missing}")

for forbidden in (
    "raw_excerpt",
    "memory_capture_candidates",
    'canon_status:"hard_canon"',
    'request.headers.get("authorization")',
):
    if forbidden.lower() in source.lower():
        raise SystemExit(f"planning-context Edge violates read-only/HMAC boundary: {forbidden}")

if "query_persisted:false" not in source or "query_hash:queryHash" not in source:
    raise SystemExit("raw planning query must never be persisted")

print("ProjectOS HMAC planning-context contract verified.")
