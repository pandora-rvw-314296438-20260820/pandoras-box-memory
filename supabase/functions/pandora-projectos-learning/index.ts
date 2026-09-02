import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.9";

const INTEGRATION_KEY = "projectos-learning-bridge";
const PRODUCT_KEY = "projectos";
const NAMESPACE = "real_life";
const SOURCE = "projectos-post-task";
const MAX_BODY_BYTES = 32 * 1024;
const MAX_CLOCK_SKEW_MS = 5 * 60_000;
const ROUTINE_AGGREGATE_WINDOW_HOURS = 6;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH_PATTERN = /^[0-9a-f]{64}$/i;
const SAFE_TOKEN_PATTERN = /^[A-Za-z0-9._:/-]{1,180}$/;
const OUTCOME_STATUSES = new Set(["completed", "failed"]);
const RISKS = new Set(["read", "write", "destructive"]);
const CONTEXT_STATUSES = new Set(["available", "empty"]);
const VISIBLE_LEARNING_KIND = "visible_creation_evidence_v1";
const VISIBLE_SOURCE = "projectos-visible-creation";
const VISIBLE_MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";
const VISIBLE_MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";
const VISIBLE_PRINCIPAL_KEY = "projectos-mcpmaster-production";
const VISIBLE_EVIDENCE_KINDS = new Set([
  "verified_build",
  "verified_preview",
  "verified_publish",
  "verified_repair",
  "repeated_failure",
]);
const VISIBLE_EVIDENCE_PROOF_STAGES: Record<string, Set<string>> = {
  verified_build: new Set(["tested", "deployed", "production_verified"]),
  verified_preview: new Set(["deployed", "production_verified"]),
  verified_publish: new Set(["production_verified"]),
  verified_repair: new Set(["tested", "deployed", "production_verified"]),
  repeated_failure: new Set(["tested", "deployed", "production_verified"]),
};
const VISIBLE_ALLOWED_KEYS = new Set([
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
  "evidence_kind",
  "proof_stage",
  "visible_project_id",
  "project_version_id",
  "build_job_id",
  "verification_run_id",
  "deployment_id",
  "publish_receipt_id",
  "source_sha256",
  "artifact_sha256",
  "failure_fingerprint",
  "recurrence_count",
  "repair_action_hash",
]);

type JsonRecord = Record<string, unknown>;

const json = (status: number, body: JsonRecord) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });

const record = (value: unknown): JsonRecord =>
  value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};

const requiredText = (value: unknown, max = 180): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > max) return null;
  return normalized;
};

const optionalText = (value: unknown, max = 180): string | null => {
  if (value === null || value === undefined || value === "") return null;
  return requiredText(value, max);
};

const safeToken = (value: unknown, max = 180): string | null => {
  const normalized = requiredText(value, max);
  return normalized && SAFE_TOKEN_PATTERN.test(normalized) ? normalized : null;
};

const uuid = (value: unknown): string | null => {
  const normalized = requiredText(value, 64);
  return normalized && UUID_PATTERN.test(normalized)
    ? normalized.toLowerCase()
    : null;
};

const optionalUuid = (value: unknown): string | null => {
  if (value === null || value === undefined || value === "") return null;
  return uuid(value);
};

const hash = (value: unknown): string | null => {
  const normalized = optionalText(value, 64);
  return normalized && HASH_PATTERN.test(normalized)
    ? normalized.toLowerCase()
    : null;
};

const integer = (value: unknown, min: number, max: number): number | null => {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) return null;
  return parsed;
};

const isoTimestamp = (value: unknown): string | null => {
  const normalized = requiredText(value, 64);
  if (!normalized) return null;
  const parsed = Date.parse(normalized);
  if (!Number.isFinite(parsed)) return null;
  return normalized;
};

const constantTimeEqual = (left: string, right: string): boolean => {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) {
    mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return mismatch === 0;
};

const hmacHex = async (secret: string, value: string): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(value),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const signatureBasis = (input: {
  sourceEventId: string;
  sourceRequestId: string;
  organizationId: string;
  intakeId: string | null;
  projectId: string | null;
  projectKey: string;
  tool: string;
  risk: string;
  outcomeStatus: string;
  durationMs: number;
  completedAt: string;
  contextStatus: string;
  contextHash: string;
  resultFingerprint: string | null;
  errorFingerprint: string | null;
}): string =>
  [
    "projectos-learning-v1",
    input.sourceEventId,
    input.sourceRequestId,
    input.organizationId,
    input.intakeId ?? "",
    input.projectId ?? "",
    input.projectKey,
    input.tool,
    input.risk,
    input.outcomeStatus,
    String(input.durationMs),
    input.completedAt,
    input.contextStatus,
    input.contextHash,
    input.resultFingerprint ?? "",
    input.errorFingerprint ?? "",
  ].join("\n");

type VisibleEvidence = {
  evidenceKind: string;
  proofStage: string;
  visibleProjectId: string;
  projectVersionId: string | null;
  buildJobId: string | null;
  verificationRunId: string | null;
  deploymentId: string | null;
  publishReceiptId: string | null;
  sourceSha256: string | null;
  artifactSha256: string | null;
  failureFingerprint: string | null;
  recurrenceCount: number | null;
  repairActionHash: string | null;
};

