import { authorizeMemoryWorkload, getMemoryAdminClient, jsonResponse, readBoundedJson } from "@/lib/server/pandora-memory-runtime";
import { ingestGrowthLearning } from "@/lib/server/pandora-growth-learning";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  if (request.headers.has("origin")) return jsonResponse({ ok: false, error: "browser_request_denied" }, 403);
  const url = new URL(request.url);
  if (url.search || url.hash) return jsonResponse({ ok: false, error: "route_not_found" }, 404);
  const parsed = await readBoundedJson(request, 128 * 1024);
  if (!parsed.ok) return parsed.response;
  if (parsed.body.action !== "growth_learning") return jsonResponse({ ok: false, error: "action_not_allowed" }, 403);
  try {
    const client = getMemoryAdminClient();
    const authorization = await authorizeMemoryWorkload(request, client);
    if (!authorization.ok) return authorization.error;
    return await ingestGrowthLearning(parsed.body, authorization.principal, client);
  } catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable" }, 503); }
}
