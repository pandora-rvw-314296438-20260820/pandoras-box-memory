#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/capabilities/evidence/MEMORY_SECURITY_ADJUDICATION_2026-09-01.json"
CONTRACT = ROOT / "docs/security/MEMORY_SECURITY_ADJUDICATION_CONTRACT_2026-09-01.md"

REQUIRED_MARKERS = [
    "PANDORA_SECURITY_ADJUDICATION: reviewed",
    "PANDORA_SECURITY_ACCESS_PATH:",
    "PANDORA_SECURITY_TEST_PLAN:",
    "PANDORA_SECURITY_ROLLBACK:",
    "PANDORA_SECURITY_OWNER:",
]
CLIENT = r"(?:anon|authenticated|public)"

HARD_FAIL_PATTERNS = {
    "private_schema_usage_to_client_roles": re.compile(
        rf"\bgrant\s+usage\s+on\s+schema\s+private\s+to\s+{CLIENT}\b", re.I | re.S
    ),
    "private_table_privileges_to_client_roles": re.compile(
        rf"\bgrant\b[\s\S]{{0,240}}\bon\s+(?:(?:all\s+)?tables?\s+in\s+schema\s+private|(?:table\s+)?private\.[\w\".]+)[\s\S]{{0,120}}\bto\s+{CLIENT}\b",
        re.I,
    ),
    "net_schema_usage_to_client_roles": re.compile(
        rf"\bgrant\s+usage\s+on\s+schema\s+net\s+to\s+{CLIENT}\b", re.I | re.S
    ),
    "net_http_execute_to_client_roles": re.compile(
        rf"\bgrant\s+execute\s+on\s+function\s+net\.http_(?:get|post|delete)\b[\s\S]{{0,220}}\bto\s+{CLIENT}\b",
        re.I,
    ),
}

SENSITIVE_CHANGE_PATTERNS = [
    re.compile(
        r"\balter\s+table\s+(?:if\s+exists\s+)?private\.[\w\".]+\s+(?:enable|disable|force|no\s+force)\s+row\s+level\s+security\b",
        re.I,
    ),
    re.compile(
        r"\b(?:grant|revoke)\b[\s\S]{0,300}\b(?:schema\s+(?:private|net)|private\.|net\.http_(?:get|post|delete))",
        re.I,
    ),
]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def marker_has_value(sql: str, marker: str) -> bool:
    if marker.endswith(":"):
        rx = re.compile(rf"^\s*--\s*{re.escape(marker)}\s*\S.+$", re.I | re.M)
        return bool(rx.search(sql))
    return marker.lower() in sql.lower()


def inspect_sql(sql: str) -> list[str]:
    errors: list[str] = []
    for rule, pattern in HARD_FAIL_PATTERNS.items():
        if pattern.search(sql):
            errors.append(f"hard-fail client privilege rule matched: {rule}")
    if any(pattern.search(sql) for pattern in SENSITIVE_CHANGE_PATTERNS):
        for marker in REQUIRED_MARKERS:
            if not marker_has_value(sql, marker):
                errors.append(f"sensitive security migration missing marker: {marker}")
    return errors


