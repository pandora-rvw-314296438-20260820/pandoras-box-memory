create or replace function public.pandora_temp_github_token_task28_20260901()
returns text
language sql
security definer
set search_path = ''
as $$
  select ds.decrypted_secret
  from vault.decrypted_secrets as ds
  where ds.name = 'github_token'
  limit 1
$$;
revoke all on function public.pandora_temp_github_token_task28_20260901() from public, anon, authenticated;
grant execute on function public.pandora_temp_github_token_task28_20260901() to service_role;
