#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs/capabilities/evidence/MEMORY_LIFECYCLE_CONSOLIDATION_CONTRACT_2026-09-01.md"
EVIDENCE = ROOT / "docs/capabilities/evidence/MEMORY_LIFECYCLE_LIVE_EVIDENCE_2026-09-01.json"
BRIDGE = ROOT / "supabase/functions/pandora-projectos-bridge/index.ts"

IMMUTABLE_TABLES = (
    "memory_items",
    "pandora_memory_record_versions",
    "pandora_approval_audits",
)

REQUIRED_CONTRACT_MARKERS = (
    "Recall-safe effective-head invariant",
    "Do NOT pre-filter `superseded_by IS NULL` before historical text matching",
    "same `user_id`",
    "same `namespace`",
    "same `project_id`",
    "same `memory_type`",
    "Deduplicate results by resolved terminal-head ID",
    "memory_pruning_candidates",
    "no production lifecycle mutation",
    "no migration execution",
)

EXPECTED_GRAPH = {
    "total_items": 280,
    "active_items": 275,
    "superseded_links": 124,
    "retrieval_eligible_nonheads": 119,
    "eligible_resolved_to_terminal": 119,
    "active_approved_terminal_heads": 143,
    "max_chain_depth": 29,
    "cycle_steps": 0,
    "missing_direct_targets": 0,
    "cross_scope_resolutions": 0,
    "invalid_terminal_heads": 0,
    "eligible_alias_title_diff": 119,
    "eligible_alias_body_diff": 119,
    "eligible_alias_hash_diff": 118,
    "review_due_null_effective_heads": 143,
    "pruning_candidates": 0,
}

@dataclass(frozen=True)
class Node:
    id: str
    user_id: str
    namespace: str
    project_id: str
    memory_type: str
    title: str
    body: str
    active: bool = True
    revoked: bool = False
    approved: bool = True
    superseded_by: Optional[str] = None

class LifecycleViolation(RuntimeError):
    pass

def same_scope(a: Node, b: Node) -> bool:
    return (
        a.user_id == b.user_id
        and a.namespace == b.namespace
        and a.project_id == b.project_id
        and a.memory_type == b.memory_type
    )

def resolve_head(nodes: Dict[str, Node], start_id: str) -> Node:
    if start_id not in nodes:
        raise LifecycleViolation("matched record missing")
    origin = nodes[start_id]
    current = origin
    seen: Set[str] = set()
    while True:
        if current.id in seen:
            raise LifecycleViolation("supersession cycle")
        seen.add(current.id)
        if current.superseded_by is None:
            if not same_scope(origin, current):
                raise LifecycleViolation("terminal head crossed scope")
            if not current.active or current.revoked or not current.approved:
                raise LifecycleViolation("terminal head not current approved")
            return current
        next_node = nodes.get(current.superseded_by)
        if next_node is None:
            raise LifecycleViolation("missing successor")
        if not same_scope(origin, next_node):
            raise LifecycleViolation("successor crossed scope")
        current = next_node

def resolve_matches(nodes: Dict[str, Node], matched_ids: Iterable[str]) -> List[Node]:
    heads: Dict[str, Node] = {}
    for item_id in matched_ids:
        head = resolve_head(nodes, item_id)
        heads[head.id] = head
    return list(heads.values())

def expect_violation(nodes: Dict[str, Node], matched: Iterable[str], label: str) -> None:
    try:
        resolve_matches(nodes, matched)
    except LifecycleViolation:
        return
    raise AssertionError(f"expected lifecycle violation: {label}")

def self_test() -> None:
    base = {
        "a": Node("a", "u", "real_life", "p", "decision", "old alias", "historic wording", superseded_by="b"),
        "b": Node("b", "u", "real_life", "p", "decision", "middle", "middle wording", superseded_by="c"),
        "c": Node("c", "u", "real_life", "p", "decision", "current", "current wording"),
        "d": Node("d", "u", "real_life", "p", "decision", "another alias", "different alias", superseded_by="c"),
    }
    out = resolve_matches(base, ["a"])
    assert [n.id for n in out] == ["c"], "alias must resolve to terminal head"
    out = resolve_matches(base, ["a", "d", "c"])
    assert [n.id for n in out] == ["c"], "multiple aliases must dedupe by head"

    missing = dict(base)
    missing["a"] = Node("a", "u", "real_life", "p", "decision", "x", "x", superseded_by="missing")
    expect_violation(missing, ["a"], "missing successor")

    cycle = dict(base)
    cycle["c"] = Node("c", "u", "real_life", "p", "decision", "c", "c", superseded_by="a")
    expect_violation(cycle, ["a"], "cycle")

    cross = dict(base)
    cross["b"] = Node("b", "u", "real_life", "other-project", "decision", "b", "b", superseded_by="c")
    expect_violation(cross, ["a"], "cross-project")

    revoked = dict(base)
    revoked["c"] = Node("c", "u", "real_life", "p", "decision", "c", "c", revoked=True)
    expect_violation(revoked, ["a"], "revoked head")

    inactive = dict(base)
    inactive["c"] = Node("c", "u", "real_life", "p", "decision", "c", "c", active=False)
    expect_violation(inactive, ["a"], "inactive head")

    unapproved = dict(base)
    unapproved["c"] = Node("c", "u", "real_life", "p", "decision", "c", "c", approved=False)
    expect_violation(unapproved, ["a"], "unapproved head")

