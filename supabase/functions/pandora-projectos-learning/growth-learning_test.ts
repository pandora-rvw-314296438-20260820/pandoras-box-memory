import {
  canonicalJson,
  GROWTH_MAX_BODY_BYTES,
  GROWTH_MEMORY_ENVIRONMENT,
  GROWTH_MEMORY_NAMESPACE,
  GROWTH_MEMORY_PRINCIPAL,
  GROWTH_MEMORY_PROJECT_ID,
  GROWTH_MEMORY_PROJECT_KEY,
  GROWTH_SOURCE_ORGANIZATION_ID,
  GROWTH_SOURCE_PROJECT_ID,
  GrowthLearningError,
  parseGrowthLearningPayload,
  validateGrowthLearningReceipt,
} from "./growth-learning.ts";

const assert = (condition: unknown, message: string) => {
  if (!condition) throw new Error(message);
};
const sha256 = async (value: string) => {
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(bytes))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};
const uuidFromHash = (hash: string) => {
  const bytes = Uint8Array.from(
    hash.slice(0, 32).match(/.{2}/g)!.map((part) => Number.parseInt(part, 16)),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes).map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${
    hex.slice(16, 20)
  }-${hex.slice(20)}`;
};

const authority: Record<string, string> = {
  verified_fact: "independent_verification",
  user_decision: "owner_decision",
  provider_evidence: "provider_readback",
  inference: "model_inference",
  assumption: "assumption",
  superseded: "supersession",
};
const sourceType: Record<string, string> = {
  verified_fact: "verification",
  user_decision: "owner",
  provider_evidence: "provider",
  inference: "model",
  assumption: "model",
  superseded: "verification",
};

type FixtureOptions = {
  learningId?: string;
  subjectKey?: string;
  claim?: string;
  confidence?: number;
  confidenceBasis?: string;
  sourceLocator?: string;
  sourceSha?: string | null;
  evidenceRefs?: Record<string, unknown>[];
};

const fixture = async (
  kind = "verified_fact",
  sourceOrganizationId = GROWTH_SOURCE_ORGANIZATION_ID,
  sourceProjectId = GROWTH_SOURCE_PROJECT_ID,
  options: FixtureOptions = {},
) => {
  const defaultEvidence = kind === "assumption" ? [] : [{
    type: "provider_receipt",
    ref: "provider:receipt:123",
    sha256: "c".repeat(64),
    artifact_class: "provider_readback",
    observed_at: "2026-09-29T00:00:00.000Z",
  }];
  const evidence = options.evidenceRefs ?? defaultEvidence;
  const supersession = kind === "superseded"
    ? {
      supersedes_ref: "growth:prior",
      reason: "Newer evidence replaced the prior claim.",
    }
    : null;
  const learning = {
    schema_version: "growth-learning-v1",
    learning_id: options.learningId ?? `learning-${kind}`,
    organization_id: sourceOrganizationId,
    project_id: sourceProjectId,
    subject_key: options.subjectKey ?? "facebook.campaign.learning",
    claim_kind: kind,
    statement: options.claim ??
      "A bounded growth learning candidate requires review.",
    observed_at: "2026-09-29T00:00:00.000Z",
    validity: {
      effective_at: "2026-09-29T00:00:00.000Z",
      review_due_at: "2026-10-29T00:00:00.000Z",
      expires_at: "2026-12-29T00:00:00.000Z",
    },
    confidence: options.confidence ?? (kind === "assumption" ? 0.4 : 0.9),
    confidence_basis: options.confidenceBasis ??
      "Bounded evidence classification retained from ProjectOS.",
    authority: { kind: authority[kind], ref: "authority:receipt:123" },
    provenance: {
      source_type: sourceType[kind],
      source_locator: options.sourceLocator ?? "provider:source:123",
      source_sha: options.sourceSha === undefined
        ? "d".repeat(40)
        : options.sourceSha,
      observed_at: "2026-09-29T00:00:00.000Z",
    },
    evidence_refs: evidence,
    supersession,
  };
  const contentHash = await sha256(JSON.stringify(learning));
  const candidate = {
    schema_version: "growth-learning-candidate-v1",
    learning_kind: "growth_learning_v1",
    source_event_id: learning.learning_id,
    organization_id: learning.organization_id,
    project_id: learning.project_id,
    subject_key: learning.subject_key,
    claim_kind: learning.claim_kind,
    claim: learning.statement,
    observed_at: learning.observed_at,
    effective_at: learning.validity.effective_at,
    review_due_at: learning.validity.review_due_at,
    expires_at: learning.validity.expires_at,
    confidence: learning.confidence,
    confidence_basis: learning.confidence_basis,
    authority_kind: learning.authority.kind,
    authority_ref: learning.authority.ref,
    provenance: learning.provenance,
    evidence_refs: learning.evidence_refs,
    supersession: learning.supersession,
    content_hash: contentHash,
    review_required: true,
    canonical_memory_written: false,
  };
  const binding = {
    schema_version: "growth-learning-outbox-binding-v1",
    source_scope: {
      organization_id: learning.organization_id,
      project_id: learning.project_id,
    },
    target_memory: {
      project_id: GROWTH_MEMORY_PROJECT_ID,
      project_key: GROWTH_MEMORY_PROJECT_KEY,
      namespace: GROWTH_MEMORY_NAMESPACE,
      principal_key: GROWTH_MEMORY_PRINCIPAL,
      environment: GROWTH_MEMORY_ENVIRONMENT,
    },
    candidate,
  };
  const contextHash = await sha256(canonicalJson(binding));
  const requestId = uuidFromHash(
    await sha256(`growth-learning-request-v1\n${contextHash}`),
  );
  return {
    schema_version: 1,
    product_key: "projectos",
    source_event_id: requestId,
    source_request_id: requestId,
    organization_id: learning.organization_id,
    intake_id: null,
    project_id: GROWTH_MEMORY_PROJECT_ID,
    project_key: GROWTH_MEMORY_PROJECT_KEY,
    tool: "facebook.growth_learning",
    risk: "write",
    outcome_status: "completed",
    duration_ms: 0,
    completed_at: learning.observed_at,
    context_status: "available",
    context_hash: contextHash,
    result_fingerprint: contentHash,
    error_fingerprint: null,
    privacy_policy: "metadata_only_v1",
    learning_kind: "growth_learning_v1",
    growth_learning: binding,
  };
};

const expectReject = async (payload: unknown, code: string) => {
  try {
    await parseGrowthLearningPayload(payload);
    throw new Error(`expected ${code}`);
  } catch (error) {
    assert(error instanceof GrowthLearningError, "unexpected error type");
    const growthError = error as GrowthLearningError;
    assert(
      growthError.code === code,
      `expected ${code}, received ${growthError.code}`,
    );
  }
};

Deno.test("accepts and preserves all six epistemic classes", async () => {
  for (
    const kind of [
      "verified_fact",
      "user_decision",
      "provider_evidence",
      "inference",
      "assumption",
      "superseded",
    ]
  ) {
    const payload = await fixture(kind);
    const parsed = await parseGrowthLearningPayload(payload);
    assert(parsed.candidate.claim_kind === kind, `lost class ${kind}`);
    assert(
      parsed.binding === payload.growth_learning,
      "binding identity changed",
    );
  }
});

Deno.test("binds exact PR804 source, target, content, context, and request identity", async () => {
  const payload = await fixture();
  const parsed = await parseGrowthLearningPayload(payload);
  assert(
    parsed.payload.source_event_id === payload.source_event_id,
    "request id changed",
  );
  assert(
    parsed.candidate.content_hash === payload.result_fingerprint,
    "content binding lost",
  );
  assert(
    (parsed.binding.target_memory as Record<string, unknown>).principal_key ===
      GROWTH_MEMORY_PRINCIPAL,
    "principal changed",
  );
});

Deno.test("rejects content tamper even when result fingerprint follows tamper", async () => {
  const payload = await fixture();
  payload.growth_learning.candidate.claim = "Tampered claim.";
  payload.result_fingerprint = payload.growth_learning.candidate.content_hash;
  await expectReject(payload, "growth_content_hash_mismatch");
});

Deno.test("rejects stale context hash and request identity", async () => {
  const payload = await fixture();
  payload.growth_learning.candidate.confidence_basis = "A changed basis.";
  const learning = payload.growth_learning.candidate;
  const normalized = {
    schema_version: "growth-learning-v1",
    learning_id: learning.source_event_id,
    organization_id: learning.organization_id,
    project_id: learning.project_id,
    subject_key: learning.subject_key,
    claim_kind: learning.claim_kind,
    statement: learning.claim,
    observed_at: learning.observed_at,
    validity: {
      effective_at: learning.effective_at,
      review_due_at: learning.review_due_at,
      expires_at: learning.expires_at,
    },
    confidence: learning.confidence,
    confidence_basis: learning.confidence_basis,
    authority: { kind: learning.authority_kind, ref: learning.authority_ref },
    provenance: learning.provenance,
    evidence_refs: learning.evidence_refs,
    supersession: learning.supersession,
  };
  learning.content_hash = await sha256(JSON.stringify(normalized));
  payload.result_fingerprint = learning.content_hash;
  await expectReject(payload, "growth_payload_binding_invalid");
});

Deno.test("rejects target principal substitution", async () => {
  const principal = await fixture();
  principal.growth_learning.target_memory.principal_key = "other-principal";
  await expectReject(principal, "growth_payload_binding_invalid");
});

Deno.test("rejects fully rehashed non-D004 source tenants", async () => {
  const wrongOrganization = await fixture(
    "verified_fact",
    "11111111-1111-4111-8111-111111111111",
    GROWTH_SOURCE_PROJECT_ID,
  );
  await expectReject(wrongOrganization, "growth_source_scope_denied");

  const wrongProject = await fixture(
    "verified_fact",
    GROWTH_SOURCE_ORGANIZATION_ID,
    "22222222-2222-4222-8222-222222222222",
  );
  await expectReject(wrongProject, "growth_source_scope_denied");
});

Deno.test("matches producer SHA, optional evidence, tiny numeric, and maximum boundaries", async () => {
  const uppercaseSha = await fixture(
    "verified_fact",
    GROWTH_SOURCE_ORGANIZATION_ID,
    GROWTH_SOURCE_PROJECT_ID,
    { sourceSha: "ABCDEF".repeat(6) + "ABCD" },
  );
  await parseGrowthLearningPayload(uppercaseSha);

  const nullShaMinimalEvidence = await fixture(
    "verified_fact",
    GROWTH_SOURCE_ORGANIZATION_ID,
    GROWTH_SOURCE_PROJECT_ID,
    {
      sourceSha: null,
      confidence: 1e-7,
      evidenceRefs: [{ type: "provider_receipt", ref: "provider:minimal" }],
    },
  );
  await parseGrowthLearningPayload(nullShaMinimalEvidence);

  const maxEvidence = Array.from({ length: 32 }, (_, index) => ({
    type: `e${index}`,
    ref: `${index}` + "r".repeat(1000 - String(index).length),
    sha256: "a".repeat(64),
    artifact_class: "a".repeat(256),
    observed_at: "2026-09-29T00:00:00.000Z",
  }));
  const maximum = await fixture(
    "verified_fact",
    GROWTH_SOURCE_ORGANIZATION_ID,
    GROWTH_SOURCE_PROJECT_ID,
    {
      learningId: "l".repeat(256),
      subjectKey: "s".repeat(256),
      claim: "c".repeat(1800),
      confidenceBasis: "b".repeat(1000),
      sourceLocator: "p".repeat(1000),
      sourceSha: "F".repeat(64),
      evidenceRefs: maxEvidence,
    },
  );
  await parseGrowthLearningPayload(maximum);
  const bytes = new TextEncoder().encode(JSON.stringify(maximum)).byteLength;
  assert(
    bytes > 32 * 1024,
    "maximum producer envelope did not exercise old cap",
  );
  assert(
    bytes <= GROWTH_MAX_BODY_BYTES,
    "maximum producer envelope exceeds cap",
  );
});

Deno.test("rejects assumption authority inflation and supersession loss", async () => {
  const assumption = await fixture("assumption");
  assumption.growth_learning.candidate.confidence = 0.8;
  await expectReject(assumption, "growth_confidence_invalid");

  const superseded = await fixture("superseded");
  superseded.growth_learning.candidate.supersession = null;
  await expectReject(superseded, "growth_supersession_invalid");
});

Deno.test("rejects extra fields at every contract boundary", async () => {
  const payload = await fixture();
  (payload as Record<string, unknown>).extra = true;
  await expectReject(payload, "growth_payload_shape_invalid");
});

Deno.test("rejects credential-like learning text", async () => {
  const payload = await fixture();
  payload.growth_learning.candidate.claim =
    "Authorization: Bearer redacted-but-shaped-value";
  await expectReject(payload, "growth_sensitive_material_rejected");
});

Deno.test("accepts only the exact PR804 pending-review receipt", async () => {
  const payload = await fixture();
  const parsed = await parseGrowthLearningPayload(payload);
  const receipt = {
    ok: true,
    status: "pending_review",
    source_event_id: payload.source_event_id,
    learning_id: parsed.candidate.source_event_id,
    content_hash: parsed.candidate.content_hash,
    candidate_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    review_item_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    review_required: true,
    canonical_memory_written: false,
    promotion_status: "not_promoted",
    retrieval_status: "not_retrievable",
    deduplicated: false,
  };
  validateGrowthLearningReceipt(parsed, receipt);
  receipt.retrieval_status = "retrievable";
  try {
    validateGrowthLearningReceipt(parsed, receipt);
    throw new Error("expected receipt rejection");
  } catch (error) {
    assert(error instanceof GrowthLearningError, "unexpected receipt error");
    assert(
      (error as GrowthLearningError).code === "growth_receipt_binding_invalid",
      "wrong receipt error",
    );
  }
});
