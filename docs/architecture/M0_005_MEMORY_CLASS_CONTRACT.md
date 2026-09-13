# M0-005 — Pandora Memory Class Contract

Status: **FROZEN — 2026-09-13**

This contract freezes the semantic boundary between what Pandora knows, infers, learns, and is authorized to do. `memory_items` remains the canonical durable Memory authority; raw execution events and polling remain separate until deliberate high-signal promotion.

## Non-negotiable authority boundary

**Inference, prediction, repeated behavior, model output, prior success, procedure reuse, or provider/model performance must never silently become authorization.**

Only an **explicit current user instruction** or an **active explicit standing policy** may authorize consequential execution, and only inside its validated scope. Memory may retrieve and explain that authority; it cannot manufacture, broaden, or renew it.

**Confidence never upgrades authority.** A 0.99 pattern is still an inference. A successful procedure is still advisory knowledge. A provider with excellent historical performance still has no permission beyond the action's current authority.

## Semantic source distinction

- **Observation** — evidence-backed runtime/provider/artifact/user-observable source. It can support facts, procedures, failures, outcomes, and performance evidence; it does not itself grant permission.
- **Inference** — a model/statistical conclusion, prediction, or repeated-behavior pattern. It may inform suggestions and anticipation only.
- **Owner decision** — explicit attributable owner/admin choice. It can create a fact and, when the decision itself is an explicit current instruction or valid standing authorization, can create policy.
- **Authoritative policy** — explicit scoped authorization/constraint with principal, capability, operation, provider/resource/environment and other applicable bindings, validity, and revocation state.

## Required durable fields

Typed durable records carry: `record_type`, `provenance`, `evidence_refs`, `observed_at`, `effective_at`, `confidence`, `authority_kind`, `authority_ref`, `promotion_basis`, `correction_of`, `superseded_by`, `superseded_at`, and `supersession_reason`.

A correction appends a new record, links the corrected record, and supersedes the prior record. Historical evidence is preserved.

## Frozen Memory classes

### Fact
Verified current information. Requires attributable evidence or explicit owner statement. Newer authoritative same-scope evidence can supersede the current fact. Retrieval prefers current non-revoked facts and preserves superseded history for audit/conflict. **Authorization effect: none.**

### Pattern
Confidence-weighted inference from repeated behavior or outcomes. Must retain evidence lineage and derivation timing. It can drive suggestions/prediction, never permission. Rejections/corrections must influence future pattern confidence. **Authorization effect: none.**

### Policy
Explicit owner/admin authorization or constraint. It must bind exact authority lineage and applicable scope. A proposal, pattern, model output, successful procedure, or prediction cannot become policy without explicit authorization. Expired/revoked/stale policy cannot authorize. Retrieval of policy is separate from advisory Memory and must validate exact scope before execution.

### Procedure
Reusable method proven by a verified outcome. It is promoted only from meaningful evidence and retrieved before similar work. The action that uses the procedure must still pass the current authority policy. **Authorization effect: none.**

### Failure lesson
Verified account of failure, diagnosis, correction, and prevention. Prioritize retrieval before similar high-risk/debug/release/provider work. Revised diagnoses append and supersede; history remains intact. **Authorization effect: none.**

### Outcome
Verified result/readback of completed work. It feeds later facts, procedures, failure lessons, patterns, and provider-performance learning. A previous successful outcome never grants future permission. **Authorization effect: none.**

### Provider/model performance
Measured quality, latency, cost, reliability, failure, and verified success by workload. Promote only sufficiently representative evidence; keep raw telemetry separate. It may influence routing, never action authority. **Authorization effect: none.**

## Promotion

Canonical Memory is not a telemetry dump. Raw polling, transient execution chatter, repeated low-value events, and private provider payloads remain outside canonical Memory.

Promotion requires a useful, bounded, evidenced lesson or state. The progression is:

`observe → learn → suggest → explicit owner/admin approval → policy`

Repeated behavior may justify a suggestion to automate. It does not create permission.

## Retrieval

Retrieval is task-aware and bounded. It respects principal/project/namespace/grant scope, excludes revoked and superseded heads by default, can include history for audit/correction/conflict, prefers verified current authority, and never treats similarity score or confidence as authority.

Policies are retrieved and evaluated separately from advisory classes. Failure lessons should be retrieved before similar high-risk work; provider-performance evidence is retrieved by workload/model/provider constraints.

## M5-001 compatibility

M5-001 must preserve the existing candidate → immutable review → explicit decision → canonical persistence path and must not introduce a parallel Memory authority.

Its typed schema/migration/tests must enforce these seven classes, provenance/evidence/timestamps/confidence, append-plus-supersede correction, and the policy boundary above. Existing legacy rows remain valid unless deliberately migrated through a separately verified path.
