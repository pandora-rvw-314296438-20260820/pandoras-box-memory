import { jsonResponse, runMemorySearch } from "@/lib/server/pandora-memory-runtime";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function GET(request: Request) {
  const url = new URL(request.url);
  if (url.search || url.hash) return jsonResponse({ ok: false, error: "route_not_found" }, 404);
  try { return await runMemorySearch(request, { action: "health" }); }
  catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable" }, 503); }
}
