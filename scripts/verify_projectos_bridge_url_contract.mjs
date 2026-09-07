import { readFile } from "node:fs/promises";

const source = await readFile(
  new URL("../lib/services/projectos-memory-bridge-client.ts", import.meta.url),
  "utf8",
);

const required = [
  'const CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn";',
  'process.env.PANDORA_MEMORY_PROJECTOS_BRIDGE_URL',
  'url.hostname !== `${CANONICAL_MEMORY_PROJECT_REF}.supabase.co`',
  'url.pathname !== CANONICAL_BRIDGE_PATH',
  'throw new Error("invalid_memory_bridge_url")',
  'const SAFE_READ_MAX_ATTEMPTS = 3;',
  'payload.action === "health" || payload.action === "search"',
  'const maxAttempts = safeToRetry ? SAFE_READ_MAX_ATTEMPTS : 1;',
  'status === 502',
  'error: "bridge_response_too_large"',
  'terminalError === "bridge_timeout" ? 504 : 503',
];

for (const fragment of required) {
  if (!source.includes(fragment)) {
    throw new Error(`ProjectOS bridge URL contract missing: ${fragment}`);
  }
}

if (/NEXT_PUBLIC_SUPABASE_URL/.test(source)) {
  throw new Error("Public Supabase configuration must not control the ProjectOS bridge.");
}

console.log("ProjectOS bridge URL and bounded read-retry contracts are verified.");
