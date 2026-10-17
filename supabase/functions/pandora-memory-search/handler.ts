export const CANONICAL_SUPABASE_URL = "https://ivmvufhcsezyhczzondn.supabase.co";
const PRINCIPAL_KEY = "pandora-mcpmaster-production";
const MAX_BODY_BYTES = 64 * 1024;
const MAX_QUERY_LENGTH = 4_000;
const MAX_ITEMS = 50;
const MAX_SEARCH_TERMS = 12;
const MIN_TERM_LENGTH = 3;
const MAX_TERM_LENGTH = 64;
const DEFAULT_CANON_STATUSES = ["hard_canon", "soft_canon"];
const RETRIEVABLE_CANON_STATUSES = new Set(["hard_canon", "soft_canon"]);
const APPROVED_CANON_STATUSES = new Set(["hard_canon", "soft_canon"]);
const STOP_TERMS = new Set([
  "and", "are", "for", "from", "has", "have", "its", "not", "our", "that",
  "the", "their", "them", "there", "these", "this", "was", "were", "what",
  "when", "which", "with", "you", "your",
]);

export const ALLOWED_SEARCH_KEYS = new Set([
  "action",
  "namespace",
  "project_id",
  "project_key",
  "query",
  "current_task",
  "max_items",
  "include_semantic",
  "include_profiles",
  "include_recent",
  "include_open_loops",
  "canon_statuses",
  "intent",
  "intent_domain",
  "intentDomain",
  "action_mode",
  "actionMode",
  "consequential",
  "required_capabilities",
  "requiredCapabilities",
]);

const PROJECT_SEARCH_KEY_PATTERN = /^[a-z0-9][a-z0-9._-]{1,95}$/;
const PROJECT_SEARCH_UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVIDENCE_UUID_PATTERN = PROJECT_SEARCH_UUID_PATTERN;

const M5_TYPED_MEMORY_CLASSES = new Set([
  "fact",
  "pattern",
  "policy",
  "procedure",
  "failure_lesson",
  "outcome",
  "provider_performance",
]);
const M1_INTENTS = new Set([
  "communication",
  "research",
  "coding_building",
  "files",
  "device_operations",
  "business",
  "travel",
  "scheduling",
  "future_capability",
  "general_assistance",
]);
const M1_ACTION_MODES = new Set(["no_action", "read_only", "state_change"]);
const M1_CAPABILITY_PATTERN = /^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$/;

export type JsonRecord = Record<string, unknown>;
export type AdminClient = {
  supabaseUrl?: string;
  from: (table: string) => any;
  rpc?: (fn: string, args?: Record<string, unknown>) => any;
};
export type Principal = {
  issuer: string;
  audience: string;
  subject: string;
  owner_id: string;
  project_id: string;
  project_name: string;
  environment: string;
  memory_user_id: string;
  allowed_namespaces: string[];
  scopes: string[];
  is_active: boolean;
};
export type AuthorizationResult =
  | { ok: true; principal: Principal }
  | { ok: false; error: Response };
export type AuthorizeFn = (
  request: Request,
  supabase: AdminClient,
) => Promise<AuthorizationResult>;

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

