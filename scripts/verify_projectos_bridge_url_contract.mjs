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
];

for (const fragment of required) {
  if (!source.includes(fragment)) {
    throw new Error(`ProjectOS bridge URL contract missing: ${fragment}`);
  }
}

if (/NEXT_PUBLIC_SUPABASE_URL/.test(source)) {
  throw new Error("Public Supabase configuration must not control the ProjectOS bridge.");
}

console.log("ProjectOS bridge URL remains bound to the canonical Memory project.");
