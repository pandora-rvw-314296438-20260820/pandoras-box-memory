# Memory indexed search and authority convergence — 2026-09-06

This evidence records the source change that adds bounded indexed generic Memory discovery while preserving the stricter ProjectOS decision-authority boundary.

## Authority

- Generic machine-gateway `memory_search` is **search-only**.
- Search is scoped to the authenticated user, `real_life` namespace, active rows, and hard/soft canon.
- ProjectOS planning remains **decision-authoritative only through exact-project approved hard-canon ContextPack retrieval**.
- No cross-project, cross-user, or cross-namespace fallback was added.

## Performance

- `memory_search_scoped_v1` uses PostgreSQL full-text search with a partial GIN index over active real-life hard/soft canon.
- Results are bounded to at most 20.
- The gateway records query latency and candidate count in its bounded response while the existing gateway audit event continues to record end-to-end latency.

## Bridge boundary

The ProjectOS web proxy may use `PANDORA_MEMORY_PROJECTOS_BRIDGE_URL`, but configuration is accepted only when it resolves to the canonical Memory Supabase project `ivmvufhcsezyhczzondn` and exact `/functions/v1/pandora-projectos-bridge` path.

## Migration lineage

Applied provider history remains immutable. A machine-readable migration-authority manifest distinguishes executable source, provider receipts, and historical controls. The frozen pre-September baseline remains unchanged.

Production provider history records `memory_indexed_search_v1` as version `20260906080241`, while its canonical executable source is `20260906075000_memory_indexed_search_v1.sql`. Source now carries `20260906080241_memory_indexed_search_v1.sql` as a no-op provider-history receipt bound to executable SHA-256 `d24c2ddebf55f5135523c9886d6c5706bd15816eeb7f18e4a8972d63826dee02`. This restores provider/source identity parity without replaying the already-live generic indexed-search SQL.

## Verification gates

The PR must pass:
- Memory migration lineage recovery
- exact-head evidence registry
- Memory hardening readiness
- same-owner cross-namespace denial
- typecheck/build
- no-literal-secrets
- Supabase migration validation
