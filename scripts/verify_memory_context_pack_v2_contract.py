from pathlib import Path

root = Path(__file__).resolve().parents[1]
sql = (root / "supabase/migrations/20260906043655_memory_approved_canon_retrieval_gate_v1_repair.sql").read_text()

required = [
    "memory_context_pack_v2",
    "p_project_id uuid",
    "p_principal_key text",
    "p_namespace text default 'real_life'",
    "p_max_bytes integer default 12288",
    "p_max_bytes not between 8192 and 12288",
    "project_not_allowed",
    "environment='production'",
    "can_read is true",
    "is_active is true",
    "revoked_at is null",
    "m.project_id=p_project_id",
    "m.namespace::text=p_namespace",
    "m.canon_status::text='hard_canon'",
    "m.approved_by is not null",
    "m.approved_at is not null",
    "m.record_type=any(v_allowed)",
    "security_constraint",
    "guardrail",
    "known_bad_path",
    "superseded_path",
    "failure_pattern",
    "never_repeat",
    "negativeKnowledge",
    "unresolved_conflicts",
    "legacyUnscopedPackUsed',false",
    "REDACTED_BY_CONTEXT_PACK",
    "octet_length(v_pack::text)>p_max_bytes",
    "contextSha256",
    "revoke all on function",
    "grant execute on function",
    "service_role",
]
for token in required:
    if token not in sql:
        raise SystemExit(f"missing ContextPack v2 contract token: {token}")

for forbidden in [
    "from public.memory_context_packs",
    "join public.memory_context_packs",
    "insert into public.memory_context_packs",
    "update public.memory_context_packs",
    "delete from public.memory_context_packs",
    "insert into public.memory_items",
    "update public.memory_items",
    "delete from public.memory_items",
    "grant execute on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) to authenticated",
    "grant execute on function public.memory_context_pack_v2(uuid,text,text,timestamptz,integer) to anon",
]:
    if forbidden in sql.lower():
        raise SystemExit(f"ContextPack v2 violates read-only/isolation contract: {forbidden}")

if sql.count("m.approved_by is not null") != 4:
    raise SystemExit("all four Memory-backed ContextPack branches must require approved_by")
if sql.count("m.approved_at is not null") != 4:
    raise SystemExit("all four Memory-backed ContextPack branches must require approved_at")
if "v_project.canonical_name" not in sql:
    raise SystemExit("ContextPack project name must use pandora_projects.canonical_name")
if "v_project.name" in sql:
    raise SystemExit("invalid pandora_projects.name reference must not return")

if sql.count("project_id=p_project_id") < 5:
    raise SystemExit("all ContextPack v2 layers must be exact-project scoped")
if "v_negative:=v_negative-(jsonb_array_length(v_negative)-1)" not in sql:
    raise SystemExit("strict budget degradation path is missing")

print("MemoryContextPack v2 + negative-knowledge contract: PASS")
