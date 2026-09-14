# M5-003 — Verified Execution Learning

Status: source implementation candidate. No production rollout is claimed by this document.

M5-003 consumes the final M1-003 continuous-execution contract after that contract has produced a terminal result. A verified result is the success-side learning boundary. It converts only high-signal execution truth into review-governed typed Memory proposals.

## Accepted learning classes

The intake may propose only `fact`, `procedure`, `failure_lesson`, or `outcome`.

A fact, procedure, or outcome requires a terminal M1 `result`, `verified=true`, an exact verification receipt, and an Activity Theatre result projection for the same job that carries that same verification receipt.

A failure lesson requires a terminal `failed` or `blocked` M1 result, the exact blocker evidence from that result, and a separate incident-verification reference. Runtime failure alone is not enough.

## Authority boundary

M5-003 does not grant execution authority. It never creates policy records and always sets `explicit_policy_authorization=false` and `authorizationEffect=none`.

The proposing principal must have an active, non-revoked production `can_propose` grant for the exact project and requested typed record class. Revocation or a narrower class allowlist fails closed.

## Persistence boundary

The function writes a capture candidate and an immutable review-queue proposal only. It does not write canonical Memory directly; existing approved review persistence remains the only canonical path.

Raw execution payloads are validated in the intake transaction but are not stored in Memory. The durable proposal keeps bounded summaries, identifiers, typed provenance, and evidence references instead.

Idempotency is bound to the M1 job ID plus learning class. Replaying the same verified learning identity returns the existing candidate/review lineage rather than creating duplicates.

## Proof coverage

Disposable PostgreSQL tests prove:

- verified procedure intake from an exact M1 result and Activity Theatre receipt;
- identity-safe replay;
- verified failure-lesson intake with independent incident verification;
- rejection of unverified success claims;
- rejection of stale/non-M1 contract envelopes;
- rejection of failure lessons without independent incident verification;
- exact project-grant record-class enforcement;
- grant revocation enforcement; and
- zero direct canonical `memory_items` writes.

This is the learning bridge requested by M5-003; production migration application and downstream release readback remain separate governed deployment evidence.
