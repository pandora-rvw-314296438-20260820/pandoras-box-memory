#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const baselinePath = "docs/capabilities/evidence/MEMORY_CROSS_PROJECT_GENERALIZATION_BASELINE_2026-09-01.json";
const contractPath = "docs/verification/MEMORY_CROSS_PROJECT_GENERALIZATION_CONTRACT_2026-09-01.md";
const bridgePath = "supabase/functions/pandora-projectos-bridge/index.ts";

const forbiddenKeys = new Set([
  "user_id","userid","customer_id","customerid","customer","customer_name","organization_id","organizationid",
  "project_id","projectid","project_key","projectkey","projects","project_name","projectname","namespace",
  "source_ref","sourceref","source_event_id","sourceeventid","source_request_id","sourcerequestid","intake_id","intakeid",
  "candidate_id","candidateid","review_id","reviewid","memory_id","memoryid","item_id","itemid",
  "raw_excerpt","rawexcerpt","raw_content","rawcontent","normalized_text","normalizedtext",
  "raw_arguments","rawarguments","raw_results","rawresults","raw_errors","rawerrors",
  "email","phone","domain","repository","repo","repository_url","repositoryurl","url",
  "deployment_id","deploymentid","provider_resource_id","providerresourceid",
  "commit_sha","commitsha","tree_sha","treesha","source_commit_sha","sourcecommitsha",
  "source_path","sourcepath","evidence_ref","evidenceref","evidence_refs","evidencerefs","proof_ref","proofref","proof_refs","proofrefs",
  "token","access_token","pat","password","secret","api_key","apikey","service_role_key","servicerolekey","recovery_code","recoverycode"
]);

const allowedKeys = new Set([
  "task_class","tool_class","risk_class","failure_class","action_family","repair_family",
  "preconditions","failure_modes","verification_procedure","confidence","sample_count",
  "same_project_verified_source","governance_state","unresolved_conflict","target_scope"
]);

const reidPatterns = [
  {name:"email", re:/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i},
  {name:"url", re:/https?:\/\//i},
  {name:"github_repo", re:/\bgithub\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\b/i},
  {name:"vercel_deployment", re:/\bdpl_[A-Za-z0-9]{8,}\b/},
  {name:"uuid", re:/\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/i},
  {name:"sha40", re:/\b[0-9a-f]{40}\b/i},
  {name:"ipv4", re:/\b(?:\d{1,3}\.){3}\d{1,3}\b/}
];

function flatten(value, prefix = "", out = []) {
  if (Array.isArray(value)) {
    value.forEach((v, i) => flatten(v, `${prefix}[${i}]`, out));
  } else if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value)) {
      out.push({key:k, path:prefix ? `${prefix}.${k}` : k, value:v});
      flatten(v, prefix ? `${prefix}.${k}` : k, out);
    }
  }
  return out;
}

function textValues(value, out = []) {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) value.forEach(v => textValues(v, out));
  else if (value && typeof value === "object") Object.values(value).forEach(v => textValues(v, out));
  return out;
}

function assessGeneralizedCandidate(candidate) {
  const reasons = [];
  if (candidate.same_project_verified_source !== true) reasons.push("source_not_independently_verified_same_project");
  if (candidate.governance_state !== "approved_source") reasons.push("source_not_governance_approved");
  if (candidate.unresolved_conflict !== false) reasons.push("conflict_not_cleared");
  if (candidate.target_scope !== "same_namespace_cross_project") reasons.push("namespace_scope_not_explicitly_bounded");

  for (const entry of flatten(candidate)) {
    const normalized = entry.key.toLowerCase().replace(/[-\s]/g, "_");
    if (forbiddenKeys.has(normalized)) reasons.push(`forbidden_key:${entry.path}`);
    if (!allowedKeys.has(normalized) && entry.path.indexOf(".") === -1) reasons.push(`unknown_top_level_key:${entry.path}`);
  }

  for (const text of textValues(candidate)) {
    for (const {name,re} of reidPatterns) if (re.test(text)) reasons.push(`reidentification_pattern:${name}`);
  }

  const sampleCount = Number(candidate.sample_count ?? 0);
  if (!Number.isFinite(sampleCount) || sampleCount < 2) reasons.push("insufficient_aggregate_sample");
  if (typeof candidate.confidence !== "number" || candidate.confidence < 0 || candidate.confidence > 1) reasons.push("invalid_confidence");

  return {ok: reasons.length === 0, reasons:[...new Set(reasons)]};
}

function expectPass(name, value) {
  const result = assessGeneralizedCandidate(value);
  if (!result.ok) throw new Error(`${name} should pass: ${result.reasons.join(",")}`);
}
function expectReject(name, value, contains) {
  const result = assessGeneralizedCandidate(value);
  if (result.ok) throw new Error(`${name} should reject`);
  if (contains && !result.reasons.some(r => r.includes(contains))) {
    throw new Error(`${name} rejected for wrong reason: ${result.reasons.join(",")}`);
  }
}

