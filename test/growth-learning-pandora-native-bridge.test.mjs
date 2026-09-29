import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const bridge = fs.readFileSync("supabase/functions/pandora-memory-bridge/index.ts", "utf8");
const migration = fs.readFileSync("supabase/migrations/20260929110000_growth_learning_pandora_native_identity_v1.sql", "utf8");

test("growth learning uses the Pandora-native bridge", () => {
  assert.match(bridge, /body\.action === "growth_learning"/);
  assert.match(bridge, /memory_ingest_growth_learning_v1/);
  assert.match(bridge, /data\.status !== "pending_review"/);
  assert.match(bridge, /data\.canonical_memory_written !== false/);
  assert.doesNotMatch(bridge, /pandora-projectos-learning/);
});

test("growth learning intake uses canonical Pandora identity without approval authority", () => {
  assert.match(migration, /pandora-mcpmaster-production/);
  assert.match(migration, /p_payload->>'product_key' is distinct from 'pandora'/);
  assert.match(migration, /source='pandora-post-task'/);
  assert.match(migration, /candidate_type='pandora_outcome'/);
  assert.match(migration, /can_approve is distinct from false/);
  assert.match(migration, /canonical_memory_written',false/);
  assert.doesNotMatch(migration, /projectos-mcpmaster-production|projectos-post-task|projectos_outcome/);
});
