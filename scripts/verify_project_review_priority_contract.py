from pathlib import Path

root = Path(__file__).resolve().parents[1]
sql = (root / "supabase/migrations/20260902224500_memory_project_review_priority_v1.sql").read_text()

required = [
    "memory_project_review_priority_v1",
    "memory_project_review_group_members_v1",
    "c.project_id = p_project_id",
    "c.project_id is not null",
    "r.status = 'pending_review'",
    "r.archived_at is null",
    "source_metadata->>'projectId'",
    "family_key",
    "fingerprint",
    "duplicate_count",
    "derived_stale_status",
    "repeated_failure",
    "candidate_ids",
    "review_item_ids",\n    "array_agg(e.candidate_id order by e.created_at desc,e.candidate_id desc)",
    "revoke all on function",
    "grant execute on function",
    "service_role",
]
for token in required:
    if token not in sql:
        raise SystemExit(f"missing Task10 contract token: {token}")

for forbidden in [
    "update public.memory_capture_candidates",
    "delete from public.memory_capture_candidates",
    "update public.memory_review_queue_items",
    "delete from public.memory_review_queue_items",
    "insert into public.memory_items",
    "memory_context_packs",\n    "max(e.candidate_id)",\n    "max(e.review_item_id)",
]:
    if forbidden in sql.lower():
        raise SystemExit(f"Task10 projection must remain read-only/exact-project: {forbidden}")

if "c.project_id=p_project_id" not in sql.replace(" ", ""):
    raise SystemExit("drill-through must remain exact-project scoped")

print("Task10 project review priority contract: PASS")
