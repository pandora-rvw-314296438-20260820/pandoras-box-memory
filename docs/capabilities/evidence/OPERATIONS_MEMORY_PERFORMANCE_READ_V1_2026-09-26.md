# Operations Room approved performance read V1

Task: OPS-MEMORY-PERFORMANCE-V1-001. Actual author: ChatGPT OPS-MEMORY-PERFORMANCE-20260926. Operations Room714 claim5838373571, tracker38. Base Memory main2d193c0667a037e815f50a1c1c81fd578eaf9d92. Source candidate only; no production activation or model-selection improvement claim.

## Implemented

A new service-only `memory_operations_performance_v1` RPC reads the existing canonical `memory_items` rather than creating another Memory store. It holds current principal, project, grant and selected-record shared locks. User, real-life namespace, project, environment, read scope and allowed record type must all match. It does not seed or expand a grant.

Only approved, active, unrevoked, unsuperseded, currently effective hard-canon provider-performance records with unexpired review dates are eligible. Malformed metrics and provenance are excluded rather than converted into invented scores. The reply retains unknown latency, quality, cost, model revision and configuration as unknown. Cost fields are window totals, not per-inference price claims.

The bounded read examines at most128 records and returns at most16 snapshots within32KiB. Scan/output truncation is explicit. Exactly one latest evidence window is selected per provider/model/revision/configuration; overlapping snapshots are not summed. This is evidence for a Router, not an authorization grant, model approval or automatic best-model ranking.

## Executed verification before publication

-96 executable SQL assertions passed against this exact migration in disposable PGlite on the authorized RDP, Node24.21.0.
-Companion Box client:78 focused cases plus one actual SQL/client boundary test passed,79 total. The boundary test executes the same96 SQL assertions; they are not an additional96 unique tests.
-Native PostgreSQL CI includes the complete SQL suite plus a two-session grant-revocation fencing scenario. It is not claimed passed until its real workflow result is read back.
-CLI2.116.0 generated migration20260925193725; closed subprocess stdin was used. No CLI or dependency version was changed.

The existing deployed Memory data plane contained zero approved provider-performance records at2026-09-25T19:26:20Z. The source therefore explicitly returns `insufficient_history` when no eligible evidence exists. Synthetic fixtures are not production learning and are never inserted into live Memory.

## Release boundary and learning

No production DDL, Memory promotion, approved history seed, provider credential, primary Router/ARES/UI/activation source modification, or independent approval is supplied by this change. The existing Router owner must wire this reader only after protected source convergence and governed deployment. Box client source is explicitly stacked on Box736 and keeps its mapping/secret guard unchanged.

Lesson: narrative Memory context is not numeric routing performance. A trustworthy Router needs approved, fresh, scoped numeric snapshots; unknown billing/revision/configuration and overlapping evidence must not silently become cheap/high-quality/independent samples. Rollback disables this new read consumer while preserving all Memory and review history.
