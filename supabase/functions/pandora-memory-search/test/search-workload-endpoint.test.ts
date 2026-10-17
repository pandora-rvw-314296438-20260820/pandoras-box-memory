import { exportJWK, generateKeyPair, SignJWT } from "npm:jose@5.10.0";
import { authorize } from "../workload-auth.ts";
import { CANONICAL_SUPABASE_URL, createSearchEndpoint, type Principal } from "../handler.ts";

const pair = await generateKeyPair("RS256");
const key = {
  ...(await exportJWK(pair.publicKey)),
  kid: "pandora-search-unit-fixture",
  alg: "RS256",
  use: "sig",
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async (input) => {
  const url = typeof input === "string"
    ? input
    : input instanceof URL
    ? input.href
    : input.url;
  if (
    ![
      "https://oidc.vercel.com/mbanatao/.well-known/jwks",
      "https://oidc.vercel.com/.well-known/jwks",
    ].includes(url)
  ) {
    throw new Error(`Unexpected test network: ${url}`);
  }
  return Response.json({ keys: [key] });
};

const PROJECT_ID = "7c686cbd-d968-49d5-86cc-918f5e777bd2";
const PROJECT_KEY = "mcpmaster-pandoras-box";
const MEMORY_ITEM_ID = "33e5b2de-048b-4814-b601-7d7daac7a649";
const RETRIEVAL_LOG_ID = "5536b0be-cd7b-454e-ab27-57574539699d";
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const basePrincipal = (): Principal => ({
  issuer: "https://oidc.vercel.com/mbanatao",
  audience: "https://vercel.com/mbanatao",
  subject: "owner:mbanatao:project:mcpmaster:environment:production",
  owner_id: "team_fixture",
  project_id: "prj_fixture",
  project_name: "mcpmaster",
  environment: "production",
  memory_user_id: "0a436417-517f-461f-819f-08f66899cdda",
  allowed_namespaces: ["real_life"],
  scopes: ["memory:read", "memory:health"],
  is_active: true,
});

const baseClaims = () => {
  const p = basePrincipal();
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: p.issuer,
    aud: p.audience,
    sub: p.subject,
    owner_id: p.owner_id,
    project_id: p.project_id,
    project: p.project_name,
    environment: p.environment,
    iat: now,
    exp: now + 300,
  };
};

async function signToken(
  payload: Record<string, unknown> = baseClaims(),
  privateKey = pair.privateKey,
) {
  return await new SignJWT(payload)
    .setProtectedHeader({ alg: "RS256", kid: key.kid })
    .sign(privateKey);
}

type FakeClientOptions = {
  principal?: Principal | null;
  project?: Record<string, unknown> | null;
  grant?: Record<string, unknown> | null;
  throwOnProject?: Error;
};

