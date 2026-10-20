# Security remediation: client EXECUTE on `public.memory_pandora_search_scoped_v1` (2026-10-20 PHT)

Owner authorization: Mark Johnson (narrowly scoped production fix). Project: pandoras-box-memory `ivmvufhcsezyhczzondn`.
Migration: `supabase/migrations/20261019235951_revoke_client_execute_memory_pandora_search_scoped_v1.sql`. No secrets, keys, or memory row contents are recorded here.

## Finding
- `public.memory_pandora_search_scoped_v1(uuid, text, uuid, text, text, text[], text[], integer)` is SECURITY DEFINER, owned by `postgres` (BYPASSRLS), `search_path=pg_catalog, public`.
- ACL before fix: `{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}`; PUBLIC had no entry.
- The function does not bind `p_user_id` to `auth.uid()`; authorization is a lookup on caller-supplied (project_id, principal_key, environment). Because it runs as a BYPASSRLS owner, memory_items RLS (`auth.uid() = user_id`, FORCE) does not apply. An anon/authenticated caller knowing a victim user id and a valid grant tuple could read that user's approved canon rows (reproduced in disposable PostgreSQL with synthetic data only).
- Root cause: `20260919153000_pandora_native_memory_bridge_v1` revoked only from PUBLIC. `pg_default_acl` (grantor postgres, schema public, functions) auto-grants EXECUTE to anon/authenticated at CREATE. The sibling `memory_search_scoped_v1` explicitly revokes from `public, anon, authenticated`.
- Exploitation evidence: no invocation by any role found across log sources from function creation (2026-10-01 15:09 PHT) to 2026-10-20 06:56 PHT; pg_stat_statements shows no invocation. Limits: plain SELECT/RPC via direct DB connections are not logged; pg_stat_statements has evictions.
- Callers: full sweep of deployed edge functions (133/134 retrieved; core `pandora-value-meter-v1-20260819` could not be retrieved) found one caller, `pandora-memory-search` v1, which uses a service-role client.

## Fix
Revoke EXECUTE from anon and authenticated; re-assert EXECUTE for service_role. Body, owner, SECURITY DEFINER, and search_path unchanged.

## Contract evidence (MEMORY_SECURITY_ADJUDICATION_CONTRACT_2026-09-01)
1. RLS: memory_items FORCE RLS, policy select_own. Unchanged.
2. Grants: see ACL above; after fix expected `{postgres=X/postgres,service_role=X/postgres}`.
3. Callers: pandora-memory-search (service role) only.
4. SECURITY DEFINER behaviour: documented above.
5/8. Before/after tests: disposable PostgreSQL 17 harness. Before: anon and authenticated read victim row. After: permission denied; service_role and authenticator->service_role still succeed.
6. Change: this migration.
7. Rollback: re-grant to anon, authenticated (re-opens the vulnerability; owner approval required).
9. Provider readback: recorded in the PR after apply.
10. Identity: Supabase MCP as role postgres.

## Residual risk
DROP + CREATE of this function would re-grant anon/authenticated via the default ACL; CREATE OR REPLACE keeps the revoked ACL. A separate default-privilege hardening change is drafted, not applied.

## Provider readback (applied 2026-10-20 ~08:00 PHT via Supabase MCP apply_migration, once)
- Provider migration version: `20261019235951` (`revoke_client_execute_memory_pandora_search_scoped_v1`); this file was renamed to match provider history. Migration count 142 -> 143.
- ACL after: `{postgres=X/postgres,service_role=X/postgres}`; has_function_privilege anon=false, authenticated=false, service_role=true; PUBLIC entry absent.
- pg_get_functiondef md5 unchanged: `7576577e6d5b3ccfd200cf8752a01759`.
- All 172 other public-schema function ACLs identical to the before snapshot (173 functions; only the target differs).
- Security advisors: `anon_security_definer_function_executable` and `authenticated_security_definer_function_executable` (this function) are gone; the remaining lints are unchanged.
- Synthetic test, rolled back: as service_role the call reached the body and raised `project_not_allowed` as designed for a nonexistent tuple. As anon: `permission denied for function`.
