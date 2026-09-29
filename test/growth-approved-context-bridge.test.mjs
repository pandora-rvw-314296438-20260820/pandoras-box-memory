import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const read = (relative) => fs.readFileSync(path.resolve(process.cwd(), relative), "utf8");
const bridge = read("supabase/functions/pandora-memory-bridge/index.ts");
const migration = read("supabase/migrations/20260930013000_growth_approved_memory_context_v1.sql");

test("growth context is authenticated before the dedicated non-Operations route", () => {
  const auth = bridge.indexOf("if (!authorization.ok) return authorization.error;");
  const route = bridge.indexOf('body.action === "growth_context"');
  assert.ok(auth >= 0 && route > auth);
  assert.match(bridge, /return growthApprovedContext\(body, authorization\.principal, supabase\)/);
  assert.doesNotMatch(
    bridge.slice(Math.max(0, route - 180), route + 240),
    /handleOperationsMemory/,
  );
});

test("growth context target and principal are server-owned", () => {
  assert.match(bridge, /GROWTH_MEMORY_PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2"/);
  assert.match(bridge, /GROWTH_MEMORY_PROJECT_KEY = "mcpmaster-pandoras-box"/);
  assert.match(bridge, /p_project_id: GROWTH_MEMORY_PROJECT_ID/);
  assert.match(bridge, /p_principal_key: PRINCIPAL_KEY/);
  assert.match(bridge, /principal\.memory_user_id/);
  assert.match(bridge, /growth_project_not_allowed/);
});

test("approved Memory receipt remains read-only and authority-denying", () => {
  assert.match(bridge, /approvedCurrentOnly === true/);
  assert.match(bridge, /retrievalDoesNotGrantExecutionAuthority === true/);
  assert.match(bridge, /canAuthorizeSpend === false/);
  assert.match(bridge, /canMutateCampaigns === false/);
  assert.match(bridge, /canPublish === false/);
  assert.match(bridge, /operationsRoomRequired === false/);
  assert.doesNotMatch(bridge, /canAuthorizeSpend === true|canMutateCampaigns === true|canPublish === true/);
});

test("retrieved records carry persisted review lineage and stable version hashes", () => {
  assert.match(migration, /m\.metadata->>'reviewItemId'/);
  assert.match(migration, /memoryVersionId'[\s\S]*digest\(convert_to\(coalesce\(m\.effective_at,m\.updated_at,m\.created_at\)::text,'utf8'\),'sha256'\)/);
  assert.match(migration, /'recordSha256'/);
  assert.match(migration, /m\.approved_by is not null/);
  assert.match(migration, /m\.approved_at is not null/);
  assert.match(migration, /m\.revoked_at is null/);
  assert.match(migration, /m\.superseded_at is null/);
});