const isRecord = (value: unknown): value is JsonRecord =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const sha256 = async (value: string): Promise<string> => {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

const safeSearchTerm = (query: string): string =>
  query
    .slice(0, 240)
    .replace(/[\\%_,().:'"`]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const safeSearchTerms = (query: string): string[] => {
  const terms = new Set<string>();
  for (const candidate of safeSearchTerm(query).split(" ")) {
    if (candidate.length < MIN_TERM_LENGTH) continue;
    if (STOP_TERMS.has(candidate.toLowerCase())) continue;
    terms.add(candidate.slice(0, MAX_TERM_LENGTH));
    if (terms.size >= MAX_SEARCH_TERMS) break;
  }
  return [...terms];
};

const requestedCanonStatuses = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [...DEFAULT_CANON_STATUSES];
  const allowed = value.filter(
    (entry): entry is string =>
      typeof entry === "string" && RETRIEVABLE_CANON_STATUSES.has(entry),
  );
  return allowed.length ? [...new Set(allowed)] : [...DEFAULT_CANON_STATUSES];
};

const warningsFor = (input: {
  approvedCount: number;
  returnedCount: number;
  profileCount: number;
  eventCount: number;
  terms: string[];
  contextPack: unknown;
}): string[] => {
  const warnings: string[] = [];
  if (input.approvedCount === 0) {
    warnings.push(
      "No approved Memory records were returned for the Pandora service principal.",
    );
  }
  if (
    input.returnedCount === 0 &&
    input.profileCount === 0 &&
    input.eventCount === 0 &&
    input.terms.length > 0
  ) {
    warnings.push(
      "Retrieval matched no records for the supplied query terms; absence is not proof that Memory is empty.",
    );
  }
  if (input.terms.length === 0) {
    warnings.push(
      "Query contained no usable search terms; results are recency-ordered only.",
    );
  }
  if (!input.contextPack) {
    warnings.push(
      "No project-scoped context pack was returned; retrieval continued with exact-project records only.",
    );
  }
  return warnings;
};

export async function readBoundedBody(
  request: Request,
  { maxBytes = MAX_BODY_BYTES, timeoutMs = 5_000 } = {},
): Promise<{ ok: true; body: JsonRecord } | { ok: false; response: Response }> {
  const length = request.headers.get("content-length");
  if (length !== null) {
    if (!/^[0-9]+$/.test(length)) {
      return { ok: false, response: respond({ ok: false, error: "invalid_json" }, 400) };
    }
    if (Number(length) > maxBytes) {
      return { ok: false, response: respond({ ok: false, error: "payload_too_large" }, 413) };
    }
  }
  if (request.signal?.aborted || !request.body?.getReader) {
    return { ok: false, response: respond({ ok: false, error: "invalid_json" }, 400) };
  }

  const reader = request.body.getReader();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let abort: (() => void) | undefined;
  const cancel = () => {
    Promise.resolve(reader.cancel()).catch(() => {});
  };
  const stopped = new Promise<never>((_, reject) => {
    abort = () => {
      cancel();
      reject(new Error("BODY_READ_CANCELLED"));
    };
    request.signal?.addEventListener("abort", abort, { once: true });
    timer = setTimeout(() => {
      cancel();
      reject(new Error("BODY_READ_TIMEOUT"));
    }, timeoutMs);
  });

  try {
    const text = await Promise.race([
      (async () => {
        const decoder = new TextDecoder("utf-8", { fatal: true });
        let acc = "";
        let size = 0;
        while (true) {
          const chunk = await reader.read();
          if (chunk.done) break;
          size += chunk.value.byteLength;
          if (size > maxBytes) {
            cancel();
            throw new Error("BODY_LIMIT");
          }
          acc += decoder.decode(chunk.value, { stream: true });
        }
        acc += decoder.decode();
        return acc;
      })(),
      stopped,
    ]);

    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return { ok: false, response: respond({ ok: false, error: "invalid_json" }, 400) };
    }
    if (!isRecord(parsed)) {
      return { ok: false, response: respond({ ok: false, error: "invalid_json" }, 400) };
    }
    return { ok: true, body: parsed };
  } catch (error) {
    if (error instanceof Error && error.message === "BODY_LIMIT") {
      return { ok: false, response: respond({ ok: false, error: "payload_too_large" }, 413) };
    }
    return { ok: false, response: respond({ ok: false, error: "invalid_json" }, 400) };
  } finally {
    if (timer !== undefined) clearTimeout(timer);
    if (abort) request.signal?.removeEventListener("abort", abort);
    try {
      reader.releaseLock();
    } catch {
      // Cancelled reader cleans itself up.
    }
  }
}

