import {
  buildMemorySearchRpcArgs,
  MEMORY_SEARCH_AUTHORITY,
} from "./memory-search-policy.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  const left = JSON.stringify(actual);
  const right = JSON.stringify(expected);
  if (left !== right) {
    throw new Error(`${message}: expected ${right}, received ${left}`);
  }
}

Deno.test("indexed memory search uses bounded RPC parameters", () => {
  assertEquals(
    buildMemorySearchRpcArgs("owner-a", "orchard", 20),
    {
      p_user_id: "owner-a",
      p_query: "orchard",
      p_limit: 20,
    },
    "RPC parameters",
  );
  assertEquals(
    MEMORY_SEARCH_AUTHORITY,
    "search_only",
    "generic search authority",
  );
});
