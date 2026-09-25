-- Disposable test database only. Contains no customer records or provider credentials.
\set ON_ERROR_STOP on
CREATE SCHEMA private;
DO $roles$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role BYPASSRLS; END IF;
END; $roles$;
CREATE TABLE public.pandora_projects (
 id uuid PRIMARY KEY, project_key text, github_owner text, github_repository text,
 memory_namespace text, lifecycle_status text, updated_at timestamptz DEFAULT now()
);
CREATE TABLE private.fixture_grants(project_id uuid,namespace text,can_read boolean,can_propose boolean,can_approve boolean);
INSERT INTO public.pandora_projects VALUES
 ('10000000-0000-4000-8000-000000000001','memory','banataosystems','pandoras-box-memory','real_life','active',now()),
 ('10000000-0000-4000-8000-000000000002','other','other-owner','unrelated-repository','real_life','active',now());
INSERT INTO private.fixture_grants VALUES('10000000-0000-4000-8000-000000000001','real_life',true,false,false);
CREATE TABLE private.fixture_original_grants AS SELECT * FROM private.fixture_grants;
