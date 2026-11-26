BEGIN;

-- Pandora Memory owns this schema only.
CREATE SCHEMA IF NOT EXISTS pandora_memory_native
  AUTHORIZATION postgres;

ALTER SCHEMA pandora_memory_native OWNER TO postgres;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'pandora_memory_runtime'
  ) THEN
    CREATE ROLE pandora_memory_runtime
      NOLOGIN NOINHERIT NOBYPASSRLS;
  END IF;
END $$;

ALTER ROLE pandora_memory_runtime
  NOLOGIN NOINHERIT NOBYPASSRLS;

-- Only postgres may assume the runtime role.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT member.rolname
    FROM pg_auth_members m
    JOIN pg_roles member ON member.oid = m.member
    WHERE m.roleid = 'pandora_memory_runtime'::regrole
      AND member.rolname <> 'postgres'
  LOOP
    EXECUTE format(
      'REVOKE pandora_memory_runtime FROM %I', r.rolname
    );
  END LOOP;

  FOR r IN
    SELECT granted.rolname
    FROM pg_auth_members m
    JOIN pg_roles granted ON granted.oid = m.roleid
    WHERE m.member = 'pandora_memory_runtime'::regrole
  LOOP
    EXECUTE format(
      'REVOKE %I FROM pandora_memory_runtime', r.rolname
    );
  END LOOP;
END $$;

GRANT pandora_memory_runtime TO postgres;

-- Explicitly deny access to PLP, Pandora Connect and staging archive.
REVOKE ALL ON SCHEMA
  plp_runtime,
  pandora_connect,
  pandora_memory_migration
FROM pandora_memory_runtime;

REVOKE ALL ON ALL TABLES IN SCHEMA
  public,
  plp_runtime,
  pandora_connect,
  pandora_memory_migration
FROM pandora_memory_runtime;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA
  public,
  plp_runtime,
  pandora_connect,
  pandora_memory_migration
FROM pandora_memory_runtime;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA
  plp_runtime,
  pandora_connect,
  pandora_memory_migration
FROM pandora_memory_runtime;

-- Future objects must not inherit cross-project Memory access.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA public
  REVOKE ALL ON TABLES FROM pandora_memory_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA plp_runtime
  REVOKE ALL ON TABLES FROM pandora_memory_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA pandora_connect
  REVOKE ALL ON TABLES FROM pandora_memory_runtime;

-- No public, authenticated or service-role access to native Memory.
REVOKE ALL ON ALL TABLES IN SCHEMA pandora_memory_native
FROM PUBLIC, anon, authenticated, service_role,
     pandora_memory_runtime;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA pandora_memory_native
FROM PUBLIC, anon, authenticated, service_role,
     pandora_memory_runtime;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA pandora_memory_native
FROM PUBLIC, anon, authenticated, service_role,
     pandora_memory_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA pandora_memory_native
  REVOKE ALL ON TABLES FROM
    PUBLIC, anon, authenticated, service_role,
    pandora_memory_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA pandora_memory_native
  REVOKE ALL ON SEQUENCES FROM
    PUBLIC, anon, authenticated, service_role,
    pandora_memory_runtime;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres
  IN SCHEMA pandora_memory_native
  REVOKE EXECUTE ON FUNCTIONS FROM
    PUBLIC, anon, authenticated, service_role,
    pandora_memory_runtime;

GRANT USAGE ON SCHEMA pandora_memory_native
  TO pandora_memory_runtime;

REVOKE CREATE ON SCHEMA pandora_memory_native
  FROM pandora_memory_runtime;

GRANT USAGE ON SCHEMA extensions
  TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION extensions.digest(bytea, text)
  TO pandora_memory_runtime;

-- Enforce RLS on every native Memory table.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'pandora_memory_native'
      AND c.relkind = 'r'
  LOOP
    EXECUTE format(
      'ALTER TABLE pandora_memory_native.%I ENABLE ROW LEVEL SECURITY',
      r.relname
    );

    EXECUTE format(
      'ALTER TABLE pandora_memory_native.%I FORCE ROW LEVEL SECURITY',
      r.relname
    );
  END LOOP;
END $$;

-- Recreate only the reviewed runtime policies.
DO $$
DECLARE
  p record;
  v_sql text;
