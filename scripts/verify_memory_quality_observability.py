#!/usr/bin/env python3
import argparse,json,os,subprocess,sys
from copy import deepcopy
from pathlib import Path
R=Path(__file__).resolve().parents[1]
M=R/'docs/capabilities/evidence/MEMORY_QUALITY_OBSERVABILITY_BASELINE_2026-09-01.json'
C=R/'docs/observability/MEMORY_QUALITY_OBSERVABILITY_CONTRACT.md'
B=R/'supabase/functions/pandora-projectos-bridge/index.ts'
CLASSES={'measurable_live_now','source_intended_only','unavailable_causal'}
CAUSAL={'retrieval_usefulness','memory_assisted_success_lift','retrieval_prevented_repeat_failure_rate','retrieval_caused_rework_rate'}
BAD_KEYS={'query','raw_query','query_text','body','content','raw_content','email','user_id','candidate_id','memory_id','item_id','head_id','record_id','token','secret','password','credential','payload','raw_payload'}
MILESTONE_FILES={'.github/workflows/memory-quality-observability-gate.yml','docs/observability/MEMORY_QUALITY_OBSERVABILITY_CONTRACT.md','docs/capabilities/evidence/MEMORY_QUALITY_OBSERVABILITY_BASELINE_2026-09-01.json','scripts/verify_memory_quality_observability.py'}
ALLOWED_COMPOSITE_FILES=MILESTONE_FILES|{'.github/workflows/learning-intelligence-contract.yml','docs/capabilities/evidence/LEARNING_INTELLIGENCE_CONTRACT_2026-09-01.md','scripts/verify_learning_intelligence_contract.py','.github/workflows/memory-hardening-readiness.yml','docs/capabilities/evidence/MEMORY_HARDENING_READINESS_2026-09-01.json','scripts/verify_memory_hardening_readiness.py','.github/workflows/memory-security-adjudication-gate.yml','docs/capabilities/evidence/MEMORY_SECURITY_ADJUDICATION_2026-09-01.json','docs/security/MEMORY_SECURITY_ADJUDICATION_CONTRACT_2026-09-01.md','scripts/verify_memory_security_adjudication.py','.github/workflows/memory-lifecycle-contract-gate.yml','docs/capabilities/evidence/MEMORY_LIFECYCLE_CONSOLIDATION_CONTRACT_2026-09-01.md','docs/capabilities/evidence/MEMORY_LIFECYCLE_LIVE_EVIDENCE_2026-09-01.json','scripts/verify_memory_lifecycle_contract.py','.github/workflows/memory-cross-project-generalization-gate.yml','docs/capabilities/evidence/MEMORY_CROSS_PROJECT_GENERALIZATION_BASELINE_2026-09-01.json','docs/verification/MEMORY_CROSS_PROJECT_GENERALIZATION_CONTRACT_2026-09-01.md','scripts/verify_memory_cross_project_generalization.mjs'}
def fail(s): raise AssertionError(s)
def load(): return json.loads(M.read_text())
def walk(v,p='root'):
 if isinstance(v,dict):
  for k,x in v.items(): yield p,k,x; yield from walk(x,f'{p}.{k}')
 elif isinstance(v,list):
  for i,x in enumerate(v): yield from walk(x,f'{p}[{i}]')
