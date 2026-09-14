#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
MIG = ROOT / 'supabase/migrations/20260914100000_m5_verified_execution_learning_v1.sql'
BASE = ROOT / 'tests/sql/m5_verified_execution_learning_baseline.sql'
BEHAV = ROOT / 'tests/sql/m5_verified_execution_learning_behavior.sql'
WF = ROOT / '.github/workflows/m5-verified-execution-learning.yml'
DOC = ROOT / 'docs/architecture/M5_003_VERIFIED_EXECUTION_LEARNING.md'

errors = []
def need(ok, message):
    if not ok:
        errors.append(message)

for path in (MIG, BASE, BEHAV, WF, DOC):
    need(path.exists(), f'missing required file: {path.relative_to(ROOT)}')
if errors:
    print('\n'.join(f'ERROR: {e}' for e in errors))
    sys.exit(1)

sql = MIG.read_text(encoding='utf-8').lower()
behavior = BEHAV.read_text(encoding='utf-8').lower()
workflow = WF.read_text(encoding='utf-8').lower()
doc = DOC.read_text(encoding='utf-8').lower()
for marker in (
    'memory_ingest_verified_execution_learning_v1',
    "pandora-continuous-execution-v2",
    "p_learning_kind not in ('fact','procedure','failure_lesson','outcome')",
    "v_status<>'result'",
    "p_execution->>'verified'",
    "verificationreceiptref",
    "x->>'type'='verification_receipt'",
    "x->>'relation'='verification'",
    "failure lesson requires independent incident verification evidence",
    "g.can_propose is true",
    "g.revoked_at is null",
    "p_learning_kind=any(coalesce(g.allowed_record_types,'{}'::text[]))",
    "'authorizationeffect','none'",
    "'canonicalmemorywritten',false",
    "'rawexecutionstored',false",
    'to service_role',
):
    need(marker in sql, f'migration contract marker missing: {marker}')

need('insert into public.memory_items' not in sql,
     'M5-003 intake must never insert canonical Memory directly')
need('update public.memory_items' not in sql,
     'M5-003 intake must never mutate canonical Memory directly')
need('explicit_policy_authorization' in sql and "p_promotion_basis,false" in sql,
     'verified execution learning must never synthesize policy authorization')
for marker in (
    'm1-job:job-success-1:procedure',
    'm1-job:job-failure-1:failure_lesson',
    'expected unverified result rejection',
    'expected old contract rejection',
    'expected missing evidence rejection',
    'expected missing incident verification rejection',
    'expected disallowed record type rejection',
    'expected revoked grant rejection',
    'canonical memory was mutated by m5-003 intake',
    'm5_verified_execution_learning_v1 pass',
):
    need(marker in behavior, f'behavior proof missing: {marker}')

for marker in (
    'pull_request:', 'workflow_dispatch:', 'postgres:16',
    'verify_m5_verified_execution_learning.py',
    'm5_verified_execution_learning_baseline.sql',
    '20260914100000_m5_verified_execution_learning_v1.sql',
    'm5_verified_execution_learning_behavior.sql',
    'check_no_literal_secrets.sh',
):
    need(marker in workflow, f'workflow proof missing: {marker}')

for marker in (
    'm5-003', 'm1-003', 'verified result', 'failure lesson',
    'review-governed', 'does not grant execution authority',
    'does not write canonical memory directly', 'raw execution',
):
    need(marker in doc, f'architecture note missing: {marker}')
credential_patterns = (
    r'ghp_[A-Za-z0-9]{12,}',
    r'github_pat_[A-Za-z0-9_]{12,}',
    r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
    r'(?i)bearer\s+[A-Za-z0-9._~+/-]{16,}',
)
for path in (MIG, BASE, BEHAV, WF, DOC):
    text = path.read_text(encoding='utf-8')
    for pattern in credential_patterns:
        need(re.search(pattern, text) is None,
             f'literal credential pattern in {path.relative_to(ROOT)}')

need(len(re.findall(r'\$function\$', sql)) % 2 == 0,
     'unbalanced PL/pgSQL function delimiter')
need('security definer' in sql and "set search_path='pg_catalog','public','extensions'" in sql,
     'service intake security/search_path contract missing')

if errors:
    print('M5-003 verified execution learning gate FAILED:')
    for error in errors:
        print(f'  - {error}')
    sys.exit(1)
print('M5-003 verified execution learning gate passed.')
