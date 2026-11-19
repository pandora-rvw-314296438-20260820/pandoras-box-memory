export const GROWTH_LEARNING_KIND = "growth_learning_v1";
export const GROWTH_BINDING_SCHEMA = "growth-learning-outbox-binding-v1";
export const GROWTH_MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";
export const GROWTH_MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";
export const GROWTH_MEMORY_NAMESPACE = "real_life";
export const GROWTH_MEMORY_PRINCIPAL = "projectos-mcpmaster-production";
export const GROWTH_MEMORY_ENVIRONMENT = "production";
export const GROWTH_SOURCE_ORGANIZATION_ID =
  "2270b266-59da-4c39-bfd9-9f8d08352af0";
export const GROWTH_SOURCE_PROJECT_ID = "ee282126-3f61-4058-8c92-2fedbfcecf1f";
export const GROWTH_MAX_BODY_BYTES = 128 * 1024;

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPAQUE = /^[A-Za-z0-9][A-Za-z0-9._:@/-]{0,255}$/;
const SHA256 = /^[0-9a-f]{64}$/;
const TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const CREDENTIAL_LIKE =
  /(authorization\s*[:=]\s*(bearer|basic)|github_pat_|gh[pousr]_[a-z0-9_]{16,}|sb_secret_|AIza[a-z0-9_-]{20,}|sk-[a-z0-9_-]{16,}|-----BEGIN [^-]*PRIVATE KEY)/i;

const CLAIM_KINDS = new Set([
  "verified_fact",
  "user_decision",
  "provider_evidence",
  "inference",
  "assumption",
  "superseded",
]);
const AUTHORITY_BY_KIND: Record<string, Set<string>> = {
  verified_fact: new Set([
    "provider_readback",
    "independent_verification",
    "authoritative_record",
  ]),
  user_decision: new Set(["owner_decision", "authorized_user_decision"]),
  provider_evidence: new Set(["provider_readback"]),
  inference: new Set(["model_inference"]),
  assumption: new Set(["assumption"]),
  superseded: new Set(["supersession"]),
};

type JsonRecord = Record<string, unknown>;

export class GrowthLearningError extends Error {
  constructor(public code: string) {
    super(code);
    this.name = "GrowthLearningError";
  }
}

const fail = (code: string): never => {
  throw new GrowthLearningError(code);
};
const record = (value: unknown): JsonRecord =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : fail("growth_object_required");
const exactKeys = (
  value: JsonRecord,
  expected: readonly string[],
  code: string,
) => {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (
    actual.length !== wanted.length ||
    actual.some((key, index) => key !== wanted[index])
  ) fail(code);
};
const text = (value: unknown, min: number, max: number, code: string) => {
  if (typeof value !== "string") fail(code);
  const normalized = (value as string).trim();
  if (normalized.length < min || normalized.length > max) fail(code);
  return normalized;
};
const uuid = (value: unknown, code: string) => {
  const normalized = text(value, 36, 36, code);
  if (!UUID.test(normalized)) fail(code);
  return normalized.toLowerCase();
};
const opaque = (value: unknown, code: string) => {
  const normalized = text(value, 1, 256, code);
  if (!OPAQUE.test(normalized)) fail(code);
  return normalized;
};
const timestamp = (value: unknown, code: string) => {
  const normalized = text(value, 24, 24, code);
  if (
    !TIMESTAMP.test(normalized) ||
    !Number.isFinite(Date.parse(normalized)) ||
    new Date(normalized).toISOString() !== normalized
  ) fail(code);
  return normalized;
};

export const canonicalJson = (value: unknown): string => {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const object = value as JsonRecord;
    return `{${
      Object.keys(object).sort().map((key) =>
        `${JSON.stringify(key)}:${canonicalJson(object[key])}`
      ).join(",")
    }}`;
  }
  return JSON.stringify(value);
};

