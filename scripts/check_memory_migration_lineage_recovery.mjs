#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const migrationDir = resolve(root, "supabase/migrations");
const evidencePath = resolve(root, "docs/capabilities/evidence/MEMORY_MIGRATION_LINEAGE_RECOVERY_2026-09-01.json");
const evidence = JSON.parse(readFileSync(evidencePath, "utf8"));
function fail(message) { throw new Error(message); }
function assert(condition, message) { if (!condition) fail(message); }
function sha256(bytes) { return createHash("sha256").update(bytes).digest("hex"); }
function gitBlobSha1(bytes) { return createHash("sha1").update(Buffer.concat([Buffer.from(`blob ${bytes.length}\0`), bytes])).digest("hex"); }
function migrationName(row) {
  const prefix = `${row.version}_`;
  assert(row.filename.startsWith(prefix) && row.filename.endsWith(".sql"), `legacy filename/version mismatch: ${row.filename}`);
  return row.filename.slice(prefix.length, -4);
}

assert(evidence.schemaVersion === "1.3", "unexpected evidence schema version");
assert(evidence.memoryProjectRef === "ivmvufhcsezyhczzondn", "Memory project ref changed");
assert(evidence.liveMigrationLedger.appliedCount === 85, "live applied count must remain 85");
assert(evidence.liveMigrationLedger.latestVersion === "20260831211258", "latest live migration changed");
const migrationTree = execFileSync("git", ["rev-parse", "HEAD:supabase/migrations"], { cwd: root, encoding: "utf8" }).trim();
assert(migrationTree === evidence.sourceSnapshot.migrationTreeSha, `migration tree mismatch: ${migrationTree}`);
execFileSync("git", ["merge-base", "--is-ancestor", evidence.sourceSnapshot.sourceRecoveryCommitSha, "HEAD"], { cwd: root, stdio: "ignore" });

const actualFiles = readdirSync(migrationDir).filter((name) => name.endsWith(".sql")).sort();
assert(actualFiles.length === 55, `expected 55 migration files, got ${actualFiles.length}`);
assert(evidence.sourceStateAfterRecovery.migrationFiles === 55, "evidence migration file count stale");
assert(evidence.sourceStateAfterRecovery.exactAppliedFiles === 55, "exact applied source count stale");
assert(evidence.sourceStateAfterRecovery.missingAppliedFiles === 30, "missing applied count stale");
assert(evidence.sourceStateAfterRecovery.pendingUnappliedFiles === 0, "pending source must remain zero");
assert(evidence.liveMigrationLedger.appliedCount === evidence.sourceStateAfterRecovery.exactAppliedFiles + evidence.sourceStateAfterRecovery.missingAppliedFiles, "applied/source arithmetic mismatch");
const expectedFiles = new Set();
assert(evidence.knownExactApplied.length === 4, "known exact migration count changed");
for (const item of evidence.knownExactApplied) {
  const bytes = readFileSync(resolve(migrationDir, item.filename));
  assert(bytes.length === item.bytes, `byte mismatch: ${item.filename}`);
  assert(sha256(bytes) === item.sha256, `sha256 mismatch: ${item.filename}`);
  expectedFiles.add(item.filename);
}