function selfTest() {
  const safe = {
    same_project_verified_source:true,
    governance_state:"approved_source",
    unresolved_conflict:false,
    target_scope:"same_namespace_cross_project",
    task_class:"database_migration",
    tool_class:"supabase",
    risk_class:"high",
    failure_class:"migration_lineage_drift",
    repair_family:"reconcile_authoritative_ledger_before_replay",
    preconditions:["provider ledger readable","source mismatch proven"],
    failure_modes:["historical source missing","ledger unavailable"],
    verification_procedure:["compare version and statement digest","re-read provider state"],
    confidence:0.91,
    sample_count:4
  };
  expectPass("safe abstraction", safe);
  expectReject("project id", {...safe, project_id:"source-project"}, "forbidden_key");
  expectReject("project key", {...safe, projectKey:"customer-project"}, "forbidden_key");
  expectReject("namespace copy", {...safe, namespace:"real_life"}, "forbidden_key");
  expectReject("user id", {...safe, user_id:"source-user"}, "forbidden_key");
  expectReject("source ref", {...safe, source_ref:"projectos-plan:redacted"}, "forbidden_key");
  expectReject("raw excerpt", {...safe, raw_excerpt:"customer text"}, "forbidden_key");
  expectReject("evidence ref", {...safe, evidence_ref:"source-proof"}, "forbidden_key");
  expectReject("repo URL", {...safe, failure_modes:["see https://github.com/acme/customer-repo"]}, "reidentification_pattern");
  expectReject("deployment id", {...safe, repair_family:"rollback dpl_ABCDEFGH1234"}, "reidentification_pattern");
  expectReject("commit sha", {...safe, verification_procedure:["compare 0123456789abcdef0123456789abcdef01234567"]}, "reidentification_pattern");
  expectReject("email", {...safe, preconditions:["owner a@example.com approved"]}, "reidentification_pattern");
  expectReject("uuid", {...safe, preconditions:["record 123e4567-e89b-12d3-a456-426614174000"]}, "reidentification_pattern");
  expectReject("unapproved source", {...safe, governance_state:"pending_review"}, "source_not_governance_approved");
  expectReject("unverified source", {...safe, same_project_verified_source:false}, "source_not_independently_verified_same_project");
  expectReject("open conflict", {...safe, unresolved_conflict:true}, "conflict_not_cleared");
  expectReject("scope broadening", {...safe, target_scope:"all_namespaces"}, "namespace_scope_not_explicitly_bounded");
  expectReject("single episode", {...safe, sample_count:1}, "insufficient_aggregate_sample");
  console.log("PASS: adversarial cross-project abstraction self-tests");
}

function fullVerify() {
  const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
  const contract = fs.readFileSync(contractPath, "utf8");
  const bridge = fs.readFileSync(bridgePath, "utf8");

  const exact = [
    [baseline.no_duplication.generalization_playbook_pattern_abstract_tables_or_routines === 0, "baseline must prove zero parallel generalization authorities"],
    [baseline.candidate_privacy.imported_secrets_true === 0, "baseline imported secrets must be zero"],
    [baseline.candidate_privacy.imported_personal_identifiers_true === 0, "baseline imported PII must be zero"],
    [baseline.candidate_privacy.imported_raw_arguments_true === 0, "baseline imported raw arguments must be zero"],
    [baseline.candidate_privacy.imported_raw_results_true === 0, "baseline imported raw results must be zero"],
    [baseline.candidate_privacy.imported_raw_errors_true === 0, "baseline imported raw errors must be zero"],
    [baseline.cross_project_signals.cross_project_exact_content_hash_groups === 0, "baseline exact cross-project content duplication must be zero"],
    [baseline.cross_project_signals.error_fingerprint_groups > 0, "baseline must preserve evidence that cross-project error recurrence exists"],
    [baseline.review_scope.with_project_key === baseline.review_scope.total, "review source is expected to remain project-bound"],
    [baseline.review_scope.append_only_true === baseline.review_scope.total, "review snapshots must remain append-only"],
    [baseline.review_scope.requires_review_true === baseline.review_scope.total, "review snapshots must remain review-required"]
  ];
  for (const [ok,msg] of exact) if (!ok) throw new Error(msg);

  const contractTokens = [
    "project A record -> direct retrieval by project B",
    "candidate -> review -> canon",
    "Generalization never broadens namespace authorization",
    "Re-identification failure rejects the candidate",
    "Unresolved contradiction/conflict rejects the candidate",
    "Zero tolerated cross-customer leakage",
    "no generalization table, RPC, Edge Function, API route or alternate learning gateway"
  ];
  for (const token of contractTokens) if (!contract.includes(token)) throw new Error(`missing contract token: ${token}`);

  const bridgeTokens = [
    '.from("pandora_projects")',
    '.eq("project_key", projectKey)',
    '.from("pandora_project_grants")',
    '.eq("can_read", true)',
    '.is("revoked_at", null)',
    '.from("memory_items")',
    '.eq("project_id", canonicalProjectId)',
    'unscoped_components_omitted: true',
    'error: "project_not_allowed"'
  ];
  for (const token of bridgeTokens) if (!bridge.includes(token)) throw new Error(`project isolation weakened: ${token}`);

  const runtimeRoots = ["supabase/functions", "app/api", "lib"];
  for (const runtimeRoot of runtimeRoots) {
    if (!fs.existsSync(runtimeRoot)) continue;
    const stack = [runtimeRoot];
    while (stack.length) {
      const current = stack.pop();
      for (const dirent of fs.readdirSync(current, {withFileTypes:true})) {
        const p = path.join(current, dirent.name);
        if (dirent.isDirectory()) stack.push(p);
        else if (/cross[-_]?project.*(general|learn)|generaliz.*memory|playbook.*gateway/i.test(p)) {
          throw new Error(`parallel cross-project runtime authority detected: ${p}`);
        }
      }
    }
  }

  selfTest();
  console.log("PASS: cross-project generalization is source-only, privacy-bounded, governance-gated, and exact-project source isolation remains intact");
}

selfTest();
if (!process.argv.includes("--self-test-only")) fullVerify();
