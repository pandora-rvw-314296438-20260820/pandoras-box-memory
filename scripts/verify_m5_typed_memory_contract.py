#!/usr/bin/env python3
"""Static and synthetic verification for M5-001 typed governed Memory."""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260913032000_m5_typed_memory_records_v1.sql"
M0_CONTRACT = ROOT / "docs/architecture/pandora-memory-class-contract-v1.json"

def require(text: str, token: str) -> None:
    if token not in text:
        raise AssertionError(f"missing contract token: {token}")

def load_contract():
    data = json.loads(M0_CONTRACT.read_text(encoding="utf-8"))
    assert data["status"] == "frozen"
    assert data["schemaVersion"] == "pandora-memory-class-contract-v1"
    return data

def accepted(record_type: str, authority: str, semantic_source: str, explicit_policy: bool, contract: dict) -> bool:
    classes = contract["classes"]
    if record_type not in classes:
        return False
    spec = classes[record_type]
    if authority not in set(spec["authorityLevel"]):
        return False
    if semantic_source not in set(spec["semanticSource"]):
        return False
    if record_type == "policy":
        if not explicit_policy:
            return False
        if authority == "explicit_current_user_instruction" and semantic_source != "owner_decision":
            return False
        if authority == "active_explicit_standing_policy" and semantic_source != "authoritative_policy":
            return False
        return True
    return not explicit_policy

def declared_plpgsql_variables(text: str) -> set[str]:
    return set(re.findall(r"(?mi)^\s*(v_[a-z0-9_]+)\s+(?:uuid|text|boolean|numeric|timestamptz|public\.[a-z0-9_]+%rowtype)\s*;", text))

def referenced_row_variables(text: str) -> set[str]:
    return set(re.findall(r"\b(v_[a-z0-9_]+)\.", text, flags=re.I))

def main() -> int:
    text = MIGRATION.read_text(encoding="utf-8")
    lower = text.lower()
    contract = load_contract()
    record_types = set(contract["classes"])
    required_fields = set(contract["requiredRecordFields"])

    assert record_types == {
        "fact","pattern","policy","procedure","failure_lesson","outcome","provider_performance"
    }
    assert contract["globalInvariants"]["canonicalAuthorityRemainsMemoryItems"] is True
    assert contract["globalInvariants"]["rawEventsAreNotCanonicalMemory"] is True
    assert contract["globalInvariants"]["predictionNeverGrantsAuthority"] is True
    assert contract["globalInvariants"]["patternNeverGrantsAuthority"] is True
    assert contract["globalInvariants"]["modelOutputNeverGrantsAuthority"] is True
    assert contract["globalInvariants"]["priorSuccessNeverGrantsAuthority"] is True
    assert contract["globalInvariants"]["confidenceNeverUpgradesAuthority"] is True

    for forbidden in (
        "create table public.memory_items_v2",
        "create table public.memory_episodes",
        "create table public.memory_learning_v2",
        "create table public.playbooks",
    ):
        if forbidden in lower:
            raise AssertionError(f"parallel Memory authority introduced: {forbidden}")

    for record_type in sorted(record_types):
        require(text, f"'{record_type}'")

    canonical_column_tokens = {
        "record_type": "record_type",
        "provenance": "add column if not exists provenance jsonb",
        "evidence_refs": "add column if not exists evidence_refs jsonb",
        "observed_at": "add column if not exists observed_at timestamptz",
        "effective_at": "effective_at",
        "confidence": "confidence",
        "authority_kind": "add column if not exists authority_kind text",
        "authority_ref": "add column if not exists authority_ref text",
        "promotion_basis": "add column if not exists promotion_basis text",
        "correction_of": "add column if not exists correction_of uuid",
        "superseded_by": "superseded_by",
        "superseded_at": "superseded_at",
        "supersession_reason": "add column if not exists supersession_reason text",
    }
    assert required_fields == set(canonical_column_tokens)
    for token in canonical_column_tokens.values():
        require(lower, token.lower())

    for token in (
        "proposed_evidence_refs",
        "proposed_observed_at",
        "proposed_promotion_basis",
        "proposed_correction_of",
        "jsonb_array_length(proposed_evidence_refs) > 0",
        "proposed_provenance ? 'semanticsource'",
        "memory_apply_reviewed_m5_record_v1",
        "memory_guard_m5_record_update_v1",
        "approved_for_append",
        "reviewdecisionid",
        "explicit_current_user_instruction",
        "active_explicit_standing_policy",
        "requires_exact_runtime_scope_validity_revocation_validation",
        "m5 typed record semantics are immutable; append a successor instead",
        "v_successor.record_type is distinct from old.record_type",
        "v_successor.memory_type is distinct from old.memory_type",
        "v_successor.canon_status not in ('soft_canon','hard_canon')",
        "v_successor.superseded_by is not null",
        "v_successor.correction_of is not null",
    ):
        require(lower, token.lower())

    if "owner_policy" in lower:
        raise AssertionError("legacy owner_policy authority remains; policy authority must use frozen M0-005 levels")
    if "v_succcessor" in lower:
        raise AssertionError("misspelled successor identifier survives")

    declared = declared_plpgsql_variables(lower)
    referenced = referenced_row_variables(lower)
    undeclared = sorted(referenced - declared)
    if undeclared:
        raise AssertionError(f"undeclared PL/pgSQL row variable(s): {undeclared}")

    for pattern in (
        r"\bdelete\s+from\s+public\.memory_items\b",
        r"\btruncate\s+(table\s+)?public\.memory_items\b",
        r"\bdrop\s+table\s+(if\s+exists\s+)?public\.memory_items\b",
        r"\bupdate\s+public\.memory_items\s+set\s+knowledge_schema_version\b",
    ):
        if re.search(pattern, text, flags=re.I):
            raise AssertionError(f"destructive/backfill pattern found: {pattern}")

    for escalation in contract["forbiddenSilentEscalations"]:
        source = escalation.removesuffix("_to_policy")
        if source in contract["classes"]:
            assert contract["classes"][source]["authorizationEffect"] == "none"

    for record_type, spec in contract["classes"].items():
        for authority in spec["authorityLevel"]:
            for semantic_source in spec["semanticSource"]:
                should_accept = record_type != "policy" or (
                    (authority == "explicit_current_user_instruction" and semantic_source == "owner_decision")
                    or (authority == "active_explicit_standing_policy" and semantic_source == "authoritative_policy")
                )
                got = accepted(record_type, authority, semantic_source, record_type == "policy", contract)
                assert got == should_accept, (record_type, authority, semantic_source, got, should_accept)

    assert not accepted("pattern","inference","inference",True,contract)
    assert not accepted("policy","inference","owner_decision",True,contract)
    assert not accepted("procedure","verified_outcome","observation",True,contract)
    assert not accepted("unknown","verified_evidence","observation",False,contract)

    if not re.search(r"octet_length\(proposed_provenance::text\)\s*<=\s*16384", text):
        raise AssertionError("bounded proposal provenance check missing")
    if not re.search(r"octet_length\(proposed_evidence_refs::text\)\s*<=\s*32768", text):
        raise AssertionError("bounded evidence references check missing")

    dollar_tags = re.findall(r"\$(?:function)?\$", text)
    if len(dollar_tags) % 2 != 0:
        raise AssertionError("unbalanced dollar-quoted function body")

    print("M5-001 typed Memory contract verification: PASS")
    return 0

if __name__ == "__main__":
    sys.exit(main())
