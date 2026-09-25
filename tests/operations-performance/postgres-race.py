#!/usr/bin/env python3
"""Prove grant revocation waits for an in-flight read and denies a subsequent read."""
import json
import os
import subprocess
import time


def sql(statement, *, check=True, env=None):
    return subprocess.run(["psql", "-XAt", "-v", "ON_ERROR_STOP=1", "-c", statement],
                          stdin=subprocess.DEVNULL, capture_output=True, text=True,
                          check=check, timeout=15, env=env)

if os.environ.get("PGDATABASE") != "ops_performance_test":
    raise SystemExit("Dedicated disposable test database required")
assert sql("select fixture from public.ops_performance_fixture_marker").stdout.strip() == "t"
request = json.dumps(dict(requestId="55555555-5555-4555-8555-555555555555",taskClass="complex_coding",
                         provider=None,model=None,modelRevision=None,configurationDigest=None,maxRecords=16))
call = ("select public.memory_operations_performance_v1('44444444-4444-4444-8444-444444444444',"
        "'real_life','33333333-3333-4333-8333-333333333333','ops-perf-test','test','"+request+"'::jsonb);")
reader = subprocess.Popen(["psql", "-XAt", "-v", "ON_ERROR_STOP=1"],stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
writer = None
try:
    reader.stdin.write("set statement_timeout='10s'; begin;\n"+call+"\n\\echo READ_LOCK_HELD\n"); reader.stdin.flush()
    while reader.stdout.readline().strip() != "READ_LOCK_HELD":
        if reader.poll() is not None:
            raise RuntimeError("Read session did not acquire its locks")
    env = {**os.environ, "PGAPPNAME":"ops-performance-revoker"}
    writer = subprocess.Popen(["psql","-XAt","-v","ON_ERROR_STOP=1","-c",
        "set statement_timeout='10s'; update public.pandora_project_grants set revoked_at=clock_timestamp() "
        "where principal_key='ops-perf-test';"],stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
    deadline = time.monotonic()+5
    blocked = False
    while time.monotonic() < deadline:
        blocked = sql("select count(*) from pg_stat_activity where application_name='ops-performance-revoker' "
                      "and wait_event_type='Lock'").stdout.strip() == "1"
        if blocked: break
        time.sleep(0.05)
    assert blocked, "Revocation did not wait on the read's shared grant lock"
    reader.stdin.write("commit;\n\\q\n"); reader.stdin.flush()
    reader.wait(timeout=15)
    _, error = writer.communicate(timeout=15)
    assert writer.returncode == 0, error
    denied = sql(call,check=False)
    assert denied.returncode != 0 and "OPS_MEMORY_PERFORMANCE_GRANT_DENIED" in denied.stderr
    print(json.dumps({"passed":2,"cases":["inflight_read_fences_revocation","fresh_read_observes_revocation"]}))
finally:
    if reader.poll() is None: reader.terminate(); reader.wait(timeout=5)
    if writer is not None and writer.poll() is None: writer.terminate(); writer.wait(timeout=5)
    sql("update public.pandora_project_grants set revoked_at=null where principal_key='ops-perf-test';")