export const searchMemory = async (
  body: JsonRecord,
  principal: Principal,
  supabase: AdminClient,
): Promise<Response> => {
  if (Object.keys(body).some((key) => !ALLOWED_SEARCH_KEYS.has(key))) {
    return respond({ ok: false, error: "unexpected_field" }, 400);
  }

  const namespace = body.namespace;
  const query = typeof body.query === "string" ? body.query.trim() : "";
  const currentTask = typeof body.current_task === "string"
    ? body.current_task.slice(0, 2_000)
    : null;
  const intentValue = body.intent ?? body.intent_domain ?? body.intentDomain;
  const intent = typeof intentValue === "string" && intentValue.trim()
    ? intentValue.trim()
    : "general_assistance";
  const actionModeValue = body.action_mode ?? body.actionMode;
  const actionMode = typeof actionModeValue === "string" && actionModeValue.trim()
    ? actionModeValue.trim()
    : "read_only";
  const consequential = body.consequential === true;
  const capabilitiesValue = body.required_capabilities ?? body.requiredCapabilities;
  const requiredCapabilities = Array.isArray(capabilitiesValue)
    ? capabilitiesValue.filter((entry): entry is string => typeof entry === "string")
    : [];
  const requestedMax = typeof body.max_items === "number" && Number.isInteger(body.max_items)
    ? body.max_items
    : 12;
  const maxItems = Math.min(Math.max(requestedMax, 1), MAX_ITEMS);
  const projectKey = typeof body.project_key === "string" ? body.project_key.trim() : "";
  const projectIdProvided = body.project_id !== null && body.project_id !== undefined;
  const projectId = projectIdProvided && typeof body.project_id === "string"
    ? body.project_id.trim()
    : null;

  if (!Array.isArray(principal.scopes) || !principal.scopes.includes("memory:read")) {
    return respond({ ok: false, error: "scope_not_allowed" }, 403);
  }
  if (namespace !== "real_life" && namespace !== "au") {
    return respond({ ok: false, error: "namespace_required" }, 400);
  }
  if (
    !Array.isArray(principal.allowed_namespaces) ||
    !principal.allowed_namespaces.includes(namespace)
  ) {
    return respond({ ok: false, error: "namespace_not_allowed" }, 403);
  }
  if (!query || query.length > MAX_QUERY_LENGTH) {
    return respond({ ok: false, error: "invalid_query" }, 400);
  }
  if (!M1_INTENTS.has(intent) || !M1_ACTION_MODES.has(actionMode)) {
    return respond({ ok: false, error: "invalid_task_context" }, 400);
  }
  if (
    requiredCapabilities.length > 16 ||
    requiredCapabilities.some((capability) =>
      capability.length > 96 || !M1_CAPABILITY_PATTERN.test(capability)
    )
  ) {
    return respond({ ok: false, error: "invalid_required_capabilities" }, 400);
  }
  if (
    (!projectKey && !projectId) ||
    (projectKey && !PROJECT_SEARCH_KEY_PATTERN.test(projectKey)) ||
    (projectIdProvided && (!projectId || !PROJECT_SEARCH_UUID_PATTERN.test(projectId)))
  ) {
    return respond({ ok: false, error: "project_identity_invalid" }, 400);
  }

  let projectQuery = supabase
    .from("pandora_projects")
    .select("id,project_key,memory_namespace,lifecycle_status")
    .eq("memory_namespace", namespace)
    .eq("lifecycle_status", "active");
  if (projectKey) projectQuery = projectQuery.eq("project_key", projectKey);
  if (projectId) projectQuery = projectQuery.eq("id", projectId);

  const { data: boundProject, error: boundProjectError } = await projectQuery.maybeSingle();
  if (boundProjectError) {
    return respond({ ok: false, error: "project_lookup_failed" }, 503);
  }
  if (
    !boundProject ||
    typeof boundProject.id !== "string" ||
    !PROJECT_SEARCH_UUID_PATTERN.test(boundProject.id) ||
    (typeof boundProject.project_key === "string" &&
      !PROJECT_SEARCH_KEY_PATTERN.test(boundProject.project_key))
  ) {
    return respond({ ok: false, error: "project_not_allowed" }, 403);
  }

  const canonicalProjectId = boundProject.id;
  const canonicalProjectKey =
    typeof boundProject.project_key === "string" && boundProject.project_key
      ? boundProject.project_key
      : projectKey;

  const { data: projectGrant, error: projectGrantError } = await supabase
    .from("pandora_project_grants")
    .select("project_id,allowed_record_types")
    .eq("principal_key", PRINCIPAL_KEY)
    .eq("project_id", canonicalProjectId)
    .eq("environment", principal.environment)
    .eq("is_active", true)
    .eq("can_read", true)
    .is("revoked_at", null)
    .maybeSingle();
  if (projectGrantError) {
    return respond({ ok: false, error: "project_grant_lookup_failed" }, 503);
  }
  if (
    !projectGrant ||
    (!projectGrant.project_id && !projectGrant.id) ||
    projectGrant.can_read === false ||
    projectGrant.is_active === false ||
    (projectGrant.revoked_at !== undefined && projectGrant.revoked_at !== null) ||
    (typeof projectGrant.environment === "string" &&
      projectGrant.environment !== principal.environment) ||
    (typeof projectGrant.principal_key === "string" &&
      projectGrant.principal_key !== PRINCIPAL_KEY)
  ) {
    return respond({ ok: false, error: "project_not_allowed" }, 403);
  }

  const hasExplicitRecordTypes = Array.isArray(projectGrant.allowed_record_types);
  const allowedRecordTypes = hasExplicitRecordTypes
    ? projectGrant.allowed_record_types.filter(
      (entry: unknown): entry is string =>
        typeof entry === "string" && /^[a-z0-9][a-z0-9._-]{0,95}$/.test(entry),
    )
    : [];
  if (hasExplicitRecordTypes && allowedRecordTypes.length === 0) {
    return respond({ ok: false, error: "project_grant_invalid" }, 503);
  }
  const allowedTypedClasses = allowedRecordTypes.filter((entry: string) =>
    M5_TYPED_MEMORY_CLASSES.has(entry)
  );

  let contextPack: JsonRecord | null = null;
  if (typeof supabase.rpc === "function") {
    const { data: rawContextPack, error: contextPackError } = await supabase.rpc(
      "memory_context_pack_v2",
      {
        p_project_id: canonicalProjectId,
        p_principal_key: PRINCIPAL_KEY,
        p_namespace: namespace,
        p_as_of: new Date().toISOString(),
        p_max_bytes: 12 * 1024,
      },
    );
    if (contextPackError) {
      return respond({ ok: false, error: "context_pack_unavailable" }, 503);
    }
    if (rawContextPack !== null && rawContextPack !== undefined) {
      const packProject = isRecord(rawContextPack?.project) ? rawContextPack.project : null;
      const packAuthorization = isRecord(rawContextPack?.authorization)
        ? rawContextPack.authorization
        : null;
      const packDegradation = isRecord(rawContextPack?.degradation)
        ? rawContextPack.degradation
        : null;
      const contextPackValid = isRecord(rawContextPack) &&
        rawContextPack.schemaVersion === "2.0" &&
        rawContextPack.status === "available" &&
        rawContextPack.namespace === namespace &&
        packProject?.id === canonicalProjectId &&
        packProject?.projectKey === canonicalProjectKey &&
        packAuthorization?.principalKey === PRINCIPAL_KEY &&
        packAuthorization?.environment === principal.environment &&
        packAuthorization?.canRead === true &&
        packDegradation?.legacyUnscopedPackUsed === false &&
        typeof rawContextPack.contextSha256 === "string" &&
        /^[a-f0-9]{64}$/.test(rawContextPack.contextSha256) &&
        typeof rawContextPack.byteSize === "number" &&
        rawContextPack.byteSize <= 12 * 1024;
      if (!contextPackValid) {
        return respond({ ok: false, error: "context_pack_invalid" }, 503);
      }
      contextPack = rawContextPack;
    }
  }

  const packDegradation = isRecord(contextPack?.degradation) ? contextPack.degradation : null;
  const packFreshness = isRecord(contextPack?.freshness) ? contextPack.freshness : null;
  const packOpenLoops = Array.isArray(contextPack?.openLoops) ? contextPack.openLoops : [];
  const packConflicts = Array.isArray(contextPack?.conflicts) ? contextPack.conflicts : [];

  const canonStatuses = requestedCanonStatuses(body.canon_statuses);
  let terms = safeSearchTerms(query);
  let retrievalMode = "project_scoped_keyword_recency_legacy_until_m5_class_grant";
  let taskContext: JsonRecord | null = null;
  let policyMemory: JsonRecord[] = [];
  let advisoryMemory: JsonRecord[] = [];
  let items: JsonRecord[] = [];

  if (typeof supabase.rpc === "function") {
    if (allowedTypedClasses.length > 0) {
      terms = safeSearchTerms([query, currentTask ?? "", ...requiredCapabilities].join(" "));
      const { data: typedContext, error: typedContextError } = await supabase.rpc(
        "memory_task_context_v1",
        {
          p_user_id: principal.memory_user_id,
          p_namespace: namespace,
          p_project_id: canonicalProjectId,
          p_principal_key: PRINCIPAL_KEY,
          p_environment: principal.environment,
          p_intent: intent,
          p_action_mode: actionMode,
          p_consequential: consequential,
          p_terms: terms,
          p_required_capabilities: [...new Set(requiredCapabilities)],
          p_canon_statuses: canonStatuses,
          p_max_bytes: 12 * 1024,
          p_as_of: new Date().toISOString(),
        },
      );
      if (typedContextError) {
        return respond({ ok: false, error: "task_context_unavailable" }, 503);
      }
      if (typedContext !== null && typedContext !== undefined) {
        const typedProject = isRecord(typedContext?.project) ? typedContext.project : null;
        const typedTask = isRecord(typedContext?.task) ? typedContext.task : null;
        const typedAuthorization = isRecord(typedContext?.authorization)
          ? typedContext.authorization
          : null;
        const typedInvariants = isRecord(typedContext?.invariants)
          ? typedContext.invariants
          : null;
        const typedAllowed: string[] = Array.isArray(typedAuthorization?.allowedTypedClasses)
          ? (typedAuthorization.allowedTypedClasses as unknown[]).filter(
            (entry: unknown): entry is string => typeof entry === "string",
          )
          : [];
        policyMemory = Array.isArray(typedContext?.policyMemory)
          ? typedContext.policyMemory.filter(isRecord)
          : [];
        advisoryMemory = Array.isArray(typedContext?.advisoryMemory)
          ? typedContext.advisoryMemory.filter(isRecord)
          : [];
        const allowedTypedSet = new Set(allowedTypedClasses);
        const typedContextValid = isRecord(typedContext) &&
          typedContext.schemaVersion === "m5.task-aware-retrieval.v1" &&
          typedContext.status === "available" &&
          typedContext.namespace === namespace &&
          typedProject?.id === canonicalProjectId &&
          typedProject?.projectKey === canonicalProjectKey &&
          typedTask?.intent === intent &&
          typedTask?.actionMode === actionMode &&
          typedAuthorization?.principalKey === PRINCIPAL_KEY &&
          typedAuthorization?.environment === principal.environment &&
          typedAuthorization?.canRead === true &&
          typedAuthorization?.retrievalDoesNotGrantExecutionAuthority === true &&
          typedAllowed.length === allowedTypedClasses.length &&
          typedAllowed.every((entry: string) => allowedTypedSet.has(entry)) &&
          typedInvariants?.advisoryMemoryNeverAuthorizes === true &&
          typedInvariants?.policiesSeparatedFromAdvisoryMemory === true &&
          typedInvariants?.policyRequiresRuntimeScopeValidityRevocationValidation === true &&
          typeof typedContext.contextSha256 === "string" &&
          /^[a-f0-9]{64}$/.test(typedContext.contextSha256) &&
          typeof typedContext.byteSize === "number" &&
          typedContext.byteSize <= 12 * 1024 &&
          advisoryMemory.every((item) =>
            item.recordType !== "policy" && item.authorizationEffect === "none"
          ) &&
          policyMemory.every((item) =>
            item.recordType === "policy" &&
            item.authorizationEffect ===
              "requires_exact_runtime_scope_validity_revocation_validation" &&
            item.requiresRuntimeAuthorizationValidation === true
          );
        if (!typedContextValid) {
          return respond({ ok: false, error: "task_context_invalid" }, 503);
        }
        taskContext = typedContext as JsonRecord;
        items = [...advisoryMemory, ...policyMemory];
        retrievalMode = "m5_task_aware_bounded";
      }
    } else {
      const { data: indexedItems, error: indexedItemsError } = await supabase.rpc(
        "memory_pandora_search_scoped_v1",
        {
          p_user_id: principal.memory_user_id,
          p_namespace: namespace,
          p_project_id: canonicalProjectId,
          p_principal_key: PRINCIPAL_KEY,
          p_environment: principal.environment,
          p_terms: terms,
          p_canon_statuses: canonStatuses,
          p_limit: maxItems,
        },
      );
      if (indexedItemsError) {
        return respond({ ok: false, error: "memory_query_failed" }, 503);
      }
      items = Array.isArray(indexedItems) ? (indexedItems as JsonRecord[]) : [];
    }
  }

  const semanticMatches = items.map((item: JsonRecord) => ({
    id: item.id,
    source: "memory_item",
    source_ref: item.source_summary ?? item.authorityRef ?? null,
    summary: typeof item.summary === "string"
      ? item.summary
      : `${String(item.title ?? "Memory")}: ${String(item.body ?? "")}`,
    confidence: item.confidence,
    created_at: item.created_at ?? item.observedAt ?? null,
    updated_at: item.updated_at ?? item.effectiveAt ?? null,
  }));
  const canonicalRecords = items.map((item: JsonRecord) => {
    const typed = typeof item.recordType === "string";
    const canonStatus = typed ? item.canonStatus : item.canon_status;
    return {
      id: item.id,
      namespace,
      title: item.title,
      body: typed ? item.summary : item.body,
      canon_status: canonStatus,
      approved: APPROVED_CANON_STATUSES.has(String(canonStatus)),
      memory_type: typed ? item.memoryType : item.memory_type,
      strength: typed ? null : item.strength,
      confidence: item.confidence,
      source_summary: typed ? item.summary : item.source_summary,
      provenance: typed
        ? { semanticSource: item.provenanceSemanticSource ?? null }
        : isRecord(item.metadata)
        ? item.metadata
        : null,
      created_at: typed ? item.observedAt : item.created_at,
      updated_at: typed ? item.effectiveAt : item.updated_at,
      record_type: typed ? item.recordType : item.record_type,
      authority_kind: typed ? item.authorityKind : null,
      authority_ref: typed ? item.authorityRef : null,
      authorization_effect: typed ? item.authorizationEffect : "none",
    };
  });
  const approvedRecords = canonicalRecords.filter((item) => item.approved);
  const approvedCount = approvedRecords.length;
  const approvedMemoryItemIds = approvedRecords
    .map((item) => (typeof item.id === "string" ? item.id : ""))
    .filter((id) => EVIDENCE_UUID_PATTERN.test(id));

  const queryHash = await sha256(
    `${namespace}:${canonicalProjectId}:${query}:${intent}:${actionMode}:${consequential}:${requiredCapabilities.join(",")}`,
  );
  let retrievalLogId: string | undefined;
  try {
    const logTable = supabase.from("memory_retrieval_logs");
    if (logTable && typeof logTable.insert === "function") {
      const { data: retrievalLog } = await logTable
        .insert({
          user_id: principal.memory_user_id,
          namespace,
          query_hash: queryHash,
          project_id: canonicalProjectId,
          memory_item_ids: approvedMemoryItemIds,
          metadata: {
            principal: PRINCIPAL_KEY,
            source: "pandora",
            project_id: canonicalProjectId,
            project_key: canonicalProjectKey,
            intent,
            action_mode: actionMode,
            consequential,
            required_capabilities: [...new Set(requiredCapabilities)],
            retrieval_mode: retrievalMode,
            allowed_typed_classes: allowedTypedClasses,
            returned_profiles: 0,
            returned_open_loops: packOpenLoops.length,
            returned_events: 0,
            returned_items: semanticMatches.length,
            returned_approved_items: approvedCount,
            returned_policy_items: policyMemory.length,
            returned_advisory_items: advisoryMemory.length,
            returned_context_pack: contextPack !== null,
            context_pack_type: "MemoryContextPack v2",
            context_pack_sha256: contextPack?.contextSha256 ?? null,
            context_pack_degraded: packDegradation?.degraded === true,
            context_pack_has_conflicts: packConflicts.length > 0,
            returned_daily_context_pack: false,
            search_terms: terms.length,
            canon_statuses: canonStatuses,
            unscoped_components_omitted: true,
            retrieval_does_not_grant_authority: true,
          },
        })
        .select("id")
        .maybeSingle();
      if (typeof retrievalLog?.id === "string") {
        retrievalLogId = retrievalLog.id;
      }
    }
  } catch {
    // Non-fatal if retrieval log table is unavailable in unit test fixtures.
  }

  const warnings = warningsFor({
    approvedCount,
    returnedCount: canonicalRecords.length,
    profileCount: 0,
    eventCount: 0,
    terms,
    contextPack,
  });
  if (allowedTypedClasses.length === 0) {
    warnings.push(
      "Project grant has no M5 typed classes; Pandora retained legacy scoped retrieval rather than silently expanding authority.",
    );
  }
  warnings.push(
    "Project isolation omits legacy unscoped profiles and events; project-scoped open loops and ContextPack v2 are returned only through the governed exact-project pack authority.",
  );

  return respond({
    ok: true,
    namespace,
    project_id: canonicalProjectId,
    project_key: canonicalProjectKey,
    ...(retrievalLogId ? { retrieval_log_id: retrievalLogId } : {}),
    approved_memory_item_ids: approvedMemoryItemIds,
    current_task: currentTask,
    intent,
    action_mode: actionMode,
    consequential,
    required_capabilities: [...new Set(requiredCapabilities)],
    allowed_typed_classes: allowedTypedClasses,
    retrieval_does_not_grant_authority: true,
    policy_memory: policyMemory,
    advisory_memory: advisoryMemory,
    task_context: taskContext,
    adaptive_profile: [],
    style_profile: [],
    project_context: [],
    people_context: [],
    risk_warnings: [],
    open_loops: packOpenLoops,
    latest_context_pack: contextPack,
    context_pack_freshness: packFreshness,
    context_pack_degraded: packDegradation?.degraded === true,
    context_pack_has_conflicts: packConflicts.length > 0,
    daily_context_pack: null,
    recent_events: [],
    semantic_matches: semanticMatches,
    canonical_records: canonicalRecords,
    approved_record_count: approvedCount,
    requested_canon_statuses: canonStatuses,
    retrieval_mode: retrievalMode,
    legacy_retrieval_mode: "project_scoped_keyword_recency",
    retrieval_reasoning_summary: retrievalMode === "m5_task_aware_bounded"
      ? "Pandora received only task-relevant, bounded, typed Memory already permitted by the exact project grant. Policy Memory is separated from advisory Memory and retrieval does not grant execution authority."
      : "Pandora retained the existing exact-project keyword/recency retrieval because this grant does not yet authorize M5 typed classes; no grant expansion was inferred.",
    warnings,
  });
};

