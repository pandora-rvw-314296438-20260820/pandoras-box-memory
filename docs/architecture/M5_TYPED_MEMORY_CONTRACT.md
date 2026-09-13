# M5 Typed Memory Contract

Status: **SOURCE IMPLEMENTATION CANDIDATE — INTEGRATION/ROLLOUT NOT YET AUTHORIZED**

Task: `M5-001` from the Pandora Device execution plan.

## Purpose

Extend the existing canonical `memory_items` + candidate/review/persistence path so Pandora can represent seven distinct durable knowledge classes without creating a parallel Memory authority:

- `fact`
- `pattern`
- `policy`
- `procedure`
- `failure_lesson`
- `outcome`
- `provider_performance`

The implementation is additive. Legacy records remain valid and are not backfilled by inference.

## Authority semantics

- `fact`: evidence-backed through `verified_evidence`, `provider_truth`, or explicit `owner_statement`.
- `pattern`: confidence-weighted `inference`; useful for prediction and suggestions but never permission.
- `policy`: `owner_policy` plus explicit approved review. A pattern cannot silently become policy.
- `procedure` and `failure_lesson`: `verified_outcome`.
- `outcome`: `runtime_truth`, `provider_truth`, or `verified_evidence`.
- `provider_performance`: `measured_evidence`; raw provider prompts/responses, credentials, and private payloads remain outside canonical learning.

## Provenance and time

A typed proposal requires exact record type, authority kind/reference, confidence in `[0,1]`, `effective_at`, and bounded structured provenance with `sourceType`, `sourceLocator`, and `observedAt`.

For policy records, canonical `authority_ref` is rebound to the exact approved review-decision ID.

## Governance path

No second persistence gateway is introduced. Existing flow remains:

`candidate -> immutable review item -> explicit decision -> memory_execute_approved_review_persistence -> memory_items`

The migration adds typed proposal fields to `memory_review_queue_items`. A `BEFORE INSERT` trigger on the existing `memory_items` insertion resolves those reviewed fields using the exact `reviewItemId` and `reviewDecisionId` already written by the canonical persistence function.

If a review item has no typed proposal, legacy behavior is unchanged.

## Supersession and correction

M5 typed semantic fields are immutable after insert. A correction must append a new typed record, complete normal review/canonicalization, then supersede the old record with the new same-scope, same-type current canonical head and record `superseded_at` plus `supersession_reason`.

The M5 update guard rejects cross-user, cross-namespace, cross-project, cross-type, revoked, inactive, unapproved, already-superseded, or self-referential successor targets. Historical evidence remains intact.

## Compatibility boundaries

- `memory_items` remains canonical durable authority.
- Existing `memory_type` remains for backward compatibility; M5 class identity uses the already-existing `record_type`.
- Existing grant allowlists continue governing retrieval by `record_type`.
- Existing provider-learning candidates and legacy rows are not rewritten.
- No production data backfill, Edge deployment, or production provider mutation is performed here.
- Retrieval behavior for these classes belongs to `M5-002`.

## M0-005 dependency

The Device plan states `M5-001` depends on coordinator-owned `M0-005` (facts vs patterns vs policies vs procedures vs outcomes). This branch is an additive candidate and must not be merged as final architecture until the coordinator confirms M0-005 compatibility.

Any class-name or authority-semantic change must be reconciled before merge.

## Verification

`scripts/verify_m5_typed_memory_contract.py` checks:

- all seven typed classes;
- fail-closed authority mappings;
- pattern/policy separation;
- required provenance/time/confidence;
- no parallel Memory authority;
- no core-history delete/truncate/backfill;
- append-plus-supersede correction behavior;
- same-scope, same-type, current approved successor requirements.

`.github/workflows/m5-typed-memory-contract.yml` runs the verifier, compiles it, and scans the M5 change set for obvious literal secrets.

Passing CI proves source-contract conformance only. It does not prove migration deployment or production runtime behavior.
