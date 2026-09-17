
alter table private.pandora_integration_credentials enable row level security;
alter table private.pandora_recovery_auth_changes enable row level security;
alter table private.flutterflow_credential_handoffs enable row level security;
alter table private.flutterflow_integration_credentials enable row level security;
alter table private.flutterflow_project_snapshots enable row level security;
alter table private.flutterflow_project_yaml_files enable row level security;
alter table private.memory_projectos_planning_nonces enable row level security;

comment on table private.pandora_integration_credentials is 'Private integration credentials; RLS enabled as defense in depth. No client policies are intentionally defined.';
comment on table private.pandora_recovery_auth_changes is 'Private recovery authorization changes; RLS enabled as defense in depth. No client policies are intentionally defined.';
comment on table private.flutterflow_credential_handoffs is 'Private FlutterFlow credential handoffs; RLS enabled as defense in depth. No client policies are intentionally defined.';
comment on table private.flutterflow_integration_credentials is 'Private FlutterFlow integration credentials; RLS enabled as defense in depth. No client policies are intentionally defined.';
comment on table private.flutterflow_project_snapshots is 'Private FlutterFlow project snapshots; RLS enabled. Service-role access remains available through its BYPASSRLS role and existing grants.';
comment on table private.flutterflow_project_yaml_files is 'Private FlutterFlow project YAML files; RLS enabled. Service-role access remains available through its BYPASSRLS role and existing grants.';
comment on table private.memory_projectos_planning_nonces is 'Private ProjectOS planning nonces; RLS enabled. Service-role access remains available through its BYPASSRLS role and existing grants.';
