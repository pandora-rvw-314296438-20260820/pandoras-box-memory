import { createOperationsEndpoint } from "@/supabase/functions/pandora-memory-bridge/operations-http.mjs";
import { authorizeMemoryWorkload, getMemoryAdminClient, jsonResponse } from "@/lib/server/pandora-memory-runtime";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  try {
    const client = getMemoryAdminClient();
    return await createOperationsEndpoint({ authorize: authorizeMemoryWorkload, client })(request);
  } catch { return jsonResponse({ ok: false, error: "memory_runtime_unavailable", outcomeUnknown: false }, 503); }
}
