export const VERIFIED_LEARNING_ACTION = "verified_learning.propose";
export const VERIFIED_LEARNING_TOOL = "memory_verified_learning_propose";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SAFE_REF = /^[^\r\n]{1,500}$/;
const SUCCESS_KINDS = new Set(["fact", "procedure", "outcome"]);
const ALL_KINDS = new Set([...SUCCESS_KINDS, "failure_lesson"]);
const CREDENTIAL_LIKE =
  /(authorization\s*:\s*(bearer|basic)|github_pat_|gh[pousr]_[a-z0-9_]{20,}|\bsk-[a-z0-9_-]{20,}|private key|api[_-]?key\s*[:=]|secret[_-]?value\s*[:=])/i;

export type VerifiedLearningInput = {
  namespace: "real_life" | "au";
  projectId: string;
  execution: Record<string, unknown>;
  learningKind: "fact" | "procedure" | "failure_lesson" | "outcome";
  learningSummary: string;
  promotionBasis: string;
  confidence: number;
  incidentVerificationRef: string | null;
  additionalEvidenceRefs: string[];
};

function boundedText(value: unknown, maximum: number): string {
  if (typeof value !== "string") return "";
  const normalized = value.replace(/\s+/g, " ").trim();
  return normalized.length <= maximum ? normalized : "";
}

function safeRef(value: unknown): string {
  const text = boundedText(value, 500);
  return SAFE_REF.test(text) && !CREDENTIAL_LIKE.test(text) ? text : "";
}

export function parseVerifiedLearningInput(
  value: unknown,
): VerifiedLearningInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("verified_learning_invalid");
  }
  const args = value as Record<string, unknown>;
  const allowed = new Set([
    "namespace",
    "projectId",
    "execution",
    "learningKind",
    "learningSummary",
    "promotionBasis",
    "confidence",
    "incidentVerificationRef",
    "additionalEvidenceRefs",
  ]);
  if (Object.keys(args).some((key) => !allowed.has(key))) {
    throw new Error("verified_learning_unexpected_field");
  }

  const namespace = args.namespace;
  if (namespace !== "real_life" && namespace !== "au") {
    throw new Error("verified_learning_namespace_invalid");
  }

  const projectId = boundedText(args.projectId, 36);
  if (!UUID.test(projectId)) {
    throw new Error("verified_learning_project_invalid");
  }

  const learningKind = boundedText(args.learningKind, 32);
  if (!ALL_KINDS.has(learningKind)) {
    throw new Error("verified_learning_kind_invalid");
  }

  const learningSummary = boundedText(args.learningSummary, 2000);
  const promotionBasis = boundedText(args.promotionBasis, 4096);
  if (!learningSummary || !promotionBasis) {
    throw new Error("verified_learning_summary_invalid");
  }
  if (
    CREDENTIAL_LIKE.test(learningSummary) ||
    CREDENTIAL_LIKE.test(promotionBasis)
  ) {
    throw new Error("verified_learning_sensitive_material");
  }

  const confidence = Number(args.confidence);
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new Error("verified_learning_confidence_invalid");
  }

  if (
    !args.execution || typeof args.execution !== "object" ||
    Array.isArray(args.execution)
  ) {
    throw new Error("verified_learning_execution_invalid");
  }
  const execution = args.execution as Record<string, unknown>;
  if (execution.contractVersion !== "pandora-continuous-execution-v2") {
    throw new Error("verified_learning_execution_contract_invalid");
  }
  const executionJson = JSON.stringify(execution);
  if (new TextEncoder().encode(executionJson).byteLength > 60 * 1024) {
    throw new Error("verified_learning_execution_too_large");
  }
  if (CREDENTIAL_LIKE.test(executionJson)) {
    throw new Error("verified_learning_sensitive_material");
  }

  const status = boundedText(execution.status, 32);
  const verified = execution.verified === true;
  if (SUCCESS_KINDS.has(learningKind)) {
    if (status !== "result" || !verified) {
      throw new Error("verified_learning_success_requires_verified_result");
    }
  } else if (!["failed", "blocked"].includes(status) || verified) {
    throw new Error("verified_learning_failure_requires_verified_incident");
  }

  const incidentVerificationRefRaw = args.incidentVerificationRef == null
    ? null
    : safeRef(args.incidentVerificationRef);
  if (learningKind === "failure_lesson" && !incidentVerificationRefRaw) {
    throw new Error("verified_learning_incident_verification_required");
  }
  if (args.incidentVerificationRef != null && !incidentVerificationRefRaw) {
    throw new Error("verified_learning_incident_verification_invalid");
  }

  const refs = args.additionalEvidenceRefs == null
    ? []
    : Array.isArray(args.additionalEvidenceRefs)
    ? args.additionalEvidenceRefs
    : null;
  if (refs == null || refs.length > 32) {
    throw new Error("verified_learning_evidence_refs_invalid");
  }
  const additionalEvidenceRefs = refs.map(safeRef);
  if (additionalEvidenceRefs.some((ref) => !ref)) {
    throw new Error("verified_learning_evidence_refs_invalid");
  }

  return {
    namespace,
    projectId,
    execution,
    learningKind: learningKind as VerifiedLearningInput["learningKind"],
    learningSummary,
    promotionBasis,
    confidence,
    incidentVerificationRef: incidentVerificationRefRaw,
    additionalEvidenceRefs,
  };
}

export function verifiedLearningResource(projectId: string): string {
  if (!UUID.test(projectId)) {
    throw new Error("verified_learning_project_invalid");
  }
  return `project:${projectId}`;
}

export function buildVerifiedLearningRpcArgs(
  userId: string,
  principalKey: string,
  input: VerifiedLearningInput,
) {
  return {
    p_memory_user_id: userId,
    p_namespace: input.namespace,
    p_project_id: input.projectId,
    p_principal_key: principalKey,
    p_execution: input.execution,
    p_learning_kind: input.learningKind,
    p_learning_summary: input.learningSummary,
    p_promotion_basis: input.promotionBasis,
    p_confidence: input.confidence,
    p_incident_verification_ref: input.incidentVerificationRef,
    p_additional_evidence_refs: input.additionalEvidenceRefs,
  };
}
