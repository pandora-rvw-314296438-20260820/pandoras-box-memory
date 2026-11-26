import "server-only";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { authorize } from "./pandora-memory-workload-auth";
import { createSearchEndpoint } from "@/supabase/functions/pandora-memory-search/handler";

export const CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn";
export const CANONICAL_MEMORY_SUPABASE_URL = `https://${CANONICAL_MEMORY_PROJECT_REF}.supabase.co`;

let cachedAdmin: SupabaseClient | null = null;
const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers });
}

export function getMemoryAdminClient(): SupabaseClient {
  const rawUrl = process.env.PANDORA_MEMORY_SUPABASE_URL
    || process.env.SUPABASE_URL
    || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secret = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!rawUrl || !secret) throw new Error("MEMORY_RUNTIME_CONFIGURATION_DENIED");
  let parsed: URL;
  try { parsed = new URL(rawUrl); } catch { throw new Error("MEMORY_RUNTIME_CONFIGURATION_DENIED"); }
  if (parsed.protocol !== "https:" || parsed.origin !== CANONICAL_MEMORY_SUPABASE_URL
      || parsed.pathname !== "/" || parsed.search || parsed.hash || parsed.username || parsed.password) {
    throw new Error("MEMORY_RUNTIME_TARGET_DENIED");
  }
  if (!cachedAdmin) {
    cachedAdmin = createClient(CANONICAL_MEMORY_SUPABASE_URL, secret, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
      global: { headers: { "x-application-name": "Pandora-Memory-Vercel-Gateway/1.0" } },
    });
  }
  return cachedAdmin;
}

export function authorizeMemoryWorkload(request: Request, client: SupabaseClient = getMemoryAdminClient()) {
  return authorize(request, client);
}

export function createMemorySearchEndpoint() {
  const client = getMemoryAdminClient();
  return createSearchEndpoint({ authorize: authorizeMemoryWorkload, client });
}

export function workloadHeaders(request: Request): Headers {
  const headers = new Headers({ "content-type": "application/json" });
  const token = request.headers.get("x-pandora-vercel-oidc");
  const authorization = request.headers.get("authorization");
  if (token) headers.set("x-pandora-vercel-oidc", token);
  else if (authorization) headers.set("authorization", authorization);
  return headers;
}

export async function readBoundedJson(
  request: Request,
  maxBytes: number,
): Promise<{ ok: true; body: Record<string, unknown> } | { ok: false; response: Response }> {
  const declared = request.headers.get("content-length");
  if (declared !== null && (!/^[0-9]+$/.test(declared) || Number(declared) > maxBytes)) {
    return { ok: false, response: jsonResponse({ ok: false, error: "payload_too_large" }, 413) };
  }
  if (request.signal?.aborted || !request.body) {
    return { ok: false, response: jsonResponse({ ok: false, error: "invalid_json" }, 400) };
  }
  let raw: string;
  try { raw = await request.text(); } catch {
    return { ok: false, response: jsonResponse({ ok: false, error: "invalid_json" }, 400) };
  }
  if (new TextEncoder().encode(raw).byteLength > maxBytes) {
    return { ok: false, response: jsonResponse({ ok: false, error: "payload_too_large" }, 413) };
  }
  let body: unknown;
  try { body = JSON.parse(raw); } catch {
    return { ok: false, response: jsonResponse({ ok: false, error: "invalid_json" }, 400) };
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return { ok: false, response: jsonResponse({ ok: false, error: "invalid_json" }, 400) };
  }
  return { ok: true, body: body as Record<string, unknown> };
}

export async function runMemorySearch(request: Request, body: Record<string, unknown>): Promise<Response> {
  const endpoint = createMemorySearchEndpoint();
  const forwarded = new Request(request.url, {
    method: "POST",
    headers: workloadHeaders(request),
    body: JSON.stringify(body),
  });
  return endpoint(forwarded);
}