const visibleEvidenceBasis = (value: VisibleEvidence): string =>
  [
    "visible-creation-evidence-v1",
    value.evidenceKind,
    value.proofStage,
    value.visibleProjectId,
    value.projectVersionId ?? "",
    value.buildJobId ?? "",
    value.verificationRunId ?? "",
    value.deploymentId ?? "",
    value.publishReceiptId ?? "",
    value.sourceSha256 ?? "",
    value.artifactSha256 ?? "",
    value.failureFingerprint ?? "",
    value.recurrenceCount === null ? "" : String(value.recurrenceCount),
    value.repairActionHash ?? "",
  ].join("\n");

const parseVisibleEvidence = (payload: JsonRecord): VisibleEvidence | null => {
  if (Object.keys(payload).some((key) => !VISIBLE_ALLOWED_KEYS.has(key))) {
    return null;
  }
  if (payload.learning_kind !== VISIBLE_LEARNING_KIND) return null;
  const evidenceKind = safeToken(payload.evidence_kind, 64);
  const proofStage = safeToken(payload.proof_stage, 64);
  const visibleProjectId = uuid(payload.visible_project_id);
  const projectVersionId = optionalUuid(payload.project_version_id);
  const buildJobId = optionalUuid(payload.build_job_id);
  const verificationRunId = optionalUuid(payload.verification_run_id);
  const deploymentId = optionalUuid(payload.deployment_id);
  const publishReceiptId = optionalUuid(payload.publish_receipt_id);
  const sourceSha256 = hash(payload.source_sha256);
  const artifactSha256 = hash(payload.artifact_sha256);
  const failureFingerprint = hash(payload.failure_fingerprint);
  const recurrenceCount =
    payload.recurrence_count === null || payload.recurrence_count === undefined
      ? null
      : integer(payload.recurrence_count, 2, 1_000_000);
  const repairActionHash = hash(payload.repair_action_hash);
  if (
    !evidenceKind || !VISIBLE_EVIDENCE_KINDS.has(evidenceKind) || !proofStage ||
    !VISIBLE_EVIDENCE_PROOF_STAGES[evidenceKind]?.has(proofStage) ||
    !visibleProjectId
  ) return null;
  const value: VisibleEvidence = {
    evidenceKind,
    proofStage,
    visibleProjectId,
    projectVersionId,
    buildJobId,
    verificationRunId,
    deploymentId,
    publishReceiptId,
    sourceSha256,
    artifactSha256,
    failureFingerprint,
    recurrenceCount,
    repairActionHash,
  };
  if (
    evidenceKind === "verified_build" &&
    (!buildJobId || !projectVersionId || !verificationRunId || !sourceSha256 ||
      !artifactSha256)
  ) return null;
  if (
    evidenceKind === "verified_preview" &&
    (!projectVersionId || !verificationRunId || !deploymentId ||
      !sourceSha256 || !artifactSha256)
  ) return null;
  if (
    evidenceKind === "verified_publish" &&
    (!projectVersionId || !verificationRunId || !deploymentId ||
      !publishReceiptId || !sourceSha256 || !artifactSha256)
  ) return null;
  if (
    evidenceKind === "verified_repair" &&
    (!buildJobId || !projectVersionId || !verificationRunId || !sourceSha256 ||
      !artifactSha256 || !failureFingerprint || !repairActionHash)
  ) return null;
  if (
    evidenceKind === "repeated_failure" &&
    (!buildJobId || !failureFingerprint || recurrenceCount === null)
  ) return null;
  return value;
};

const visibleEvidenceRefs = (
  value: VisibleEvidence,
  sourceEventId: string,
): string[] => {
  const refs = [
    `source_event:${sourceEventId}`,
    `visible_project:${value.visibleProjectId}`,
  ];
  if (value.buildJobId) refs.push(`build_job:${value.buildJobId}`);
  if (value.projectVersionId) {
    refs.push(`project_version:${value.projectVersionId}`);
  }
  if (value.verificationRunId) {
    refs.push(`verification_run:${value.verificationRunId}`);
  }
  if (value.deploymentId) refs.push(`deployment:${value.deploymentId}`);
  if (value.publishReceiptId) {
    refs.push(`publish_receipt:${value.publishReceiptId}`);
  }
  if (value.sourceSha256) refs.push(`source_sha256:${value.sourceSha256}`);
  if (value.artifactSha256) {
    refs.push(`artifact_sha256:${value.artifactSha256}`);
  }
  if (value.failureFingerprint) {
    refs.push(`failure_fingerprint:${value.failureFingerprint}`);
  }
  if (value.repairActionHash) {
    refs.push(`repair_action:${value.repairActionHash}`);
  }
  return refs;
};