function createFakeClient(options: FakeClientOptions = {}) {
  const principalRow = options.principal === undefined ? basePrincipal() : options.principal;
  const projectRow = options.project === undefined
    ? {
      id: PROJECT_ID,
      project_key: PROJECT_KEY,
      memory_namespace: "real_life",
      lifecycle_status: "active",
    }
    : options.project;
  const grantRow = options.grant === undefined
    ? {
      project_id: PROJECT_ID,
      allowed_record_types: ["project_identity", "architecture", "decision"],
    }
    : options.grant;

  return {
    supabaseUrl: CANONICAL_SUPABASE_URL,
    from(table: string) {
      if (table === "pandora_service_principals") {
        const filters: Record<string, unknown> = {};
        const query = {
          select: (_cols: string) => query,
          eq: (k: string, v: unknown) => {
            filters[k] = v;
            return query;
          },
          maybeSingle: async () => {
            if (
              filters.principal_key !== "pandora-mcpmaster-production" ||
              filters.is_active !== true
            ) {
              return { data: null, error: null };
            }
            return { data: principalRow, error: null };
          },
        };
        return query;
      }

      if (table === "pandora_projects") {
        if (options.throwOnProject) {
          throw options.throwOnProject;
        }
        const filters: Record<string, unknown> = {};
        const query = {
          select: (_cols: string) => query,
          eq: (k: string, v: unknown) => {
            filters[k] = v;
            return query;
          },
          maybeSingle: async () => {
            if (
              !projectRow ||
              filters.memory_namespace !== projectRow.memory_namespace ||
              filters.lifecycle_status !== "active" ||
              (filters.project_key && filters.project_key !== projectRow.project_key) ||
              (filters.id && filters.id !== projectRow.id)
            ) {
              return { data: null, error: null };
            }
            return { data: projectRow, error: null };
          },
        };
        return query;
      }

      if (table === "pandora_project_grants") {
        const eqFilters: Record<string, unknown> = {};
        const isFilters: Record<string, unknown> = {};
        const query = {
          select: (_cols: string) => query,
          eq: (k: string, v: unknown) => {
            eqFilters[k] = v;
            return query;
          },
          is: (k: string, v: unknown) => {
            isFilters[k] = v;
            return query;
          },
          maybeSingle: async () => {
            if (
              !grantRow ||
              eqFilters.principal_key !== "pandora-mcpmaster-production" ||
              eqFilters.project_id !== PROJECT_ID ||
              eqFilters.environment !== (principalRow?.environment ?? "production") ||
              eqFilters.is_active !== true ||
              eqFilters.can_read !== true ||
              isFilters.revoked_at !== null
            ) {
              return { data: null, error: null };
            }
            return { data: grantRow, error: null };
          },
        };
        return query;
      }

      if (table === "memory_retrieval_logs") {
        const query = {
          insert: (_row: unknown) => query,
          select: (_cols: string) => query,
          maybeSingle: async () => ({
            data: { id: RETRIEVAL_LOG_ID },
            error: null,
          }),
        };
        return query;
      }

      throw new Error(`Unexpected table: ${table}`);
    },
    rpc: async (fn: string, args?: Record<string, unknown>) => {
      if (fn === "memory_context_pack_v2") {
        return {
          data: {
            schemaVersion: "2.0",
            status: "available",
            namespace: args?.p_namespace ?? "real_life",
            project: {
              id: PROJECT_ID,
              projectKey: PROJECT_KEY,
            },
            authorization: {
              principalKey: "pandora-mcpmaster-production",
              environment: "production",
              canRead: true,
            },
            degradation: {
              degraded: false,
              legacyUnscopedPackUsed: false,
            },
            freshness: {
              generatedAt: "2026-10-18T00:00:00Z",
            },
            openLoops: [{ id: "loop-1", summary: "Verify edge search deployment" }],
            conflicts: [],
            contextSha256: "a".repeat(64),
            byteSize: 512,
          },
          error: null,
        };
      }
      if (fn === "memory_pandora_search_scoped_v1") {
        return {
          data: [
            {
              id: MEMORY_ITEM_ID,
              title: "Pandora Architecture",
              body: "Dedicated search edge function isolates read traffic.",
              canon_status: "hard_canon",
              memory_type: "architecture",
              record_type: "architecture",
              confidence: 0.95,
              strength: 0.9,
              source_summary: "architecture-doc",
              metadata: { reviewed: true },
              created_at: "2026-10-18T00:00:00Z",
              updated_at: "2026-10-18T00:00:00Z",
            },
          ],
          error: null,
        };
      }
      throw new Error(`Unexpected RPC: ${fn}`);
    },
  };
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("search allowed (200) for a valid principal with a project and grant, returning pandoras-box client schema", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient(),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "real_life",
        project_id: PROJECT_ID,
        project_key: PROJECT_KEY,
        query: "Pandora architecture search",
      }),
    }),
  );

  assert(response.status === 200, `Expected 200, got ${response.status}`);
  const body = await response.json();
  assert(body && typeof body === "object" && !Array.isArray(body), "Response must be a JSON object");
  assert(body.ok === true, "ok must be literal true");
  assert(body.namespace === "real_life", "namespace must match");
  assert(typeof body.project_id === "string" && UUID_REGEX.test(body.project_id), "project_id must be a uuid");
  assert(body.project_key === PROJECT_KEY, "project_key must match");
  assert(
    typeof body.retrieval_log_id === "string" && UUID_REGEX.test(body.retrieval_log_id),
    "retrieval_log_id must be a uuid",
  );
  assert(
    Array.isArray(body.approved_memory_item_ids) &&
      body.approved_memory_item_ids.length === 1 &&
      body.approved_memory_item_ids.every((id: unknown) => typeof id === "string" && UUID_REGEX.test(id)),
    "approved_memory_item_ids must be an array of uuids",
  );
  for (const field of [
    "project_context",
    "risk_warnings",
    "open_loops",
    "recent_events",
    "semantic_matches",
    "adaptive_profile",
    "style_profile",
  ]) {
    assert(Array.isArray(body[field]), `Expected ${field} to be an array`);
  }
  assert(body.semantic_matches.length === 1, "Expected 1 semantic match");
});

Deno.test("health allowed (200) and returns ok boolean plus project and status strings", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient(),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({ action: "health" }),
    }),
  );

  assert(response.status === 200, `Expected 200, got ${response.status}`);
  const body = await response.json();
  assert(typeof body.ok === "boolean" && body.ok === true, "health ok must be true");
  assert(typeof body.project === "string" && body.project === "pandora-memory-engine", "health project string");
  assert(typeof body.status === "string" && body.status === "pandora-connected", "health status string");
});

