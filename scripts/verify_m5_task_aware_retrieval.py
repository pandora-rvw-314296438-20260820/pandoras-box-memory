#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20260913143500_m5_task_aware_retrieval_v1.sql"
BRIDGE = ROOT / "supabase/functions/pandora-projectos-bridge/index.ts"
DOC = ROOT / "docs/architecture/M5_002_TASK_AWARE_RETRIEVAL.md"
INTENTS = {"communication","research","coding_building","files","device_operations","business","travel","scheduling","future_capability","general_assistance"}
CLASSES = {"fact","pattern","policy","procedure","failure_lesson","outcome","provider_performance"}

def need(text, token):
    if token not in text:
        raise AssertionError(f"missing contract token: {token}")

def main():
    sql = MIGRATION.read_text(encoding="utf-8")
    bridge = BRIDGE.read_text(encoding="utf-8")
    doc = DOC.read_text(encoding="utf-8")
    need(sql,"memory_task_context_v1")
    for value in sorted(INTENTS): need(sql,f"'{value}'")
    for value in sorted(CLASSES): need(sql,f"'{value}'")
    for token in (
      "allowed_record_types","can_read is true","revoked_at is null","superseded_at is null",
      "knowledge_schema_version='m5.v1'","policyMemory","advisoryMemory",
      "retrievalDoesNotGrantExecutionAuthority","advisoryMemoryNeverAuthorizes",
      "policiesSeparatedFromAdvisoryMemory","policyRequiresRuntimeScopeValidityRevocationValidation",
      "similarityNeverDeterminesAuthority","grantExpansionPerformed",
      "requires_exact_runtime_scope_validity_revocation_validation","authorizationEffect','none'",
      "p_max_bytes not between 4096 and 16384","v_advisory_limit integer := 12","v_policy_limit integer := 4",
      "record_type='policy'","record_type<>'policy'","record_type=any(v_allowed)","project_not_allowed","extensions.digest"
    ): need(sql,token)
    failure=re.search(r"when 'failure_lesson' then case .*? then (\d+)",sql,re.S)
    procedure=re.search(r"when 'procedure' then case .*? then (\d+)",sql,re.S)
    fact=re.search(r"when 'fact' then (\d+)",sql,re.S)
    if not (failure and procedure and fact): raise AssertionError("class priority weights missing")
    if not (int(failure.group(1))>int(procedure.group(1))>int(fact.group(1))): raise AssertionError("failure lesson priority invalid")
    for token in ('const M5_TYPED_MEMORY_CLASSES','"memory_task_context_v1"','m5_task_aware_bounded','project_scoped_keyword_recency_legacy_until_m5_class_grant','retrieval_does_not_grant_authority','allowed_typed_classes'):
        need(bridge,token)
    for value in sorted(INTENTS): need(bridge,f'"{value}"')
    for phrase in ("Production grants are **not** expanded","policy/advisory separation","bounded byte output","cross-project exclusion"):
        need(doc,phrase)
    print("M5-002 task-aware bounded retrieval contract verification: PASS")
    return 0

if __name__ == "__main__": sys.exit(main())