const persistVisibleEvidence = async (
  admin: ReturnType<typeof createClient<any>>,
  memoryUserId: string,
  sourceEventId: string,
  contextHash: string,
  completedAt: string,
  value: VisibleEvidence,
): Promise<Response> => {
  const { data: project, error: projectError } = await admin
    .from("pandora_projects")
    .select("id,project_key,memory_namespace,lifecycle_status")
    .eq("id", VISIBLE_MEMORY_PROJECT_ID)
    .eq("project_key", VISIBLE_MEMORY_PROJECT_KEY)
    .eq("memory_namespace", NAMESPACE)
    .eq("lifecycle_status", "active")
    .maybeSingle();
  if (projectError) {
    return json(500, { ok: false, error: "visible_project_lookup_failed" });
  }
  if (!project?.id) {
    return json(403, { ok: false, error: "visible_project_not_allowed" });
  }

  const { data: grant, error: grantError } = await admin
    .from("pandora_project_grants")
    .select("project_id")
    .eq("principal_key", VISIBLE_PRINCIPAL_KEY)
    .eq("project_id", VISIBLE_MEMORY_PROJECT_ID)
    .eq("environment", "production")
    .eq("is_active", true)
    .eq("can_propose", true)
    .is("revoked_at", null)
    .maybeSingle();
  if (grantError) {
    return json(500, {
      ok: false,
      error: "visible_project_grant_lookup_failed",
    });
  }
  if (!grant?.project_id) {
    return json(403, { ok: false, error: "visible_project_not_allowed" });
  }

  const sourceRef =
    `visible-creation:${value.visibleProjectId}:${value.evidenceKind}:${sourceEventId}`;
  const title = value.evidenceKind === "repeated_failure"
    ? "Visible Creation repeated failure evidence"
    : `Visible Creation ${value.evidenceKind.replaceAll("_", " ")} evidence`;
  const summary = value.evidenceKind === "repeated_failure"
    ? `A bounded failure fingerprint recurred ${value.recurrenceCount} times for Visible Creation project ${value.visibleProjectId}. Review is required before any durable learning promotion.`
    : `Verified ${
      value.evidenceKind.replaceAll("_", " ")
    } evidence for Visible Creation project ${value.visibleProjectId} is bound to authoritative identifiers and cryptographic digests. Review is required before any durable learning promotion.`;
  const refs = visibleEvidenceRefs(value, sourceEventId);
  const metadata = {
    schema_version: 1,
    intake_kind: VISIBLE_LEARNING_KIND,
    evidence_kind: value.evidenceKind,
    proof_stage: value.proofStage,
    visible_project_id: value.visibleProjectId,
    project_version_id: value.projectVersionId,
    build_job_id: value.buildJobId,
    verification_run_id: value.verificationRunId,
    deployment_id: value.deploymentId,
    publish_receipt_id: value.publishReceiptId,
    source_sha256: value.sourceSha256,
    artifact_sha256: value.artifactSha256,
    failure_fingerprint: value.failureFingerprint,
    recurrence_count: value.recurrenceCount,
    repair_action_hash: value.repairActionHash,
    fingerprint: contextHash,
    privacy_policy: "metadata_only_v2_fail_closed",
    imported_raw_arguments: false,
    imported_raw_results: false,
    imported_raw_errors: false,
    canonical_memory_written: false,
  };

  const { data: existing, error: existingError } = await admin
    .from("memory_capture_candidates")
    .select("id,metadata")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("source", VISIBLE_SOURCE)
    .eq("source_ref", sourceRef)
    .maybeSingle();
  if (existingError) {
    return json(500, { ok: false, error: "visible_candidate_lookup_failed" });
  }
  if (existing?.id && record(existing.metadata).fingerprint !== contextHash) {
    return json(409, { ok: false, error: "idempotency_conflict" });
  }

  let candidateId = existing?.id ?? null;
  let candidateCreated = false;
  if (!candidateId) {
    const sourceRunIds = value.verificationRunId
      ? [value.verificationRunId]
      : [sourceEventId];
    const { data: inserted, error: insertError } = await admin
      .from("memory_capture_candidates")
      .insert({
        user_id: memoryUserId,
        namespace: NAMESPACE,
        source: VISIBLE_SOURCE,
        source_ref: sourceRef,
        raw_excerpt: null,
        redacted_excerpt: summary,
        memory_type: value.evidenceKind === "repeated_failure"
          ? "risk_signal"
          : "business_fact",
        title,
        summary,
        importance: value.evidenceKind === "verified_publish" ? 9 : 8,
        sensitivity: "low",
        confidence: 0.98,
        should_capture: true,
        requires_review: true,
        status: "pending",
        reason:
          "Visible Creation lifecycle evidence is review-gated and cannot become canonical without an authenticated human decision.",
        people: [],
        projects: [VISIBLE_MEMORY_PROJECT_KEY],
        risks: value.evidenceKind === "repeated_failure"
          ? ["repeated_failure_requires_review"]
          : [],
        tags: [
          "projectos",
          "visible_creation",
          value.evidenceKind,
          value.proofStage,
        ],
        metadata,
        usefulness_score: 0.9,
        confidence_score: 0.98,
        freshness_score: 1,
        retrieval_weight: 0.9,
        stale_status: "active",
        scoring_version: "visible-creation-evidence-v1",
        scored_at: completedAt,
        project_id: VISIBLE_MEMORY_PROJECT_ID,
        record_type: "memory_candidate",
        source_run_ids: sourceRunIds,
        evidence_refs: refs,
        evidence_window_start: completedAt,
        evidence_window_end: completedAt,
        sample_count: value.recurrenceCount ?? 1,
        verification_pass_count: value.evidenceKind === "repeated_failure"
          ? 0
          : 1,
        negative_outcome_count: value.evidenceKind === "repeated_failure"
          ? value.recurrenceCount
          : 0,
        execution_status: value.evidenceKind === "repeated_failure"
          ? "failed"
          : "completed",
        verification_status: value.evidenceKind === "repeated_failure"
          ? "FAIL"
          : "PASS",
        downstream_outcome_status: value.evidenceKind === "repeated_failure"\n          ? "failed"\n          : "succeeded",
        source_system: "pandora-visible-creation",
      })
      .select("id")
      .maybeSingle();
    if (insertError || !inserted?.id) {
      return json(500, { ok: false, error: "visible_candidate_insert_failed" });
    }
    candidateId = inserted.id;
    candidateCreated = true;
  }

  const { data: existingReview, error: reviewLookupError } = await admin
    .from("memory_review_queue_items")
    .select("id")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("candidate_type", "projectos_outcome")
    .eq("source_ref", sourceRef)
    .maybeSingle();
  if (reviewLookupError) {
    return json(500, { ok: false, error: "visible_review_lookup_failed" });
  }
  let reviewItemId = existingReview?.id ?? null;
  let reviewCreated = false;
  if (!reviewItemId) {
    const { data: insertedReview, error: reviewInsertError } = await admin
      .from("memory_review_queue_items")
      .insert({
        user_id: memoryUserId,
        namespace: NAMESPACE,
        status: "pending_review",
        candidate_type: "projectos_outcome",
        normalized_text: summary,
        evidence_snapshot: {
          hasEvidence: true,
          sourceRef,
          candidateId,
          evidenceKind: value.evidenceKind,
          proofStage: value.proofStage,
          refs,
        },
        sensitivity_snapshot: {
          classification: "low",
          containsSecrets: false,
          containsPersonalData: false,
          containsRawArguments: false,
          containsRawResults: false,
          containsRawErrors: false,
        },
        namespace_snapshot: {
          sourceNamespace: NAMESPACE,
          targetNamespace: NAMESPACE,
          namespaceMatch: true,
        },
        source_metadata: {
          source: VISIBLE_SOURCE,
          sourceRef,
          projectId: VISIBLE_MEMORY_PROJECT_ID,
          projectKey: VISIBLE_MEMORY_PROJECT_KEY,
          visibleProjectId: value.visibleProjectId,
          evidenceKind: value.evidenceKind,
        },
        audit_metadata: {
          schemaVersion: 1,
          candidateId,
          appendOnly: true,
          reviewRequired: true,
          fingerprint: contextHash,
        },
        append_only: true,
        proposed_operation: "append",
        requires_review: true,
        source_ref: sourceRef,
        request_hash: contextHash,
        fingerprint: contextHash,
        persistence_execution_metadata: {},
      })
      .select("id")
      .maybeSingle();
    if (reviewInsertError || !insertedReview?.id) {
      return json(500, { ok: false, error: "visible_review_insert_failed" });
    }
    reviewItemId = insertedReview.id;
    reviewCreated = true;
  }

  return json(candidateCreated || reviewCreated ? 202 : 200, {
    ok: true,
    status: "pending_review",
    candidate_id: candidateId,
    review_item_id: reviewItemId,
    evidence_kind: value.evidenceKind,
    proof_stage: value.proofStage,
    visible_project_id: value.visibleProjectId,
    deduplicated: !(candidateCreated || reviewCreated),
    canonical_memory_written: false,
    privacy_policy: "metadata_only_v2_fail_closed",
  });
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return json(405, { ok: false, error: "method_not_allowed" });
  }

  const declaredLength = Number(request.headers.get("content-length") || 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    return json(413, { ok: false, error: "payload_too_large" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(503, { ok: false, error: "service_not_configured" });
  }

  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
    return json(413, { ok: false, error: "payload_too_large" });
  }

  let payload: JsonRecord;
  try {
    payload = record(JSON.parse(rawBody));
  } catch {
    return json(400, { ok: false, error: "invalid_json" });
  }

  if (
    integer(payload.schema_version, 1, 1) !== 1 ||
    payload.product_key !== PRODUCT_KEY ||
    payload.privacy_policy !== "metadata_only_v1"
  ) {
    return json(400, { ok: false, error: "unsupported_schema" });
  }

  const sourceEventId = uuid(payload.source_event_id);
  const sourceRequestId = uuid(payload.source_request_id);
  const organizationId = uuid(payload.organization_id);
  const intakeId = optionalUuid(payload.intake_id);
  const projectId = optionalUuid(payload.project_id);
  const projectKey = safeToken(payload.project_key, 160);
  const tool = safeToken(payload.tool, 180);
  const risk = requiredText(payload.risk, 32);
  const outcomeStatus = requiredText(payload.outcome_status, 32);
  const durationMs = integer(payload.duration_ms, 0, 86_400_000);
  const completedAt = isoTimestamp(payload.completed_at);
  const contextStatus = requiredText(payload.context_status, 32);
  const contextHash = hash(payload.context_hash);
  const resultFingerprint = hash(payload.result_fingerprint);
  const errorFingerprint = hash(payload.error_fingerprint);

  if (
    !sourceEventId ||
    !sourceRequestId ||
    !organizationId ||
    !projectKey ||
    !tool ||
    !risk ||
    !RISKS.has(risk) ||
    !outcomeStatus ||
    !OUTCOME_STATUSES.has(outcomeStatus) ||
    durationMs === null ||
    !completedAt ||
    !contextStatus ||
    !CONTEXT_STATUSES.has(contextStatus) ||
    !contextHash
  ) {
    return json(400, { ok: false, error: "invalid_learning_event" });
  }

  if (risk !== "read" && contextStatus !== "available") {
    return json(400, { ok: false, error: "invalid_context_gate_state" });
  }
  if (outcomeStatus === "failed" && !errorFingerprint) {
    return json(400, {
      ok: false,
      error: "failed_event_requires_error_fingerprint",
    });
  }

  const timestamp = request.headers.get("x-pandora-timestamp") || "";
  const suppliedSignature = request.headers.get("x-pandora-signature") || "";
  const timestampMs = Number(timestamp);
  if (
    !Number.isFinite(timestampMs) ||
    Math.abs(Date.now() - timestampMs) > MAX_CLOCK_SKEW_MS
  ) {
    return json(401, { ok: false, error: "stale_or_invalid_timestamp" });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: credential, error: credentialError } = await admin.rpc(
    "pandora_integration_credential",
    { p_integration_key: INTEGRATION_KEY },
  );
  const credentialRecord = record(credential);
  const secret = requiredText(credentialRecord.secret_value, 512);
  const memoryUserId = uuid(credentialRecord.memory_user_id);
  const allowedProducts = Array.isArray(credentialRecord.allowed_product_keys)
    ? credentialRecord.allowed_product_keys.filter(
      (value): value is string => typeof value === "string",
    )
    : [];

  if (
    credentialError ||
    !secret ||
    !memoryUserId ||
    credentialRecord.is_active !== true ||
    !allowedProducts.includes(PRODUCT_KEY)
  ) {
    return json(503, { ok: false, error: "bridge_not_configured" });
  }

  const basis = signatureBasis({
    sourceEventId,
    sourceRequestId,
    organizationId,
    intakeId,
    projectId,
    projectKey,
    tool,
    risk,
    outcomeStatus,
    durationMs,
    completedAt,
    contextStatus,
    contextHash,
    resultFingerprint,
    errorFingerprint,
  });
  const expectedSignature = await hmacHex(secret, `${timestamp}.${basis}`);
  if (!constantTimeEqual(expectedSignature, suppliedSignature)) {
    return json(401, { ok: false, error: "invalid_signature" });
  }

  if (payload.learning_kind !== undefined) {
    if (payload.learning_kind !== VISIBLE_LEARNING_KIND) {
      return json(400, { ok: false, error: "unsupported_learning_kind" });
    }
    const visible = parseVisibleEvidence(payload);
    if (
      !visible || projectId !== VISIBLE_MEMORY_PROJECT_ID ||
      projectKey !== VISIBLE_MEMORY_PROJECT_KEY ||
      contextStatus !== "available" || risk !== "write"
    ) {
      return json(400, {
        ok: false,
        error: "invalid_visible_creation_evidence",
      });
    }
    const expectedContextHash = await sha256(visibleEvidenceBasis(visible));
    if (!constantTimeEqual(expectedContextHash, contextHash)) {
      return json(400, { ok: false, error: "visible_evidence_hash_mismatch" });
    }
    if (visible.evidenceKind === "repeated_failure") {
      if (
        outcomeStatus !== "failed" ||
        errorFingerprint !== visible.failureFingerprint ||
        resultFingerprint !== null
      ) {
        return json(400, {
          ok: false,
          error: "visible_failure_binding_invalid",
        });
      }
    } else if (
      outcomeStatus !== "completed" ||
      resultFingerprint !== visible.sourceSha256 || errorFingerprint !== null
    ) {
      return json(400, {
        ok: false,
        error: "visible_verified_binding_invalid",
      });
    }
    return await persistVisibleEvidence(
      admin,
      memoryUserId,
      sourceEventId,
      contextHash,
      completedAt,
      visible,
    );
  }

  // Routine successful reads/writes are operational telemetry, not durable
  // Memory facts. Keep them out of the human review queue and retain only a
  // bounded aggregate marker. Durable lessons continue through the dedicated
  // evidence-candidate path, while failures/destructive/ambiguous outcomes
  // remain review-gated here.
  const reviewRequired = outcomeStatus === "failed" ||
    risk === "destructive" ||
    errorFingerprint !== null ||
    (risk === "write" && !resultFingerprint);

  if (!reviewRequired) {
    const completedDate = new Date(completedAt);
    completedDate.setUTCMinutes(0, 0, 0);
    completedDate.setUTCHours(
      Math.floor(completedDate.getUTCHours() / ROUTINE_AGGREGATE_WINDOW_HOURS) *
        ROUTINE_AGGREGATE_WINDOW_HOURS,
    );
    const aggregateWindowStart = completedDate.toISOString();
    const aggregateKey = await sha256(
      [aggregateWindowStart, projectKey, tool, risk].join("\n"),
    );
    const aggregateSourceRef = `projectos-summary:${aggregateKey}`;
    const aggregateTitle = `ProjectOS routine ${risk} activity: ${tool}`.slice(
      0,
      240,
    );
    const aggregateSummary = [
      `Routine successful ${risk} activity for ${projectKey} via ${tool}`,
      `was observed during the ${ROUTINE_AGGREGATE_WINDOW_HOURS}-hour window beginning ${aggregateWindowStart}.`,
      "Individual operation details remain authoritative in ProjectOS; Pandora Memory retains only this bounded privacy-safe summary marker.",
    ].join(" ").slice(0, 1800);

    let digestId: string | null = null;
    let digestCreated = false;
    const { data: existingDigest, error: existingDigestError } = await admin
      .from("memory_session_digests")
      .select("id")
      .eq("user_id", memoryUserId)
      .eq("namespace", NAMESPACE)
      .eq("source", SOURCE)
      .eq("source_ref", aggregateSourceRef)
      .maybeSingle();

    if (existingDigestError) {
      console.error(
        "projectos_aggregate_lookup_failed",
        existingDigestError.message,
      );
      return json(500, { ok: false, error: "aggregate_lookup_failed" });
    }

    digestId = existingDigest?.id ?? null;
    if (!digestId) {
      const { data: insertedDigest, error: digestInsertError } = await admin
        .from("memory_session_digests")
        .insert({
          user_id: memoryUserId,
          namespace: NAMESPACE,
          source: SOURCE,
          source_ref: aggregateSourceRef,
          title: aggregateTitle,
          summary: aggregateSummary,
          durable_updates: [{
            type: "projectos_routine_operation_summary",
            projectKey,
            tool,
            risk,
            outcomeStatus: "completed",
            windowStart: aggregateWindowStart,
            windowHours: ROUTINE_AGGREGATE_WINDOW_HOURS,
            reviewRequired: false,
            authoritativeEventSource: "projectos",
            privacyPolicy: "metadata_only_v1",
          }],
          decisions: [],
          open_loops: [],
          risks: [],
          people: [],
          projects: [projectKey],
          style_updates: [],
          candidate_ids: [],
          captured_event_ids: [],
          profile_ids: [],
        })
        .select("id")
        .maybeSingle();

      if (digestInsertError && digestInsertError.code !== "23505") {
        console.error(
          "projectos_aggregate_insert_failed",
          digestInsertError.message,
        );
        return json(500, { ok: false, error: "aggregate_insert_failed" });
      }

      if (insertedDigest?.id) {
        digestId = insertedDigest.id;
        digestCreated = true;
      } else {
        const { data: racedDigest, error: racedDigestError } = await admin
          .from("memory_session_digests")
          .select("id")
          .eq("user_id", memoryUserId)
          .eq("namespace", NAMESPACE)
          .eq("source", SOURCE)
          .eq("source_ref", aggregateSourceRef)
          .maybeSingle();
        if (racedDigestError || !racedDigest?.id) {
          return json(500, { ok: false, error: "aggregate_recovery_failed" });
        }
        digestId = racedDigest.id;
      }
    }

    if (digestCreated && digestId) {
      const { error: auditInsertError } = await admin.from("audit_logs").insert(
        {
          user_id: memoryUserId,
          namespace: NAMESPACE,
          action: "projectos_post_task_learning_aggregate_created",
          table_name: "memory_session_digests",
          record_id: digestId,
          before_snapshot: null,
          after_snapshot: {
            digestId,
            aggregateSourceRef,
            projectKey,
            tool,
            risk,
            aggregateWindowStart,
            reviewRequired: false,
            canonicalMemoryWritten: false,
          },
          metadata: {
            integration_key: INTEGRATION_KEY,
            product_key: PRODUCT_KEY,
            privacy_policy: "metadata_only_v1",
            authoritative_event_source: "projectos",
            aggregate_window_hours: ROUTINE_AGGREGATE_WINDOW_HOURS,
          },
        },
      );
      if (auditInsertError) {
        console.error(
          "projectos_aggregate_audit_failed",
          auditInsertError.message,
        );
      }
    }

    return json(digestCreated ? 202 : 200, {
      ok: true,
      status: digestCreated
        ? "aggregated_summary_created"
        : "aggregated_existing_summary",
      source_ref: aggregateSourceRef,
      candidate_id: null,
      review_item_id: null,
      digest_id: digestId,
      review_required: false,
      canonical_memory_written: false,
      authoritative_event_source: "projectos",
      privacy_policy: "metadata_only_v1",
    });
  }

  const sourceRef = `projectos-plan:${sourceEventId}`;
  const title = `ProjectOS ${outcomeStatus}: ${tool}`.slice(0, 240);
  const summary = [
    `ProjectOS ${outcomeStatus} the ${risk} operation ${tool}`,
    `for ${projectKey}`,
    `after ${contextStatus} Pandora Memory hydration`,
    `in ${durationMs} ms at ${completedAt}.`,
    "Only privacy-safe operational metadata and cryptographic fingerprints were retained.",
  ].join(" ").slice(0, 1800);
  const requestHash = await sha256(rawBody);
  const fingerprint = await sha256(`${sourceRef}\n${summary}`);
  const riskSignal = outcomeStatus === "failed" || risk === "destructive" ||
    errorFingerprint !== null;
  const reviewRisk = outcomeStatus === "failed"
    ? "A ProjectOS operation failed; investigate using authoritative provider evidence."
    : risk === "destructive"
    ? "A destructive ProjectOS operation completed; verify exact provider state before promoting any durable lesson."
    : "A ProjectOS write completed without a result fingerprint; verify authoritative provider evidence before promotion.";

  let candidateId: string | null = null;
  let candidateCreated = false;

  const { data: existingCandidate, error: existingCandidateError } = await admin
    .from("memory_capture_candidates")
    .select("id")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("source", SOURCE)
    .eq("source_ref", sourceRef)
    .maybeSingle();

  if (existingCandidateError) {
    console.error(
      "projectos_candidate_lookup_failed",
      existingCandidateError.message,
    );
    return json(500, { ok: false, error: "candidate_lookup_failed" });
  }

  candidateId = existingCandidate?.id ?? null;
  if (!candidateId) {
    const candidate = {
      user_id: memoryUserId,
      namespace: NAMESPACE,
      source: SOURCE,
      source_ref: sourceRef,
      raw_excerpt: null,
      redacted_excerpt: summary,
      memory_type: riskSignal ? "risk_signal" : "business_fact",
      title,
      summary,
      importance: outcomeStatus === "failed"
        ? 8
        : risk === "destructive"
        ? 7
        : 6,
      sensitivity: "low",
      confidence: 0.92,
      should_capture: true,
      requires_review: true,
      status: "pending",
      reason:
        "Post-task learning is review-gated for failures, destructive operations, and ambiguous successful writes. This candidate cannot become canonical without an authenticated human decision.",
      people: [],
      projects: [projectKey],
      risks: [reviewRisk],
      tags: [
        "projectos",
        "post_task_learning",
        outcomeStatus,
        risk,
        "review_required",
      ],
      metadata: {
        schema_version: 1,
        source_event_id: sourceEventId,
        source_request_id: sourceRequestId,
        organization_id: organizationId,
        intake_id: intakeId,
        project_id: projectId,
        project_key: projectKey,
        tool,
        risk,
        outcome_status: outcomeStatus,
        duration_ms: durationMs,
        completed_at: completedAt,
        context_status: contextStatus,
        context_hash: contextHash,
        result_fingerprint: resultFingerprint,
        error_fingerprint: errorFingerprint,
        privacy_policy: "metadata_only_v1",
        review_policy: "projectos_selective_review_v2",
        imported_raw_arguments: false,
        imported_raw_results: false,
        imported_raw_errors: false,
        imported_personal_identifiers: false,
        imported_secrets: false,
      },
      usefulness_score: outcomeStatus === "failed" ? 0.9 : 0.78,
      confidence_score: 0.92,
      freshness_score: 1,
      retrieval_weight: outcomeStatus === "failed" ? 0.9 : 0.78,
      stale_status: "active",
      scoring_version: "projectos-learning-v2",
      scored_at: new Date().toISOString(),
    };

    const { data: insertedCandidate, error: candidateInsertError } = await admin
      .from("memory_capture_candidates")
      .insert(candidate)
      .select("id")
      .maybeSingle();

    if (candidateInsertError && candidateInsertError.code !== "23505") {
      console.error(
        "projectos_candidate_insert_failed",
        candidateInsertError.message,
      );
      return json(500, { ok: false, error: "candidate_insert_failed" });
    }

    if (insertedCandidate?.id) {
      candidateId = insertedCandidate.id;
      candidateCreated = true;
    } else {
      const { data: racedCandidate, error: racedCandidateError } = await admin
        .from("memory_capture_candidates")
        .select("id")
        .eq("user_id", memoryUserId)
        .eq("namespace", NAMESPACE)
        .eq("source", SOURCE)
        .eq("source_ref", sourceRef)
        .maybeSingle();
      if (racedCandidateError || !racedCandidate?.id) {
        return json(500, { ok: false, error: "candidate_recovery_failed" });
      }
      candidateId = racedCandidate.id;
    }
  }

  let reviewItemId: string | null = null;
  let reviewItemCreated = false;
  const { data: existingReview, error: existingReviewError } = await admin
    .from("memory_review_queue_items")
    .select("id")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("candidate_type", "projectos_outcome")
    .eq("source_ref", sourceRef)
    .maybeSingle();

  if (existingReviewError) {
    return json(500, { ok: false, error: "review_lookup_failed" });
  }
  reviewItemId = existingReview?.id ?? null;

  if (!reviewItemId) {
    const { data: insertedReview, error: reviewInsertError } = await admin
      .from("memory_review_queue_items")
      .insert({
        user_id: memoryUserId,
        namespace: NAMESPACE,
        status: "pending_review",
        candidate_type: "projectos_outcome",
        normalized_text: summary,
        evidence_snapshot: {
          hasEvidence: true,
          sourceRef,
          sourceEventId,
          sourceRequestId,
          contextHash,
          resultFingerprint,
          errorFingerprint,
          completedAt,
        },
        sensitivity_snapshot: {
          classification: "low",
          containsSecrets: false,
          containsPersonalData: false,
          containsRawArguments: false,
          containsRawResults: false,
          containsRawErrors: false,
        },
        namespace_snapshot: {
          sourceNamespace: NAMESPACE,
          targetNamespace: NAMESPACE,
          namespaceMatch: true,
        },
        source_metadata: {
          source: SOURCE,
          sourceRef,
          projectKey,
          tool,
          risk,
          outcomeStatus,
          reviewPolicy: "projectos_selective_review_v2",
        },
        audit_metadata: {
          schemaVersion: 1,
          requestHash,
          candidateId,
          appendOnly: true,
          reviewRequired: true,
        },
        append_only: true,
        proposed_operation: "append",
        requires_review: true,
        source_ref: sourceRef,
        request_hash: requestHash,
        fingerprint,
        persistence_execution_metadata: {},
      })
      .select("id")
      .maybeSingle();

    if (reviewInsertError && reviewInsertError.code !== "23505") {
      console.error(
        "projectos_review_insert_failed",
        reviewInsertError.message,
      );
      return json(500, { ok: false, error: "review_insert_failed" });
    }

    if (insertedReview?.id) {
      reviewItemId = insertedReview.id;
      reviewItemCreated = true;
    } else {
      const { data: racedReview, error: racedReviewError } = await admin
        .from("memory_review_queue_items")
        .select("id")
        .eq("user_id", memoryUserId)
        .eq("namespace", NAMESPACE)
        .eq("candidate_type", "projectos_outcome")
        .eq("source_ref", sourceRef)
        .maybeSingle();
      if (racedReviewError || !racedReview?.id) {
        return json(500, { ok: false, error: "review_recovery_failed" });
      }
      reviewItemId = racedReview.id;
    }
  }

  let digestId: string | null = null;
  let digestCreated = false;
  const { data: existingDigest, error: existingDigestError } = await admin
    .from("memory_session_digests")
    .select("id")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("source", SOURCE)
    .eq("source_ref", sourceRef)
    .maybeSingle();

  if (existingDigestError) {
    return json(500, { ok: false, error: "digest_lookup_failed" });
  }
  digestId = existingDigest?.id ?? null;

  if (!digestId) {
    const { data: insertedDigest, error: digestInsertError } = await admin
      .from("memory_session_digests")
      .insert({
        user_id: memoryUserId,
        namespace: NAMESPACE,
        source: SOURCE,
        source_ref: sourceRef,
        title,
        summary,
        durable_updates: [{
          type: "projectos_operation_outcome",
          projectKey,
          tool,
          risk,
          outcomeStatus,
          durationMs,
          completedAt,
          contextStatus,
          reviewRequired: true,
          reviewPolicy: "projectos_selective_review_v2",
        }],
        decisions: [],
        open_loops: [{
          type: "provider_evidence_review_required",
          title: outcomeStatus === "failed"
            ? `Investigate failed ProjectOS operation ${tool}`
            : `Verify review-gated ProjectOS operation ${tool}`,
          sourceRef,
        }],
        risks: [{
          type: outcomeStatus === "failed"
            ? "operation_failure"
            : risk === "destructive"
            ? "destructive_operation_review"
            : "ambiguous_write_review",
          tool,
          sourceRef,
        }],
        people: [],
        projects: [projectKey],
        style_updates: [],
        candidate_ids: candidateId ? [candidateId] : [],
        captured_event_ids: [],
        profile_ids: [],
      })
      .select("id")
      .maybeSingle();

    if (digestInsertError && digestInsertError.code !== "23505") {
      console.error(
        "projectos_digest_insert_failed",
        digestInsertError.message,
      );
      return json(500, { ok: false, error: "digest_insert_failed" });
    }

    if (insertedDigest?.id) {
      digestId = insertedDigest.id;
      digestCreated = true;
    } else {
      const { data: racedDigest, error: racedDigestError } = await admin
        .from("memory_session_digests")
        .select("id")
        .eq("user_id", memoryUserId)
        .eq("namespace", NAMESPACE)
        .eq("source", SOURCE)
        .eq("source_ref", sourceRef)
        .maybeSingle();
      if (racedDigestError || !racedDigest?.id) {
        return json(500, { ok: false, error: "digest_recovery_failed" });
      }
      digestId = racedDigest.id;
    }
  }

  const { data: existingAudit, error: auditLookupError } = await admin
    .from("audit_logs")
    .select("id")
    .eq("user_id", memoryUserId)
    .eq("namespace", NAMESPACE)
    .eq("action", "projectos_post_task_learning_accepted")
    .eq("record_id", candidateId)
    .limit(1)
    .maybeSingle();

  if (!auditLookupError && !existingAudit?.id) {
    const { error: auditInsertError } = await admin.from("audit_logs").insert({
      user_id: memoryUserId,
      namespace: NAMESPACE,
      action: "projectos_post_task_learning_accepted",
      table_name: "memory_capture_candidates",
      record_id: candidateId,
      before_snapshot: null,
      after_snapshot: {
        candidateId,
        reviewItemId,
        digestId,
        sourceRef,
        outcomeStatus,
        reviewRequired: true,
      },
      metadata: {
        integration_key: INTEGRATION_KEY,
        product_key: PRODUCT_KEY,
        project_key: projectKey,
        privacy_policy: "metadata_only_v1",
        review_policy: "projectos_selective_review_v2",
        append_only: true,
      },
    });
    if (auditInsertError) {
      console.error(
        "projectos_learning_audit_failed",
        auditInsertError.message,
      );
    }
  }

  const created = candidateCreated || reviewItemCreated || digestCreated;
  return json(created ? 202 : 200, {
    ok: true,
    status: created ? "accepted_for_review" : "idempotent_replay",
    source_ref: sourceRef,
    candidate_id: candidateId,
    review_item_id: reviewItemId,
    digest_id: digestId,
    review_required: true,
    canonical_memory_written: false,
    review_policy: "projectos_selective_review_v2",
    privacy_policy: "metadata_only_v1",
  });
});
