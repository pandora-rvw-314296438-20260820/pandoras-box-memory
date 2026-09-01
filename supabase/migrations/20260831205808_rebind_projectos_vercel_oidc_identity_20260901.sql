-- Rebind ProjectOS production workload identity after the canonical Vercel project transfer.
-- Vercel team issuer mode binds issuer/audience/subject to the current team slug,
-- while owner_id binds the immutable current team id. No bearer token is stored.

do $rebind$
declare
  changed integer;
begin
  update public.pandora_service_principals
     set issuer = 'https://oidc.vercel.com/mbanatao',
         audience = 'https://vercel.com/mbanatao',
         subject = 'owner:mbanatao:project:mcpmaster:environment:production',
         owner_id = 'team_3yw1CN59ce4pj5SwyQGCAqN3',
         updated_at = now()
   where principal_key = 'projectos-mcpmaster-production'
     and provider = 'vercel_oidc'
     and project_id = 'prj_Y5rZVcq8xJVzHVt4uvfmg9wPvXMk'
     and project_name = 'mcpmaster'
     and environment = 'production'
     and is_active = true;

  get diagnostics changed = row_count;
  if changed <> 1 then
    raise exception 'expected exactly one active ProjectOS production principal, changed %', changed
      using errcode = '55000';
  end if;

  if exists (
    select 1 from public.pandora_service_principals
     where principal_key = 'projectos-mcpmaster-production'
       and (
         issuer <> 'https://oidc.vercel.com/mbanatao'
         or audience <> 'https://vercel.com/mbanatao'
         or subject <> 'owner:mbanatao:project:mcpmaster:environment:production'
         or owner_id <> 'team_3yw1CN59ce4pj5SwyQGCAqN3'
         or project_id <> 'prj_Y5rZVcq8xJVzHVt4uvfmg9wPvXMk'
         or project_name <> 'mcpmaster'
         or environment <> 'production'
         or is_active is not true
       )
  ) then
    raise exception 'ProjectOS production principal did not converge to transferred Vercel identity'
      using errcode = '55000';
  end if;
end;
$rebind$;
