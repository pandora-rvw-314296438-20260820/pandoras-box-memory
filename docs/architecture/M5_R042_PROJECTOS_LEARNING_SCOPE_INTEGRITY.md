# M5 R-042 — ProjectOS Learning Scope Integrity

Status: source prerequisite for M5-003. This does not complete M5-003. M5-003 remains blocked on the final merged M1-003 continuous-execution contract.

## Why this prerequisite exists

Production readback found that the generic ProjectOS-to-Memory learning path was review-gated but not reliably bound to the governed Memory project registry at the relational candidate/review boundary. The live audit found 3,614 `projectos_outcome` review rows with `source_metadata.candidateId` absent. Of their matched candidates, 3,560 had `project_id IS NULL`. None of those review rows had been canonically persisted at the time of the audit.

The current selective-review v2 population contained 96 review-required rows across five distinct source project keys. Canonical-key/alias resolution plus the active project registry resolved 43 rows to exactly one active Memory project with an active production `can_propose` grant. The remaining 53 rows were unresolved and must not be guessed or silently backfilled.

## Frozen integrity rule

New governed ProjectOS learning candidates must resolve to exactly one active `pandora_projects` row in the same Memory namespace before entering review. Resolution may use the canonical Memory `project_key`, an authoritative `aliases[]` entry, or an already relational `project_id` that is validated against the active registry. The source event's embedded project UUID/key is evidence for resolution, not authority by itself.

The resolved project must have exactly one active, non-revoked production `can_propose` grant for `projectos-mcpmaster-production`. Absence, ambiguity, namespace mismatch, inactive project state or revoked/missing grant fails closed.

New `projectos_outcome` review rows must bind the exact candidate ID and canonical Memory project ID in the review lineage consumed by persistence. Caller-supplied lineage may agree with the governed binding but cannot override it. Canonical persistence must re-check the review→candidate→project→grant chain and reject missing or mismatched lineage.

## Legacy behavior

There is **no legacy backfill** in this prerequisite. Existing unscoped candidates and review rows are not updated, retyped, approved, rejected or promoted. An old review that lacks exact candidate/project lineage is held fail-closed at canonical persistence until a separate governed reconciliation can prove its scope. Embedded historical source metadata is never treated as sufficient authority to guess a project mapping.

The existing `projectos_selective_review_v2` admission policy remains intact: failed, destructive, error-fingerprint and ambiguous successful-write outcomes are review-gated; routine successful reads/writes remain bounded operational summaries rather than per-operation durable Memory candidates.

## Authority boundary

This repair does not grant execution authority. It only strengthens where a learning candidate belongs and whether it is allowed to enter the governed Memory review path. It does not turn a result, pattern, model output, provider history or repeated behavior into policy or permission.

It also does not define M5-003 verified-outcome promotion semantics. Those semantics must consume the exact final M1-003 terminal/result contract after M1-003 is reconciled and merged.

## Verification

The disposable PostgreSQL proof covers:

- canonical-key and alias project resolution;
- existing relational project validation;
- active production `can_propose` grant enforcement;
- unresolved and ambiguous scope rejection;
- missing-grant rejection;
- candidate/project lineage injection into review rows;
- forged candidate lineage rejection;
- legacy unscoped review rejection at canonical persistence; and
- grant revocation blocking later canonical persistence.

The migration is additive and insert-time only for the governed learning path. It does not deploy to production, modify existing candidate/review/Memory rows, or claim M5-003 complete.
