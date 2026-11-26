import { readFile } from "node:fs/promises";
const read = (path) => readFile(new URL("../" + path, import.meta.url), "utf8");
const projectos = await read("lib/services/projectos-memory-bridge-client.ts");
const projectosRequired = [
  'const CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn";',
  "process.env.PANDORA_MEMORY_PROJECTOS_BRIDGE_URL",
  "CANONICAL_MEMORY_PROJECT_REF}.supabase.co",
  "const SAFE_READ_MAX_ATTEMPTS = 3;",
  'payload.action === "health" || payload.action === "search"',
];
for (const marker of projectosRequired) if (!projectos.includes(marker)) throw new Error("ProjectOS legacy bridge contract missing: " + marker);
if (projectos.includes("NEXT_PUBLIC_SUPABASE_URL")) throw new Error("Public Supabase config cannot control ProjectOS bridge.");
const runtime = await read("lib/server/pandora-memory-runtime.ts");
const routes = await Promise.all([
  "app/api/pandora/health/route.ts", "app/api/pandora/memory/search/route.ts",
  "app/api/pandora/memory/evidence-candidates/route.ts", "app/api/pandora/operations-memory/route.ts",
  "app/api/pandora/growth-learning/route.ts",
].map(read));
if (!runtime.includes('CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn"') || !runtime.includes("SUPABASE_SECRET_KEY")) throw new Error("Pandora Vercel runtime must bind to dedicated Sydney Memory.");
if (runtime.includes("xyefkykwuppbweabvvmk") || runtime.includes("/functions/v1/")) throw new Error("Pandora runtime must not bind to PLP or quota-limited Edge functions.");
for (const route of routes) if (route.includes("proxyPandoraMemoryRequest") || route.includes("xyefkykwuppbweabvvmk")) throw new Error("Pandora route still uses the retired Tokyo staging proxy.");
console.log("ProjectOS legacy Edge boundary and Pandora direct Vercel gateway contracts are verified.");
