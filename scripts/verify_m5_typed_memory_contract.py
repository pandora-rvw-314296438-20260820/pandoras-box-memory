#!/usr/bin/env python3
"""Static and synthetic verification for M5-001 typed governed Memory."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260913032000_m5_typed_memory_records_v1.sql"

RECORD_TYPES = {
    "fact",
    "pattern",
    "policy",
    "procedure",
    "failure_lesson",
    "outcome",
    "provider_performance",
}
AUTHORITY_RULES = {
    "fact": {"verified_evidence", "provider_truth", "owner_statement"},
    "pattern": {"inference"},
    "policy": {"owner_policy"},
    "procedure": {"verified_outcome"},
    "failure_lesson": {"verified_outcome"},
    "outcome": {"runtime_truth", "provider_truth", "verified_evidence"},
    "provider_performance": {"measured_evidence"},
}

def require(text: str, token: str) -> None:
    if token not in text:
        raise AssertionError(f"missing contract token: {token}")

def accepted(record_type: str, authority: str, explicit_policy: bool) -> bool:
    if record_type not in RECORD_TYPES:
        return False
    if authority not in AUTHORITY_RULES[record_type]:
        return False
    if record_type == "pattern" and explicit_policy:
        return False
    if record_type == "policy" and not explicit_policy:
        return False
    return True

def synthetic_contract_tests() -> None:
    for record_type, authorities in AUTHORITY_RULES.items():
        for authority in authorities:
            assert accepted(record_type, authority, record_type == "policy")
    assert not accepted("pattern", "owner_policy", False)
    assert not accepted("pattern", "inference", True)
    assert not accepted("policy", "inference", True)
    assert not accepted("policy", "owner_policy", False)
    assert not accepted("procedure", "inference", False)
    assert not accepted("provider_performance", "provider_truth", False)
    assert not accepted("unknown", "verified_evidence", False)

def main() -> int:
    text = MIGRATION.read_text(encoding="utf-8")
    lower = text.lower()

    for forbidden in (
        "create table public.memory_items_v2",
        "create table public.memory_episodes",
        "create table public.memory_learning_v2",
        "create table public.playbooks",
    ):
        if forbidden in lower:
            raise AssertionError(f"parallel Memory authority introduced: {forbidden}")

    for record_type in sorted(RECORD_TYPES):
        require(text, f"'{record_type}'")

    for token in (
        "knowledge_schema_version",
        "authority_kind",
        "authority_ref",
        "provenance",
        "proposed_confidence",
        "proposed_effective_at",
        "superseded_by",
        "superseded_at",
        "supersession_reason",
        "explicit_policy_authorization",
        "memory_apply_reviewed_m5_record_v1",
        "memory_guard_m5_record_update_v1",
        "approved_for_append",
        "reviewDecisionId",
        "inference cannot become policy authorization",
        "M5 typed record semantics are immutable; append a successor instead",
        "v_successor.record_type is distinct from old.record_type",
        "v_successor.canon_status not in ('soft_canon','hard_canon')",
        "v_successor.superseded_by is not null",
        "proposed_provenance ? 'sourceType'",
        "proposed_provenance ? 'sourceLocator'",
        "proposed_provenance ? 'observedAt'",
    ):
        require(text, token)

    for pattern in (
        r"\bdelete\s+from\s+public\.memory_items\b",
        r"\btruncate\s+(table\s+)?public\.memory_items\b",
        r"\bdrop\s+table\s+(if\s+exists\s+)?public\.memory_items\b",
        r"\bupdate\s+public\.memory_items\s+set\s+knowledge_schema_version\b",
    ):
        if re.search(pattern, text, flags=re.I):
            raise AssertionError(f"destructive/backfill pattern found: {pattern}")

    policy_clause = re.search(
        r"when\s+'policy'\s+then(?P<body>.*?)when\s+'procedure'",
        text,
        flags=re.I | re.S,
    )
    if not policy_clause:
        raise AssertionError("policy authority clause missing")
    body = policy_clause.group("body").lower()
    for token in ("owner_policy", "explicit_policy_authorization"):
        if token not in body:
            raise AssertionError(f"policy gate missing: {token}")
    if re.search(r"authority_kind\s*=\s*'inference'", body):
        raise AssertionError("policy clause accepts inference")

    if not re.search(r"octet_length\(proposed_provenance::text\)\s*<=\s*16384", text):
        raise AssertionError("bounded proposal provenance check missing")

    synthetic_contract_tests()
    print("M5-001 typed Memory contract verification: PASS")
    return 0

if __name__ == "__main__":
    sys.exit(main())
