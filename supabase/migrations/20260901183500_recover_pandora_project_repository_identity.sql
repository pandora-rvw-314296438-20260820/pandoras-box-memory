-- Recover canonical Pandora project repository identity after provider transfer.
-- This migration changes only project registry metadata; no Memory content or grants.

do $$
declare
  v_updated integer;
begin
  update public.pandora_projects
  set github_owner = 'pandora-rvw-314296438-20260820',
      github_repository = 'pandoras-box',
      updated_at = timezone('utc', now())
  where project_key = 'mcpmaster-pandoras-box'
    and github_owner = 'banataosystems'
    and lower(github_repository) = 'pandoras-box';

  get diagnostics v_updated = row_count;

  if v_updated = 0 and not exists (
    select 1
    from public.pandora_projects
    where project_key = 'mcpmaster-pandoras-box'
      and github_owner = 'pandora-rvw-314296438-20260820'
      and github_repository = 'pandoras-box'
  ) then
    raise exception 'Pandora project registry identity did not match the expected legacy or canonical state';
  end if;
end
$$;
