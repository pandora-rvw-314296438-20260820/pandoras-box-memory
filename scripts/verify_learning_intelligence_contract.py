#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs/capabilities/evidence/LEARNING_INTELLIGENCE_CONTRACT_2026-09-01.md"
LEARNING = ROOT / "supabase/functions/pandora-projectos-learning/index.ts"
CANON_GATE = ROOT / "scripts/check_memory_canon_promotion_gate.mjs"
EVIDENCE_GATE = ROOT / "scripts/check_memory_evidence_intake.mjs"

for path in (CONTRACT, LEARNING, CANON_GATE, EVIDENCE_GATE):
    if not path.is_file():
        raise SystemExit(f"required authority missing: {path.relative_to(ROOT)}")

contract = CONTRACT.read_text(encoding="utf-8")
learning = LEARNING.read_text(encoding="utf-8")
canon_gate = CANON_GATE.read_text(encoding="utf-8")
evidence_gate = EVIDENCE_GATE.read_text(encoding="utf-8")

required_contract = [
    "aa9294fe3d23f7dec515c4d559450422382d2768",
    "790c4160131c8f2fb99feea43bfca667200a9643",
    "metadata_only_v1",
    "No `memory_episodes` table is authorized now.",
    "No separate playbook table is authorized now.",
    "project_id + task_class + tool + risk + error_fingerprint",
    "`action_fingerprint` is a trajectory/attempt dimension",
    "seen_before=true does not imply proven_repair=true",
    "proven_repair=false",
    ">= 3 comparable",
    ">= 2 independently verified",
    "type-preserving governed persistence",
    "production_verified",
    "Cross-project retrieval is prohibited.",
    "correlation must not be labeled causation",
    "canonical_memory_written=false",
    "dpl_BEexxMqWK6LYmzvbGHb9emd8HAX4",
    "source-controlled only",
]
for marker in required_contract:
    if marker not in contract:
        raise SystemExit(f"learning-intelligence contract marker missing: {marker}")

required_learning = [
    'payload.privacy_policy !== "metadata_only_v1"',
    "raw_excerpt: null",
    "imported_raw_arguments: false",
    "imported_raw_results: false",
    "imported_raw_errors: false",
    "imported_personal_identifiers: false",
    "imported_secrets: false",
    "requires_review: true",
    'status: "pending"',
    '.from("memory_capture_candidates")',
    '.from("memory_review_queue_items")',
    "canonical_memory_written: false",
    "ROUTINE_AGGREGATE_WINDOW_HOURS = 6",
    "projectos_selective_review_v2",
    "projectos_routine_operation_summary",
    "scoring_version: \"projectos-learning-v2\"",
    "(risk === \"write\" && !resultFingerprint)",
]
for marker in required_learning:
    if marker not in learning:
        raise SystemExit(f"learning source safety marker missing: {marker}")

for forbidden in [
    "canonical_memory_written: true",
    "raw_excerpt: rawBody",
    "requires_review: false",
    "scoring_version: \"projectos-learning-v1\"",
    "usefulness_score: outcomeStatus === \"failed\" ? 0.9 : 0.72",
]:
    if forbidden in learning:
        raise SystemExit(f"unsafe learning source marker present: {forbidden}")

# The current learning service is an intake/review service, never a direct canon writer.
if '.from("memory_items")' in learning:
    raise SystemExit("learning intake must not write/read canonical memory_items directly")

# Existing governance authorities must remain present; the new contract extends them.
for source_name, source, markers in [
    (
        "canon gate",
        canon_gate,
        ["memory_items", "authenticated", "service_role", "draft"],
    ),
    (
        "evidence gate",
        evidence_gate,
        ["memory_capture_candidates", "memory_review_queue_items", "canonical_memory_written: false"],
    ),
]:
    for marker in markers:
        if marker not in source:
            raise SystemExit(f"{source_name} authority marker missing: {marker}")

# Reject obvious duplicate authorities rather than allowing a parallel Memory v2 path.
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT).as_posix().lower()
    for fragment in (
        "memory_episodes",
        "learning_gateway_v2",
        "memory_learning_v2",
        "playbook_gateway",
    ):
        if fragment in rel:
            raise SystemExit(f"prohibited duplicate learning authority path: {rel}")

# Do not weaken the frozen playbook thresholds in the contract text.
if ">= 2 comparable" in contract or ">= 1 independently verified" in contract:
    raise SystemExit("playbook threshold weakened below evidence-backed minimum")

print(
    "PASS: learning intelligence contract preserves privacy, review governance, "
    "project-scoped failure identity, proof/repair separation, and no-duplication invariants."
)
