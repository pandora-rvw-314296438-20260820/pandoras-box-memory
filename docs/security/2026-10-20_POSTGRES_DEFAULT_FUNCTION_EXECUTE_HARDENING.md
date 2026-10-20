# Postgres default function EXECUTE hardening (2026-10-20)

Status: **proposed, NOT applied to production.** Requires owner approval to apply.
Owner: Mark Johnson. Project: pandoras-box-memory (`ivmvufhcsezyhczzondn`). Follow-up to PR #147 / migration `20261019235951`.

## 1. Current state (prod readback, SELECT-only, 2026-10-20 PHT)
pg_default_acl, objtype `f` (no global/namespace-0 rows exist):

| creator role | schema | defaclacl |
|---|---|---|
| postgres | public | `{postgres=X,anon=X,authenticated=X,service_role=X}` **(root cause)** |
| postgres | storage | `{postgres=X,anon=X,authenticated=X,service_role=X}` |
| supabase_admin | public | `{postgres=X,anon=X,authenticated=X,service_role=X}` (platform; postgres cannot alter) |
| supabase_admin | graphql, graphql_public | same 4 roles (platform) |
| supabase_admin | cron, extensions | `{postgres=X*}` |
| supabase_admin | realtime | `{postgres=X,dashboard_user=X}` |
| supabase_auth_admin | auth | `{postgres=X,dashboard_user=X}` |

Because there is no global row, every postgres-created function also gets the built-in `PUBLIC=X`.
Schema-specific rows are additive and cannot remove the built-in/global grant.

## 2. Effective grants / callers
21 non-extension public functions are client-executable; 0 are SECURITY DEFINER (10 trigger functions, 4 INVOKER RPCs with PUBLIC/anon, 7 INVOKER RPCs authenticated-only). This change does not modify them.
Repo references are contract/verify scripts only; no deployed edge function calls them. Edge functions use service-role clients.

## 3. Change
```sql
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```
Expected readback: postgres/global `{postgres=X/postgres}`; postgres/public `{postgres=X/postgres,service_role=X/postgres}`; others unchanged.

## 4. Impact
- Future functions created by postgres in public: EXECUTE for postgres and service_role only. Client RPCs must `GRANT EXECUTE ... TO authenticated` (fails closed).
- Future postgres functions in other schemas (e.g. private): owner-only unless granted. Prod has 0 postgres-owned non-public functions relying on PUBLIC today.
- `CREATE OR REPLACE` keeps the existing ACL (unaffected). `DROP`+`CREATE` gets the hardened ACL.
- Trigger functions fire regardless of caller EXECUTE.
- storage row and supabase_admin rows unchanged.

## 5. Tests (disposable PG17, prod role/default-ACL mirror)
See evidence note. All expectations met, including rollback restoring the exact prior pg_default_acl, and a negative control that shows a schema-only `REVOKE ... FROM PUBLIC` still leaves anon able to execute.

## 6. Rollback
```sql
BEGIN;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated;
COMMIT;
```

## 7. Verification identity
SQL readback via Supabase MCP as `postgres` (SELECT-only). Local tests are on a disposable cluster with synthetic objects only.