def check(d):
 if d.get('schema_version')!='memory-quality-observability-v1': fail('schema version')
 if d.get('authority_order',[None])[0]!='fresh_provider_truth': fail('provider authority')
 s=d['source_state']; parity=s['memory_main_sha']==s['production_source_sha']
 if s['source_runtime_parity']!=parity: fail('source/runtime parity')
 if not s['canonical_source_has_project_identity'] or not s['canonical_source_has_exact_project_filter']: fail('project source intent')
 ms=d['metrics']
 for n,m in ms.items():
  c=m.get('classification')
  if c not in CLASSES: fail(f'{n}: class')
  if c!='unavailable_causal' and not m.get('source'): fail(f'{n}: source')
  if c=='measurable_live_now' and not ('value' in m or ('numerator' in m and 'denominator' in m)): fail(f'{n}: live value')
  if c=='source_intended_only' and (m.get('value') is not None or not m.get('reason')): fail(f'{n}: source-only masquerade')
  if c=='unavailable_causal' and (m.get('value') is not None or not m.get('missing_authorities') or not m.get('reason')): fail(f'{n}: unavailable coercion')
 for n in CAUSAL:
  if ms[n]['classification']!='unavailable_causal' or ms[n]['value'] is not None: fail(f'{n}: causal enabled')
 total=ms['retrieval_events_total']['value']; cov=ms['live_retrieval_project_identity_coverage']
 if cov['numerator']!=0 or cov['denominator']!=total or cov.get('state')!='degraded': fail('project coverage baseline')
 if ms['source_runtime_parity']['value']!=s['source_runtime_parity']: fail('parity metric')
 if any(d['historical_telemetry_policy'].values()): fail('historical inference')
 if d['privacy'].get('aggregate_only') is not True or any(v for k,v in d['privacy'].items() if k!='aggregate_only'): fail('privacy flags')
 for p,k,v in walk(d):
  if k.lower() in BAD_KEYS: fail(f'privacy key {p}.{k}')
  if isinstance(v,str) and '@' in v: fail(f'email-like value {p}.{k}')
def contract():
 t=C.read_text(); req=['measurable_live_now','source_intended_only','unavailable_causal','Zero is not a substitute for unavailable','Historical retrieval logs are immutable evidence','Do not backfill, rewrite or infer historical','Database volume is not product value','production_verified','exact resolved-head identity','raw search text','Current non-actions']
 for x in req:
  if x not in t: fail(f'contract marker {x}')
def bridge(d):
 t=B.read_text();
 for x in ['"project_id"','"project_key"','.eq("project_id", canonicalProjectId)','memory_retrieval_logs']:
  if x not in t: fail(f'bridge marker {x}')
 for flag,x in [('canonical_source_has_resolved_head_ids','resolved_head_ids'),('canonical_source_has_used_item_ids','used_item_ids'),('canonical_source_has_outcome_ref','outcome_ref')]:
  if d['source_state'][flag] != (x in t): fail(f'stale source evidence {x}')
def changed():
 b=os.getenv('BASE_SHA','').strip()
 if not b:return
 out=subprocess.check_output(['git','diff','--name-only',f'{b}...HEAD'],cwd=R,text=True)
 got={x for x in out.splitlines() if x}; extra=got-ALLOWED_COMPOSITE_FILES; missing=MILESTONE_FILES-got
 if extra: fail(f'source-only unexpected files {sorted(extra)}')
 if missing: fail(f'missing milestone files {sorted(missing)}')
def selftest():
 d=load();check(d)
 tests=[('causal',lambda x:x['metrics']['retrieval_usefulness'].__setitem__('value',0)),('parity',lambda x:x['source_state'].__setitem__('source_runtime_parity',True)),('history',lambda x:x['historical_telemetry_policy'].__setitem__('allow_inferred_project_scope',True)),('source-only',lambda x:x['metrics']['project_scoped_retrieval_telemetry'].__setitem__('value',1))]
 for n,mut in tests:
  x=deepcopy(d);mut(x)
  try:check(x)
  except AssertionError:continue
  fail(f'selftest did not reject {n}')
 print('PASS: observability fail-closed self-tests')
def main():
 a=argparse.ArgumentParser();a.add_argument('--self-test',action='store_true');z=a.parse_args()
 if z.self_test:selftest();return
 d=load();check(d);contract();bridge(d);changed();print('PASS: Memory observability truth contract and source-only scope')
if __name__=='__main__':
 try:main()
 except AssertionError as e:print(f'FAIL: {e}',file=sys.stderr);sys.exit(1)