const boundary = evidence.legacyRecoveryBoundary;
assert(boundary.legacyAppliedCount === 52, "legacy applied count changed");
assert(boundary.candidateSafeCount === 40, "safe legacy count must be 40");
assert(boundary.quarantinedCount === 12, "quarantined legacy count must be 12");
assert(boundary.recoveredCandidateSafeCount === 22, "recovered legacy-safe count must be 22");
assert(boundary.remainingCandidateSafeCount === 18, "remaining legacy-safe count must be 18");
assert(boundary.candidateSafeCount + boundary.quarantinedCount === boundary.legacyAppliedCount, "legacy partition arithmetic mismatch");
assert(boundary.recoveredCandidateSafeCount + boundary.remainingCandidateSafeCount === boundary.candidateSafeCount, "safe recovery arithmetic mismatch");
assert(boundary.fullManifestBytes === 6328, "legacy full manifest bytes changed");
assert(boundary.fullManifestSha256 === "cd39ac8230a3644f3ff028471fb2b2874cd0050a8a4513d02f26d5ef6de73e6a", "legacy full manifest digest changed");
assert(boundary.safeManifestBytes === 4778, "safe manifest bytes changed");
assert(boundary.safeManifestSha256 === "c12bfeadb8753524d22020d7d4d82c0d5f1d6b4b1fc4ebff6e880a9d552a07f6", "safe manifest digest changed");
assert(boundary.quarantineManifestBytes === 1549, "quarantine manifest bytes changed");
assert(boundary.quarantineManifestSha256 === "9452c5cd5971011da16ff9c23510286f7e8e4fb62db1601f337bc4700476eb1c", "quarantine manifest digest changed");
assert(boundary.recoveredManifestBytes === 2662, "recovered manifest bytes changed");
assert(boundary.recoveredManifestSha256 === "2f0cf1f7a573d680f0bc42cff7d6f195024cb9ce73c9c4bd38b73ffb25dacc6d", "recovered manifest digest changed");
assert(boundary.remainingSafeManifestBytes === 2115, "remaining-safe manifest bytes changed");
assert(boundary.remainingSafeManifestSha256 === "6502acd5688f9e0bf46205894e50f6247a6aae9c5864057088cbda2a26b5fa0b", "remaining-safe manifest digest changed");
const expectedQuarantine = ["20260623006600","20260627040000","20260731111248","20260801163126","20260803111852","20260807055209","20260807081540","20260807082820","20260807084620","20260807085215","20260807085935","20260807090844"];
assert(JSON.stringify(boundary.quarantinedVersions) === JSON.stringify(expectedQuarantine), "quarantine version set changed");
assert(boundary.recoveredSafe.length === 22, "recovered legacy row count changed");
const recoveredVersions = new Set();
const recoveredManifestRows = [];
for (const row of boundary.recoveredSafe) {
  assert(!recoveredVersions.has(row.version), `duplicate recovered legacy version: ${row.version}`);
  assert(!expectedQuarantine.includes(row.version), `quarantined version materialized: ${row.version}`);
  recoveredVersions.add(row.version);
  const bytes = readFileSync(resolve(migrationDir, row.filename));
  assert(bytes.length === row.bytes, `legacy byte mismatch: ${row.filename}`);
  const digest = sha256(bytes);
  assert(digest === row.sha256, `legacy sha256 mismatch: ${row.filename}`);
  assert(gitBlobSha1(bytes) === row.gitBlobSha1, `legacy git blob mismatch: ${row.filename}`);
  recoveredManifestRows.push(`${row.version}|${migrationName(row)}|${row.statementCount}|${bytes.length}|${digest}`);
  expectedFiles.add(row.filename);
}
const recoveredManifest = recoveredManifestRows.join("\n");
assert(Buffer.byteLength(recoveredManifest) === boundary.recoveredManifestBytes, "recovered provider manifest byte mismatch");
assert(sha256(Buffer.from(recoveredManifest)) === boundary.recoveredManifestSha256, "recovered provider manifest digest mismatch");
for (const version of expectedQuarantine) {
  assert(!actualFiles.some((filename) => filename.startsWith(`${version}_`)), `quarantined migration source is present: ${version}`);
}

const lastKnownExact = evidence.knownExactApplied.at(-1).version;
const postVault = [];
for (const filename of actualFiles) {
  const version = filename.split("_", 1)[0];
  if (version > lastKnownExact && version < "20260901000000") postVault.push(filename);
}
assert(postVault.length === 29, `expected 29 post-Vault exact files, got ${postVault.length}`);
assert(evidence.postVaultExactSource.appliedFiles === 29, "post-Vault evidence count stale");
const postVaultManifestRows = [];
for (const filename of postVault) {
  const bytes = readFileSync(resolve(migrationDir, filename));
  const digest = sha256(bytes);
  postVaultManifestRows.push(`supabase/migrations/${filename}|${bytes.length}|${digest}`);
  expectedFiles.add(filename);
}
const postVaultManifest = postVaultManifestRows.join("\n");
assert(Buffer.byteLength(postVaultManifest) === evidence.postVaultExactSource.manifestBytes, "post-Vault manifest byte mismatch");
assert(sha256(Buffer.from(postVaultManifest)) === evidence.postVaultExactSource.manifestSha256, "post-Vault manifest digest mismatch");
assert(evidence.postVaultExactSource.providerConcatenationManifestBytes === 4340, "provider-concatenation manifest byte proof changed");
assert(evidence.postVaultExactSource.providerConcatenationManifestSha256 === "03ce480d587bf767d60b565a18f3d462f9155a291952a8e93439eb3fa09b0a81", "provider-concatenation manifest digest proof changed");
assert(evidence.postVaultExactSource.multiStatementFiles === 4, "post-Vault multi-statement provider proof changed");
assert(evidence.postVaultExactSource.replayableSource === true, "post-Vault replayability proof changed");
assert(evidence.postVaultExactSource.serialization === "provider statements preserved in-order; multi-statement migrations add explicit semicolon/newline terminators; single-statement migrations preserve provider statement bytes plus one terminal newline", "post-Vault serialization contract changed");
assert(expectedFiles.size === 55, `expected source set has ${expectedFiles.size} files`);
assert(JSON.stringify([...expectedFiles].sort()) === JSON.stringify(actualFiles), "migration tree contains an unexpected or missing SQL file");
assert(evidence.pendingSource.length === 0, "pending unapplied migration source must remain absent");
assert(evidence.recovery.recoveredPostVaultFiles === 29, "recovered post-Vault count stale");
assert(evidence.recovery.recoveredLegacySafeFiles === 22, "legacy recovery count stale");
assert(evidence.recovery.remainingLegacyFiles === 30, "remaining legacy count stale");
assert(evidence.recovery.remainingCandidateSafeFiles === 18, "remaining safe count stale");
assert(evidence.recovery.quarantinedLegacyFiles === 12, "quarantined count stale");
assert(evidence.recovery.productionSchemaMutation === false, "production mutation must remain false");
assert(evidence.recovery.productionReplayAuthorized === false, "production replay must remain unauthorized");
process.stdout.write("Memory migration lineage checkpoint valid: 55/85 exact source; legacy boundary 40 safe / 12 quarantined; 22 safe restored / 18 safe pending.\n");