const sha256Hex = async (value: string) => {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const uuidFromHash = (hash: string) => {
  const bytes = Uint8Array.from(
    hash.slice(0, 32).match(/.{2}/g)!.map((part) => Number.parseInt(part, 16)),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join("-");
};

const normalizeProvenance = (value: unknown) => {
  const input = record(value);
  exactKeys(
    input,
    ["source_type", "source_locator", "source_sha", "observed_at"],
    "growth_provenance_shape_invalid",
  );
  if (
    !["provider", "document", "repository", "owner", "verification", "model"]
      .includes(String(input.source_type))
  ) fail("growth_provenance_type_invalid");
  const sourceSha = input.source_sha === null
    ? null
    : text(input.source_sha, 7, 64, "growth_provenance_sha_invalid");
  if (sourceSha !== null && !/^[0-9a-f]{7,64}$/i.test(sourceSha)) {
    fail("growth_provenance_sha_invalid");
  }
  return {
    source_type: input.source_type,
    source_locator: text(
      input.source_locator,
      1,
      1000,
      "growth_provenance_locator_invalid",
    ),
    source_sha: sourceSha,
    observed_at: timestamp(
      input.observed_at,
      "growth_provenance_observed_at_invalid",
    ),
  };
};

const normalizeEvidence = (value: unknown) => {
  if (!Array.isArray(value) || value.length > 32) {
    fail("growth_evidence_invalid");
  }
  return (value as unknown[]).map((entry: unknown) => {
    const input = record(entry);
    const allowed = ["type", "ref", "sha256", "artifact_class", "observed_at"];
    if (
      Object.keys(input).some((key) => !allowed.includes(key)) ||
      !("type" in input) || !("ref" in input)
    ) fail("growth_evidence_ref_invalid");
    const result: JsonRecord = {
      type: opaque(input.type, "growth_evidence_type_invalid"),
      ref: text(input.ref, 1, 1000, "growth_evidence_ref_invalid"),
    };
    if ("sha256" in input) {
      const digest = text(input.sha256, 64, 64, "growth_evidence_sha_invalid")
        .toLowerCase();
      if (!SHA256.test(digest)) fail("growth_evidence_sha_invalid");
      result.sha256 = digest;
    }
    if ("artifact_class" in input) {
      result.artifact_class = opaque(
        input.artifact_class,
        "growth_artifact_class_invalid",
      );
    }
    if ("observed_at" in input) {
      result.observed_at = timestamp(
        input.observed_at,
        "growth_evidence_observed_at_invalid",
      );
    }
    return result;
  });
};

export type ParsedGrowthLearning = {
  payload: JsonRecord;
  binding: JsonRecord;
  candidate: JsonRecord;
};

export const parseGrowthLearningPayload = async (
  value: unknown,
): Promise<ParsedGrowthLearning> => {
  const payload = record(value);
  exactKeys(payload, [
    "schema_version",
    "product_key",
    "source_event_id",
    "source_request_id",
    "organization_id",
    "intake_id",
    "project_id",
    "project_key",
    "tool",
    "risk",
    "outcome_status",
    "duration_ms",
    "completed_at",
    "context_status",
    "context_hash",
    "result_fingerprint",
    "error_fingerprint",
    "privacy_policy",
    "learning_kind",
    "growth_learning",
  ], "growth_payload_shape_invalid");

  const binding = record(payload.growth_learning);
  exactKeys(
    binding,
    ["schema_version", "source_scope", "target_memory", "candidate"],
    "growth_binding_shape_invalid",
  );
  // Phase A stores the exact bounded learning contract for review. It is not a
  // transport for raw provider/customer payloads or credential-like material.
  const decodedStrings: string[] = [];
  const collectDecodedStrings = (input: unknown): void => {
    if (typeof input === "string") {
      decodedStrings.push(input);
    } else if (Array.isArray(input)) {
      input.forEach(collectDecodedStrings);
    } else if (input !== null && typeof input === "object") {
      for (const [key, child] of Object.entries(input as JsonRecord)) {
        decodedStrings.push(key);
        collectDecodedStrings(child);
      }
    }
  };
  collectDecodedStrings(binding);
  if (decodedStrings.some((entry) => CREDENTIAL_LIKE.test(entry))) {
    fail("growth_sensitive_material_rejected");
  }
  const sourceScope = record(binding.source_scope);
  exactKeys(
    sourceScope,
    ["organization_id", "project_id"],
    "growth_source_scope_invalid",
  );
  const target = record(binding.target_memory);
  exactKeys(target, [
    "project_id",
    "project_key",
    "namespace",
    "principal_key",
    "environment",
  ], "growth_target_shape_invalid");
  const candidate = record(binding.candidate);
  exactKeys(candidate, [
    "schema_version",
    "learning_kind",
    "source_event_id",
    "organization_id",
    "project_id",
    "subject_key",
    "claim_kind",
    "claim",
    "observed_at",
    "effective_at",
    "review_due_at",
    "expires_at",
    "confidence",
    "confidence_basis",
    "authority_kind",
    "authority_ref",
    "provenance",
    "evidence_refs",
    "supersession",
    "content_hash",
    "review_required",
    "canonical_memory_written",
  ], "growth_candidate_shape_invalid");

  const sourceOrg = uuid(
    sourceScope.organization_id,
    "growth_source_scope_invalid",
  );
  const sourceProject = uuid(
    sourceScope.project_id,
    "growth_source_scope_invalid",
  );
  if (
    sourceOrg !== GROWTH_SOURCE_ORGANIZATION_ID ||
    sourceProject !== GROWTH_SOURCE_PROJECT_ID
  ) fail("growth_source_scope_denied");
  const claimKind = String(candidate.claim_kind);
  if (!CLAIM_KINDS.has(claimKind)) fail("growth_claim_kind_invalid");
  if (!AUTHORITY_BY_KIND[claimKind].has(String(candidate.authority_kind))) {
    fail("growth_authority_invalid");
  }
  const provenance = normalizeProvenance(candidate.provenance);
  const evidenceRefs = normalizeEvidence(candidate.evidence_refs);
  if (
    ["verified_fact", "provider_evidence", "superseded"].includes(claimKind) &&
    evidenceRefs.length === 0
  ) fail("growth_evidence_required");
  if (
    claimKind === "provider_evidence" && provenance.source_type !== "provider"
  ) {
    fail("growth_provider_provenance_required");
  }
  if (
    claimKind === "user_decision" &&
    !["owner", "document"].includes(String(provenance.source_type))
  ) fail("growth_decision_provenance_invalid");
  if (claimKind === "inference" && provenance.source_type !== "model") {
    fail("growth_inference_provenance_invalid");
  }
  if (claimKind === "assumption" && evidenceRefs.length !== 0) {
    fail("growth_assumption_evidence_invalid");
  }

  const confidence = candidate.confidence;
  if (
    typeof confidence !== "number" || !Number.isFinite(confidence) ||
    confidence < 0 || confidence > 1 ||
    (claimKind === "assumption" && confidence > 0.5)
  ) fail("growth_confidence_invalid");
  const effectiveAt = timestamp(
    candidate.effective_at,
    "growth_effective_at_invalid",
  );
  const reviewDueAt = timestamp(
    candidate.review_due_at,
    "growth_review_due_at_invalid",
  );
  const expiresAt = candidate.expires_at === null
    ? null
    : timestamp(candidate.expires_at, "growth_expires_at_invalid");
  if (
    effectiveAt > reviewDueAt || (expiresAt !== null && reviewDueAt > expiresAt)
  ) {
    fail("growth_validity_order_invalid");
  }
  let supersession: JsonRecord | null = null;
  if (claimKind === "superseded") {
    if (candidate.supersession === null) fail("growth_supersession_invalid");
    supersession = record(candidate.supersession);
    exactKeys(
      supersession,
      ["supersedes_ref", "reason"],
      "growth_supersession_invalid",
    );
    supersession = {
      supersedes_ref: opaque(
        supersession.supersedes_ref,
        "growth_supersession_invalid",
      ),
      reason: text(supersession.reason, 3, 1000, "growth_supersession_invalid"),
    };
  } else if (candidate.supersession !== null) {
    fail("growth_supersession_invalid");
  }

  const normalizedLearning = {
    schema_version: "growth-learning-v1",
    learning_id: opaque(
      candidate.source_event_id,
      "growth_learning_id_invalid",
    ),
    organization_id: uuid(
      candidate.organization_id,
      "growth_candidate_scope_invalid",
    ),
    project_id: uuid(candidate.project_id, "growth_candidate_scope_invalid"),
    subject_key: opaque(candidate.subject_key, "growth_subject_invalid"),
    claim_kind: claimKind,
    statement: text(candidate.claim, 1, 1800, "growth_claim_invalid"),
    observed_at: timestamp(candidate.observed_at, "growth_observed_at_invalid"),
    validity: {
      effective_at: effectiveAt,
      review_due_at: reviewDueAt,
      expires_at: expiresAt,
    },
    confidence,
    confidence_basis: text(
      candidate.confidence_basis,
      1,
      1000,
      "growth_confidence_basis_invalid",
    ),
    authority: {
      kind: candidate.authority_kind,
      ref: opaque(candidate.authority_ref, "growth_authority_ref_invalid"),
    },
    provenance,
    evidence_refs: evidenceRefs,
    supersession,
  };
  const expectedContentHash = await sha256Hex(
    JSON.stringify(normalizedLearning),
  );
  const contentHash = text(
    candidate.content_hash,
    64,
    64,
    "growth_content_hash_invalid",
  ).toLowerCase();
  if (!SHA256.test(contentHash) || expectedContentHash !== contentHash) {
    fail("growth_content_hash_mismatch");
  }
  const normalizedCandidate = {
    schema_version: "growth-learning-candidate-v1",
    learning_kind: GROWTH_LEARNING_KIND,
    source_event_id: normalizedLearning.learning_id,
    organization_id: normalizedLearning.organization_id,
    project_id: normalizedLearning.project_id,
    subject_key: normalizedLearning.subject_key,
    claim_kind: claimKind,
    claim: normalizedLearning.statement,
    observed_at: normalizedLearning.observed_at,
    effective_at: effectiveAt,
    review_due_at: reviewDueAt,
    expires_at: expiresAt,
    confidence,
    confidence_basis: normalizedLearning.confidence_basis,
    authority_kind: normalizedLearning.authority.kind,
    authority_ref: normalizedLearning.authority.ref,
    provenance,
    evidence_refs: evidenceRefs,
    supersession,
    content_hash: contentHash,
    review_required: true,
    canonical_memory_written: false,
  };
  if (canonicalJson(normalizedCandidate) !== canonicalJson(candidate)) {
    fail("growth_candidate_normalization_mismatch");
  }

  const expectedContextHash = await sha256Hex(canonicalJson(binding));
  const expectedRequestId = uuidFromHash(
    await sha256Hex(`growth-learning-request-v1\n${expectedContextHash}`),
  );
  if (
    binding.schema_version !== GROWTH_BINDING_SCHEMA ||
    sourceOrg !== normalizedLearning.organization_id ||
    sourceProject !== normalizedLearning.project_id ||
    target.project_id !== GROWTH_MEMORY_PROJECT_ID ||
    target.project_key !== GROWTH_MEMORY_PROJECT_KEY ||
    target.namespace !== GROWTH_MEMORY_NAMESPACE ||
    target.principal_key !== GROWTH_MEMORY_PRINCIPAL ||
    target.environment !== GROWTH_MEMORY_ENVIRONMENT ||
    payload.schema_version !== 1 || payload.product_key !== "projectos" ||
    payload.source_event_id !== expectedRequestId ||
    payload.source_request_id !== expectedRequestId ||
    payload.organization_id !== sourceOrg || payload.intake_id !== null ||
    payload.project_id !== GROWTH_MEMORY_PROJECT_ID ||
    payload.project_key !== GROWTH_MEMORY_PROJECT_KEY ||
    payload.tool !== "facebook.growth_learning" || payload.risk !== "write" ||
    payload.outcome_status !== "completed" || payload.duration_ms !== 0 ||
    payload.completed_at !== normalizedLearning.observed_at ||
    payload.context_status !== "available" ||
    payload.context_hash !== expectedContextHash ||
    payload.result_fingerprint !== contentHash ||
    payload.error_fingerprint !== null ||
    payload.privacy_policy !== "metadata_only_v1" ||
    payload.learning_kind !== GROWTH_LEARNING_KIND
  ) fail("growth_payload_binding_invalid");

  return { payload, binding, candidate: normalizedCandidate };
};

export const validateGrowthLearningReceipt = (
  parsed: ParsedGrowthLearning,
  value: unknown,
): JsonRecord => {
  const receipt = record(value);
  if (receipt.status === "already_reviewed") {
    exactKeys(receipt, [
      "ok",
      "status",
      "source_event_id",
      "learning_id",
      "content_hash",
      "candidate_id",
      "review_item_id",
      "review_status",
      "deduplicated",
    ], "growth_receipt_shape_invalid");
    const reviewStatus = String(receipt.review_status ?? "");
    if (
      receipt.ok !== true ||
      receipt.source_event_id !== parsed.payload.source_event_id ||
      receipt.learning_id !== parsed.candidate.source_event_id ||
      receipt.content_hash !== parsed.candidate.content_hash ||
      !UUID.test(String(receipt.candidate_id ?? "")) ||
      !UUID.test(String(receipt.review_item_id ?? "")) ||
      ![
        "needs_clarification",
        "blocked_namespace_mismatch",
        "blocked_sensitive",
        "blocked_policy",
        "approved_for_append",
        "rejected",
        "archived",
      ].includes(reviewStatus) ||
      receipt.deduplicated !== true
    ) fail("growth_receipt_binding_invalid");
    return receipt;
  }

  exactKeys(receipt, [
    "ok",
    "status",
    "source_event_id",
    "learning_id",
    "content_hash",
    "candidate_id",
    "review_item_id",
    "review_required",
    "canonical_memory_written",
    "promotion_status",
    "retrieval_status",
    "deduplicated",
  ], "growth_receipt_shape_invalid");
  if (
    receipt.ok !== true || receipt.status !== "pending_review" ||
    receipt.source_event_id !== parsed.payload.source_event_id ||
    receipt.learning_id !== parsed.candidate.source_event_id ||
    receipt.content_hash !== parsed.candidate.content_hash ||
    !UUID.test(String(receipt.candidate_id ?? "")) ||
    !UUID.test(String(receipt.review_item_id ?? "")) ||
    receipt.review_required !== true ||
    receipt.canonical_memory_written !== false ||
    receipt.promotion_status !== "not_promoted" ||
    receipt.retrieval_status !== "not_retrievable" ||
    typeof receipt.deduplicated !== "boolean"
  ) fail("growth_receipt_binding_invalid");
  return receipt;
};
