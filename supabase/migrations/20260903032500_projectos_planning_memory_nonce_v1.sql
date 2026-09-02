
create table if not exists private.projectos_planning_memory_nonces (
  nonce uuid primary key,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

revoke all on table private.projectos_planning_memory_nonces from public, anon, authenticated;

create or replace function public.memory_claim_planning_nonce_v1(
  p_nonce uuid,
  p_request_hash text,
  p_expires_at timestamptz
) returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_inserted integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service_role_required' using errcode = '42501';
  end if;
  if p_nonce is null
     or p_request_hash !~ '^[0-9a-f]{64}$'
     or p_expires_at <= now()
     or p_expires_at > now() + interval '10 minutes' then
    raise exception 'invalid_planning_nonce' using errcode = '22023';
  end if;

  delete from private.projectos_planning_memory_nonces
  where expires_at < now() - interval '1 minute';

  insert into private.projectos_planning_memory_nonces(nonce,request_hash,expires_at)
  values(p_nonce,p_request_hash,p_expires_at)
  on conflict (nonce) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted = 1;
end;
$function$;

revoke all on function public.memory_claim_planning_nonce_v1(uuid,text,timestamptz)
from public, anon, authenticated;
grant execute on function public.memory_claim_planning_nonce_v1(uuid,text,timestamptz)
to service_role;
