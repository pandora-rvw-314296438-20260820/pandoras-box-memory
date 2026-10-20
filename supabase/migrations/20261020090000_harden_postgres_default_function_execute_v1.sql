-- Security hardening: stop auto-granting EXECUTE on FUTURE functions created by role postgres to clients.
-- Project: pandoras-box-memory (ivmvufhcsezyhczzondn). Placeholder version; provider may assign its own on apply.
-- Scope: pg_default_acl only. No existing function ACL, body, owner, or data changes (ALTER DEFAULT PRIVILEGES never touches existing objects).
-- Root cause addressed: pg_default_acl (role postgres, schema public, objtype f) = {postgres,anon,authenticated,service_role}=X,
--   plus the built-in PUBLIC EXECUTE default (no global pg_default_acl row exists). Together they made
--   memory_pandora_search_scoped_v1 client-executable at CREATE (fixed by 20261019235951).
-- A schema-level REVOKE ... FROM PUBLIC is a no-op against the built-in default (schema rows are additive), so the
--   PUBLIC revoke must be global (FOR ROLE postgres, no IN SCHEMA). Verified: prod has 0 postgres-owned functions outside
--   public that rely on PUBLIC (private.* already revoked); trigger functions do not need caller EXECUTE.
-- Not addressed (cannot from postgres): supabase_admin defaults in public/graphql*. Not addressed (separate decision): postgres/storage row.
-- PANDORA_SECURITY_ADJUDICATION: reviewed
-- PANDORA_SECURITY_ACCESS_PATH: future client RPCs in public must GRANT EXECUTE TO authenticated/anon explicitly; service_role keeps auto-grant in public via the remaining schema row; edge functions (service-role clients) unaffected.
-- PANDORA_SECURITY_TEST_PLAN: disposable PG17 mirror of prod roles + pg_default_acl: new public fn => {postgres,service_role} only; explicit GRANT to authenticated works; anon denied; service_role allowed; existing fn ACLs unchanged; CREATE OR REPLACE keeps ACL; DROP+CREATE gets hardened ACL; trigger fires for authenticated; rollback restores exact pg_default_acl; schema-only negative control shows PUBLIC still leaks.
-- PANDORA_SECURITY_ROLLBACK: alter default privileges for role postgres grant execute on functions to public; alter default privileges for role postgres in schema public grant execute on functions to anon, authenticated;
-- PANDORA_SECURITY_OWNER: Mark Johnson
-- Record: docs/security/2026-10-20_POSTGRES_DEFAULT_FUNCTION_EXECUTE_HARDENING.md
BEGIN;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
COMMIT;