BEGIN
  FOR p IN
    SELECT *
    FROM (VALUES
      ('memory_capture_candidates','runtime_select','SELECT','true',NULL::text),
      ('memory_capture_candidates','runtime_insert','INSERT',NULL::text,'true'),
      ('memory_items','runtime_select','SELECT','true',NULL::text),
      ('memory_items','runtime_lock','UPDATE','true','false'),
      ('memory_review_queue_items','runtime_select','SELECT','true',NULL::text),
      ('memory_review_queue_items','runtime_insert','INSERT',NULL::text,'true'),
      ('operating_project_constraints','runtime_select','SELECT','true',NULL::text),
      ('operating_project_decisions','runtime_select','SELECT','true',NULL::text),
      ('operating_project_open_loops','runtime_select','SELECT','true',NULL::text),
      ('pandora_memory_conflicts','runtime_select','SELECT','true',NULL::text),
      ('pandora_ops_memory_receipts_v1','runtime_select','SELECT','true',NULL::text),
      ('pandora_ops_memory_receipts_v1','runtime_insert','INSERT',NULL::text,'true'),
      ('pandora_project_grants','runtime_select','SELECT','true',NULL::text),
      ('pandora_project_grants','runtime_lock','UPDATE','true','false'),
      ('pandora_projects','runtime_select','SELECT','true',NULL::text),
      ('pandora_projects','runtime_lock','UPDATE','true','false'),
      ('pandora_service_principals','runtime_select','SELECT','true',NULL::text),
      ('pandora_service_principals','runtime_lock','UPDATE','true','false')
    ) AS x(table_name,policy_name,command,using_expr,check_expr)
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON pandora_memory_native.%I',
      p.policy_name, p.table_name
    );

    v_sql := format(
      'CREATE POLICY %I ON pandora_memory_native.%I
       FOR %s TO pandora_memory_runtime',
      p.policy_name, p.table_name, p.command
    );

    IF p.using_expr IS NOT NULL THEN
      v_sql := v_sql || format(' USING (%s)', p.using_expr);
    END IF;

    IF p.check_expr IS NOT NULL THEN
      v_sql := v_sql || format(' WITH CHECK (%s)', p.check_expr);
    END IF;

    EXECUTE v_sql;
  END LOOP;
END $$;

-- Exact runtime table privileges.
GRANT SELECT, INSERT ON TABLE
  pandora_memory_native.memory_capture_candidates,
  pandora_memory_native.memory_review_queue_items,
  pandora_memory_native.pandora_ops_memory_receipts_v1
TO pandora_memory_runtime;

GRANT SELECT ON TABLE
  pandora_memory_native.memory_items,
  pandora_memory_native.operating_project_constraints,
  pandora_memory_native.operating_project_decisions,
  pandora_memory_native.operating_project_open_loops,
  pandora_memory_native.pandora_memory_conflicts,
  pandora_memory_native.pandora_project_grants,
  pandora_memory_native.pandora_projects,
  pandora_memory_native.pandora_service_principals
TO pandora_memory_runtime;

-- Reviewed RPC catalogue.
GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_context_pack_v2(
    uuid,text,text,timestamptz,integer
  ) TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_ingest_model_outcome_candidate_v1(
    uuid,text,uuid,uuid,text,text,text,text,text,text,text,text,
    numeric,bigint,bigint,bigint,timestamptz,text[],text,text,text,
    timestamptz
  ) TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_operations_bridge_v1(
    text,uuid,text,uuid,text,text,jsonb
  ) TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_operations_performance_v1(
    uuid,text,uuid,text,text,jsonb
  ) TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_pandora_search_scoped_v1(
    uuid,text,uuid,text,text,text[],text[],integer
  ) TO pandora_memory_runtime;

GRANT EXECUTE ON FUNCTION
  pandora_memory_native.memory_task_context_v1(
    uuid,text,uuid,text,text,text,text,boolean,
    text[],text[],text[],integer,timestamptz
  ) TO pandora_memory_runtime;

COMMENT ON SCHEMA pandora_memory_native IS
  'Isolated Pandora Memory runtime. No PLP or Pandora Connect ownership.';

COMMENT ON ROLE pandora_memory_runtime IS
  'NOLOGIN, NOINHERIT, NOBYPASSRLS. Assumable only by postgres.';

-- Fail closed if the existing Tokyo baseline differs.
DO $$
DECLARE
  v_tables text[];
  v_types text[];
  v_functions text[];
  v_columns bigint;
  v_rls bigint;
  v_policies bigint;
  v_role record;
