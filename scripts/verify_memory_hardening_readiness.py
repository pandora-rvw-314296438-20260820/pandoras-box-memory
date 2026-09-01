
#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_PATH = ROOT / "docs/capabilities/evidence/MEMORY_HARDENING_READINESS_2026-09-01.json"
FUNCTIONS_DIR = ROOT / "supabase/functions"


def fail(message: str) -> None:
    raise SystemExit(f"hardening readiness failed: {message}")


def text(path: str) -> str:
    target = ROOT / path
    if not target.is_file():
        fail(f"required source missing: {path}")
    return target.read_text(encoding="utf-8")


def require_markers(path: str, markers: list[str]) -> None:
    source = text(path)
    missing = [marker for marker in markers if marker not in source]
    if missing:
        fail(f"{path} lost required fail-closed markers: {missing}")


if not EVIDENCE_PATH.is_file():
    fail("hardening evidence is missing")

evidence = json.loads(EVIDENCE_PATH.read_text(encoding="utf-8"))
if evidence.get("schemaVersion") != "1.0":
    fail("unexpected evidence schema")
if evidence.get("repository") != "pandora-rvw-314296438-20260820/pandoras-box-memory":
    fail("unexpected repository authority")

boundary = evidence.get("safetyBoundary", {})
for key in (
    "productionMutationAuthorized",
    "edgeDeletionAuthorized",
    "schemaMutationAuthorized",
    "crossProjectGeneralizationAuthorized",
):
    if boundary.get(key) is not False:
        fail(f"source-only gate must keep {key}=false")
if boundary.get("sourceOnlyGate") is not True:
    fail("sourceOnlyGate must remain true")

expected = {entry["slug"] for entry in evidence.get("canonicalEdgeAuthorities", [])}
actual = {p.name for p in FUNCTIONS_DIR.iterdir() if p.is_dir()}
if actual != expected:
    fail(f"Edge authority set changed without lifecycle adjudication: actual={sorted(actual)} expected={sorted(expected)}")

retired = set(evidence.get("memoryRetiredSourceForbiddenSlugs", []))
reintroduced = actual & retired
if reintroduced:
    fail(f"hard-retired helper source was reintroduced: {sorted(reintroduced)}")

forbidden = set(evidence.get("forbiddenParallelAuthorityNames", []))
for path in FUNCTIONS_DIR.rglob("*"):
    lowered = path.name.lower()
    if any(token.lower() in lowered for token in forbidden):
        fail(f"parallel Memory authority path detected: {path.relative_to(ROOT)}")

learning_dirs = sorted(p.name for p in FUNCTIONS_DIR.iterdir() if p.is_dir() and "learning" in p.name.lower())
if learning_dirs != ["pandora-projectos-learning"]:
    fail(f"learning Edge authority is no longer singular: {learning_dirs}")

require_markers(
    "supabase/functions/pandora-projectos-bridge/index.ts",
    [
        'const PRINCIPAL_KEY = "projectos-mcpmaster-production";',
        "jwtVerify",
        '.from("pandora_service_principals")',
        '.from("pandora_project_grants")',
        '.eq("project_id", canonicalProjectId)',
        '.eq("namespace", namespace)',
        '"memory:read"',
        '"memory:write"',
        'error: "namespace_not_allowed"',
        "project_id: canonicalProjectId",
        "project_key: canonicalProjectKey",
    ],
)

require_markers(
    "supabase/functions/pandora-machine-gateway/index.ts",
    [
        "jwtVerify",
        "verifyVercelOidc",
        'admin.rpc("gateway_authorize_oauth"',
        'admin.rpc("gateway_authorize_oidc"',
        "MEMORY_SEARCH_RESOURCE",
        'oauthChallenge("missing_bearer")',
        'reason: "unknown_principal"',
        'reason: decision?.reason_code || "missing_grant"',
    ],
)

require_markers(
    "supabase/functions/pandora-machine-gateway/memory-search-policy.ts",
    [
        'MEMORY_SEARCH_NAMESPACE = "real_life"',
        '.eq("namespace", MEMORY_SEARCH_NAMESPACE)',
        "same-owner rows in another namespace",
    ],
)

require_markers(
    ".github/workflows/machine-gateway-namespace-isolation.yml",
    [
        "EXPECTED_HEAD",
        "deno test",
        "memory-search-policy_test.ts",
        "memory-search-postgrest_test.ts",
        "deno check",
    ],
)

required_existing_gates = [
    ".github/workflows/projectos-bridge-project-isolation.yml",
    ".github/workflows/machine-gateway-namespace-isolation.yml",
    ".github/workflows/security-source-gate.yml",
    ".github/workflows/capability-registry-gate.yml",
    "scripts/verify_projectos_bridge_project_scope.py",
    "scripts/check_no_literal_secrets.sh",
]
for path in required_existing_gates:
    if not (ROOT / path).is_file():
        fail(f"existing hardening authority disappeared: {path}")

print(json.dumps({
    "ok": True,
    "edgeAuthorities": sorted(actual),
    "retiredMemoryHelpersAbsent": sorted(retired),
    "learningAuthority": learning_dirs[0],
    "sourceOnly": True,
}, indent=2))
