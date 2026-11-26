import type { Principal } from "./pandora-memory-workload-auth";

type JsonRecord = Record<string, unknown>;
type AdminClient = { rpc: (name: string, args: Record<string, unknown>) => Promise<{data: unknown; error: any}> };
const isRecord = (value: unknown): value is JsonRecord =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  } });
const errorCode = (error: unknown): string =>
  typeof error === "object" && error !== null && "code" in error
    ? String((error as {code?: unknown}).code ?? "") : "";

export async function ingestGrowthLearning(
  body: JsonRecord,
  principal: Principal,
  supabase: AdminClient,
): Promise<Response> {
  // The existing SQL contract is deliberately production-principal-only.
  // Preview credentials must never be rewritten to the production principal.
  if (principal.principal_key !== "pandora-mcpmaster-production" || principal.environment !== "production") {
    return respond({ ok: false, error: "growth_learning_production_identity_required" }, 403);
  }
  if (!principal.scopes.includes("memory:write")) {
    return respond({ ok: false, error: "scope_not_allowed" }, 403);
  }
  const payload = body.payload;
  if (!isRecord(payload) || Object.keys(body).some((key) => !["action", "payload"].includes(key))) {
    return respond({ ok: false, error: "growth_learning_payload_invalid" }, 400);
  }
  const { data, error } = await supabase.rpc("memory_ingest_growth_learning_v1", {
    p_memory_user_id: principal.memory_user_id,
    p_payload: payload,
  });
  if (error) {
    const code = errorCode(error);
    const status = code === "42501" ? 403 : code === "22023" ? 400 : code === "23505" ? 409 : 503;
    return respond({
      ok: false,
      error: status === 403 ? "growth_learning_denied"
        : status === 400 ? "growth_learning_invalid"
        : status === 409 ? "growth_learning_conflict"
        : "growth_learning_unavailable",
    }, status);
  }
  if (!isRecord(data) || data.ok !== true || data.status !== "pending_review"
      || data.canonical_memory_written !== false || data.review_required !== true) {
    return respond({ ok: false, error: "growth_learning_receipt_invalid" }, 503);
  }
  return respond({ ok: true, project: "pandora-memory-engine", action: "growth_learning", data });
}