BEGIN
  SELECT array_agg(c.relname ORDER BY c.relname)
  INTO v_tables
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'pandora_memory_native'
    AND c.relkind = 'r';

  IF v_tables IS DISTINCT FROM ARRAY[
    'evidence_items',
    'memory_capture_candidates',
    'memory_context_packs',
    'memory_events',
    'memory_items',
    'memory_open_loops',
    'memory_patches',
    'memory_proposals',
    'memory_review_queue_decisions',
    'memory_review_queue_items',
    'memory_session_digests',
    'memory_sources',
    'one_best_next_actions',
    'operating_project_artifacts',
    'operating_project_constraints',
    'operating_project_decisions',
    'operating_project_open_loops',
    'operating_project_tasks',
    'operating_projects',
    'pandora_approval_audits',
    'pandora_memory_conflicts',
    'pandora_memory_record_versions',
    'pandora_ops_memory_receipts_v1',
    'pandora_project_grants',
    'pandora_projects',
    'pandora_service_principals',
    'pandora_source_snapshots',
    'priority_locks'
  ]::text[] THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_TABLE_MANIFEST_MISMATCH';
  END IF;

  SELECT count(*) INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'pandora_memory_native';

  IF v_columns <> 463 THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_COLUMN_MANIFEST_MISMATCH';
  END IF;

  SELECT array_agg(t.typname ORDER BY t.typname)
  INTO v_types
  FROM pg_type t
  JOIN pg_namespace n ON n.oid = t.typnamespace
  WHERE n.nspname = 'pandora_memory_native'
    AND t.typtype = 'e';

  IF v_types IS DISTINCT FROM ARRAY[
    'canon_status',
    'evidence_source_type',
    'memory_strength',
    'memory_type',
    'pandora_namespace'
  ]::text[] THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_ENUM_MANIFEST_MISMATCH';
  END IF;

  SELECT array_agg(p.proname ORDER BY p.proname)
  INTO v_functions
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'pandora_memory_native'
    AND p.prokind = 'f';

  IF v_functions IS DISTINCT FROM ARRAY[
    'memory_context_pack_v2',
    'memory_ingest_model_outcome_candidate_v1',
    'memory_operations_bridge_v1',
    'memory_operations_performance_v1',
    'memory_pandora_search_scoped_v1',
    'memory_task_context_v1'
  ]::text[] THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_FUNCTION_MANIFEST_MISMATCH';
  END IF;

  SELECT count(*) INTO v_rls
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'pandora_memory_native'
    AND c.relkind = 'r'
    AND c.relrowsecurity
    AND c.relforcerowsecurity;

  SELECT count(*) INTO v_policies
  FROM pg_policies
  WHERE schemaname = 'pandora_memory_native'
    AND roles = ARRAY['pandora_memory_runtime'::name];

  IF v_rls <> 28 OR v_policies <> 18 THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_RLS_MANIFEST_MISMATCH';
  END IF;

  SELECT rolcanlogin, rolinherit, rolbypassrls
  INTO v_role
  FROM pg_roles
  WHERE rolname = 'pandora_memory_runtime';

  IF v_role.rolcanlogin OR v_role.rolinherit OR v_role.rolbypassrls THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_ROLE_FLAGS_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_auth_members
    WHERE roleid = 'pandora_memory_runtime'::regrole
      AND member <> 'postgres'::regrole
  ) OR EXISTS (
    SELECT 1 FROM pg_auth_members
    WHERE member = 'pandora_memory_runtime'::regrole
  ) THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_ROLE_MEMBERSHIP_INVALID';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public','plp_runtime','pandora_connect')
      AND c.relkind IN ('r','p','v','m','f')
      AND (
        has_table_privilege('pandora_memory_runtime',c.oid,'SELECT')
        OR has_table_privilege('pandora_memory_runtime',c.oid,'INSERT')
        OR has_table_privilege('pandora_memory_runtime',c.oid,'UPDATE')
        OR has_table_privilege('pandora_memory_runtime',c.oid,'DELETE')
        OR has_table_privilege('pandora_memory_runtime',c.oid,'TRUNCATE')
      )
  ) THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_CROSS_SCHEMA_TABLE_PRIVILEGE';
  END IF;

  IF has_schema_privilege('pandora_memory_runtime','plp_runtime','USAGE')
     OR has_schema_privilege('pandora_memory_runtime','pandora_connect','USAGE')
     OR has_schema_privilege('pandora_memory_runtime','pandora_memory_migration','USAGE')
  THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_CROSS_SCHEMA_USAGE';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public','plp_runtime','pandora_connect')
      AND p.prosecdef
      AND has_function_privilege('pandora_memory_runtime',p.oid,'EXECUTE')
  ) THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_CROSS_SCHEMA_FUNCTION_EXECUTE';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE grantee = 'pandora_memory_runtime'
      AND table_schema = 'pandora_memory_native'
      AND privilege_type NOT IN ('SELECT','INSERT')
  ) THEN
    RAISE EXCEPTION 'TOKYO_MEMORY_UNEXPECTED_TABLE_PRIVILEGE';
  END IF;
END $$;

COMMIT;
