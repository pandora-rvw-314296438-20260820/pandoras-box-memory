import { readFile, access, readdir } from "node:fs/promises";
import assert from "node:assert/strict";
const read = (path) => readFile(new URL("../" + path, import.meta.url), "utf8");
const runtime = await read("lib/server/pandora-memory-runtime.ts");
const auth = await read("lib/server/pandora-memory-workload-auth.ts");
const handler = await read("supabase/functions/pandora-memory-search/handler.ts");
const operations = await read("supabase/functions/pandora-memory-bridge/operations-bridge.mjs");
const health = await read("app/api/pandora/health/route.ts");
const search = await read("app/api/pandora/memory/search/route.ts");
const evidence = await read("app/api/pandora/memory/evidence-candidates/route.ts");
const operationsRoute = await read("app/api/pandora/operations-memory/route.ts");
const growthRoute = await read("app/api/pandora/growth-learning/route.ts");
const projectosEvidence = await read("app/api/projectos/memory/evidence-candidates/route.ts");
const stagingReadme = await read("ops/memory-cutover/tokyo/README.md");
assert.ok(runtime.includes('CANONICAL_MEMORY_PROJECT_REF = "ivmvufhcsezyhczzondn"'));
assert.ok(runtime.includes("SUPABASE_SECRET_KEY") && runtime.includes("PANDORA_MEMORY_SUPABASE_URL"));
assert.ok(!runtime.includes("xyefkykwuppbweabvvmk") && !runtime.includes("/functions/v1/"));
assert.ok(auth.includes("pandora-mcpmaster-preview") && auth.includes("pandora-mcpmaster-production"));
assert.ok(auth.includes("principal_key") && auth.includes("jwtVerify") && auth.includes("createRemoteJWKSet"));
assert.ok(!handler.includes("PRINCIPAL_KEY") && handler.includes("principal.principal_key"));
assert.ok(operations.includes("principal.principal_key") && operations.includes("principal.environment"));
assert.ok(!operations.includes("const PRINCIPAL ="));
for (const [name, source, markers] of [
  ["health", health, ["runMemorySearch", 'action: "health"']],
  ["search", search, ["runMemorySearch", 'action: "search"', "ALLOWED_SEARCH_KEYS"]],
  ["evidence", evidence, ["submitEvidenceCandidate", "authorizeMemoryWorkload", "getMemoryAdminClient"]],
  ["operations", operationsRoute, ["createOperationsEndpoint", "authorizeMemoryWorkload", "getMemoryAdminClient"]],
  ["growth", growthRoute, ["ingestGrowthLearning", "authorizeMemoryWorkload"]],
  ["ProjectOS evidence", projectosEvidence, ["submitProjectOsEvidenceCandidate", "authorizeMemoryWorkload", "getMemoryAdminClient"]],
]) for (const marker of markers) assert.ok(source.includes(marker), name + " route missing " + marker);
for (const source of [health, search, evidence, operationsRoute, growthRoute, projectosEvidence]) {
  assert.ok(!source.includes("proxyPandoraMemoryRequest") && !source.includes("xyefkykwuppbweabvvmk"));
}
assert.ok(stagingReadme.includes("NOT CANONICAL") && stagingReadme.includes("exists only as live objects"));
const migrationFiles = (await readdir(new URL("../supabase/migrations/", import.meta.url))).filter((f) => f.endsWith(".sql"));
const migrationText = (await Promise.all(migrationFiles.map((f) => read("supabase/migrations/" + f)))).join("\n");
for (const marker of ["pandora_memory_native", "pandora_memory_migration", "pandora_memory_runtime"]) assert.ok(!migrationText.includes(marker));
try { await access(new URL("../lib/services/pandora-memory-bridge-client.ts", import.meta.url)); throw new Error("obsolete Edge proxy client still exists"); }
catch (error) { if (error.message === "obsolete Edge proxy client still exists") throw error; }
console.log("Dedicated Sydney Memory Vercel gateway boundary: PASS");