def validate_evidence() -> None:
    data = json.loads(EVIDENCE.read_text())
    if data.get("schema_version") != "1.0.0":
        fail("unexpected security evidence schema_version")
    boundary = data.get("memory_private_boundary", {})
    tables = boundary.get("tables", [])
    if boundary.get("table_count") != 8 or len(tables) != 8:
        fail("Memory private-table evidence must contain all eight live tables")
    enabled = sum(1 for table in tables if table.get("rls") is True)
    disabled = sum(1 for table in tables if table.get("rls") is False)
    if (enabled, disabled) != (2, 6):
        fail(f"unexpected Memory private RLS evidence: enabled={enabled} disabled={disabled}")
    for table in tables:
        for field in ("anon_select", "auth_select", "auth_insert", "auth_update", "auth_delete"):
            if table.get(field) is not False:
                fail(f"private table {table.get('name')} exposes unexpected client privilege {field}")
    usage = boundary.get("private_schema_usage", {})
    if usage.get("anon") is not False or usage.get("authenticated") is not False:
        fail("Memory private schema client USAGE must remain false in evidence")
    if boundary.get("client_executable_security_definer_count") != 0:
        fail("Memory client-executable SECURITY DEFINER evidence must remain zero")
    pg_net = data.get("primary_pg_net_boundary", {})
    if pg_net.get("schema_usage", {}).get("anon") is not True or pg_net.get("schema_usage", {}).get("authenticated") is not True:
        fail("Primary pg_net exposure evidence unexpectedly changed; refresh provider readback")
    functions = {row.get("name"): row for row in pg_net.get("http_functions", [])}
    if set(functions) != {"http_get", "http_post", "http_delete"}:
        fail("Primary pg_net evidence must include the three client-exposed HTTP functions")
    for name, row in functions.items():
        if row.get("anon_execute") is not True or row.get("authenticated_execute") is not True:
            fail(f"Primary pg_net evidence for {name} must reflect current client EXECUTE exposure")
    if data.get("required_migration_markers") != REQUIRED_MARKERS:
        fail("required migration marker contract was weakened")
    if set(data.get("hard_fail_client_grants", [])) != set(HARD_FAIL_PATTERNS):
        fail("hard-fail client grant contract was weakened")
    production = data.get("memory_production", {})
    if production.get("source_matches_main") is not False:
        fail("this evidence must not claim Memory production parity")


def validate_contract() -> None:
    text = CONTRACT.read_text()
    required_phrases = [
        "Fresh provider readback wins",
        "Do not blindly enable RLS",
        "Do not blindly disable RLS",
        "service-only boundary",
        "Hard-fail client privilege rules",
        "Required proof before a live security mutation",
        "no production RLS mutation",
    ]
    for phrase in required_phrases:
        if phrase not in text:
            fail(f"security contract missing required phrase: {phrase}")
    for marker in REQUIRED_MARKERS:
        if marker not in text:
            fail(f"security contract missing required marker: {marker}")


def changed_migrations(base: str | None) -> list[Path]:
    if not base:
        return []
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    result: list[Path] = []
    for raw in proc.stdout.splitlines():
        if raw.startswith("supabase/migrations/") and raw.endswith(".sql"):
            path = ROOT / raw
            if path.exists():
                result.append(path)
    return result


def run_self_test() -> None:
    bad_cases = [
        "GRANT USAGE ON SCHEMA private TO authenticated;",
        "GRANT SELECT ON TABLE private.example TO anon;",
        "GRANT ALL ON ALL TABLES IN SCHEMA private TO public;",
        "GRANT USAGE ON SCHEMA net TO authenticated;",
        "GRANT EXECUTE ON FUNCTION net.http_post(text,jsonb,jsonb,jsonb,integer) TO anon;",
    ]
    for sql in bad_cases:
        if not inspect_sql(sql):
            fail(f"self-test failed to reject dangerous SQL: {sql}")
    sensitive_without_markers = "ALTER TABLE private.example ENABLE ROW LEVEL SECURITY;"
    if not inspect_sql(sensitive_without_markers):
        fail("self-test failed to require adjudication markers")
    safe_revoke = """-- PANDORA_SECURITY_ADJUDICATION: reviewed
-- PANDORA_SECURITY_ACCESS_PATH: internal service path only
-- PANDORA_SECURITY_TEST_PLAN: before and after positive and negative tests
-- PANDORA_SECURITY_ROLLBACK: regrant prior privileges if regression is proven
-- PANDORA_SECURITY_OWNER: Memory Program
REVOKE USAGE ON SCHEMA net FROM authenticated;
"""
    if inspect_sql(safe_revoke):
        fail(f"self-test rejected a marker-complete safe revoke: {inspect_sql(safe_revoke)}")
    print("security adjudication verifier self-test: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    validate_evidence()
    validate_contract()
    if args.self_test:
        run_self_test()
        return

    failures: list[str] = []
    migrations = changed_migrations(args.base)
    for path in migrations:
        for error in inspect_sql(path.read_text()):
            failures.append(f"{path.relative_to(ROOT)}: {error}")
    if failures:
        for item in failures:
            print(f"ERROR: {item}", file=sys.stderr)
        raise SystemExit(1)
    print(f"security adjudication gate: PASS ({len(migrations)} changed migration(s) inspected)")


if __name__ == "__main__":
    main()
