# Memory Quality Observability Truth Contract

Status: source-readiness only. Program: Pandora Memory Maximization. Owner: Chat C.

## Purpose
Pandora must measure Memory quality without converting missing telemetry into false certainty. **Database volume is not product value.** This extends existing Memory authorities; it creates no parallel analytics, feedback, retrieval, lifecycle, or provider-truth authority.

## Metric authority classes
Every KPI is exactly one of:
- `measurable_live_now`: fresh live DB/provider count or ratio with explicit source/capture evidence.
- `source_intended_only`: present in canonical source but not observed in the current production runtime.
- `unavailable_causal`: required causal identity/join is absent. Numeric value must be null. **Zero is not a substitute for unavailable.**

Fresh provider readback wins mutable external state. CI/source cannot prove deployment or `production_verified` behavior.

## Baseline truth
On 2026-09-01 GitHub Memory main is newer than the Vercel production source, so source/runtime parity is false. Live retrieval logs are measurable as events, but they contain no exact project identity, returned/resolved/used Memory-head identity, or downstream outcome reference. Canonical main contains project identity and exact project filtering, but that is `source_intended_only` until production readback proves it.

Therefore these remain `unavailable_causal`:
- retrieval usefulness,
- Memory-assisted success lift,
- prevented-repeat-failure attribution,
- caused-rework attribution.

They require `retrieval -> exact resolved-head identity -> used/feedback identity -> execution -> verification/outcome`.

## Dashboard semantics
Surface four distinct states: **Live measured**, **Source intended**, **Unavailable**, **Degraded**. Never coerce unavailable to zero, false, green, success, or 100%-failure.

Live measurable aggregates include candidate/review backlog and age, retrieval count/hash hygiene/project identity coverage, feedback count, open conflicts, superseded retrieval-eligible count, effective-head review-policy coverage, pruning count, aggregate failure recurrence, and exact source/runtime parity. These facts do not by themselves prove usefulness.

## Historical telemetry rule
**Historical retrieval logs are immutable evidence.** Do not backfill, rewrite or infer historical `project_id`, `project_key`, returned item IDs, resolved head IDs, used item IDs, or outcome references to improve charts. Coverage improves only from new authoritative runtime telemetry.

## Source/runtime rule
`github_main_sha != production_source_sha` means parity is false. A green PR, build, preview, or source field does not prove deployment. Production proof requires exact deployment/source readback and runtime behavior.

## Privacy rule
Observability evidence is aggregate and privacy-safe. Do not store raw search text, raw Memory content, user email/IDs, candidate/item/head IDs, raw provider payloads, or credential/secret material. Provider deployment IDs, source SHAs, schema/service names, counts and ratios are permitted evidence identifiers. Cross-project aggregation may expose privacy-safe aggregates only, never source customer facts.

## Release gate
Fail closed if:
- a causal metric receives a numeric value before linkage exists;
- unavailable is represented as zero;
- source-only is labeled deployed/production_verified;
- parity is true while exact SHAs differ;
- historical identity inference/backfill is authorized;
- aggregate evidence contains raw identity/content/secret fields;
- this source-only milestone changes migrations/runtime;
- exact-project isolation, literal-secret scan, or exact-head checkout fails.

## Current non-actions
No production schema/migration/Edge/retrieval/telemetry/backfill/feedback/ranking/causal-scoring/Vercel-production/canonical-Memory mutation is authorized.

## Exit criteria for causal observability
Require: production source/runtime parity; exact project identity on new retrievals; privacy-safe exact resolved-head identity; governed use/feedback signal; execution identity; verification/outcome identity; join/isolation tests; no historical inference; production readback; rollback proof.
