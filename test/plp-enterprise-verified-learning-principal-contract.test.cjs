const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");

const migration = fs.readFileSync(
  "supabase/migrations/20260919091500_plp_enterprise_verified_learning_principal_v1.sql",
  "utf8",
);

test("PLP Enterprise gets an exact non-legacy workload identity", () => {
  assert.match(migration, /principal_key[\s\S]*plp-enterprise-production/i);
  assert.match(migration, /https:\/\/oidc\.vercel\.com\/mbanatao/);
  assert.match(migration, /https:\/\/vercel\.com\/mbanatao/);
  assert.match(
    migration,
    /owner:mbanatao:project:enterprise:environment:production/,
  );
  assert.doesNotMatch(migration, /ProjectOS/i);
  assert.doesNotMatch(migration, /min\s*\(\s*gp\.user_id\s*\)/i);
  assert.match(migration, /select gp\.user_id[\s\S]*limit 1;/i);
});

test("verified learning is enabled only for exact PLP project proposals", () => {
  assert.match(migration, /action_key='verified_learning\.propose'/);
  assert.match(migration, /set enabled=true/i);
  assert.match(
    migration,
    /project:5536b0be-cd7b-454e-ab27-57574539699d/,
  );
  assert.match(migration, /can_propose=true/i);
  assert.match(migration, /can_approve=false/i);
  assert.match(
    migration,
    /array\['fact','procedure','failure_lesson','outcome'\]/,
  );
});

test("Memory promotion remains review-governed", () => {
  assert.match(migration, /'canonicalWrite',false/);
  assert.match(migration, /'reviewRequired',true/);
  assert.doesNotMatch(migration, /can_approve\s*=\s*true/i);
});
