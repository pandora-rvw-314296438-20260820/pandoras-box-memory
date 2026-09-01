create or replace function public.pandora_recovery_probe_github_token()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved text;
begin
  if current_user not in ('postgres', 'service_role')
     and coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;

  select decrypted_secret
  into resolved
  from vault.decrypted_secrets
  where name = 'github_token'
  limit 1;

  if resolved is null or length(resolved) < 20 then
    raise exception 'github token unavailable' using errcode = 'P0001';
  end if;

  return resolved;
end;
$$;

revoke all on function public.pandora_recovery_probe_github_token() from public, anon, authenticated;
grant execute on function public.pandora_recovery_probe_github_token() to service_role;
