create table if not exists private.pandora_recovery_auth_changes (
  id uuid primary key default gen_random_uuid(),
  changed_at timestamptz not null default now(),
  user_id uuid not null,
  change_type text not null,
  details jsonb not null default '{}'::jsonb
);
revoke all on private.pandora_recovery_auth_changes from anon, authenticated;
grant select, insert on private.pandora_recovery_auth_changes to service_role;
insert into private.pandora_recovery_auth_changes(user_id, change_type, details)
values ('0a436417-517f-461f-819f-08f66899cdda','grant_env_admin',jsonb_build_object('role','env_admin','adminCapabilities',jsonb_build_array('env:admin'),'reason','Pandora Memory auth recovery 2026-08-09'));

