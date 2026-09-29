
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const read = (relativePath) => fs.readFileSync(path.resolve(process.cwd(), relativePath), "utf8");

const growth = read("supabase/migrations/20260930013000_growth_approved_memory_context_v1.sql");
const review = read("supabase/migrations/20260620000900_memory_review_decision_append_rpc.sql");
const persist = read("supabase/migrations/20260903075000_memory_review_persistence_lineage_idempotency_v1.sql");
const typed = read("supabase/migrations/20260913032000_m5_typed_memory_records_v1.sql");
const retrieval = read("supabase/migrations/20260913143500_m5_task_aware_retrieval_v1.sql");

assert.match(review, /when 'approve_append' then 'approved_for_append'/);
assert.match(review, /when 'reject' then 'rejected'/);
assert.match(review, /approval changes review state only; it never persists candidate memory rows/i);

assert.match(persist, /v_item\.status <> 'approved_for_append'/);
assert.match(persist, /valid approved append decision required/);
assert.match(persist, /only append operation is allowed/);

assert.match(typed, /M5 typed record semantics are immutable; append a successor instead/);
assert.match(typed, /superseded_at is not null/);
assert.match(typed, /invalid M5 supersession successor/);

assert.match(retrieval, /m\.approved_by is not null and m\.approved_at is not null/);
assert.match(retrieval, /m\.revoked_at is null and m\.superseded_at is null/);
assert.match(retrieval, /advisoryMemoryNeverAuthorizes',true/);
assert.match(retrieval, /retrievalDoesNotGrantExecutionAuthority',true/);

assert.match(growth, /memory_growth_approved_context_v1/);
assert.match(growth, /memory_task_context_v1/);
assert.match(growth, /'status','approved_current'/);
assert.match(growth, /'pendingExcluded',true/);
assert.match(growth, /'rejectedExcluded',true/);
assert.match(growth, /'revokedExcluded',true/);
assert.match(growth, /'supersededExcluded',true/);
assert.match(growth, /'canAuthorizeSpend',false/);
assert.match(growth, /'canMutateCampaigns',false/);
assert.match(growth, /'canPublish',false/);
assert.match(growth, /'operationsRoomRequired',false/);
assert.match(growth, /grant execute on function public\.memory_growth_approved_context_v1[\s\S]*to service_role/);
assert.doesNotMatch(growth, /pandora_ops_|spendAuthorized',true/);

console.log("growth approved Memory context contract PASS");
