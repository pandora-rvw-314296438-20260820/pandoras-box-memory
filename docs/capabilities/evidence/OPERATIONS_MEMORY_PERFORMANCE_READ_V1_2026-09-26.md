# Operations Room approved performance read V1

Task: OPS-MEMORY-PERFORMANCE-V1-001. Actual author: ChatGPT OPS-MEMORY-PERFORMANCE-20260926. Operations Room 714 claim 5838373571, tracker 38. Base Memory main 2d193c0667a037e815f50a1c1c81fd578eaf9d92. Source candidate only; no production activation or model-selection improvement claim.

## Implemented

A new service-only `memory_operations_performance_v1` RPC reads the existing canonical `memory_items` rather than creating another Memory store. It holds current principal, project, grant and selected-record shared locks. User, real-life namespace, project, environment, read scope and allowed record type must all match. It does not seed or expand a grant.

Only approved, active, unrevoked, unsuperseded, currently effective hard-canon provider-performance records with unexpired review dates are eligible. Malformed metrics and provenance are excluded rather than converted into invented scores. The reply retains unknown latency, quality, cost, model revision and configuration as unknown. Cost fields are window totals, not per-inference price claims.

The bounded read examines at most 128 records and returns at most 16 snapshots within 32 KiB. Scan/output truncation is explicit. Exactly one latest evidence window is selected per provider/model/revision/configuration; overlapping snapshots are not summed. This is evidence for a Router, not an authorization grant, model approval or automatic best-model ranking.

## Executed verification before publication

- 96 executable SQL assertions passed against this exact migration in disposable PGlite on the authorized RDP, Node 24.21.0.
- Companion Box client: 84/84 tests passed, including the exact 96-assertion SQL/client seam. The seam executes the same 96 SQL assertions; it is not an additional unique test.
- Native PostgreSQL CI passed for reviewed head `2a35b71a0da910d9da99bde9b19eb2c5e88e9ba1` in workflow run `36183445235`. It includes the complete SQL suite plus a two-session grant-revocation fencing scenario.
- CLI 2.116.0 generated migration 20260925193725; closed subprocess stdin was used. No CLI or dependency version was changed.

The existing deployed Memory data plane contained zero approved provider-performance records at 2026-09-25T19:26:20Z. The source therefore explicitly returns `insufficient_history` when no eligible evidence exists. Synthetic fixtures are not production learning and are never inserted into live Memory.

## Release boundary and learning

No production DDL, Memory promotion, approved history seed, provider credential, primary Router/ARES/UI/activation source modification, or independent approval is supplied by this change. The existing Router owner must wire this reader only after protected source convergence and governed deployment. Box client source is explicitly stacked on Box736 and keeps its mapping/secret guard unchanged.

Lesson: narrative Memory context is not numeric routing performance. A trustworthy Router needs approved, fresh, scoped numeric snapshots; unknown billing/revision/configuration and overlapping evidence must not silently become cheap/high-quality/independent samples. Rollback disables this new read consumer while preserving all Memory and review history.
