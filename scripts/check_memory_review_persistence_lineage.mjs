#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { exit } from 'node:process';

const path = 'supabase/migrations/20260903075000_memory_review_persistence_lineage_idempotency_v1.sql';
const sql = readFileSync(path, 'utf8').replace(/\r\n/g,'\n');
const low = sql.toLowerCase();
const errors = [];
const need = (ok,msg) => { if (!ok) errors.push(msg); };

need(/create\s+or\s+replace\s+function\s+public\.memory_execute_approved_review_persistence\s*\(/i.test(sql),'function replacement missing');
need(low.includes('v_planned_operation_sha256'),'planned-operation digest missing');
need(low.includes("v_existing.id is distinct from p_review_item_id"),'replay review identity binding missing');
need(low.includes("persistence_execution_metadata->>'previewfingerprint'"),'stored preview fingerprint binding missing');
need(low.includes("persistence_execution_metadata->>'plannedoperationsha256'"),'stored operation digest binding missing');
need(low.includes("raise exception 'idempotency_conflict'"),'stable idempotency conflict missing');
need(low.includes("v_project_id := nullif(v_item.source_metadata->>'projectid','')::uuid"),'project lineage parse missing');
need(low.includes("v_candidate_id := nullif(v_item.source_metadata->>'candidateid','')::uuid"),'candidate lineage parse missing');
need(low.includes('if v_candidate_id is not null and v_project_id is null then'),'candidate/project dependency missing');
for (const predicate of ['c.id = v_candidate_id','c.user_id = v_user_id','c.namespace = v_item.namespace','c.project_id = v_project_id','c.source_ref = v_item.source_ref']) need(low.includes(predicate),`candidate lineage predicate missing: ${predicate}`);
need(/insert\s+into\s+public\.memory_items\s*\([\s\S]*?project_id\s*\)[\s\S]*?v_project_id\s*\)\s*;/i.test(sql),'memory_items project binding missing');
need(low.includes("'plannedoperationsha256', v_planned_operation_sha256"),'execution metadata digest missing');
need(low.includes("'projectid', v_project_id"),'execution metadata project binding missing');
need(!/\b(update|delete\s+from)\s+public\.memory_items\b/i.test(sql),'existing memory item mutation forbidden');
need(!/canon_status\s*=\s*'approved'|hard_canon|soft_canon/i.test(sql),'canonical promotion must remain separate');
for (const r of [/service[_-]?role[_-]?key\s*[:=]/i,/api[_-]?key\s*[:=]/i,/postgres(?:ql)?:\/\//i,/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/]) need(!r.test(sql),'literal credential pattern');

if (errors.length) {
  console.error('Memory review persistence lineage gate FAILED:');
  for (const error of errors) console.error(`  - ${error}`);
  exit(1);
}
console.log('Memory review persistence lineage gate passed.');
