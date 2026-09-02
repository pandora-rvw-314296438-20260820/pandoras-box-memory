import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.9";

const INTEGRATION_KEY = "projectos-learning-bridge";
const PRINCIPAL_KEY = "projectos-mcpmaster-production";
const PRODUCT_KEY = "projectos";
const PURPOSE = "projectos-planning-context-v1";
const NAMESPACE = "real_life";
const MAX_BODY_BYTES = 16 * 1024;
const MAX_CLOCK_SKEW_MS = 5 * 60_000;
const MAX_ITEMS = 6;
const MAX_SUMMARY_CHARS = 700;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH = /^[0-9a-f]{64}$/i;
const PROJECT_KEY = /^[a-z0-9][a-z0-9._-]{1,95}$/;
const DECISION_TYPES = new Set(["project_spec", "build", "repair"]);
const APPROVED_CANON = ["hard_canon", "soft_canon"];
const SECRETISH = /(?:authorization\s*[:=]|bearer\s+[A-Za-z0-9._~+\/-]{12,}|api[_-]?key\s*[:=]|secret[_-]?value\s*[:=]|password\s*[:=]|private[_-]?key|github_pat_|gh[pousr]_|sb_secret_|-----BEGIN [A-Z ]*PRIVATE KEY-----)/i;

type JsonRecord = Record<string, unknown>;
type AdminClient = ReturnType<typeof createClient<any>>;