def read_text(path: Path) -> str:
    if not path.exists():
        raise AssertionError(f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")

def changed_files(base_sha: Optional[str]) -> List[str]:
    if not base_sha:
        return []
    proc = subprocess.run(
        ["git", "diff", "--name-only", f"{base_sha}...HEAD"],
        cwd=ROOT,
        check=True,
        text=True,
        capture_output=True,
    )
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]

def reject_terminal_only_prematch_filter(source: str) -> None:
    dangerous = (
        r'\.is\(\s*["\']superseded_by["\']\s*,\s*null\s*\)',
        r'\.eq\(\s*["\']superseded_by["\']\s*,\s*null\s*\)',
    )
    for pattern in dangerous:
        if re.search(pattern, source):
            raise AssertionError(
                "canonical bridge pre-filters terminal heads before historical matching; "
                "this destroys alias recall"
            )

def reject_duplicate_authorities(files: Iterable[str]) -> None:
    lowered = [f.lower() for f in files]
    forbidden_fragments = (
        "memory_items_v2",
        "memory_lifecycle_v2",
        "memory_pruning_v2",
    )
    for f in lowered:
        if any(fragment in f for fragment in forbidden_fragments):
            raise AssertionError(f"duplicate lifecycle authority path rejected: {f}")
        if f.startswith("supabase/functions/") and (
            "memory-lifecycle" in f or "memory_lifecycle" in f
        ):
            raise AssertionError(
                "new generic lifecycle Edge authority rejected; extend existing authority"
            )

def inspect_migration(path: Path, text: str) -> None:
    normalized = re.sub(r"\s+", " ", text.lower())
    for table in IMMUTABLE_TABLES:
        if re.search(rf"\btruncate(?:\s+table)?\s+(?:public\.)?{re.escape(table)}\b", normalized):
            raise AssertionError(f"destructive truncate of immutable history rejected: {path}")
        if re.search(rf"\bdelete\s+from\s+(?:public\.)?{re.escape(table)}\b", normalized):
            raise AssertionError(f"destructive delete of immutable history rejected: {path}")

    if "pandora_supersede_memory_record" in text:
        markers = (
            "lifecycle-adjudication",
            "scope-invariant",
            "replacement-invariant",
            "cycle-check",
            "rollback",
        )
        missing = [m for m in markers if m not in text.lower()]
        if missing:
            raise AssertionError(
                f"supersede RPC change lacks lifecycle adjudication markers {missing}: {path}"
            )

def validate_contract() -> None:
    contract = read_text(CONTRACT)
    for marker in REQUIRED_CONTRACT_MARKERS:
        if marker not in contract:
            raise AssertionError(f"contract missing marker: {marker}")

    evidence = json.loads(read_text(EVIDENCE))
    graph = evidence.get("lifecycle_graph", {})
    for key, expected in EXPECTED_GRAPH.items():
        actual = graph.get(key)
        if actual != expected:
            raise AssertionError(
                f"live lifecycle evidence mismatch for {key}: expected {expected}, got {actual}"
            )

    rpc = evidence.get("supersede_rpc", {})
    required_false = (
        "enforces_same_user",
        "enforces_same_namespace",
        "enforces_same_project",
        "enforces_same_memory_type",
        "requires_replacement_active",
        "requires_replacement_non_revoked",
        "requires_replacement_approved",
        "requires_replacement_terminal",
        "checks_cycle",
    )
    for key in required_false:
        if rpc.get(key) is not False:
            raise AssertionError(f"evidence must preserve current supersede-RPC gap: {key}")

    bridge = read_text(BRIDGE)
    if '.from("memory_items")' not in bridge:
        raise AssertionError("canonical bridge no longer reads memory_items")
    for marker in (
        '.eq("user_id", principal.memory_user_id)',
        '.eq("namespace", namespace)',
        '.eq("project_id", canonicalProjectId)',
        '.eq("is_active", true)',
    ):
        if marker not in bridge:
            raise AssertionError(f"canonical project-scoped bridge invariant missing: {marker}")
    reject_terminal_only_prematch_filter(bridge)

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-sha", default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()

    validate_contract()
    files = changed_files(args.base_sha)
    reject_duplicate_authorities(files)
    for name in files:
        if name.startswith("supabase/migrations/") and name.endswith(".sql"):
            path = ROOT / name
            inspect_migration(path, read_text(path))

    print(
        "Memory lifecycle contract gate: PASS "
        f"(changed_files={len(files)}, base={args.base_sha or 'none'})"
    )
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, LifecycleViolation, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"Memory lifecycle contract gate: FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
