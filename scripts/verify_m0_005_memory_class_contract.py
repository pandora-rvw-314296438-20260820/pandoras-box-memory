#!/usr/bin/env python3
"""Executable contract test for M0-005 Memory class semantics."""
from pathlib import Path
import json, sys

ROOT = Path(__file__).resolve().parents[1]
JSON = ROOT / "docs/architecture/pandora-memory-class-contract-v1.json"
DOC = ROOT / "docs/architecture/M0_005_MEMORY_CLASS_CONTRACT.md"
EXPECTED = {"fact","pattern","policy","procedure","failure_lesson","outcome","provider_performance"}
NON_POLICY = EXPECTED - {"policy"}

def main() -> int:
    c = json.loads(JSON.read_text(encoding="utf-8"))
    d = DOC.read_text(encoding="utf-8")
    assert c["schemaVersion"] == "pandora-memory-class-contract-v1"
    assert c["status"] == "frozen"
    assert set(c["classes"]) == EXPECTED
    inv = c["globalInvariants"]
    for key in (
        "canonicalAuthorityRemainsMemoryItems","rawEventsAreNotCanonicalMemory",
        "promotionRequiresHighSignalEvidence","appendOnlyCorrectionHistory",
        "predictionNeverGrantsAuthority","patternNeverGrantsAuthority",
        "modelOutputNeverGrantsAuthority","priorSuccessNeverGrantsAuthority",
        "authorizationSourcesAreExplicitCurrentInstructionOrActiveExplicitStandingPolicy",
        "confidenceNeverUpgradesAuthority","supersededHistoryIsPreserved",
        "retrievalMustRespectProjectNamespacePrincipalAndGrantScope","staleOrRevokedPolicyNeverAuthorizes",
    ):
        assert inv[key] is True, key
    assert set(c["semanticSources"]) == {"observation","inference","owner_decision","authoritative_policy"}
    assert c["semanticSources"]["observation"]["mayAuthorize"] is False
    assert c["semanticSources"]["inference"]["mayAuthorize"] is False
    required = {
        "record_type","provenance","evidence_refs","observed_at","effective_at","confidence",
        "authority_kind","authority_ref","promotion_basis","correction_of","superseded_by",
        "superseded_at","supersession_reason",
    }
    assert set(c["requiredRecordFields"]) == required
    class_fields = {
        "definition","semanticSource","provenance","evidenceLinkage","timestamp","confidence",
        "authorityLevel","supersessionBehavior","correctionBehavior","promotionCriteria",
        "retrievalSemantics","authorizationEffect",
    }
    for name, spec in c["classes"].items():
        assert class_fields <= set(spec), (name, class_fields-set(spec))
    for name in NON_POLICY:
        assert c["classes"][name]["authorizationEffect"] == "none", name
    policy = c["classes"]["policy"]
    assert policy["authorizationEffect"] == "may_authorize_only_when_exact_scope_is_validated"
    assert "explicit" in policy["promotionCriteria"].lower()
    assert "scope" in policy["retrievalSemantics"].lower()
    assert set(c["forbiddenSilentEscalations"]) == {
        "pattern_to_policy","prediction_to_policy","model_output_to_policy","prior_success_to_policy",
        "procedure_to_policy","provider_performance_to_policy",
    }
    rr=c["retrievalRules"]
    for key in (
        "boundedTaskRelevantRetrieval","grantScopedRetrieval","excludeRevokedAndSupersededByDefault",
        "includeHistoryForAuditConflictAndCorrection","preferVerifiedCurrentAuthority",
        "similarityNeverDeterminesAuthority","retrieveFailureLessonsBeforeSimilarHighRiskWork",
        "policiesRetrievedSeparatelyFromAdvisoryMemory",
    ):
        assert rr[key] is True, key
    assert c["rawEventPlane"]["separateFromCanonicalMemory"] is True
    assert c["rawEventPlane"]["promotionRequired"] is True
    for phrase in (
        "must never silently become authorization",
        "Confidence never upgrades authority",
        "explicit current user instruction",
        "active explicit standing policy",
        "raw execution events and polling remain separate",
    ):
        assert phrase.lower() in d.lower(), phrase
    print("M0-005 Memory class contract verification: PASS")
    return 0

if __name__ == "__main__":
    sys.exit(main())
