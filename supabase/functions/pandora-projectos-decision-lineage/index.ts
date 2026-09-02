import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.9";

const INTEGRATION_KEY = "projectos-learning-bridge";
const PRODUCT_KEY = "projectos";
const NAMESPACE = "real_life";
const MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";
const MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";
const MAX_BODY_BYTES = 32 * 1024;
const MAX_CLOCK_SKEW_MS = 5 * 60_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH = /^[0-9a-f]{64}$/i;
const SAFE_TOKEN = /^[A-Za-z0-9._:/-]{1,180}$/;
const DECISION_TYPES = new Set(["project_spec", "build", "repair"]);
const OUTCOME_DETAILS = new Set(["succeeded", "failed", "accepted", "rejected", "regressed", "unknown"]);
const INFLUENCE_KIND = "visible_creation_decision_influence_v1";
const OUTCOME_KIND = "visible_creation_decision_outcome_v1";

type JsonRecord = Record<string, unknown>;
type AdminClient = ReturnType<typeof createClient<any>>;

const json = (status: number, body: JsonRecord) => new Response(JSON.stringify(body), {
  status,
  headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  },
});
const record = (value: unknown): JsonRecord => value && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
const requiredText = (value: unknown, max = 180): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized && normalized.length <= max ? normalized : null;
};
const optionalText = (value: unknown, max = 180): string | null => value === null || value === undefined || value === "" ? null : requiredText(value, max);
const uuid = (value: unknown): string | null => {
  const normalized = requiredText(value, 64);
  return normalized && UUID.test(normalized) ? normalized.toLowerCase() : null;
};
const optionalUuid = (value: unknown): string | null => value === null || value === undefined || value === "" ? null : uuid(value);
const hash = (value: unknown): string | null => {
  const normalized = optionalText(value, 64);
  return normalized && HASH.test(normalized) ? normalized.toLowerCase() : null;
};
const integer = (value: unknown, min: number, max: number): number | null => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : null;
};
const finiteNumber = (value: unknown, min: number, max: number): number | null => {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= min && parsed <= max ? parsed : null;
};
const safeToken = (value: unknown, max = 180): string | null => {
  const normalized = requiredText(value, max);
  return normalized && SAFE_TOKEN.test(normalized) ? normalized : null;
};
const approvedIds = (value: unknown): string[] | null => {
  if (!Array.isArray(value) || value.length < 1 || value.length > 50) return null;
  const ids = value.map(uuid);
  if (ids.some((id) => !id)) return null;
  const normalized = ids as string[];
  if (new Set(normalized).size !== normalized.length) return null;
  return normalized;
};
const sameIdSet = (left: string[], right: unknown): boolean => {
  if (!Array.isArray(right)) return false;
  const normalized = right.map(uuid);
  if (normalized.some((id) => !id) || normalized.length !== left.length) return false;
  return [...left].sort().join(",") === (normalized as string[]).sort().join(",");
};
const constantTimeEqual = (left: string, right: string): boolean => {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i += 1) mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return mismatch === 0;
};
const hmacHex = async (secret: string, value: string): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
};
const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
};
const signatureBasis = (input: {
  sourceEventId: string; sourceRequestId: string; organizationId: string; intakeId: string | null;
  projectId: string | null; projectKey: string; tool: string; risk: string; outcomeStatus: string;
  durationMs: number; completedAt: string; contextStatus: string; contextHash: string;
  resultFingerprint: string | null; errorFingerprint: string | null;
}): string => [
  "projectos-learning-v1", input.sourceEventId, input.sourceRequestId, input.organizationId,
  input.intakeId ?? "", input.projectId ?? "", input.projectKey, input.tool, input.risk,
  input.outcomeStatus, String(input.durationMs), input.completedAt, input.contextStatus,
  input.contextHash, input.resultFingerprint ?? "", input.errorFingerprint ?? "",
].join("\n");
const influenceBasis = (value: {
  retrievalLogId: string; receiptId: string; decisionType: string; decisionId: string;
  decisionRunId: string | null; approvedMemoryItemIds: string[];
}): string => [
  "visible-creation-decision-influence-v1", MEMORY_PROJECT_ID, MEMORY_PROJECT_KEY,
  value.retrievalLogId, value.receiptId, value.decisionType, value.decisionId,
  value.decisionRunId ?? "", value.approvedMemoryItemIds.join(","),
].join("\n");
const outcomeBasis = (value: {
  retrievalLogId: string; receiptId: string; decisionType: string; decisionId: string;
  outcomeRunId: string; outcomeStatus: string; usefulnessDelta: number; evidenceRef: string;
  approvedMemoryItemIds: string[];
}): string => [
  "visible-creation-decision-outcome-v1", MEMORY_PROJECT_ID, MEMORY_PROJECT_KEY,
  value.retrievalLogId, value.receiptId, value.decisionType, value.decisionId,
  value.outcomeRunId, value.outcomeStatus, String(value.usefulnessDelta), value.evidenceRef,
  value.approvedMemoryItemIds.join(","),
].join("\n");
const rpcError = (error: { code?: string } | null | undefined, fallback: string): Response => {
  const code = error?.code || "";
  return json(code === "23505" ? 409 : code === "P0002" ? 404 : 503, {
    ok: false,
    error: code === "23505" ? "decision_lineage_conflict" : code === "P0002" ? "decision_lineage_not_found" : fallback,
  });
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });
  const declaredLength = Number(request.headers.get("content-length") || 0);
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });
  let payload: JsonRecord;
  try { payload = record(JSON.parse(rawBody)); } catch { return json(400, { ok: false, error: "invalid_json" }); }

  if (integer(payload.schema_version, 1, 1) !== 1 || payload.product_key !== PRODUCT_KEY || payload.privacy_policy !== "metadata_only_v1") {
    return json(400, { ok: false, error: "unsupported_schema" });
  }
  const learningKind = requiredText(payload.learning_kind, 64);
  if (learningKind !== INFLUENCE_KIND && learningKind !== OUTCOME_KIND) return json(400, { ok: false, error: "unsupported_learning_kind" });

  const sourceEventId = uuid(payload.source_event_id);
  const sourceRequestId = uuid(payload.source_request_id);
  const organizationId = uuid(payload.organization_id);
  const intakeId = optionalUuid(payload.intake_id);
  const projectId = uuid(payload.project_id);
  const projectKey = safeToken(payload.project_key, 160);
  const tool = safeToken(payload.tool, 180);
  const risk = requiredText(payload.risk, 32);
  const outcomeStatus = requiredText(payload.outcome_status, 32);
  const durationMs = integer(payload.duration_ms, 0, 86_400_000);
  const completedAt = requiredText(payload.completed_at, 64);
  const contextStatus = requiredText(payload.context_status, 32);
  const contextHash = hash(payload.context_hash);
  const resultFingerprint = hash(payload.result_fingerprint);
  const errorFingerprint = hash(payload.error_fingerprint);
  const visibleProjectId = uuid(payload.visible_project_id);
  const receiptId = uuid(payload.receipt_id);
  const retrievalLogId = uuid(payload.retrieval_log_id);
  const decisionType = requiredText(payload.decision_type, 32);
  const decisionId = uuid(payload.decision_id);
  const itemIds = approvedIds(payload.approved_memory_item_ids);

  if (!sourceEventId || !sourceRequestId || !organizationId || intakeId !== null || projectId !== MEMORY_PROJECT_ID ||
      projectKey !== MEMORY_PROJECT_KEY || !tool || risk !== "write" || outcomeStatus !== "completed" ||
      durationMs !== 0 || !completedAt || Number.isNaN(Date.parse(completedAt)) || contextStatus !== "available" ||
      !contextHash || !resultFingerprint || errorFingerprint !== null || !visibleProjectId || !receiptId ||
      sourceRequestId !== receiptId || !retrievalLogId || !decisionType || !DECISION_TYPES.has(decisionType) ||
      !decisionId || !itemIds) {
    return json(400, { ok: false, error: "invalid_decision_lineage_event" });
  }

  const timestamp = request.headers.get("x-pandora-timestamp") || "";
  const suppliedSignature = request.headers.get("x-pandora-signature") || "";
  const timestampMs = Number(timestamp);
  if (!Number.isFinite(timestampMs) || Math.abs(Date.now() - timestampMs) > MAX_CLOCK_SKEW_MS) {
    return json(401, { ok: false, error: "stale_or_invalid_timestamp" });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(503, { ok: false, error: "service_not_configured" });
  const admin: AdminClient = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: credential, error: credentialError } = await admin.rpc("pandora_integration_credential", { p_integration_key: INTEGRATION_KEY });
  const credentialRecord = record(credential);
  const secret = requiredText(credentialRecord.secret_value, 512);
  const memoryUserId = uuid(credentialRecord.memory_user_id);
  const allowedProducts = Array.isArray(credentialRecord.allowed_product_keys)
    ? credentialRecord.allowed_product_keys.filter((value): value is string => typeof value === "string") : [];
  if (credentialError || !secret || !memoryUserId || credentialRecord.is_active !== true || !allowedProducts.includes(PRODUCT_KEY)) {
    return json(503, { ok: false, error: "bridge_not_configured" });
  }

  const expectedSignature = await hmacHex(secret, `${timestamp}.${signatureBasis({
    sourceEventId, sourceRequestId, organizationId, intakeId, projectId, projectKey, tool, risk,
    outcomeStatus, durationMs, completedAt, contextStatus, contextHash, resultFingerprint, errorFingerprint,
  })}`);
  if (!constantTimeEqual(expectedSignature, suppliedSignature)) return json(401, { ok: false, error: "invalid_signature" });

  if (learningKind === INFLUENCE_KIND) {
    if (tool !== "visible_creation.memory_decision_influence" || sourceEventId !== decisionId) {
      return json(400, { ok: false, error: "decision_influence_binding_invalid" });
    }
    const decisionRunId = optionalUuid(payload.decision_run_id);
    const expectedContextHash = await sha256(influenceBasis({ retrievalLogId, receiptId, decisionType, decisionId, decisionRunId, approvedMemoryItemIds: itemIds }));
    if (!constantTimeEqual(expectedContextHash, contextHash)) return json(400, { ok: false, error: "decision_influence_hash_mismatch" });
    const { data, error } = await admin.rpc("memory_bind_decision_context_v1", {
      p_memory_user_id: memoryUserId,
      p_namespace: NAMESPACE,
      p_project_id: MEMORY_PROJECT_ID,
      p_retrieval_log_id: retrievalLogId,
      p_decision_type: decisionType,
      p_decision_id: decisionId,
      p_decision_run_id: decisionRunId,
    });
    if (error) return rpcError(error, "decision_influence_failed");
    const lineage = record(data);
    if (!sameIdSet(itemIds, lineage.memoryItemIds)) return json(409, { ok: false, error: "approved_memory_lineage_mismatch" });
    return json(200, {
      ok: true,
      status: "decision_context_bound",
      source_event_id: sourceEventId,
      visible_project_id: visibleProjectId,
      receipt_id: receiptId,
      retrieval_log_id: retrievalLogId,
      decision_type: decisionType,
      decision_id: decisionId,
      decision_run_id: decisionRunId,
      approved_memory_item_ids: itemIds,
      idempotent_replay: lineage.idempotentReplay === true,
      canonical_memory_written: false,
    });
  }

  if (tool !== "visible_creation.memory_decision_outcome") return json(400, { ok: false, error: "decision_outcome_binding_invalid" });
  const outcomeRunId = uuid(payload.outcome_run_id);
  const outcomeDetail = requiredText(payload.outcome_status_detail, 32);
  const usefulnessDelta = finiteNumber(payload.usefulness_delta, -1, 1);
  const evidenceRef = requiredText(payload.evidence_ref, 500);
  if (!outcomeRunId || sourceEventId !== outcomeRunId || !outcomeDetail || !OUTCOME_DETAILS.has(outcomeDetail) || usefulnessDelta === null ||
      !evidenceRef || /(authorization|api[_-]?key|secret[_-]?value|bearer\s)/i.test(evidenceRef)) {
    return json(400, { ok: false, error: "decision_outcome_binding_invalid" });
  }
  const expectedContextHash = await sha256(outcomeBasis({
    retrievalLogId, receiptId, decisionType, decisionId, outcomeRunId,
    outcomeStatus: outcomeDetail, usefulnessDelta, evidenceRef, approvedMemoryItemIds: itemIds,
  }));
  if (!constantTimeEqual(expectedContextHash, contextHash)) return json(400, { ok: false, error: "decision_outcome_hash_mismatch" });
  const { data, error } = await admin.rpc("memory_record_decision_outcome_v1", {
    p_memory_user_id: memoryUserId,
    p_namespace: NAMESPACE,
    p_project_id: MEMORY_PROJECT_ID,
    p_retrieval_log_id: retrievalLogId,
    p_decision_type: decisionType,
    p_decision_id: decisionId,
    p_outcome_run_id: outcomeRunId,
    p_outcome_status: outcomeDetail,
    p_usefulness_delta: usefulnessDelta,
    p_evidence_ref: evidenceRef,
  });
  if (error) return rpcError(error, "decision_outcome_failed");
  const outcome = record(data);
  if (!sameIdSet(itemIds, outcome.memoryItemIds)) return json(409, { ok: false, error: "approved_memory_lineage_mismatch" });
  return json(200, {
    ok: true,
    status: "decision_outcome_recorded",
    source_event_id: sourceEventId,
    visible_project_id: visibleProjectId,
    receipt_id: receiptId,
    retrieval_log_id: retrievalLogId,
    decision_type: decisionType,
    decision_id: decisionId,
    outcome_run_id: outcomeRunId,
    outcome_status: outcomeDetail,
    approved_memory_item_ids: itemIds,
    feedback_rows_inserted: Number(outcome.feedbackRowsInserted || 0),
    idempotent_replay: outcome.idempotentReplay === true,
    canonical_memory_written: false,
  });
});
