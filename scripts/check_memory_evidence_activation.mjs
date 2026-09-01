import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";

const bridgePath = "supabase/functions/pandora-projectos-bridge/index.ts";
const manifestPath =
  "recovery/evidence/memory-evidence-intake-activation-release-manifest.md";
const workflowPath = ".github/workflows/memory-evidence-intake.yml";

const bridge = fs.readFileSync(bridgePath, "utf8");
const manifest = fs.readFileSync(manifestPath, "utf8");
const workflow = fs.readFileSync(workflowPath, "utf8");

for (const marker of [
  'body.action === "submit_evidence_candidate"',
  'principal.scopes.includes("memory:write")',
  '.from("pandora_project_grants")',
  '.eq("can_propose", true)',
  '.eq("is_active", true)',
  '.is("revoked_at", null)',
  'canonical_memory_written: false',
  'status: "pending_review"',
]) {
  assert.ok(bridge.includes(marker), `bridge activation marker missing: ${marker}`);
}

for (const path of [bridgePath, manifestPath, "scripts/check_memory_evidence_activation.mjs"]) {
  assert.ok(workflow.includes(path), `workflow path filter missing: ${path}`);
}
assert.ok(workflow.includes("node scripts/check_memory_evidence_activation.mjs"));

for (const stalePath of [
  "supabase/migrations/20260820113000_enable_projectos_evidence_candidate_write_scope.sql",
  "supabase/recovery/20260820_disable_projectos_evidence_candidate_write_scope.sql",
]) {
  assert.ok(!workflow.includes(stalePath), `stale never-applied activation path remains: ${stalePath}`);
}

const bridgeSha256 = createHash("sha256").update(bridge, "utf8").digest("hex");
assert.ok(
  manifest.includes(`Candidate bridge raw SHA-256: \`${bridgeSha256}\``),
  "manifest is not bound to the exact candidate bridge bytes",
);

for (const marker of [
  "CURRENT LIVE BASELINE / REVIEW-GATED",
  "pandora-rvw-314296438-20260820/pandoras-box-memory",
  "pandora-projectos-bridge@16",
  "3c5857fa787cbfc039100722d32aacfea080743ba6c5b998fdf6854d3467a18b",
  "verify_jwt=false",
  "projectos-mcpmaster-production",
  "memory:health`, `memory:read`, `memory:write",
  "real_life",
  "mcpmaster-pandoras-box",
  "7c686cbd-d968-49d5-86cc-918f5e777bd2",
  "can_read=true",
  "can_propose=true",
  "can_approve=false",
  "20260820113000` is absent from live migration history",
  "No scope mutation in this PR",
  "No automatic canonical Memory promotion",
]) {
  assert.ok(manifest.includes(marker), `manifest marker missing: ${marker}`);
}

assert.ok(!manifest.includes("banataosystems/pandoras-box-memory"));
console.log("Current Memory evidence-intake activation and rollback contract: PASS");
