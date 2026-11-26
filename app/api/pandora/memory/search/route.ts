import { ALLOWED_SEARCH_KEYS } from "@/supabase/functions/pandora-memory-search/handler";
import { jsonResponse, readBoundedJson, runMemorySearch } from "@/lib/server/pandora-memory-runtime";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  if (request.headers.has("origin")) return jsonResponse({ ok: false, error: "browser_request_denied" }, 403);
  const url = new URL(request.url);
  if (url.search || url.hash) return jsonResponse({ ok: false, error: "route_not_found" }, 404);
  const parsed = await readBoundedJson(request, 64 * 1024);
  if (!parsed.ok) return parsed.response;
  const filtered = Object.fromEntries(Object.entries(parsed.body).filter(([key]) => ALLOWED_SEARCH_KEYS.has(key)));
  try { return await runMemorySearch(request, { ...filtered, action: "search" }); }
  catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable" }, 503); }
}
