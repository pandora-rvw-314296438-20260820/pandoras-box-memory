# M5 Typed Memory Contract

Status: **SOURCE IMPLEMENTATION CANDIDATE - M0-005 RECONCILED; PRODUCTION ROLLOUT NOT YET AUTHORIZED**

Task: `M5-001` from the Pandora Device execution plan.

## Purpose

Extend the existing canonical `memory_items` plus candidate/review/persistence path so Pandora can represent the seven Memory classes frozen by M0-005 without creating a parallel authority:

- `fact`
- `pattern`
- `policy`
- `procedure`
- `failure_lesson`
- `outcome`
- `provider_performance`

The implementation is additive. Legacy records remain valid and are not backfilled by inference.

## Frozen M0-005 alignment

Typed records persist every M0-005 required field:

`record_type`, `provenance`, `evidence_refs`, `observed_at`, `effective_at`, `confidence`, `authority_kind`, `authority_ref`, `promotion_basis`, `correction_of`, `superseded_by`, `superseded_at`, and `supersession_reason`.

`provenance.semanticSource` explicitly distinguishes:

- `observation`
- `inference`
- `owner_decision`
- `authoritative_policy`

The schema does not infer authority from confidence, repetition, similarity, prior success, a procedure, provider performance, prediction, or model output.

## Authority semantics

- `fact`: `verified_evidence`, `provider_truth`, `runtime_truth`, or `owner_statement`; authorization effect is none.
- `pattern`: `inference`; authorization effect is none.
- `policy`: only `explicit_current_user_instruction` or `active_explicit_standing_policy`.
- `procedure`: `verified_outcome`; authorization effect is none.
- `failure_lesson`: `verified_incident` or `verified_outcome`; authorization effect is none.
- `outcome`: `runtime_truth`, `provider_truth`, or `verified_evidence`; authorization effect is none.
- `provider_performance`: `measured_evidence`; authorization effect is none.

A policy row is not sufficient by itself to authorize execution. Runtime governance must still validate exact principal, capability, operation, provider/resource, environment, sensitivity, cost, validity/conditions, fingerprint/scope, and revocation state. A stale or revoked policy never authorizes.

The exact instruction or standing-policy identifier remains in `authority_ref`; the canonical review decision remains independently preserved in review lineage metadata.

## Provenance, evidence, time, promotion

A typed proposal requires:

- bounded structured provenance with `sourceType`, `sourceLocator`, `observedAt`, and `semanticSource`;
- a non-empty bounded `evidence_refs` array;
- explicit `observed_at` and `effective_at`;
- confidence in `[0,1]`;
- explicit `promotion_basis` explaining why the item is high-signal canonical Memory rather than raw telemetry;
- optional `correction_of` for append-only semantic correction.

Raw polling, transient runtime chatter, and low-value telemetry remain outside canonical Memory.

## Governance path

No second persistence gateway is introduced. Existing flow remains:

`candidate -> immutable review item -> explicit decision -> memory_execute_approved_review_persistence -> memory_items`

The M5 `BEFORE INSERT` trigger resolves the typed proposal using the exact `reviewItemId` and `reviewDecisionId` already written by canonical persistence. If a review item has no typed proposal, legacy behavior is unchanged.

Policy proposals require explicit policy authorization and one of the two frozen policy authority kinds. Non-policy classes cannot carry the policy-authorization flag.

## Supersession and correction

M5 semantic fields are immutable after insertion. A correction appends a new reviewed/canonical typed record linked through `correction_of`; the prior record can then be superseded.

Supersession rejects:

- cross-user, cross-namespace, cross-project, cross-`memory_type`, or cross-record-type successors;
- legacy/untyped successors;
- revoked, inactive, unapproved, already-superseded, or self-referential targets;
- correction links pointing to a different predecessor;
- later mutation of an already-recorded supersession timestamp/reason.

Historical evidence remains intact.

## Compatibility boundaries

- `memory_items` remains canonical durable authority.
- Existing `memory_type` remains for backward compatibility; M5 class identity uses `record_type`.
- Existing grant allowlists continue governing retrieval by `record_type`.
- Existing provider-learning candidates and legacy rows are not rewritten.
- Existing rows are not silently reclassified.
- No production data backfill, Edge deployment, or production provider mutation is performed by this source change.
- Task-aware retrieval behavior belongs to `M5-002`.
- High-signal automatic learning promotion belongs to `M5-003` and remains gated by M1-003.

## Verification

`scripts/verify_m5_typed_memory_contract.py` reads the frozen M0-005 machine contract and checks:

- exact seven-class parity;
- parity with all required record fields and authority levels;
- semantic-source/authority compatibility;
- pattern/policy and advisory/authorization separation;
- required provenance/evidence/time/confidence/promotion fields;
- no parallel Memory authority;
- no core-history delete/truncate/backfill;
- append-plus-supersede correction behavior;
- same-scope, same-type, current approved successor requirements;
- undeclared PL/pgSQL row-variable references, which catches the previously observed successor-identifier typo.

CI source checks prove source-contract conformance. Supabase Preview is the safe migration execution/compile proof before any production migration is considered. Production remains unchanged until governed release evidence explicitly authorizes it.
