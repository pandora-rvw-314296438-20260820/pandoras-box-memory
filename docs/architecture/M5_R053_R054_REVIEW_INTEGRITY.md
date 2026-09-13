# M5 R-053/R-054 — Review Integrity Prerequisite

Status: source prerequisite only. This does not complete M5-003 and does not authorize or perform a production deployment.

Exact implementation base: `pandoras-box-memory@d29738e32d7bda9bb4d61be2b27853220427cbc9`.

## Why this prerequisite exists

R-053: an approved review did not bind its immutable semantic payload. The approval row recorded the transition but not the exact M5 typed proposal/evidence/lineage that would later be read during persistence. A privileged or service-role semantic mutation after approval could therefore change what was canonized under an older approval.

R-054: the review transition and persistence RPCs were SECURITY INVOKER while `memory_review_queue_items` intentionally exposes no authenticated UPDATE RLS policy. They also did not assert the review/candidate bookkeeping UPDATE affected exactly one row. Canonical inserts therefore needed a fail-closed atomic bookkeeping boundary before M5 typed promotion can activate.

## Frozen repair

1. Review semantics are immutable after INSERT. The only mutable fields are lifecycle/persistence bookkeeping: `status`, `updated_at`, `archived_at`, `persisted_at`, `persistence_status`, and `persistence_execution_metadata`. Every `status` transition additionally requires a matching append-only decision row already present in the same transaction.
2. A canonical `m5.review-semantic.v1` SHA-256 binds review identity, normalized content, snapshots, source/candidate/project lineage metadata, and every M5 `proposed_*` / explicit-policy-authority field. Timestamps are encoded as absolute epoch values so the digest is session-timezone independent.
3. `approve_append` writes a system-owned `reviewSemanticSha256`; caller metadata cannot override it.
4. Typed generic persistence requires that approved digest and recomputes/compares it before any canonical insert. The digest is also recorded in persistence/audit lineage.
5. Review transition and generic/provider persistence become narrow SECURITY DEFINER RPCs with an empty fixed search path and fully qualified non-catalog objects. User ownership still comes only from `auth.uid()`; exact review/namespace/decision/lineage checks remain mandatory.
6. No broad authenticated UPDATE policy is added. Direct review UPDATE/DELETE and direct decision INSERT/UPDATE/DELETE are revoked from authenticated/service-role callers; the narrow RPCs are the mutation boundary. Decision rows also have an UPDATE/DELETE append-only trigger guard.
7. Every trusted bookkeeping UPDATE asserts `ROW_COUNT = 1`; any mismatch raises and rolls the transaction back, including earlier canonical inserts.
8. Legacy provider-learning reviews remain compatible. The legacy provider persistence function explicitly rejects any review with `proposed_record_type` so new M5 typed provider learning must use the single hardened generic persistence path.
9. Existing legacy rows are not backfilled or rewritten. This migration is forward-only.

## Authority boundary

The semantic digest is an approval/evidence integrity primitive, not execution authority. Patterns, predictions, provider performance, model output, prior success, or a review digest never create permission. M5-003 remains blocked on the final M1 terminal/effect contract and the repaired/merged M3-005 authority path.

## Credential/write boundary

D-017 remains active: GitHub App first for repository writes; only after a verified permission denial/no mutation may the approved Supabase Vault-backed GitHub route write. No PAT/API key may be exposed, committed, or persisted to normal device storage.

## Acceptance

The no-path-filter workflow must prove in disposable PostgreSQL that direct authenticated/service-role review mutation privileges are absent; direct decision insertion is denied; semantic hashes are timezone-stable; the SECURITY DEFINER approval transition succeeds exactly once for the owner; wrong-owner approval fails; decisions are append-only; status changes without a decision fail; a zero-row decision transition rolls back the just-inserted decision; privileged semantic mutation is rejected; forced post-approval semantic drift is rejected at persistence; unchanged typed persistence is idempotent; zero-row review bookkeeping rolls back canonical inserts; zero-row provider-candidate bookkeeping rolls back canonical/provider bookkeeping; legacy provider persistence remains idempotent; and typed provider reviews cannot enter the legacy provider persistence route.

## Production effect

No production deployment is authorized or performed by this source/CI prerequisite.
