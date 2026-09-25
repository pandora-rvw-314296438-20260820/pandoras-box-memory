-- PANDORA_SECURITY_ADJUDICATION: reviewed (operator source assessment; independent PR approval is still required)
-- PANDORA_SECURITY_ACCESS_PATH: owner/service-only project metadata and private receipt; no new RPC, client privilege, namespace or approval grant.
-- PANDORA_SECURITY_TEST_PLAN: isolated PostgreSQL legacy-to-canonical transition, idempotent replay, grant preservation, unexpected-owner denial and receipt access tests; live binding/receipt readback.
-- PANDORA_SECURITY_ROLLBACK: use the private before/after receipt only after verified regression and exact current-binding comparison; retain receipt history and do not regrant clients.
-- PANDORA_SECURITY_OWNER: Pandora owner authorized audit remediation on 2026-09-25; implementation by ChatGPT, independent review pending on PR 93.
-- Applied SQL body SHA-256: 80a72bdec54254dde0442da20e9801889a6caa577cd68aecd33c30e0da30f6a1
-- Replay correction after independent review 5315166277: missing-project safety,
-- service schema access and late-provisioning reconciliation. Live historical
-- migration history is unchanged. Exact previously applied SQL is retained at
-- recovery/migrations/20260925061728.applied.sql and at Git c9e733ab.
-- BEGIN REVIEWED REPLAY SQL
-- The owner-defined canonical repository supersedes the historical owner binding.
-- This changes project metadata only: no user, namespace, or approval grants.
create schema if not exists private;
grant usage on schema private to service_role;
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
-- A fresh database may not have this project yet. The narrow trigger also
-- reconciles it when provisioned later; it grants no user or project authority.
create or replace function private.memory_enforce_canonical_binding_v2()
returns trigger language plpgsql security definer set search_path=''
as $lifecycle$
declare b jsonb; a jsonb;
begin
 if new.project_key is distinct from 'memory'
    or new.github_repository is distinct from 'pandoras-box-memory'
    or new.memory_namespace::text is distinct from 'real_life'
    or new.lifecycle_status is distinct from 'active' then return new; end if;
 if new.github_owner='pandora-rvw-314296438-20260820' then return new; end if;
 if new.github_owner is distinct from 'banataosystems' then
  raise exception 'Memory repository owner changed; reconcile before modifying';
 end if;
 b:=jsonb_build_object('projectKey',new.project_key,'githubOwner',new.github_owner,'githubRepository',new.github_repository);
 new.github_owner:='pandora-rvw-314296438-20260820';
 new.updated_at:=now();
 a:=jsonb_build_object('projectKey',new.project_key,'githubOwner',new.github_owner,'githubRepository',new.github_repository);
 insert into private.memory_project_binding_receipts(migration_key,project_id,before_binding,after_binding,provenance)
 values('memory_canonical_binding_lifecycle_v2',new.id,b,a,
  'Owner canonical repository binding; late provisioning reconciled without changing project, namespace or approval grants.')
 on conflict do nothing;
 return new;
end; $lifecycle$;
revoke all on function private.memory_enforce_canonical_binding_v2() from public,anon,authenticated;
grant execute on function private.memory_enforce_canonical_binding_v2() to service_role;
drop trigger if exists memory_canonical_binding_v2 on public.pandora_projects;
create trigger memory_canonical_binding_v2
before insert or update of project_key,github_owner,github_repository,memory_namespace,lifecycle_status
on public.pandora_projects for each row execute function private.memory_enforce_canonical_binding_v2();

do $binding$
declare p record; b jsonb; a jsonb;
begin
 begin
 select id,project_key,github_owner,github_repository into strict p
 from public.pandora_projects
 where project_key='memory' and github_repository='pandoras-box-memory'
  and memory_namespace='real_life' and lifecycle_status='active'
 for update;
 exception when no_data_found then
  -- Trigger above reconciles this exact project at future provisioning.
  return;
 end;
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
