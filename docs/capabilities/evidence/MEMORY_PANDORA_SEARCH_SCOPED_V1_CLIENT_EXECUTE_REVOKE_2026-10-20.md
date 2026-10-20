# Memory pandora search scoped v1: client EXECUTE revoke (2026-10-20)

Status: applied to production (owner-authorized security fix) and provider readback recorded.

- Migration: `supabase/migrations/20261019235951_revoke_client_execute_memory_pandora_search_scoped_v1.sql`. It matches the provider history version `20261019235951` (sha256 `3dcb8cdb77e6975e437429964aa84700f3b502c628f739d10b2d0bc7ae6a109a`, 1702 bytes).
- Security record: `docs/security/2026-10-20_MEMORY_PANDORA_SEARCH_SCOPED_V1_CLIENT_EXECUTE_REMEDIATION.md`.
- Scope: one function ACL only. anon and authenticated lose EXECUTE; service_role keeps it. No body, owner, data, grant-row, Edge, or Vercel change.
- Readback: ACL `{postgres=X/postgres,service_role=X/postgres}`. functiondef md5 is unchanged. The other 172 public function ACLs are unchanged. The two SECURITY DEFINER client-executable advisor lints for this function are cleared.
