# Gemini all-namespace Pandora Memory access — 2026-09-27

## Owner decision

The owner explicitly approved expanding the Google Gemini OAuth MCP client from the existing `real_life`-only Memory search grant to read/search access across all Pandora Memory namespaces.

This authorization does **not** grant provider-admin access, GitHub/Vercel/Supabase mutation authority, direct canonical Memory writes, or `memory_verified_learning_propose`.

## Implementation

- Existing `memory_search` remains backward compatible: omitted `namespace` defaults to `real_life`.
- `namespace=au` uses the explicit `namespace:au` authorization resource.
- `namespace=all` uses `namespace:*` and requires an explicit wildcard resource grant.
- A new service-role-only `memory_search_namespaced_v1` RPC performs bounded hard/soft-canon discovery across one namespace or, when authorized, all namespaces.
- The existing real-life-only search RPC remains unchanged for compatibility and least privilege.
- Gemini receives the wildcard search grant; other OAuth principals retain their existing narrower grants.

## Security invariants

- Authorization remains fail-closed in `gateway_authorize_oauth`.
- Results remain discovery-only and are not decision-authoritative.
- Search is still owner/user scoped, active-row only, hard/soft canon only, and bounded to 20 rows.
- No provider credential or OAuth token is stored in source or evidence.
