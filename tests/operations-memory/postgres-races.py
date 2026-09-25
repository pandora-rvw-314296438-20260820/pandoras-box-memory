#!/usr/bin/env python3
"""Independent psql sessions; only the fixed disposable CI database is accepted."""
import concurrent.futures
import datetime
import json
import os
import subprocess
import time
import uuid

assert os.environ.get('PGHOST') == '127.0.0.1', 'Disposable loopback PostgreSQL only'
assert os.environ.get('PGDATABASE') == 'ops_memory_test', 'Fixed disposable CI database only'
PSQL = ['psql', '-X', '-A', '-t', '-v', 'ON_ERROR_STOP=1']
USER = '44444444-4444-4444-8444-444444444444'
PROJECT = '33333333-3333-4333-8333-333333333333'

def sql(query, expected=True):
    result = subprocess.run(PSQL, input=query, capture_output=True, text=True, timeout=20)
    if expected and result.returncode:
        raise AssertionError(result.stderr[-1500:])
    return result

def payload():
    now = datetime.datetime.now(datetime.timezone.utc)
    return dict(contractVersion='pandora-operations-model-outcome-v1', sourceRunId=str(uuid.uuid4()),
        provider='fixture', model='fixture-model', modelRevision=None, taskClass='complex_coding',
        routingPolicyVersion='policy.v1', executionStatus='succeeded', verificationStatus='pass',
        downstreamOutcomeStatus='accepted', qualitySignal=None, latencyMs=42,
        estimatedCostMicros=100, billedCostMicros=None, occurredAt=(now-datetime.timedelta(minutes=1)).isoformat(),
        reviewDueAt=(now+datetime.timedelta(days=30)).isoformat(), evidenceRefs=['verification:race-fixture'],
        sourceCommit='a'*40, sourceDeploymentRef=None,
        usage=dict(inputTokens=None, outputTokens=None, totalTokens=None), retryCount=0, configurationDigest=None)

def call(body):
    encoded = json.dumps(body, separators=(',', ':')).replace("'", "''")
    return "select public.memory_operations_bridge_v1('propose_outcome','%s','real_life','%s','ops-test-principal','test','%s'::jsonb);" % (USER, PROJECT, encoded)

def held(body, label):
    return sql("begin; set application_name='%s'; %s select pg_sleep(2); commit;" % (label, call(body)))

def wait_held(label):
    deadline = time.monotonic()+10
    while time.monotonic()<deadline:
        row=sql("select count(*) from pg_stat_activity where application_name='%s' and wait_event='PgSleep';" % label).stdout.strip()
        if row=='1': return
        time.sleep(.05)
    raise AssertionError('First session did not reach actual database hold')

def json_line(result):
    return next(json.loads(line) for line in result.stdout.splitlines() if line.startswith('{'))

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    body=payload(); first=pool.submit(held,body,'ops_memory_same_replay'); wait_held('ops_memory_same_replay')
    second=sql(call(body)); one=json_line(first.result()); two=json_line(second)
    assert one['candidateId']==two['candidateId'] and two['idempotentReplay'] is True
    count=sql("select count(*) from public.memory_capture_candidates where source_ref='model-run:%s';" % body['sourceRunId']).stdout.strip()
    assert count=='1'; print('PASS independent sessions: duplicate delivery yields one candidate',flush=True)
    body=payload(); first=pool.submit(held,body,'ops_memory_conflict'); wait_held('ops_memory_conflict')
    second=sql(call(dict(body,billedCostMicros=99)),expected=False); first.result()
    assert second.returncode and 'OPS_MEMORY_REPLAY_CONFLICT' in second.stderr
    print('PASS independent sessions: changed payload is rejected after the winning commit',flush=True)
    body=payload(); first=pool.submit(held,body,'ops_memory_revocation'); wait_held('ops_memory_revocation')
    revoke=pool.submit(sql,"set application_name='ops_memory_revoke_writer'; update public.pandora_project_grants set is_active=false where principal_key='ops-test-principal' and project_id='%s';" % PROJECT)
    deadline=time.monotonic()+1.5
    while time.monotonic()<deadline:
        waiting=sql("select count(*) from pg_stat_activity where application_name='ops_memory_revoke_writer' and wait_event_type='Lock';").stdout.strip()
        if waiting=='1': break
        time.sleep(.025)
    else: raise AssertionError('Revocation did not wait on the actual shared grant lock')
    first.result(); revoke.result(); denied=sql(call(body),expected=False)
    assert denied.returncode and 'OPS_MEMORY_GRANT_DENIED' in denied.stderr
    sql("update public.pandora_project_grants set is_active=true where principal_key='ops-test-principal' and project_id='%s';" % PROJECT)
    print('PASS independent sessions: grant revocation fences all later replay',flush=True)
print(json.dumps(dict(postgresConcurrencyCases=3,passed=3,productionAcceptance=False)))
