# Postgres default function EXECUTE hardening: evidence (2026-10-20)

Status: proposed; **not applied to production**.

- Migration: `supabase/migrations/20261020090000_harden_postgres_default_function_execute_v1.sql` (placeholder version).
- Security record: `docs/security/2026-10-20_POSTGRES_DEFAULT_FUNCTION_EXECUTE_HARDENING.md`.
- Local PG17 results after applying the migration:
  - New SECURITY DEFINER fn in public: `{postgres=X,service_role=X}`. anon and authenticated are denied; service_role is allowed.
  - New fn plus explicit `GRANT ... TO authenticated`: authenticated is allowed; anon is denied.
  - New fn in private: `{postgres=X}`. New fn in storage: unchanged (it still has the client grants).
  - Existing fns: ACLs are identical before and after. `CREATE OR REPLACE` keeps the ACL. DROP+CREATE gets the hardened ACL.
  - A new trigger fn without client EXECUTE still fires on an authenticated INSERT.
  - The rollback restores the exact prior pg_default_acl. postgres cannot alter supabase_admin defaults (`permission denied to change default privileges`).
  - Negative control: a schema-only revoke that includes PUBLIC leaves `=X/postgres`, and anon can still call the function.
