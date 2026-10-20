-- Security fix: remove client (anon, authenticated) EXECUTE from a SECURITY DEFINER memory search RPC.
-- Project: pandoras-box-memory (ivmvufhcsezyhczzondn). Forward-only; body, owner, SECURITY DEFINER and search_path unchanged.
-- Prior ACL (verified 2026-10-20 PHT): {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
-- Root cause: 20260919153000_pandora_native_memory_bridge_v1 revoked only from PUBLIC; pg_default_acl
-- (role postgres, schema public, functions) had auto-granted anon/authenticated at CREATE.
-- PANDORA_SECURITY_ADJUDICATION: reviewed
-- PANDORA_SECURITY_ACCESS_PATH: only caller is edge function pandora-memory-search (service-role client, workload JWT gate); service_role keeps EXECUTE.
-- PANDORA_SECURITY_TEST_PLAN: before/after has_function_privilege for anon/authenticated/service_role/PUBLIC, functiondef md5 unchanged, all other public function ACLs unchanged, advisor readback; disposable PostgreSQL repro (anon/authenticated denied, service_role allowed).
-- PANDORA_SECURITY_ROLLBACK: grant execute on function public.memory_pandora_search_scoped_v1(uuid, text, uuid, text, text, text[], text[], integer) to anon, authenticated; (re-opens the vulnerability; do not run without owner approval)
-- PANDORA_SECURITY_OWNER: Mark Johnson
-- Record: docs/security/2026-10-20_MEMORY_PANDORA_SEARCH_SCOPED_V1_CLIENT_EXECUTE_REMEDIATION.md
BEGIN;
REVOKE EXECUTE ON FUNCTION public.memory_pandora_search_scoped_v1(uuid, text, uuid, text, text, text[], text[], integer) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.memory_pandora_search_scoped_v1(uuid, text, uuid, text, text, text[], text[], integer) TO service_role;
COMMIT;
