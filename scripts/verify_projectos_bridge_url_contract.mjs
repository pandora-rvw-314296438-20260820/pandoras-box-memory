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

const pandoraClient = await readFile(
  new URL("../lib/services/pandora-memory-bridge-client.ts", import.meta.url),
  "utf8",
);
const pandoraSearchRoute = await readFile(
  new URL("../app/api/pandora/memory/search/route.ts", import.meta.url),
  "utf8",
);
const pandoraHealthRoute = await readFile(
  new URL("../app/api/pandora/health/route.ts", import.meta.url),
  "utf8",
);
const pandoraEvidenceRoute = await readFile(
  new URL("../app/api/pandora/memory/evidence-candidates/route.ts", import.meta.url),
  "utf8",
);

const pandoraRequired = [
  'const CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn";',
  'const CANONICAL_BRIDGE_PATH = "/functions/v1/pandora-memory-bridge";',
  'const CANONICAL_SEARCH_PATH = "/functions/v1/pandora-memory-search";',
  "process.env.PANDORA_MEMORY_BRIDGE_URL",
  "process.env.PANDORA_MEMORY_SEARCH_URL",
  'url.hostname !== `${CANONICAL_MEMORY_PROJECT_REF}.supabase.co`',
  'throw new Error("invalid_memory_bridge_url")',
];

for (const fragment of pandoraRequired) {
  if (!pandoraClient.includes(fragment)) {
    throw new Error(`Pandora bridge/search URL contract missing: ${fragment}`);
  }
}

if (/NEXT_PUBLIC_SUPABASE_URL/.test(pandoraClient)) {
  throw new Error("Public Supabase configuration must not control the Pandora bridge/search client.");
}

if (!pandoraSearchRoute.includes('target: "search"') || !pandoraHealthRoute.includes('target: "search"')) {
  throw new Error("Pandora search and health routes must target pandora-memory-search.");
}

if (pandoraEvidenceRoute.includes('target: "search"')) {
  throw new Error("Pandora evidence-candidates route must remain on pandora-memory-bridge.");
}

console.log("ProjectOS and Pandora bridge/search URL and bounded read-retry contracts are verified.");
