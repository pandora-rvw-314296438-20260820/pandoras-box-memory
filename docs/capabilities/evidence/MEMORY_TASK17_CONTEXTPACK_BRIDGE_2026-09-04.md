# Memory Task17 ContextPack Bridge Evidence — 2026-09-04

Scope: P5 Memory-side Task17 convergence only.

Base signed Memory main: `94fcf1698432ca06afa11fb2e416f6d390eac7c3`.
Candidate branch: `chatgpt-memory/task17-contextpack-bridge-20260904`.
Candidate head before this evidence co-change: `0a7ab58bf8a3aa8db0994fc418dfba889814f02a`.

Implemented contract:
- reuse existing service-only `public.memory_context_pack_v2(uuid,text,text,timestamptz,integer)`;
- invoke it from the existing authenticated `pandora-projectos-bridge` after exact active project + grant resolution;
- validate schemaVersion/status, exact namespace/project/projectKey, principal/environment/canRead, `legacyUnscopedPackUsed=false`, SHA-256 shape, and <=12KiB bound;
- fail closed as `context_pack_unavailable` or `context_pack_invalid` rather than silently continuing without the governed pack;
- surface governed open loops, latest ContextPack v2, freshness, degradation, and unresolved-conflict presence;
- record pack SHA/degraded/conflict state in retrieval telemetry;
- preserve existing exact-project/current-head/allowed-record-type Memory item filtering;
- do not introduce a new transport, table, canonical authority, migration, customer-bearer forwarding, Box source change, or Vercel mutation.

Mandatory current-run model workers:
- Kimi `7320835e-dd20-4810-a1df-08fb33aea44c` — succeeded, attempt 1. Useful isolation/fail-closed checks retained; unsupported assumptions discarded.
- Gemini `6e54b98b-a314-4c29-9513-1c6fdf7d07c6` — succeeded, attempt 1. Existing-bridge/minimal-test guidance retained; invented paths discarded.

Acceptance still required before merge/deploy: exact-head CI, fresh ownership/main read, signed merge provenance, Edge source/runtime parity, live exact-project success, wrong-project/wrong-namespace fail-closed proof, Box compatibility, and rollback baseline preservation.
