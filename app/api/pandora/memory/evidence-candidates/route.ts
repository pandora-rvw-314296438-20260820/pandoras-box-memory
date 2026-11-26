import { authorizeMemoryWorkload, getMemoryAdminClient, jsonResponse, readBoundedJson } from "@/lib/server/pandora-memory-runtime";
import { submitEvidenceCandidate } from "@/lib/server/pandora-memory-evidence-intake";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const MAX_BODY_BYTES = 16 * 1024;
export async function POST(request: Request) {
  if (request.headers.has("origin")) return jsonResponse({ ok: false, error: "browser_request_denied" }, 403);
  const url = new URL(request.url);
  if (url.search || url.hash) return jsonResponse({ ok: false, error: "route_not_found" }, 404);
  const parsed = await readBoundedJson(request, MAX_BODY_BYTES);
  if (!parsed.ok) return parsed.response;
  try {
    const client = getMemoryAdminClient();
    const authorization = await authorizeMemoryWorkload(request, client);
    if (!authorization.ok) return authorization.error;
    return await submitEvidenceCandidate({ ...parsed.body, action: "submit_evidence_candidate" }, authorization.principal, client);
  } catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable" }, 503); }
}
