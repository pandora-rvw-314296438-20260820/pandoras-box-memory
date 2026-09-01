-- H02: authorization must never provision an OAuth identity or grant.
-- Existing explicitly provisioned principals and grants continue to work.
-- This is a forward-only fail-closed replacement of gateway_authorize_oauth.

CREATE OR REPLACE FUNCTION public.gateway_authorize_oauth(
  p_user_id uuid,
  p_client_id text,
  p_service_key text,
  p_action_key text,
  p_environment text,
  p_resource_key text DEFAULT NULL
)
RETURNS TABLE(
  principal_id uuid,
  principal_key text,
  allowed boolean,
  reason_code text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_principal_id uuid;
  v_principal_key text;
  v_capability_enabled boolean := false;
  v_allowed boolean := false;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM public.gateway_service_actions gsa
    WHERE gsa.service_key = p_service_key
      AND gsa.action_key = p_action_key
      AND gsa.enabled
  ) INTO v_capability_enabled;

  SELECT gp.id, gp.principal_key
    INTO v_principal_id, v_principal_key
  FROM public.gateway_principals gp
  WHERE gp.principal_type = 'oauth_user_client'
    AND gp.user_id = p_user_id
    AND gp.oauth_client_id = p_client_id
    AND gp.is_active
  LIMIT 1;

  IF v_principal_id IS NOT NULL AND v_capability_enabled THEN
    SELECT EXISTS(
      SELECT 1
      FROM public.gateway_grants gg
      WHERE gg.principal_id = v_principal_id
        AND gg.is_active
        AND gg.service_key = p_service_key
        AND gg.environment = p_environment
        AND (
          gg.action_pattern = p_action_key
          OR gg.action_pattern = p_action_key || ':*'
        )
        AND (
          gg.resource_pattern IS NULL
          OR gg.resource_pattern = p_resource_key
        )
    ) INTO v_allowed;
  END IF;

  RETURN QUERY
  SELECT
    v_principal_id,
    v_principal_key,
    v_allowed,
    CASE
      WHEN NOT v_capability_enabled THEN 'capability_not_enabled'
      WHEN v_principal_id IS NULL THEN 'unknown_principal'
      WHEN v_allowed THEN 'authorized'
      ELSE 'missing_grant'
    END;
END;
$$;
COMMENT ON FUNCTION public.gateway_authorize_oauth(uuid, text, text, text, text, text)
IS 'Fail-closed OAuth authorization. Identity and grants must be explicitly pre-provisioned; authorization never creates or reactivates them.';
