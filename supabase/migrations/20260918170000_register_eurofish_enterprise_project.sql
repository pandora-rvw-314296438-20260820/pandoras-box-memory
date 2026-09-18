insert into public.pandora_projects (
  project_key,
  canonical_name,
  aliases,
  github_owner,
  github_repository,
  supabase_project_ref,
  vercel_project_id,
  production_url,
  memory_namespace,
  lifecycle_status,
  confidentiality
) values (
  'enterprise-eurofish',
  '1064 Euro-Fish Trading — Pandora Enterprise',
  array['1064 Euro-Fish Trading','Euro-Fish','Pandora Enterprise Business 1'],
  'pandora-rvw-314296438-20260820',
  'pandoras-box',
  'jcyqixttuebxqqfkjonq',
  'prj_4SmL34fR5vxArnqhNZDeSLrsP7JJ',
  'https://pandora-enterprise-business-1.vercel.app',
  'real_life',
  'active',
  'restricted'
)
on conflict (project_key) do update set
  canonical_name=excluded.canonical_name,
  aliases=excluded.aliases,
  github_owner=excluded.github_owner,
  github_repository=excluded.github_repository,
  supabase_project_ref=excluded.supabase_project_ref,
  vercel_project_id=excluded.vercel_project_id,
  production_url=excluded.production_url,
  memory_namespace=excluded.memory_namespace,
  lifecycle_status=excluded.lifecycle_status,
  confidentiality=excluded.confidentiality,
  updated_at=now();
