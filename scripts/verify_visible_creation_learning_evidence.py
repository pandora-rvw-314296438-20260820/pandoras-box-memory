from pathlib import Path
import hashlib

bridge_path = Path("supabase/functions/pandora-projectos-bridge/index.ts")
learning_path = Path("supabase/functions/pandora-projectos-learning/index.ts")
evidence_path = Path("docs/capabilities/evidence/VISIBLE_CREATION_MEMORY_EVIDENCE_CONTRACT_2026-09-02.md")
activation_path = Path("recovery/evidence/memory-evidence-intake-activation-release-manifest.md")

bridge = bridge_path.read_text(encoding="utf-8")
learning = learning_path.read_text(encoding="utf-8")
evidence = evidence_path.read_text(encoding="utf-8")
activation = activation_path.read_text(encoding="utf-8")

bridge_sha = hashlib.sha256(bridge_path.read_bytes()).hexdigest()
learning_sha = hashlib.sha256(learning_path.read_bytes()).hexdigest()

assert bridge_sha in evidence, "visible evidence doc is not bound to exact bridge bytes"
assert learning_sha in evidence, "visible evidence doc is not bound to exact learning bytes"
assert f"Candidate bridge raw SHA-256: `{bridge_sha}`" in activation, "activation manifest bridge digest drift"

for kind in (
    "verified_build",
    "verified_preview",
    "verified_publish",
    "verified_repair",
    "repeated_failure",
):
    assert kind in bridge, f"bridge taxonomy missing {kind}"
    assert kind in learning, f"learning intake missing {kind}"

for marker in (
    'const VISIBLE_LEARNING_KIND = "visible_creation_evidence_v1"',
    'const VISIBLE_MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2"',
    'const VISIBLE_MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box"',
    'const VISIBLE_PRINCIPAL_KEY = "projectos-mcpmaster-production"',
    'Object.keys(payload).some((key) => !VISIBLE_ALLOWED_KEYS.has(key))',
    'visibleEvidenceBasis',
    'expectedContextHash',
    'visible_evidence_hash_mismatch',
    '.from("pandora_projects")',
    '.from("pandora_project_grants")',
    '.eq("can_propose", true)',
    'raw_excerpt: null',
    'requires_review: true',
    'status: "pending"',
    'status: "pending_review"',
    'canonical_memory_written: false',
    'review_required: true',
    'source_event_id: sourceEventId',
    'privacy_policy: "metadata_only_v2_fail_closed"',
    'resultFingerprint !== visible.sourceSha256',
    'errorFingerprint !== visible.failureFingerprint',
):
    assert marker in learning, f"learning invariant missing: {marker}"

persist_start = learning.index("const persistVisibleEvidence")
persist_end = learning.index("\nDeno.serve(", persist_start)
persist = learning[persist_start:persist_end]
assert '.from("memory_items")' not in persist, "visible lifecycle intake must not write canonical memory_items"
assert "source_payload" not in persist, "visible lifecycle intake must not persist source payloads"
assert "public_error_summary" not in persist, "visible lifecycle intake must not persist provider/customer error summaries"
assert "raw_excerpt: null" in persist

# The automated path is intentionally metadata-only: IDs, enum-like values,
# counters, timestamps and digests. Raw customer/provider material is absent.
for forbidden in (
    "prompt_text",
    "intent_text",
    "source_chunk",
    "environment_value",
    "access_token",
    "refresh_token",
    "service_role_key",
):
    assert forbidden not in persist.lower(), f"forbidden raw field marker in visible intake: {forbidden}"

print("PASS: Visible Creation Memory lifecycle evidence is exact-source-bound, project-scoped, privacy-bounded, and review-gated")
