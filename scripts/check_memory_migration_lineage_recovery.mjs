#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const evidence = JSON.parse(readFileSync(resolve(root, "docs/capabilities/evidence/MEMORY_MIGRATION_LINEAGE_RECOVERY_2026-09-01.json"), "utf8"));
const migrationsDir = resolve(root, "supabase/migrations");
const fail = (message) => { throw new Error(message); };
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");

if (evidence.schemaVersion !== "1.0") fail("unexpected lineage evidence schema");
if (evidence.memoryProjectRef !== "ivmvufhcsezyhczzondn") fail("unexpected Memory project ref");
if (evidence.liveMigrationLedger?.appliedCount !== 85) fail("live applied migration count changed; refresh provider evidence");
if (evidence.sourceStateBeforeRecovery?.missingAppliedFiles !== 81) fail("expected historical migration debt changed");
if (!Array.isArray(evidence.knownExactApplied) || evidence.knownExactApplied.length !== 4) fail("exact applied source set must contain four migrations");
if (!Array.isArray(evidence.pendingSource) || evidence.pendingSource.length !== 1) fail("pending source set changed");

const expectedFiles = new Set();
const seenVersions = new Set();
for (const row of evidence.knownExactApplied) {
  if (!/^\d{14}$/.test(row.version) || seenVersions.has(row.version)) fail(`invalid or duplicate version ${row.version}`);
  seenVersions.add(row.version);
  expectedFiles.add(row.filename);
  const bytes = readFileSync(resolve(migrationsDir, row.filename));
  if (bytes.length !== row.bytes) fail(`byte-size mismatch for ${row.filename}`);
  if (digest(bytes) !== row.sha256) fail(`sha256 mismatch for ${row.filename}`);
}
for (const filename of evidence.pendingSource) expectedFiles.add(filename);

const actualFiles = readdirSync(migrationsDir).filter((name) => name.endsWith(".sql")).sort();
const expectedSorted = [...expectedFiles].sort();
if (JSON.stringify(actualFiles) !== JSON.stringify(expectedSorted)) {
  fail(`migration source set changed without refreshed live-lineage evidence: ${JSON.stringify(actualFiles)}`);
}

if (evidence.liveMigrationLedger.appliedCount - evidence.knownExactApplied.length !== evidence.recovery.remainingHistoricalFiles) {
  fail("historical recovery debt arithmetic mismatch");
}
if (evidence.recovery.productionSchemaMutation !== false || evidence.recovery.productionReplayAuthorized !== false) {
  fail("recovery evidence must not authorize production mutation/replay");
}

console.log(JSON.stringify({
  ok: true,
  liveApplied: evidence.liveMigrationLedger.appliedCount,
  exactAppliedSource: evidence.knownExactApplied.length,
  historicalFilesRemaining: evidence.recovery.remainingHistoricalFiles,
  pendingSource: evidence.pendingSource,
}, null, 2));
