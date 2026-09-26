# Native Operations Memory workload connection

This extends the existing `pandora-memory-bridge`, not a retired ProjectOS service. The existing entrypoint verifies the real Vercel-issued JWT, including issuer, audience, subject, owner ID, project ID/name and production environment before dispatching `action: operations`.

Request: `{action, operation, requestId, projectId, namespace, payload}`. Operations are `context`, `performance`, `propose_outcome`, `readback`. Namespace is `real_life`. The server derives principal, Memory user and environment from the verified workload; callers cannot supply those fields or a target function/URL/SQL statement. The two existing service-only Operations RPCs recheck active project/principal/grant rows under their existing revocation locks. This change adds no identity, scope, project grant, credential, model approval or canonical promotion.

The Box caller must be actual production `mcpmaster` code resolving its own platform-issued OIDC token. A local model, browser bearer, Edge Function name or this ChatGPT conversation is not that identity. Worker/task/lease and independent verification validation remain the trusted Box runtime's responsibility before submitting outcome metadata. The native Memory receipt contract keeps candidate delivery separate from reviewed canonical learning.

Each RPC is sent once. Definite native rejections remain definite; timeout/cancellation or uncertain mutation transport remains `outcomeUnknown`. Existing Box delivery code must use readback rather than repeat a write. Requests and responses are bounded, including streaming bodies without Content-Length. Provider error strings and credentials are not emitted.

Tests exercise real handler code with synthetic transports and verify the actual entrypoint delegates only after its existing authentication boundary. CI and a merged source do not prove deployed identity acceptance. Release requires exact-source Edge readback and an actual Vercel-to-Memory context/performance/outcome roundtrip under narrow current grants. No such production acceptance is asserted in this source document.

Coordination: Operations Room #714, `OPS-RUNTIME-SEAMS-20260926`, tracker row42. Prior source/failures remain in Memory #115. Existing native-worker PR743 and Router PR742 ownership are preserved.


## Deployment scope correction

The native function name exists in source but was not present in the live inventory. Release only `operations-entrypoint.ts`, selected explicitly in `supabase/config.toml`, at the native `pandora-memory-bridge` slug. It authenticates with the shared real Vercel verifier and exposes ONLY the Operations handler. Do not deploy historical index.ts or reuse a ProjectOS-named runtime. The endpoint rejects every browser Origin and all historical actions. Existing native SQL grants and revocation checks still apply. This is an additive native service deployment, not a claim that the earlier source was already live.