const json = (status: number, body: JsonRecord) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff" },
});
const record = (value: unknown): JsonRecord => value && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
const text = (value: unknown): string => typeof value === "string" ? value.trim() : "";
const uuid = (value: unknown): string | null => { const v = text(value).toLowerCase(); return UUID.test(v) ? v : null; };
const hash = (value: unknown): string | null => { const v = text(value).toLowerCase(); return HASH.test(v) ? v : null; };
const exactKeys = (value: JsonRecord, expected: string[]): boolean => {
  const actual = Object.keys(value).sort(); const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
};
const compact = (value: unknown, max = MAX_SUMMARY_CHARS): string => {
  const normalized = typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
  return normalized.slice(0, max);
};
const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
};
const hmacHex = async (secret: string, value: string): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return [...new Uint8Array(signature)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
};
const constantTimeEqual = (left: string, right: string): boolean => {
  if (left.length !== right.length) return false;
  let mismatch = 0; for (let i = 0; i < left.length; i += 1) mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return mismatch === 0;
};
const queryBasis = (input: { organizationId: string; visibleProjectId: string; projectKey: string; decisionType: string }): string => [
  "projectos-planning-query-v1", input.organizationId, input.visibleProjectId, input.projectKey, input.decisionType,
].join("\n");
const requestBasis = (input: { requestId: string; organizationId: string; visibleProjectId: string; projectKey: string; decisionType: string; queryHash: string }): string => [
  PURPOSE, input.requestId, input.organizationId, input.visibleProjectId, input.projectKey, input.decisionType, input.queryHash,
].join("\n");
const responseBasis = (input: {
  requestId: string; organizationId: string; visibleProjectId: string; memoryProjectId: string; projectKey: string;
  decisionType: string; queryHash: string; retrievalLogId: string; contextStatus: string;
  approvedMemoryItemIds: string[]; highlights: JsonRecord[];
}): string => [
  "projectos-planning-context-response-v1", input.requestId, input.organizationId, input.visibleProjectId,
  input.memoryProjectId, input.projectKey, input.decisionType, input.queryHash, input.retrievalLogId,
  input.contextStatus, input.approvedMemoryItemIds.join(","),
  ...input.highlights.map((item) => [text(item.id), text(item.memory_type), compact(item.summary), text(item.updated_at)].join("|")),
].join("\n");

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });
  const declared = Number(request.headers.get("content-length") || 0);
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });
  let payload: JsonRecord; try { payload = record(JSON.parse(raw)); } catch { return json(400, { ok: false, error: "invalid_json" }); }
  if (!exactKeys(payload, ["schema_version", "purpose", "request_id", "organization_id", "visible_project_id", "project_key", "decision_type", "query_hash"])) {
    return json(400, { ok: false, error: "invalid_request_shape" });
  }

  const requestId = uuid(payload.request_id);
  const organizationId = uuid(payload.organization_id);
  const visibleProjectId = uuid(payload.visible_project_id);
  const projectKey = text(payload.project_key);
  const decisionType = text(payload.decision_type);
  const queryHash = hash(payload.query_hash);
  if (payload.schema_version !== 1 || payload.purpose !== PURPOSE || !requestId || !organizationId || !visibleProjectId
      || !PROJECT_KEY.test(projectKey) || !DECISION_TYPES.has(decisionType) || !queryHash) {
    return json(400, { ok: false, error: "planning_identity_invalid" });
  }
  const expectedQueryHash = await sha256(queryBasis({ organizationId, visibleProjectId, projectKey, decisionType }));
  if (!constantTimeEqual(expectedQueryHash, queryHash)) return json(400, { ok: false, error: "planning_query_hash_invalid" });

  const timestamp = request.headers.get("x-pandora-timestamp") || "";
  const suppliedSignature = request.headers.get("x-pandora-signature") || "";
  const timestampMs = Number(timestamp);
  if (!Number.isFinite(timestampMs) || Math.abs(Date.now() - timestampMs) > MAX_CLOCK_SKEW_MS) return json(401, { ok: false, error: "stale_or_invalid_timestamp" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(503, { ok: false, error: "service_not_configured" });
  const admin: AdminClient = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: credential, error: credentialError } = await admin.rpc("pandora_integration_credential", { p_integration_key: INTEGRATION_KEY });
  const credentialRecord = record(credential);
  const secret = compact(credentialRecord.secret_value, 512);
  const memoryUserId = uuid(credentialRecord.memory_user_id);
  const allowedProducts = Array.isArray(credentialRecord.allowed_product_keys) ? credentialRecord.allowed_product_keys.filter((value): value is string => typeof value === "string") : [];
  if (credentialError || !secret || !memoryUserId || credentialRecord.is_active !== true || !allowedProducts.includes(PRODUCT_KEY)) return json(503, { ok: false, error: "bridge_not_configured" });

  const expectedSignature = await hmacHex(secret, `${timestamp}.${requestBasis({ requestId, organizationId, visibleProjectId, projectKey, decisionType, queryHash })}`);
  if (!constantTimeEqual(expectedSignature, suppliedSignature)) return json(401, { ok: false, error: "invalid_signature" });

  const { data: project, error: projectError } = await admin.from("pandora_projects")
    .select("id,project_key,memory_namespace,lifecycle_status")
    .eq("project_key", projectKey).eq("memory_namespace", NAMESPACE).eq("lifecycle_status", "active").maybeSingle();
  const memoryProjectId = uuid(project?.id);
  if (projectError || !memoryProjectId || project?.project_key !== projectKey) return json(403, { ok: false, error: "project_not_allowed" });
  const { data: grant, error: grantError } = await admin.from("pandora_project_grants")
    .select("project_id").eq("principal_key", PRINCIPAL_KEY).eq("project_id", memoryProjectId)
    .eq("is_active", true).eq("can_read", true).is("revoked_at", null).maybeSingle();
  if (grantError || !grant?.project_id) return json(403, { ok: false, error: "project_not_allowed" });

  const { data: claimed, error: claimError } = await admin.rpc("memory_claim_projectos_planning_nonce_v1", {
    p_request_id: requestId, p_organization_id: organizationId, p_visible_project_id: visibleProjectId,
    p_memory_project_id: memoryProjectId, p_project_key: projectKey, p_decision_type: decisionType, p_query_hash: queryHash,
  });
  if (claimError) return json(503, { ok: false, error: "planning_nonce_unavailable" });
  if (claimed !== true) return json(409, { ok: false, error: "planning_request_replayed" });

  const { data: items, error: itemError } = await admin.from("memory_items")
    .select("id,title,source_summary,confidence,canon_status,memory_type,updated_at")
    .eq("user_id", memoryUserId).eq("namespace", NAMESPACE).eq("project_id", memoryProjectId)
    .eq("is_active", true).in("canon_status", APPROVED_CANON).order("updated_at", { ascending: false }).limit(MAX_ITEMS);
  if (itemError) return json(503, { ok: false, error: "memory_query_failed" });

  const highlights: JsonRecord[] = [];
  for (const rawItem of items ?? []) {
    const item = record(rawItem); const id = uuid(item.id); if (!id) continue;
    const title = compact(item.title, 220); const sourceSummary = compact(item.source_summary, 420);
    const summary = compact([title, sourceSummary].filter(Boolean).join(": "));
    if (!summary || SECRETISH.test(summary)) continue;
    highlights.push({ id, memory_type: compact(item.memory_type, 80), summary, updated_at: compact(item.updated_at, 64) });
  }
  const approvedMemoryItemIds = highlights.map((item) => text(item.id));
  const contextStatus = approvedMemoryItemIds.length ? "available" : "empty";
  const { data: retrievalLog, error: retrievalError } = await admin.from("memory_retrieval_logs").insert({
    user_id: memoryUserId, namespace: NAMESPACE, query_hash: queryHash, project_id: memoryProjectId,
    memory_item_ids: approvedMemoryItemIds, used_for_routing: false,
    metadata: { principal: "projectos-hmac-planning", purpose: PURPOSE, request_id: requestId,
      organization_id: organizationId, visible_project_id: visibleProjectId, project_id: memoryProjectId,
      project_key: projectKey, decision_type: decisionType, returned_approved_items: approvedMemoryItemIds.length,
      summary_source: "title_plus_source_summary_only", raw_memory_body_returned: false, raw_prompt_returned: false },
  }).select("id").maybeSingle();
  const retrievalLogId = uuid(retrievalLog?.id);
  if (retrievalError || !retrievalLogId) return json(503, { ok: false, error: "retrieval_log_failed" });

  const contextHash = await sha256(responseBasis({ requestId, organizationId, visibleProjectId, memoryProjectId, projectKey,
    decisionType, queryHash, retrievalLogId, contextStatus, approvedMemoryItemIds, highlights }));
  return json(200, { ok: true, schema_version: 1, purpose: PURPOSE, request_id: requestId,
    organization_id: organizationId, visible_project_id: visibleProjectId, memory_project_id: memoryProjectId,
    project_key: projectKey, decision_type: decisionType, query_hash: queryHash, context_status: contextStatus,
    context_hash: contextHash, retrieval_log_id: retrievalLogId, approved_memory_item_ids: approvedMemoryItemIds,
    highlights, canonical_memory_written: false });
});
