import {
  buildVerifiedLearningRpcArgs,
  parseVerifiedLearningInput,
  VERIFIED_LEARNING_ACTION,
  VERIFIED_LEARNING_TOOL,
  verifiedLearningResource,
} from "./verified-learning-policy.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message: string) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  assert(a === e, `${message}: expected ${e}, received ${a}`);
}

function expectError(fn: () => unknown, expected: string) {
  try {
    fn();
  } catch (error) {
    assert(error instanceof Error, "expected Error");
    assertEquals(error.message, expected, "error message");
    return;
  }
  throw new Error(`expected ${expected}`);
}

const projectId = "123e4567-e89b-42d3-a456-426614174000";
const verificationRef = "verify:plp:job-1";

function verifiedExecution() {
  return {
    contractVersion: "pandora-continuous-execution-v2",
    jobId: "plp-job-1",
    status: "result",
    verified: true,
    summary: "Guest request workflow completed and verified.",
    evidence: [{ phase: "verify", ref: verificationRef }],
    verification: {
      verified: true,
      verificationReceiptRef: verificationRef,
    },
    activityProjection: {
      state: "result",
      jobId: "plp-job-1",
      evidenceRefs: [{
        type: "verification_receipt",
        relation: "verification",
        ref: verificationRef,
      }],
    },
  };
}
Deno.test("verified success becomes a bounded Memory proposal input", () => {
  const parsed = parseVerifiedLearningInput({
    namespace: "real_life",
    projectId,
    execution: verifiedExecution(),
    learningKind: "procedure",
    learningSummary:
      "Use the verified guest-request sequence for the same class of request.",
    promotionBasis:
      "The exact execution completed with a verification receipt and matching result projection.",
    confidence: 0.94,
    additionalEvidenceRefs: ["runtime:plp:job-1"],
  });

  assertEquals(parsed.learningKind, "procedure", "kind");
  assertEquals(parsed.confidence, 0.94, "confidence");
  assertEquals(
    verifiedLearningResource(projectId),
    `project:${projectId}`,
    "resource",
  );
  assertEquals(
    VERIFIED_LEARNING_TOOL,
    "memory_verified_learning_propose",
    "tool",
  );
  assertEquals(VERIFIED_LEARNING_ACTION, "verified_learning.propose", "action");

  const args = buildVerifiedLearningRpcArgs(
    "owner-user",
    "plp-runtime",
    parsed,
  );
  assertEquals(args.p_project_id, projectId, "project");
  assertEquals(args.p_principal_key, "plp-runtime", "principal");
  assertEquals(args.p_learning_kind, "procedure", "rpc kind");
});
Deno.test("unverified success is rejected before Memory dispatch", () => {
  const execution = { ...verifiedExecution(), verified: false };
  expectError(
    () =>
      parseVerifiedLearningInput({
        namespace: "real_life",
        projectId,
        execution,
        learningKind: "outcome",
        learningSummary: "Do not save this.",
        promotionBasis: "It has no verified result.",
        confidence: 0.5,
      }),
    "verified_learning_success_requires_verified_result",
  );
});

Deno.test("failure lessons require independent incident verification", () => {
  const execution = {
    ...verifiedExecution(),
    status: "blocked",
    verified: false,
    blocker: { evidenceRef: "blocker:plp:job-2" },
  };
  expectError(
    () =>
      parseVerifiedLearningInput({
        namespace: "real_life",
        projectId,
        execution,
        learningKind: "failure_lesson",
        learningSummary: "A provider write was blocked.",
        promotionBasis: "The incident must be independently verified first.",
        confidence: 0.8,
      }),
    "verified_learning_incident_verification_required",
  );
});
Deno.test("credential-like material is rejected", () => {
  expectError(
    () =>
      parseVerifiedLearningInput({
        namespace: "real_life",
        projectId,
        execution: verifiedExecution(),
        learningKind: "fact",
        learningSummary: "Authorization: Bearer secret-token-value",
        promotionBasis: "Verified",
        confidence: 1,
      }),
    "verified_learning_sensitive_material",
  );
});

Deno.test("gateway uses the review-governed M5 intake, not direct canon writes", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assert(
    source.includes('"memory_ingest_verified_execution_learning_v1"'),
    "gateway must call the M5 verified-learning intake",
  );
  assert(
    !/from\(["']memory_items["']\)\.insert/.test(source),
    "gateway must not insert canonical memory_items directly",
  );
  assert(
    source.includes("canonical_memory_written: false"),
    "gateway response must preserve non-canonical status",
  );
});

Deno.test("activation migration is fail-closed and grants nobody", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../../migrations/20260918193000_register_verified_learning_gateway_action_v1.sql",
      import.meta.url,
    ),
  );
  assert(
    migration.includes("'verified_learning.propose'"),
    "migration must register the exact action",
  );
  assert(
    /enabled\s*,[\s\S]*false/i.test(migration),
    "verified learning must remain disabled after registration",
  );
  assert(
    !/insert\s+into\s+public\.gateway_grants/i.test(migration),
    "registration must not grant any principal",
  );
});
