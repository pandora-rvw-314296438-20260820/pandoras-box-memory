begin;

revoke all on function private.refresh_projectos_daily_context_pack() from public, anon, authenticated;

commit;
