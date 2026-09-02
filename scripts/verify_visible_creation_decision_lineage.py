#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EDGE = ROOT / "supabase/functions/pandora-projectos-decision-lineage/index.ts"
MIGRATION = ROOT / "supabase/migrations/20260902081500_memory_decision_usefulness_v1.sql"
EVIDENCE = ROOT / "docs/capabilities/evidence/MEMORY_HARDENING_READINESS_2026-09-01.json"


def require(path: Path, markers: list[str]) -> None:
    source = path.read_text(encoding="utf-8")
    missing = [marker for marker in markers if marker not in source]
    if missing:
        raise SystemExit(f"{path.relative_to(ROOT)} missing required markers: {missing}")


require(EDGE, [
    'const INTEGRATION_KEY = "projectos-learning-bridge";',
    'const INFLUENCE_KIND = "visible_creation_decision_influence_v1";',
    'const OUTCOME_KIND = "visible_creation_decision_outcome_v1";',
    'const MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";',
    'const MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";',
    '"projectos-learning-v1"',
    '"visible-creation-decision-influence-v1"',
    '"visible-creation-decision-outcome-v1"',
    'admin.rpc("pandora_integration_credential"',
    'admin.rpc("memory_bind_decision_context_v1"',
    'admin.rpc("memory_record_decision_outcome_v1"',
    'approved_memory_item_ids: itemIds',
    'canonical_memory_written: false',
    'invalid_signature',
    'decision_influence_hash_mismatch',
    'decision_outcome_hash_mismatch',
])

require(MIGRATION, [
    'create or replace function public.memory_bind_decision_context_v1',
    'retrieval contains non-approved memory reference',
    'memory decision lineage conflict',
    'create or replace function public.memory_record_decision_outcome_v1',
    "'decision_memory_outcome'",
    "'canonicalPolicyChanged', false",
    'on conflict (retrieval_log_id, memory_item_id, source_run_id)',
])

require(EVIDENCE, [
    '"slug": "pandora-projectos-decision-lineage"',
    '"crossProjectGeneralizationAuthorized": false',
    '"sourceOnlyGate": true',
])

source = EDGE.read_text(encoding="utf-8")
for forbidden in ("raw_excerpt", "memory_capture_candidates", "memory_items).copy():
    if forbidden in source:
        raise SystemExit(f"decision-lineage Edge must not become a parallel Memory store: {forbidden}")

print("Visible Creation decision-lineage contract verified.")
