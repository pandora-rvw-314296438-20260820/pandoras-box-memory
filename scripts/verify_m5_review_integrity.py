#!/usr/bin/env python3
from pathlib import Path
import re
import sys

MIG = Path('supabase/migrations/20260914061000_m5_review_integrity_r053_r054_v1.sql')
BASE = Path('tests/sql/m5_review_integrity_baseline.sql')
BEHAV = Path('tests/sql/m5_review_integrity_behavior.sql')
WF = Path('.github/workflows/m5-review-integrity.yml')
DOC = Path('docs/architecture/M5_R053_R054_REVIEW_INTEGRITY.md')

errors = []
def need(ok, msg):
    if not ok:
        errors.append(msg)

for p in (MIG, BASE, BEHAV, WF, DOC):
    need(p.exists(), f'missing required file: {p}')
if errors:
    print('\n'.join(f'ERROR: {e}' for e in errors)); sys.exit(1)

sql = MIG.read_text(encoding='utf-8')
low = sql.lower()
behavior = BEHAV.read_text(encoding='utf-8').lower()
workflow = WF.read_text(encoding='utf-8').lower()
doc = DOC.read_text(encoding='utf-8').lower()

for marker in (
    'memory_review_semantic_sha256_v1',
    "'m5.review-semantic.v1'",
    "'proposedobservedatepoch'",
    "'proposedeffectiveatepoch'",
    "set search_path=''",
    'memory_constant_time_hex_equal_v1',
    'memory_guard_review_semantics_v1',
    'memory_guard_review_decision_append_only_v1',
    'review status transition requires an append-only decision',
    'memory review decisions are append-only',
    'revoke update,delete on table public.memory_review_queue_items',
    'revoke insert,update,delete on table public.memory_review_queue_decisions',
    "to_jsonb(new) - array[",
    'security definer',
    "'reviewsemanticsha256'",
    'get diagnostics v_row_count = row_count',
    'review decision status transition did not update exactly one row',
    'review persistence bookkeeping did not update exactly one row',
    'provider review persistence bookkeeping did not update exactly one row',
    'provider candidate persistence bookkeeping did not update exactly one row',
    'm5 typed review must use generic approved-review persistence',
    'revoke all on function public.memory_review_append_decision',
    'revoke all on function public.memory_execute_approved_review_persistence',
    'revoke all on function public.memory_execute_approved_provider_learning_v1',
):
    need(marker in low, f'migration marker missing: {marker}')

need('create policy' not in low, 'migration must not add a broad RLS policy')
need('grant update on public.memory_review_queue_items' not in low, 'migration must not grant direct review UPDATE')
need(re.search(r'\bupdate\s+public\.memory_review_queue_items\s+set\s+normalized_text', low) is None,
     'migration must not rewrite review semantics')
need(re.search(r'\bupdate\s+public\.memory_capture_candidates\s+set\s+project_id', low) is None,
     'migration must not backfill project lineage')

for marker in (
    'direct authenticated semantic update bypassed mutation boundary',
    'timezone changed semantic digest',
    'expected direct decision insert denial',
    'expected append-only decision update rejection',
    'expected append-only decision delete rejection',
    'expected status transition without decision rejection',
    'expected zero-row decision transition rollback',
    'wrong-owner approval rejection',
    'caller overrode system semantic digest',
    'expected immutable review semantic rejection',
    'expected review semantic digest mismatch',
    'idempotent replay duplicated canonical memory',
    'expected zero-row bookkeeping rollback',
    'provider candidate was not captured',
    'expected provider candidate bookkeeping rollback',
    'expected typed provider review rejection',
    'm5_review_integrity_r053_r054_v1 pass',
):
    need(marker in behavior, f'behavior proof missing: {marker}')

for marker in (
    'pull_request:',
    'workflow_dispatch:',
    'postgres:16',
    'verify_m5_review_integrity.py',
    'm5_review_integrity_baseline.sql',
    '20260914061000_m5_review_integrity_r053_r054_v1.sql',
    'm5_review_integrity_behavior.sql',
    'check_no_literal_secrets.sh',
):
    need(marker in workflow, f'workflow marker missing: {marker}')
need('paths:' not in workflow and 'paths-ignore:' not in workflow,
     'required review-integrity workflow must not be path-filtered')

for marker in (
    'r-053', 'r-054', 'does not complete m5-003', 'no production deployment',
    'github app first', 'supabase vault', 'service-role', 'reviewsemanticsha256'
):
    need(marker in doc, f'architecture note missing: {marker}')

credential_patterns = (
    r'ghp_[A-Za-z0-9]{12,}',
    r'github_pat_[A-Za-z0-9_]{12,}',
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    r'(?i)bearer\s+[A-Za-z0-9._~+/-]{16,}',
)
for p in (MIG, BASE, BEHAV, WF, DOC):
    text = p.read_text(encoding='utf-8')
    for pattern in credential_patterns:
        need(re.search(pattern, text) is None, f'literal credential pattern in {p}')

if errors:
    print('M5 R-053/R-054 review-integrity gate FAILED:')
    for e in errors: print(f'  - {e}')
    sys.exit(1)
print('M5 R-053/R-054 review-integrity gate passed.')
