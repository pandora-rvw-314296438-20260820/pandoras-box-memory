revoke all privileges on table public.pandora_source_snapshots from anon, authenticated;
revoke all privileges on table public.pandora_source_snapshot_files from anon, authenticated;
alter table public.pandora_source_snapshots enable row level security;
alter table public.pandora_source_snapshots force row level security;
alter table public.pandora_source_snapshot_files enable row level security;
alter table public.pandora_source_snapshot_files force row level security;
grant all privileges on table public.pandora_source_snapshots to service_role;
grant all privileges on table public.pandora_source_snapshot_files to service_role;
