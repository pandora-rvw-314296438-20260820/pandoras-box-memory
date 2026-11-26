import { authorizeMemoryWorkload, getMemoryAdminClient, jsonResponse, readBoundedJson } from "@/lib/server/pandora-memory-runtime";
import { submitProjectOsEvidenceCandidate } from "@/lib/server/projectos-evidence-intake";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const MAX_BODY_BYTES = 16 * 1024;
const ALLOWED_KEYS = new Set([
  "namespace","project_id","project_key","title","summary","proof_stage","evidence_kind",
  "claim","evidence_refs","provenance","idempotency_key",
]);
export async function POST(request: Request) {
  if (request.headers.has("origin")) return jsonResponse({ ok: false, error: "browser_request_denied" }, 403);
  const url = new URL(request.url);
  if (url.search || url.hash) return jsonResponse({ ok: false, error: "route_not_found" }, 404);
  const parsed = await readBoundedJson(request, MAX_BODY_BYTES);
  if (!parsed.ok) return parsed.response;
  if (Object.keys(parsed.body).some((key) => !ALLOWED_KEYS.has(key))) {
    return jsonResponse({ ok: false, error: "unexpected_field" }, 400);
  }
  try {
    const client = getMemoryAdminClient();
    const authorization = await authorizeMemoryWorkload(request, client);
    if (!authorization.ok) return authorization.error;
    return await submitProjectOsEvidenceCandidate({ ...parsed.body, action: "submit_evidence_candidate" }, authorization.principal, client);
  } catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable" }, 503); }
}
