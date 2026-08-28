-- Memory security hardening.
-- Live Supabase migration version: 20260828122214
-- Removes unusable direct table privileges from browser roles while preserving service_role authority.

revoke all privileges on table public.env_audit_events from anon, authenticated;
revoke all privileges on table public.env_key_versions from anon, authenticated;
revoke all privileges on table public.env_managed_keys from anon, authenticated;
revoke all privileges on table public.env_managed_projects from anon, authenticated;
revoke all privileges on table public.memory_ingest_response_cache from anon, authenticated;
