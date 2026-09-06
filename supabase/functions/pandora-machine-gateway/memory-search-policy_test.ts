import {
  applyMemoryHealthScope,
  buildMemorySearchRpcArgs,
  MEMORY_DECISION_AUTHORITY,
  MEMORY_SEARCH_AUTHORITY,
  MEMORY_SEARCH_CANON_STATUSES,
  MEMORY_SEARCH_NAMESPACE,
  MEMORY_SEARCH_RESOURCE,
  sanitizeMemorySearchQuery,
} from "./memory-search-policy.ts";

type MemoryRow = {
  id: string;
  user_id: string;
  namespace: "real_life" | "au";
  is_active: boolean;
};

type Operation = { method: "eq"; column: string; value: unknown };

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message: string) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  assert(
    actualJson === expectedJson,
    `${message}: expected ${expectedJson}, received ${actualJson}`,
  );
}

class InMemoryHealthChain {
  operations: Operation[] = [];

  constructor(public rows: MemoryRow[]) {}

  eq(column: string, value: unknown) {
    this.operations.push({ method: "eq", column, value });
    this.rows = this.rows.filter((row) =>
      row[column as keyof MemoryRow] === value
    );
    return this;
  }
}

Deno.test("memory_health count excludes same-owner AU metadata", () => {
  const query = new InMemoryHealthChain([
    {
      id: "allowed",
      user_id: "owner-a",
      namespace: "real_life",
      is_active: true,
    },
    { id: "au", user_id: "owner-a", namespace: "au", is_active: true },
    {
      id: "other",
      user_id: "owner-b",
      namespace: "real_life",
      is_active: true,
    },
    {
      id: "inactive",
      user_id: "owner-a",
      namespace: "real_life",
      is_active: false,
    },
  ]);
  const scoped = applyMemoryHealthScope(query, "owner-a");
  assert(scoped === query, "health scope must preserve the query builder");
  assertEquals(
    query.rows.map((row) => row.id),
    ["allowed"],
    "health scope",
  );
});

Deno.test("memory_search RPC args are bounded and principal-scoped", () => {
  assertEquals(
    buildMemorySearchRpcArgs("owner-a", "orchard status", 200),
    { p_user_id: "owner-a", p_query: "orchard status", p_limit: 20 },
    "search RPC args",
  );
});

Deno.test("generic search and decision authority are explicitly distinct", () => {
  assertEquals(MEMORY_SEARCH_AUTHORITY, "search_only", "search authority");
  assertEquals(
    MEMORY_DECISION_AUTHORITY,
    "approved_hard_canon",
    "decision authority",
  );
  assertEquals(
    MEMORY_SEARCH_CANON_STATUSES,
    ["hard_canon", "soft_canon"],
    "generic states",
  );
  assertEquals(MEMORY_SEARCH_NAMESPACE, "real_life", "namespace");
  assertEquals(MEMORY_SEARCH_RESOURCE, "namespace:real_life", "resource");
});

Deno.test("memory_search rejects wildcard-only input after sanitization", () => {
  for (const wildcardOnly of ["*", "***", " %%_(), ", " *%_*,() "]) {
    assertEquals(
      sanitizeMemorySearchQuery(wildcardOnly),
      "",
      "wildcard-only query",
    );
  }
  assertEquals(
    sanitizeMemorySearchQuery(" orchard_*%   status "),
    "orchard status",
    "ordinary query text",
  );
});

Deno.test({
  name: "machine gateway invokes indexed search RPC and labels it search-only",
  async fn() {
    const source = await Deno.readTextFile(
      new URL("./index.ts", import.meta.url),
    );
    const searchBranchStart = source.indexOf('if (name === "memory_search")');
    const searchBranchEnd = source.indexOf(
      'return rpcError(body.id, -32602, "unknown_tool");',
      searchBranchStart,
    );
    const searchBranch = source.slice(searchBranchStart, searchBranchEnd);
    assert(
      /admin\.rpc\(\s*"memory_search_scoped_v1"/m.test(searchBranch),
      "indexed RPC",
    );
    assert(
      /buildMemorySearchRpcArgs\(identity\.userId, safe, limit\)/m.test(
        searchBranch,
      ),
      "tested RPC args",
    );
    assert(
      /authority:\s*MEMORY_SEARCH_AUTHORITY/m.test(searchBranch),
      "authority label",
    );
    assert(
      /decision_authoritative:\s*false/m.test(searchBranch),
      "not decision authority",
    );
  },
});
