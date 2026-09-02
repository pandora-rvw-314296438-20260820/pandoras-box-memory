# Memory decision usefulness candidate evidence — 2026-09-02

Status: **CANDIDATE / NOT YET PRODUCTION-ACTIVE**

This evidence records the scoped implementation for Pandora Visible Creation Tasks 93/95. It does not claim deployment or canonical completion.

## Source authority

- Repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Base main at implementation start: `eb98322f850a9682b03a6a85e433a42c6594e9c5`
- Branch: `visible/memory-planning-usefulness-20260902`
- Bridge candidate raw SHA-256: `39b7ccecc2653c455dbfe197a94c3cdac38a23b59dfc20d2a952421059519063`
- Forward migration: `20260902081500_memory_decision_usefulness_v1.sql`
- Forward migration Git blob SHA-1: `61af2ec934724ba726c9f8c1ae7744194426f778`
- Forward migration SHA-256: `e2864d845e2eca06e4cd4c9da62322f2472e78183a02f80fbf432bb9d86df846`

## Contract added

Project-scoped Memory search persists the exact approved Memory item IDs in `memory_retrieval_logs` and returns the retrieval-log identity. Service-role-only RPCs then bind one exact retrieval to one `project_spec`, `build`, or `repair` decision and later record one verified outcome/usefulness event per approved Memory item. Existing Memory tables remain authoritative; no second lifecycle or analytics store is introduced.

The bridge remains Vercel-workload-OIDC authenticated, requires the existing `memory:write` scope for decision/outcome writes, enforces the active exact-project grant, and accepts only bounded identity/status/evidence-reference metadata. It does not accept prompts, source code, environment values, credentials, raw provider results, or raw errors.

## Rollback-only production-schema rehearsal

The exact migration contract was rehearsed against the live Memory schema inside a transaction that was deliberately rolled back. The probe verified:

- first retrieval-to-decision bind succeeds;
- identical bind replay is idempotent;
- first verified-outcome write succeeds;
- identical outcome replay is idempotent;
- exactly one `decision_memory_outcome` feedback row is produced for the test item;
- the transaction rollback leaves no synthetic decision/outcome rows persisted.

## Governance boundaries

The frozen 85-file historical migration baseline is unchanged. This file documents one new forward post-baseline migration only. Canonical Memory promotion rules are unchanged; usefulness feedback does not automatically promote or rewrite Memory.

Production deployment and Task 93/95 closure remain pending exact-head repository CI, current-main convergence, merge, provider migration/deployment readback, and Box-side consumer proof.
