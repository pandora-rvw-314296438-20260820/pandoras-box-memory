#!/usr/bin/env python3
from pathlib import Path
import re
import sys

MIG = Path('supabase/migrations/20260913185000_m5_projectos_learning_scope_integrity_v1.sql')
BASE = Path('tests/sql/m5_projectos_learning_scope_integrity_baseline.sql')
BEHAV = Path('tests/sql/m5_projectos_learning_scope_integrity_behavior.sql')
WF = Path('.github/workflows/m5-projectos-learning-scope-integrity.yml')
DOC = Path('docs/architecture/M5_R042_PROJECTOS_LEARNING_SCOPE_INTEGRITY.md')

errors = []
def need(ok, message):
    if not ok:
        errors.append(message)

for path in (MIG, BASE, BEHAV, WF, DOC):
    need(path.exists(), f'missing required file: {path}')
if errors:
    for e in errors:
        print(f'ERROR: {e}')
    sys.exit(1)

sql = MIG.read_text(encoding='utf-8')
low = sql.lower()
behavior = BEHAV.read_text(encoding='utf-8').lower()
workflow = WF.read_text(encoding='utf-8').lower()
doc = DOC.read_text(encoding='utf-8').lower()

for marker in (
    'memory_bind_projectos_learning_scope_v1',
    'memory_bind_projectos_review_lineage_v1',
    'memory_guard_projectos_canonical_lineage_v1',
    "projectos-mcpmaster-production",
    "g.environment='production'",
    'g.can_propose is true',
    'g.is_active is true',
    'g.revoked_at is null',
    "p.lifecycle_status='active'",
    'p.memory_namespace=new.namespace::text',
    "p.project_key=v_source_key",
    "v_source_key=any(coalesce(p.aliases,'{}'::text[]))",
    "new.project_id:=v_project_id",
    "'candidateid',v_candidate_id",
    "'projectid',v_project_id",
    "c.source_ref=v_review.source_ref",
    'new.project_id is distinct from v_project_id',
    'no legacy backfill',
):
    need(marker in low, f'migration contract marker missing: {marker}')

for trigger_table in (
    r'create\s+trigger\s+trg_memory_bind_projectos_learning_scope_v1[\s\S]*?before\s+insert\s+on\s+public\.memory_capture_candidates',
    r'create\s+trigger\s+trg_memory_bind_projectos_review_lineage_v1[\s\S]*?before\s+insert\s+on\s+public\.memory_review_queue_items',
    r'create\s+trigger\s+trg_memory_guard_projectos_canonical_lineage_v1[\s\S]*?before\s+insert\s+on\s+public\.memory_items',
):
    need(re.search(trigger_table, low) is not None, f'trigger binding missing: {trigger_table}')

# This prerequisite is additive and must never mutate legacy learning/canonical rows.
need(re.search(r'\bupdate\s+public\.(memory_capture_candidates|memory_review_queue_items|memory_items)\b', low) is None,
     'migration must not update legacy Memory rows')
need(re.search(r'\bdelete\s+from\s+public\.(memory_capture_candidates|memory_review_queue_items|memory_items)\b', low) is None,
     'migration must not delete Memory rows')

for marker in (
    'missing-project',
    'shared-alias',
    'source-no-grant',
    'expected candidate lineage mismatch',
    'expected legacy canonical rejection',
    'expected revoked grant rejection',
    'm5_projectos_learning_scope_integrity_v1 pass',
):
    need(marker in behavior, f'behavior proof missing: {marker}')

for marker in (
    'pull_request:',
    'workflow_dispatch:',
    'postgres:16',
    'verify_m5_projectos_learning_scope_integrity.py',
    'm5_projectos_learning_scope_integrity_baseline.sql',
    'm5_projectos_learning_scope_integrity_behavior.sql',
    'check_no_literal_secrets.sh',
):
    need(marker in workflow, f'workflow proof missing: {marker}')

for marker in (
    'm1-003',
    'does not complete m5-003',
    'no legacy backfill',
    'does not grant execution authority',
    '43',
    '53',
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
        need(re.search(pattern, text) is None, f'literal credential pattern in {path}')

if errors:
    print('M5 ProjectOS learning scope integrity gate FAILED:')
    for error in errors:
        print(f'  - {error}')
    sys.exit(1)
print('M5 ProjectOS learning scope integrity gate passed.')
