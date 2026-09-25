# Operations Room Memory bridge V1 - source evidence

Task: OPS-MEMORY-INTEGRATION-V1-001. Authority: current owner continuation after Box #728 merged; Operations Room #714 comments 5837040854 and 5837131347. Source-only scope: new Memory wrapper/migration, synthetic tests, new CI and this evidence. Incumbent Memory #93, gateway, original M5 context, model-outcome ingester and approval/promotion functions are unchanged.

## Implemented

`memory_operations_bridge_v1` exposes service-only `context`, `propose_outcome` and `readback` operations. It verifies current principal/user/namespace/environment/project grants under shared row locks; no principals or grants are seeded or expanded. Context uses native typed hard-canon retrieval and never grants action authority.

Outcome delivery uses a transaction-scoped per-source lock and a sanitized immutable receipt. The wrapper rejects a reused source identity with different content, prevents silent adoption of legacy candidates without a matching receipt, and independently rereads full candidate and review lineage. It reuses native capture/review persistence and never writes or approves canonical `memory_items`.

Metadata includes provider/model/revision, task class, routing policy, real occurrence time, execution/verification/downstream status, evidence references, source SHA, nullable latency/cost/usage, retry count and configuration digest. Raw customer data, prompts, outputs and credentials are not accepted. An unreported model revision is explicitly labeled; unknown cost is retained as null.

## Verified so far

- Companion Box client: 57/57 executable cases, Node 24.21.0, mocked RPC transport.
- This migration plus exact native M5 context and model-outcome SQL: 66/66 assertions passed in a disposable PGlite database on the authorized RDP.
- Native PostgreSQL independent-session workflow is included; its three race cases are not claimed passed until actual CI execution returns successful evidence.
- Neither PGlite nor mocked client transport is production runtime acceptance.

Initial SQL tests exposed an unparenthesized CASE expression, PostgreSQL's bounded-regex repetition limit, and incomplete metric readback. Those failures were corrected and the exact SQL suite rerun successfully. The metric-drift negative control failed before full status/metric/evidence readback was added and passed afterward. History of failed runs is retained in the RDP evidence directory rather than presented as success.

The migration filename was created with the repository-pinned Supabase CLI 2.116.0. A first invocation inherited REPL stdin and captured following input into the empty file; its task-owned generator was stopped and the file rewritten before any publication. Future CLI subprocesses use explicit closed stdin. No provider credential or private SSH key was read, copied or weakened.

## Native source binding

Tests extract the existing native ingester directly from `supabase/migrations/20260901184935_pandora_provider_learning_v1.sql` and execute the complete `20260913143500_m5_task_aware_retrieval_v1.sql`. They do not replace those functions with fake success. The fixture supplies only required table shapes and a PostgreSQL SHA-256 compatibility function, so full production schema/replay and live tenant acceptance remain separate release gates.

## Not claimed

No production DDL, Memory grant, Edge deployment, independent approval, hard-canon promotion, live Router adoption, numeric routing-performance learning or physical Android acceptance. The trusted calling runtime must prove the task/lease and canonical verification before invoking this privileged component. Review queue admission is not final Memory approval.

Rollback is consumer pause plus receipt-preserving reconciliation, not deletion or rewriting of native Memory history.
