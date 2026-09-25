-- The owner-defined canonical repository supersedes the historical owner binding.
-- This changes project metadata only: no user, namespace, or approval grants.
create table if not exists private.memory_project_binding_receipts (
 migration_key text not null,
 project_id uuid not null,
 before_binding jsonb not null,
 after_binding jsonb not null,
 provenance text not null,
 observed_at timestamptz not null default now(),
 primary key(migration_key,project_id)
);
alter table private.memory_project_binding_receipts enable row level security;
revoke all on private.memory_project_binding_receipts from public,anon,authenticated;
grant select,insert on private.memory_project_binding_receipts to service_role;
do $binding$
declare p record; b jsonb; a jsonb;
begin
 select id,project_key,github_owner,github_repository into strict p
 from public.pandora_projects
 where project_key='memory' and github_repository='pandoras-box-memory'
  and memory_namespace='real_life' and lifecycle_status='active'
 for update;
 if p.github_owner='pandora-rvw-314296438-20260820' then return; end if;
 if p.github_owner is distinct from 'banataosystems' then
  raise exception 'Memory repository owner changed; reconcile before modifying';
 end if;
 b:=jsonb_build_object('projectKey',p.project_key,'githubOwner',p.github_owner,'githubRepository',p.github_repository);
 update public.pandora_projects set github_owner='pandora-rvw-314296438-20260820',updated_at=now()
 where id=p.id and github_owner=p.github_owner;
 a:=jsonb_build_object('projectKey',p.project_key,'githubOwner','pandora-rvw-314296438-20260820','githubRepository',p.github_repository);
 insert into private.memory_project_binding_receipts(migration_key,project_id,before_binding,after_binding,provenance)
 values('memory_canonical_repository_binding_reconciliation',p.id,b,a,
 'Owner canonical-repository instruction; GitHub provider main 1215efacf47acb08aa463e0863efa51c616a43b3 verified 2026-09-25. Historical owner retained in this receipt.')
 on conflict do nothing;
end; $binding$;
