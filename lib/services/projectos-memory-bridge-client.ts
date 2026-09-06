import { NextResponse, type NextRequest } from "next/server";

const MAX_RESPONSE_BYTES = 500_000;
const TIMEOUT_MS = 8_000;

// Security boundary: configuration may change the deployment URL only within
// the canonical Memory Supabase project. A stale/foreign public Supabase URL
// can never redirect ProjectOS service-principal authentication.
const CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn";
const CANONICAL_BRIDGE_PATH = "/functions/v1/pandora-projectos-bridge";
const DEFAULT_BRIDGE_URL =
  `https://${CANONICAL_MEMORY_PROJECT_REF}.supabase.co${CANONICAL_BRIDGE_PATH}`;

function bridgeUrl() {
  const configured =
    process.env.PANDORA_MEMORY_PROJECTOS_BRIDGE_URL?.trim() ||
    DEFAULT_BRIDGE_URL;
  const url = new URL(configured);
  if (
    url.protocol !== "https:" ||
    url.hostname !== `${CANONICAL_MEMORY_PROJECT_REF}.supabase.co` ||
    url.pathname !== CANONICAL_BRIDGE_PATH ||
    url.username ||
    url.password ||
    url.search ||
    url.hash
  ) {
    throw new Error("invalid_memory_bridge_url");
  }
  return url.toString();
}

function workloadToken(request: NextRequest) {
  const dedicated = request.headers.get("x-pandora-vercel-oidc")?.trim();
  if (dedicated) return dedicated;
  const authorization = request.headers.get("authorization") ?? "";
  const [scheme, token] = authorization.split(" ");
  return scheme?.toLowerCase() === "bearer" && token ? token : null;
}

async function readBounded(response: Response) {
  const declared = Number(response.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > MAX_RESPONSE_BYTES) {
    throw new Error("response_too_large");
  }

  const reader = response.body?.getReader();
  if (!reader) {
    const text = await response.text();
    if (new TextEncoder().encode(text).byteLength > MAX_RESPONSE_BYTES) {
      throw new Error("response_too_large");
    }
    return text;
  }

  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      size += value.byteLength;
      if (size > MAX_RESPONSE_BYTES) {
        await reader.cancel("response_too_large");
        throw new Error("response_too_large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

export async function proxyProjectOSMemoryRequest(
  request: NextRequest,
  payload: Record<string, unknown>,
) {
  const token = workloadToken(request);
  if (!token) {
    return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(bridgeUrl(), {
      method: "POST",
      cache: "no-store",
      redirect: "error",
      headers: {
        // Supabase reserves Authorization for its gateway. Carry the bounded
        // Vercel workload token in a dedicated internal header so the custom-
        // auth Edge boundary receives it byte-for-byte.
        "x-pandora-vercel-oidc": token,
        accept: "application/json",
        "content-type": "application/json",
        "user-agent": "Pandora-Memory-ProjectOS-Proxy/1.2",
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const text = await readBounded(response);
    return new NextResponse(
      text || JSON.stringify({ ok: false, error: "empty_bridge_response" }),
      {
        status: response.status,
        headers: {
          "content-type": "application/json; charset=utf-8",
          "cache-control": "no-store",
        },
      },
    );
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "AbortError";
    return NextResponse.json(
      { ok: false, error: timedOut ? "bridge_timeout" : "bridge_unavailable" },
      { status: 503 },
    );
  } finally {
    clearTimeout(timeout);
  }
}