for (const disallowedAction of [
  "operations",
  "submit_evidence_candidate",
  "growth_context",
  "unknown_action",
  undefined,
]) {
  const label = disallowedAction === undefined ? "missing action" : disallowedAction;
  Deno.test(`returns 403 action_not_allowed for ${label}`, async () => {
    const token = await signToken();
    const endpoint = createSearchEndpoint({
      authorize,
      client: createFakeClient(),
    });

    const payload = disallowedAction === undefined ? {} : { action: disallowedAction };
    const response = await endpoint(
      new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
        method: "POST",
        headers: {
          "x-pandora-vercel-oidc": token,
          "content-type": "application/json",
        },
        body: JSON.stringify(payload),
      }),
    );

    assert(response.status === 403, `Expected 403 for ${label}, got ${response.status}`);
    const body = await response.json();
    assert(body.ok === false && body.error === "action_not_allowed", `Expected action_not_allowed for ${label}`);
  });
}

for (const claimField of [
  "iss",
  "aud",
  "sub",
  "owner_id",
  "project_id",
  "project",
  "environment",
]) {
  Deno.test(`wrong principal claim (${claimField}) gives 403`, async () => {
    const badToken = await signToken({
      ...baseClaims(),
      [claimField]: claimField === "iss"
        ? "https://oidc.vercel.com/otherteam"
        : "wrong_value",
    });
    const endpoint = createSearchEndpoint({
      authorize,
      client: createFakeClient(),
    });

    const response = await endpoint(
      new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
        method: "POST",
        headers: {
          "x-pandora-vercel-oidc": badToken,
          "content-type": "application/json",
        },
        body: JSON.stringify({ action: "health" }),
      }),
    );

    assert(response.status === 403, `Expected 403 for wrong ${claimField}, got ${response.status}`);
    const body = await response.json();
    assert(body.ok === false, "Expected ok: false");
  });
}

Deno.test("no grant row gives 403 project_not_allowed", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient({ grant: null }),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "real_life",
        project_id: PROJECT_ID,
        project_key: PROJECT_KEY,
        query: "Pandora architecture",
      }),
    }),
  );

  assert(response.status === 403, `Expected 403, got ${response.status}`);
  const body = await response.json();
  assert(body.ok === false && body.error === "project_not_allowed", `Expected project_not_allowed, got ${body.error}`);
});

Deno.test("wrong namespace (au when principal only allows real_life) gives 403", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient(),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "au",
        project_id: PROJECT_ID,
        project_key: PROJECT_KEY,
        query: "Pandora architecture",
      }),
    }),
  );

  assert(response.status === 403, `Expected 403, got ${response.status}`);
  const body = await response.json();
  assert(body.ok === false && body.error === "namespace_not_allowed", `Expected namespace_not_allowed, got ${body.error}`);
});

Deno.test("missing memory:read scope gives 403", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient({
      principal: {
        ...basePrincipal(),
        scopes: ["memory:health"],
      },
    }),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "real_life",
        project_id: PROJECT_ID,
        project_key: PROJECT_KEY,
        query: "Pandora architecture",
      }),
    }),
  );

  assert(response.status === 403, `Expected 403, got ${response.status}`);
  const body = await response.json();
  assert(body.ok === false && body.error === "scope_not_allowed", `Expected scope_not_allowed, got ${body.error}`);
});

Deno.test("Origin header gives 403", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient(),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        origin: "https://evil.example",
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({ action: "health" }),
    }),
  );

  assert(response.status === 403, `Expected 403, got ${response.status}`);
  const body = await response.json();
  assert(body.ok === false, "Expected ok: false");
});

Deno.test("unexpected body keys for search return 400 and non-POST returns 405", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient(),
  });

  const getResp = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "GET",
    }),
  );
  assert(getResp.status === 405, `Expected 405 for GET, got ${getResp.status}`);

  const badBodyResp = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "real_life",
        project_key: PROJECT_KEY,
        query: "Pandora",
        unexpected_extra_key: "not_allowed",
      }),
    }),
  );
  assert(badBodyResp.status === 400, `Expected 400 for unexpected key, got ${badBodyResp.status}`);
  const badBody = await badBodyResp.json();
  assert(badBody.ok === false && badBody.error === "unexpected_field", "Expected unexpected_field");
});

Deno.test("internal exceptions return 503 with no internal detail", async () => {
  const token = await signToken();
  const endpoint = createSearchEndpoint({
    authorize,
    client: createFakeClient({
      throwOnProject: new Error("sensitive_database_connection_string_leak"),
    }),
  });

  const response = await endpoint(
    new Request("https://memory.invalid/functions/v1/pandora-memory-search", {
      method: "POST",
      headers: {
        "x-pandora-vercel-oidc": token,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "search",
        namespace: "real_life",
        project_id: PROJECT_ID,
        project_key: PROJECT_KEY,
        query: "Pandora architecture",
      }),
    }),
  );

  assert(response.status === 503, `Expected 503, got ${response.status}`);
  const text = await response.text();
  assert(!text.includes("sensitive_database_connection_string_leak"), "Must not leak internal error detail");
});

Deno.test("restore mocked JWKS transport", () => {
  globalThis.fetch = originalFetch;
});
