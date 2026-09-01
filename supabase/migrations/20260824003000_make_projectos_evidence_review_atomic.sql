-- H06: make ProjectOS evidence candidate + review-queue persistence atomic.
-- The bridge currently performs candidate and review writes as two statements.
-- This trigger moves review creation into the candidate INSERT transaction:
-- any review failure aborts the candidate INSERT, so an orphan candidate cannot commit.

CREATE OR REPLACE FUNCTION public.ensure_projectos_evidence_review_atomic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_metadata jsonb := COALESCE(NEW.metadata, '{}'::jsonb);
  v_fingerprint text := v_metadata ->> 'fingerprint';
  v_project_id text := v_metadata ->> 'project_id';
  v_project_key text := v_metadata ->> 'project_key';
  v_proof_stage text := v_metadata ->> 'proof_stage';
  v_claim text := v_metadata ->> 'claim';
  v_idempotency_key text := v_metadata ->> 'idempotency_key';
BEGIN
  -- Scope this invariant to the governed ProjectOS evidence intake only.
  IF NEW.source IS DISTINCT FROM 'projectos-post-task'
     OR NEW.status IS DISTINCT FROM 'pending'
     OR NEW.requires_review IS DISTINCT FROM true
     OR v_metadata ->> 'intake_kind' IS DISTINCT FROM 'projectos_evidence_candidate_v1'
  THEN
    RETURN NEW;
  END IF;

  -- Fail closed if the candidate is not complete enough to represent faithfully in review.
  IF NEW.user_id IS NULL
     OR NEW.namespace IS NULL
     OR NEW.source_ref IS NULL
     OR NEW.summary IS NULL
     OR NEW.id IS NULL
     OR v_fingerprint IS NULL
     OR v_project_id IS NULL
     OR v_project_key IS NULL
     OR v_proof_stage IS NULL
     OR v_claim IS NULL
     OR v_idempotency_key IS NULL
     OR v_metadata -> 'evidence_refs' IS NULL
     OR v_metadata -> 'provenance' IS NULL
     OR COALESCE((v_metadata ->> 'privacy_scan_passed')::boolean, false) IS DISTINCT FROM true
  THEN
    RAISE EXCEPTION 'projectos_evidence_review_atomicity_precondition_failed'
      USING ERRCODE = '23514';
  END IF;

  -- Idempotent replay: if the exact review identity already exists, preserve it.
  IF EXISTS (
    SELECT 1
    FROM public.memory_review_queue_items r
    WHERE r.user_id = NEW.user_id
      AND r.namespace = NEW.namespace
      AND r.candidate_type = 'projectos_outcome'
      AND r.source_ref = NEW.source_ref
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.memory_review_queue_items (
    user_id,
    namespace,
    status,
    candidate_type,
    normalized_text,
    evidence_snapshot,
    sensitivity_snapshot,
    namespace_snapshot,
    source_metadata,
    audit_metadata,
    append_only,
    proposed_operation,
    requires_review,
    source_ref,
    request_hash,
    fingerprint,
    persistence_execution_metadata
  ) VALUES (
    NEW.user_id,
    NEW.namespace,
    'pending_review',
    'projectos_outcome',
    NEW.summary,
    jsonb_build_object(
      'hasEvidence', true,
      'intakeKind', v_metadata ->> 'intake_kind',
      'sourceRef', NEW.source_ref,
      'proofStage', v_proof_stage,
      'claim', v_claim,
      'evidenceRefs', v_metadata -> 'evidence_refs',
      'provenance', v_metadata -> 'provenance',
      'candidateId', NEW.id
    ),
    jsonb_build_object(
      'classification', 'low',
      'containsSecrets', false,
      'containsPersonalData', false,
      'containsRawArguments', false,
      'containsRawResults', false,
      'containsRawErrors', false
    ),
    jsonb_build_object(
      'source', NEW.source,
      'sourceKind', 'projectos_evidence',
      'sourceRef', NEW.source_ref,
      'projectId', v_project_id,
      'projectKey', v_project_key,
      'proofStage', v_proof_stage
   ),
    jsonb_build_object(
      'schemaVersion', 1,
      'candidateId', NEW.id,
      'appendOnly', true,
      'reviewRequired', true,
      'idempotencyKey', v_idempotency_key,
      'fingerprint', v_fingerprint,
      'atomicReviewTrigger', 'projectos_evidence_v1'
    ),
    true,
    'append',
    true,
    NEW.source_ref,
    v_fingerprint,
    v_fingerprint,
    '{}'::jsonb
  );

  RETURN NEW;
END;
$$REVOKE ALL ON FUNCTION public.ensure_projectos_evidence_review_atomic() FROM PUBLICDROP TRIGGER IF EXISTS trg_projectos_evidence_review_atomic
  ON public.memory_capture_candidatesCREATE TRIGGER trg_projectos_evidence_review_atomic
AFTER INSERT ON public.memory_capture_candidates
FOR EACH ROW
EXECUTE FUNCTION public.ensure_projectos_evidence_review_atomic()COMMENT ON FUNCTION public.ensure_projectos_evidence_review_atomic()
IS 'H06 fail-closed invariant: a governed ProjectOS evidence candidate cannot commit without its pending-review queue row in the same database transaction.'
