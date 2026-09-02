
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.110.9";

const INTEGRATION_KEY = "projectos-learning-bridge";
const PURPOSE = "projectos-planning-context-v1";
const PRINCIPAL_KEY = "projectos-mcpmaster-production";
const NAMESPACE = "real_life";
const MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";
const MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box";
const MAX_BODY_BYTES = 8 * 1024;
const MAX_CLOCK_SKEW_MS = 5 * 60_000;
const MAX_QUERY_LENGTH = 1000;
const MAX_ITEMS = 6;
const MAX_SUMMARY_BYTES = 4000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/;
const PROJECT_KEY = /^[a-z0-9][a-z0-9._-]{1,95}$/;
const APPROVED = new Set(["hard_canon", "soft_canon"]);
const STOP = new Set(["and","are","for","from","has","have","into","project","spec","the","this","with","your"]);

type JsonRecord = Record<string, unknown>;
const record = (value: unknown): JsonRecord => value && typeof value === "object" && !Array.isArray(value) ? value as JsonRecord : {};
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff" } });
const text = (value: unknown, max = 1000): string => typeof value === "string" && value.trim().length <= max ? value.trim() : "";

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
  let mismatch = 0;
  for (let index = 0; index < left.length; index += 1) mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return mismatch === 0;
};
const canonicalJson = (value: unknown): string => {
  if (value === null) return "null";
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (typeof value === "object") {
    const row = value as JsonRecord;
    return `{${Object.keys(row).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(row[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
};

const normalizedPrivacyText = (value: string): string => {
  let out = value.normalize("NFKC").replace(/[\u200B-\u200F\u2060\uFEFF]/g, "");
  for (let i = 0; i < 2; i += 1) {
    try { const decoded = decodeURIComponent(out); if (decoded === out) break; out = decoded; } catch { break; }
  }
  return out.slice(0, 20000);
};
const privacyReason = (value: string): string | null => {
  const input = normalizedPrivacyText(value);
  if (/AIza[0-9A-Za-z_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|sb_secret_[A-Za-z0-9_-]{20,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:password|passwd|secret|client_secret|api[_-]?key|access[_-]?token|refresh[_-]?token)\s*[:=]/i.test(input)) return "secret";
  if (/```(?:[a-z0-9_+.-]+)?\s*\n[\s\S]{20,}```/i.test(input)) return "raw_source_fence";
  if (/<\|(?:system|user|assistant)\|>/i.test(input) || (input.match(/^\s*(?:system|user|assistant)\s*:/gim) || []).length >= 2) return "prompt_transcript";
  const lines = input.split(/\r?\n/).filter((line) => line.trim());
  if (/\.env\b/i.test(input) && lines.some((line) => /^[A-Z][A-Z0-9_]{2,}\s*=/.test(line.trim()))) return "config_dump";
  if (lines.filter((line) => /^[A-Z][A-Z0-9_]{2,}\s*=/.test(line.trim())).length >= 2) return "config_dump";
  const codeLines = lines.filter((line) => /^(?:\s*(?:import|export|class|function|const|let|var|CREATE\s+TABLE|ALTER\s+TABLE|SELECT\s+|INSERT\s+|UPDATE\s+|DELETE\s+)|.*=>|\s*<\/?[A-Za-z][^>]*>)/i.test(line)).length;
  if (lines.length >= 3 && codeLines >= 3 && codeLines / lines.length >= 0.35) return "raw_source_dump";
  return null;
};
const searchTerms = (query: string): string[] => [...new Set((query.toLowerCase().match(/[a-z0-9][a-z0-9._-]{2,31}/g) || []).filter((term) => !STOP.has(term)))].slice(0, 8);
const safeRef = (value: unknown): string | null => {
  const normalized = text(value, 300);
  return normalized && !privacyReason(normalized) ? normalized : null;
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json(405, { ok: false, error: "method_not_allowed" });
  const declared = Number(request.headers.get("content-length") || 0);
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });
  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) return json(413, { ok: false, error: "payload_too_large" });

  let body: JsonRecord;
  try { body = record(JSON.parse(raw)); } catch { return json(400, { ok: false, error: "invalid_json" }); }
  const expectedKeys = ["memory_project_id","memory_project_key","nonce","organization_id","query","query_hash","schema_version","timestamp_ms","visible_project_id","visible_project_key"].sort();
  if (JSON.stringify(Object.keys(body).sort()) !== JSON.stringify(expectedKeys) || body.schema_version !== 1) return json(400, { ok: false, error: "invalid_schema" });

  const organizationId = text(body.organization_id, 64).toLowerCase();
  const visibleProjectId = text(body.visible_project_id, 64).toLowerCase();
  const visibleProjectKey = text(body.visible_project_key, 96).toLowerCase();
  const memoryProjectId = text(body.memory_project_id, 64).toLowerCase();
  const memoryProjectKey = text(body.memory_project_key, 96).toLowerCase();
  const query = text(body.query, MAX_QUERY_LENGTH);
  const queryHash = text(body.query_hash, 64).toLowerCase();
  const nonce = text(body.nonce, 64).toLowerCase();
  const timestampMs = Number(body.timestamp_ms);
  if (!UUID.test(organizationId) || !UUID.test(visibleProjectId) || !PROJECT_KEY.test(visibleProjectKey) || memoryProjectId !== MEMORY_PROJECT_ID || memoryProjectKey !== MEMORY_PROJECT_KEY || !query || !SHA256.test(queryHash) || !UUID.test(nonce) || !Number.isSafeInteger(timestampMs)) return json(400, { ok: false, error: "invalid_identity" });
  if (await sha256(query) !== queryHash) return json(400, { ok: false, error: "query_hash_mismatch" });
  if (Math.abs(Date.now() - timestampMs) > MAX_CLOCK_SKEW_MS) return json(401, { ok: false, error: "stale_or_invalid_timestamp" });
  if (request.headers.get("x-pandora-planning-timestamp") !== String(timestampMs) || request.headers.get("x-pandora-planning-nonce") !== nonce) return json(401, { ok: false, error: "header_binding_invalid" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!supabaseUrl || !serviceRole) return json(503, { ok: false, error: "service_not_configured" });
  const admin = createClient(supabaseUrl, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: credential, error: credentialError } = await admin.rpc("pandora_integration_credential", { p_integration_key: INTEGRATION_KEY });
  const credentialRow = record(credential);
  const baseSecret = text(credentialRow.secret_value, 512);
  const memoryUserId = text(credentialRow.memory_user_id, 64).toLowerCase();
  if (credentialError || !baseSecret || !UUID.test(memoryUserId) || credentialRow.is_active !== true) return json(503, { ok: false, error: "bridge_not_configured" });

  const purposeKey = await hmacHex(baseSecret, PURPOSE);
  const basis = [PURPOSE, organizationId, visibleProjectId, visibleProjectKey, memoryProjectId, memoryProjectKey, queryHash, nonce, String(timestampMs)].join("\n");
  const expectedSignature = await hmacHex(purposeKey, basis);
  const suppliedSignature = request.headers.get("x-pandora-planning-signature") || "";
  if (!constantTimeEqual(expectedSignature, suppliedSignature)) return json(401, { ok: false, error: "invalid_signature" });

  const requestHash = await sha256(basis);
  const { data: claimed, error: claimError } = await admin.rpc("memory_claim_planning_nonce_v1", { p_nonce: nonce, p_request_hash: requestHash, p_expires_at: new Date(timestampMs + MAX_CLOCK_SKEW_MS).toISOString() });
  if (claimError) return json(503, { ok: false, error: "replay_guard_unavailable" });
  if (claimed !== true) return json(409, { ok: false, error: "replay_detected" });

  const { data: project, error: projectError } = await admin.from("pandora_projects").select("id,project_key,memory_namespace,lifecycle_status").eq("id", MEMORY_PROJECT_ID).eq("project_key", MEMORY_PROJECT_KEY).eq("memory_namespace", NAMESPACE).eq("lifecycle_status", "active").maybeSingle();
  if (projectError) return json(503, { ok: false, error: "project_lookup_failed" });
  if (!project?.id) return json(403, { ok: false, error: "project_not_allowed" });
  const { data: grant, error: grantError } = await admin.from("pandora_project_grants").select("project_id").eq("principal_key", PRINCIPAL_KEY).eq("project_id", MEMORY_PROJECT_ID).eq("environment", "production").eq("is_active", true).eq("can_read", true).is("revoked_at", null).maybeSingle();
  if (grantError) return json(503, { ok: false, error: "project_grant_lookup_failed" });
  if (!grant?.project_id) return json(403, { ok: false, error: "project_not_allowed" });

  let itemQuery = admin.from("memory_items").select("id,title,body,canon_status,memory_type,source_summary,metadata,updated_at").eq("user_id", memoryUserId).eq("namespace", NAMESPACE).eq("project_id", MEMORY_PROJECT_ID).eq("is_active", true).in("canon_status", ["hard_canon","soft_canon"]).order("updated_at", { ascending: false }).limit(20);
  const terms = searchTerms(query);
  if (terms.length) itemQuery = itemQuery.or(terms.flatMap((term) => [`title.ilike.%${term}%`,`body.ilike.%${term}%`]).join(","));
  const { data: items, error: itemsError } = await itemQuery;
  if (itemsError) return json(503, { ok: false, error: "memory_query_failed" });

  const records: JsonRecord[] = [];
  let summaryBytes = 0;
  for (const rawItem of items || []) {
    const item = record(rawItem);
    const id = text(item.id, 64).toLowerCase();
    const canonStatus = text(item.canon_status, 32);
    const memoryType = text(item.memory_type, 64);
    const title = text(item.title, 300);
    const itemBody = text(item.body, 1800);
    if (!UUID.test(id) || !APPROVED.has(canonStatus) || !memoryType || !title || !itemBody) continue;
    const summary = `${title}: ${itemBody}`.replace(/\s+/g, " ").trim().slice(0, 1400);
    if (!summary || privacyReason(summary)) continue;
    const bytes = new TextEncoder().encode(summary).byteLength;
    if (summaryBytes + bytes > MAX_SUMMARY_BYTES) continue;
    summaryBytes += bytes;
    const metadata = record(item.metadata);
    const reviewRef = UUID.test(text(metadata.review_item_id, 64)) ? text(metadata.review_item_id, 64).toLowerCase() : null;
    const proofRef = safeRef(metadata.evidence_ref) || safeRef(item.source_summary);
    records.push({ id, memory_type: memoryType, canon_status: canonStatus, source_ref: safeRef(item.source_summary), review_ref: reviewRef, proof_ref: proofRef, summary });
    if (records.length >= MAX_ITEMS) break;
  }
  records.sort((left, right) => String(left.id).localeCompare(String(right.id)));

  const itemIds = records.map((item) => item.id);
  const { data: retrieval, error: retrievalError } = await admin.from("memory_retrieval_logs").insert({ user_id: memoryUserId, namespace: NAMESPACE, query_hash: queryHash, project_id: MEMORY_PROJECT_ID, memory_item_ids: itemIds, metadata: { principal: PRINCIPAL_KEY, source: PURPOSE, visible_project_id: visibleProjectId, visible_project_key: visibleProjectKey, organization_id: organizationId, approved_only: true, raw_query_persisted: false } }).select("id").maybeSingle();
  if (retrievalError || !retrieval?.id) return json(503, { ok: false, error: "retrieval_log_failed" });

  const digestBody = { schema_version: 1, organization_id: organizationId, visible_project_id: visibleProjectId, visible_project_key: visibleProjectKey, memory_project_id: MEMORY_PROJECT_ID, memory_project_key: MEMORY_PROJECT_KEY, query_hash: queryHash, nonce, retrieval_log_id: retrieval.id, context_used_candidate: records.length > 0, records };
  const responseDigest = await sha256(canonicalJson(digestBody));
  return json(200, { ok: true, ...digestBody, response_digest: responseDigest });
});
