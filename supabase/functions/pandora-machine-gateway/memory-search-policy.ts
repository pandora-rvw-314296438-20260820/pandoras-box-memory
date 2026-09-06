export const MEMORY_SEARCH_NAMESPACE = "real_life" as const;
export const MEMORY_SEARCH_RESOURCE =
  `namespace:${MEMORY_SEARCH_NAMESPACE}` as const;
export const MEMORY_SEARCH_CANON_STATUSES = [
  "hard_canon",
  "soft_canon",
] as const;
export const MEMORY_SEARCH_AUTHORITY = "search_only" as const;
export const MEMORY_DECISION_AUTHORITY = "approved_hard_canon" as const;

export type MemoryScopeFilterChain = {
  eq(column: string, value: unknown): MemoryScopeFilterChain;
};

export function sanitizeMemorySearchQuery(query: string): string {
  return query
    .replace(/[%_*]/g, "")
    .replace(/[(),]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Constrain even aggregate health metadata to the principal's real_life rows.
 * The service-role client must never disclose same-owner rows in another namespace.
 */
export function applyMemoryHealthScope<T>(
  query: T,
  userId: string,
): T {
  const filterable = query as unknown as MemoryScopeFilterChain;
  return filterable
    .eq("user_id", userId)
    .eq("namespace", MEMORY_SEARCH_NAMESPACE)
    .eq("is_active", true) as unknown as T;
}

export function buildMemorySearchRpcArgs(
  userId: string,
  safeQuery: string,
  limit: number,
) {
  const boundedLimit = Math.max(1, Math.min(20, Math.trunc(limit || 10)));
  return {
    p_user_id: userId,
    p_query: safeQuery,
    p_limit: boundedLimit,
  } as const;
}