export function createSearchEndpoint({
  authorize,
  client,
}: {
  authorize: AuthorizeFn;
  client: AdminClient;
}) {
  if (
    typeof authorize !== "function" ||
    !client ||
    typeof client.from !== "function" ||
    (client.supabaseUrl !== undefined && client.supabaseUrl !== CANONICAL_SUPABASE_URL)
  ) {
    throw new Error("SEARCH_MEMORY_CONFIGURATION_DENIED");
  }

  return async (request: Request): Promise<Response> => {
    try {
      if (request.method !== "POST") {
        return respond({ ok: false, error: "method_not_allowed" }, 405);
      }
      if (request.headers.has("origin")) {
        return respond({ ok: false, error: "origin_not_allowed" }, 403);
      }
      const token =
        request.headers.get("x-pandora-vercel-oidc")?.trim() ||
        request.headers.get("authorization")?.trim() ||
        "";
      if (!token || token.length > 8200) {
        return respond({ ok: false, error: "unauthorized" }, 401);
      }

      const authorization = await authorize(request, client);
      if (!authorization.ok) return authorization.error;

      const bodyResult = await readBoundedBody(request, { maxBytes: MAX_BODY_BYTES });
      if (!bodyResult.ok) return bodyResult.response;
      const body = bodyResult.body;

      if (body.action === "health") {
        if (
          !Array.isArray(authorization.principal.scopes) ||
          !authorization.principal.scopes.includes("memory:health")
        ) {
          return respond({ ok: false, error: "scope_not_allowed" }, 403);
        }
        return respond({
          ok: true,
          project: "pandora-memory-engine",
          status: "pandora-connected",
          context_pack_hydration: "active",
          daily_context_pack: "scheduled_15m",
          post_task_learning: "review_gated",
        });
      }

      if (body.action === "search") {
        return await searchMemory(body, authorization.principal, client);
      }

      return respond({ ok: false, error: "action_not_allowed" }, 403);
    } catch {
      return respond({ ok: false, error: "service_unavailable" }, 503);
    }
  };
}
