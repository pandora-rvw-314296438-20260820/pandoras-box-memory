\set ON_ERROR_STOP on
DO $test$
BEGIN
 IF (SELECT github_owner FROM public.pandora_projects WHERE project_key='memory') IS DISTINCT FROM 'pandora-rvw-314296438-20260820' THEN
  RAISE EXCEPTION 'Canonical binding not established';
 END IF;
 IF (SELECT github_owner FROM public.pandora_projects WHERE project_key='other') IS DISTINCT FROM 'other-owner' THEN
  RAISE EXCEPTION 'Unrelated project changed';
 END IF;
 IF (SELECT count(*) FROM private.memory_project_binding_receipts)<>1 THEN RAISE EXCEPTION 'Replay duplicated or lost receipt'; END IF;
 IF NOT EXISTS(SELECT 1 FROM private.memory_project_binding_receipts WHERE before_binding->>'githubOwner'='banataosystems' AND after_binding->>'githubOwner'='pandora-rvw-314296438-20260820') THEN
  RAISE EXCEPTION 'Before/after lineage missing';
 END IF;
 IF EXISTS((SELECT * FROM private.fixture_grants EXCEPT SELECT * FROM private.fixture_original_grants) UNION ALL (SELECT * FROM private.fixture_original_grants EXCEPT SELECT * FROM private.fixture_grants)) THEN
  RAISE EXCEPTION 'Unrelated project grants changed';
 END IF;
 IF has_table_privilege('anon','private.memory_project_binding_receipts','select') OR has_table_privilege('authenticated','private.memory_project_binding_receipts','select') THEN
  RAISE EXCEPTION 'Client may read private receipt';
 END IF;
 IF NOT has_table_privilege('service_role','private.memory_project_binding_receipts','select') THEN RAISE EXCEPTION 'Service receipt read broken'; END IF;
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='private.memory_project_binding_receipts'::regclass) THEN RAISE EXCEPTION 'Receipt RLS missing'; END IF;
END; $test$;
SET ROLE service_role;
SELECT count(*) AS service_receipt_read FROM private.memory_project_binding_receipts;
RESET ROLE;
SELECT 'PASS: canonical binding, replay, independent project, grant preservation, receipt lineage and access' AS result;
