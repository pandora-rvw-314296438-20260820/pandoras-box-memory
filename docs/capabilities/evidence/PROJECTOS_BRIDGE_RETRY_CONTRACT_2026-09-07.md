# ProjectOS Bridge Retry Contract — 2026-09-07

Status: source candidate evidence only; production verification remains pending merge, deployment, and runtime readback.

## Candidate identity

- Repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Pull request: #54
- Candidate source commit observed before this evidence co-change: `ffbb45e61ba95ec8ec0251471511f95e7219a530`
- Transport source: `lib/services/projectos-memory-bridge-client.ts`
- Transport source blob SHA-1: `6be193f4967d7d4dbc141e2d5be2763e9b57d644`
- Retry contract verifier: `scripts/verify_projectos_bridge_url_contract.mjs`

The historical recovery baseline in `PANDORA_CAPABILITY_REGISTRY_V2.json` is intentionally unchanged. This artifact records the current candidate without rewriting immutable baseline evidence.

## Bounded retry contract

The ProjectOS web proxy retries only read-only Memory actions:

- `health`
- `search`

Transient responses eligible for bounded retry are HTTP 408, 429, 500, 502, 503, and 504. Fast network failures are also eligible while the existing total request budget remains available.

The retry limit is three attempts total. Backoff is bounded and `Retry-After` is honored only up to two seconds. All attempts share the existing eight-second proxy deadline; the change does not multiply timeout duration.

## Mutation safety

Evidence-candidate submission and every non-read action remain single-attempt. A timeout or upstream 5xx on a mutation can be ambiguous, so this change does not introduce blind mutation retry or weaken existing idempotency/governance boundaries.

## Error classification

The candidate maps terminal proxy failures as follows:

- exhausted bridge timeout: HTTP 504 / `bridge_timeout`
- unavailable upstream: HTTP 503 / `bridge_unavailable`
- oversized upstream response: HTTP 502 / `bridge_response_too_large`
- invalid canonical bridge configuration: HTTP 500 / `bridge_misconfigured`

The bridge URL remains restricted to the canonical Memory Supabase project and exact ProjectOS bridge path.

## Exact-head checks observed before evidence co-change

At candidate head `ffbb45e61ba95ec8ec0251471511f95e7219a530`:

- Memory Hardening Readiness Gate — success, run `34095121773`
- Machine Gateway Namespace Isolation — success, run `34095121951`
- Pandora source security gate — success, run `34095121827`
- Memory Quality Observability Gate — success, run `34095121816`
- Memory recovery web build — success, run `34095121910`
- Capability Registry Gate — failed only because tracked source lacked the required registry/manifest/evidence/roadmap co-change, run `34095121812`

This evidence file is the governance co-change for that exact source contract. A fresh exact-head Capability Registry Gate is still required after this commit.

## Claim boundary

This artifact does **not** claim that production 502s are resolved. Closure requires merge, provider deployment, and authenticated production health/search readback showing the retry/error path behaves as intended.
