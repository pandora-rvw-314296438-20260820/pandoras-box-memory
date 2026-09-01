#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const evidence = JSON.parse(readFileSync(resolve(root, "docs/capabilities/evidence/MEMORY_MIGRATION_LINEAGE_RECOVERY_2026-09-01.json"), "utf8"));
const migrationsDir = resolve(root, "supabase/migrations");
const fail = (message) => { throw new Error(message); };
const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const pathFor = (filename) => `supabase/migrations/${filename}`;

if (evidence.schemaVersion !== "1.1") fail("unexpected lineage evidence schema");
if (evidence.memoryProjectRef !== "ivmvufhcsezyhczzondn") fail("unexpected Memory project ref");
if (evidence.liveMigrationLedger?.appliedCount !== 85) fail("live applied migration count changed; refresh provider evidence");
if (evidence.sourceStateBeforeRecovery?.missingAppliedFiles !== 81) fail("pre-recovery migration debt changed");
if (evidence.sourceStateAfterRecovery?.exactAppliedFiles !== 33) fail("expected 33 exact applied migration sources");
if (evidence.sourceStateAfterRecovery?.missingAppliedFiles !== 52) fail("expected 52 quarantined legacy migration gaps");
if (!Array.isArray(evidence.knownExactApplied) || evidence.knownExactApplied.length !== 4) fail("known exact applied source set must contain four migrations");
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

const actualFiles = readdirSync(migrationsDir).filter((name) => name.endsWith(".sql")).sort();
const postVault = [];
for (const filename of actualFiles) {
  const match = filename.match(/^(\d{14})_(.+)\.sql$/);
  if (!match) fail(`invalid migration filename ${filename}`);
  const [, version] = match;
  if (seenVersions.has(version)) continue;
  if (version > evidence.knownExactApplied.at(-1).version && version < "20260901000000") {
    seenVersions.add(version);
    expectedFiles.add(filename);
    const bytes = readFileSync(resolve(migrationsDir, filename));
    postVault.push({ path: pathFor(filename), bytes: bytes.length, sha256: digest(bytes) });
  }
}

if (postVault.length !== evidence.postVaultExactSource?.appliedFiles) {
  fail(`post-Vault exact source count mismatch: ${postVault.length}`);
}
if (evidence.postVaultExactSource?.providerConcatenationManifestBytes !== 4340 || evidence.postVaultExactSource?.providerConcatenationManifestSha256 !== "03ce480d587bf767d60b565a18f3d462f9155a291952a8e93439eb3fa09b0a81") {
  fail("provider statement-concatenation proof changed; refresh provider evidence");
}
if (evidence.postVaultExactSource?.multiStatementFiles !== 4 || evidence.postVaultExactSource?.replayableSource !== true) {
  fail("replayable post-Vault source topology changed");
}
if (evidence.postVaultExactSource?.serialization !== "provider statements preserved in-order; multi-statement migrations add explicit semicolon/newline terminators; single-statement migrations preserve provider statement bytes plus one terminal newline") {
  fail("post-Vault serialization contract changed");
}
const manifest = postVault
  .sort((a, b) => a.path.localeCompare(b.path))
  .map((row) => `${row.path}|${row.bytes}|${row.sha256}`)
  .join("\n");
if (Buffer.byteLength(manifest) !== evidence.postVaultExactSource.manifestBytes) {
  fail("post-Vault manifest byte count mismatch");
}
if (digest(Buffer.from(manifest)) !== evidence.postVaultExactSource.manifestSha256) {
  fail("post-Vault migration manifest SHA-256 mismatch");
}

for (const filename of evidence.pendingSource) {
  const match = filename.match(/^(\d{14})_/);
  if (!match || seenVersions.has(match[1])) fail(`invalid or duplicate pending migration ${filename}`);
  seenVersions.add(match[1]);
  expectedFiles.add(filename);
}

const expectedSorted = [...expectedFiles].sort();
if (JSON.stringify(actualFiles) !== JSON.stringify(expectedSorted)) {
  fail(`migration source set changed without refreshed live-lineage evidence: ${JSON.stringify(actualFiles)}`);
}
if (actualFiles.length !== evidence.sourceStateAfterRecovery.migrationFiles) {
  fail("migration source file count mismatch");
}
if (evidence.liveMigrationLedger.appliedCount - evidence.sourceStateAfterRecovery.exactAppliedFiles !== evidence.recovery.remainingLegacyFiles) {
  fail("legacy recovery debt arithmetic mismatch");
}
if (evidence.recovery.productionSchemaMutation !== false || evidence.recovery.productionReplayAuthorized !== false) {
  fail("recovery evidence must not authorize production mutation/replay");
}

console.log(JSON.stringify({
  ok: true,
  liveApplied: evidence.liveMigrationLedger.appliedCount,
  exactAppliedSource: evidence.sourceStateAfterRecovery.exactAppliedFiles,
  postVaultExactFiles: postVault.length,
  postVaultManifestSha256: evidence.postVaultExactSource.manifestSha256,
  legacyFilesRemaining: evidence.recovery.remainingLegacyFiles,
  pendingSource: evidence.pendingSource,
}, null, 2));
