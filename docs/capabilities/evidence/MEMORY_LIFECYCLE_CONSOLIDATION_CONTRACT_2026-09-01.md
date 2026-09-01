# Memory Lifecycle & Consolidation Contract — 2026-09-01

## Purpose

This contract freezes the dependency-safe Task 41–42 lifecycle invariants for Pandora Memory.
It is a source-readiness gate only. It does not authorize a production data rewrite, migration,
Edge deployment, pruning run, supersession backfill, or Vercel production change.

## Current authority boundary

- Fresh provider truth remains authoritative for mutable external state.
- Historical Memory evidence remains immutable history.
- `memory_items` remains the canonical durable item authority.
- `memory_pruning_candidates`, `pandora_memory_record_versions`, and
  `pandora_approval_audits` are reused; no parallel lifecycle database is authorized.
- Current canonical `pandora-projectos-bridge` is the retrieval authority to extend when
  dependencies unlock. A second lifecycle/search gateway is not authorized.
- Current production runtime is older than canonical source and is not lifecycle-authoritative.

## Live baseline frozen for adjudication

The accompanying evidence manifest records the fresh 2026-09-01 Memory Supabase readback:

- 280 total `memory_items`; 275 active.
- 124 rows link to a successor through `superseded_by`.
- 119 active approved superseded rows remain retrieval-eligible under current item filters.
- Every one of those 119 resolves to a valid same-scope active approved terminal head.
- Maximum observed supersession depth is 29.
- Zero observed cycles, missing direct targets, cross-scope terminal resolutions, or invalid terminal heads.
- All 119 retrieval-eligible predecessor titles differ from terminal-head titles.
- All 119 retrieval-eligible predecessor bodies differ from terminal-head bodies.
- 118/119 retrieval-eligible predecessor content hashes differ from terminal-head hashes.
- 143 active approved terminal heads exist and all 143 have `review_due_at` unset.
- `memory_pruning_candidates` currently has zero rows.

These observations describe current state. They do not weaken the fail-closed invariants below.

## Recall-safe effective-head invariant

Lifecycle consolidation MUST preserve historical wording as searchable alias evidence.

The required retrieval sequence is:

1. Authorize exact identity, namespace, project, grant, action, and purpose.
2. Match eligible historical/current Memory text inside that exact authorized scope.
3. For each matched row, follow `superseded_by` transitively.
4. Fail closed if any successor is missing, a cycle is encountered, or scope changes.
5. Require the terminal head to preserve the same:
   - `user_id`
   - `namespace`
   - `project_id`
   - `memory_type`
6. Require the terminal head to be:
   - active,
   - non-revoked,
   - approved canonical (`hard_canon` or `soft_canon`),
   - terminal (`superseded_by IS NULL`).
7. Deduplicate results by resolved terminal-head ID.
8. Return the terminal head as current authority while retaining the historical matched
   predecessor only as provenance/alias evidence where needed.

### Forbidden shortcut

Do NOT pre-filter `superseded_by IS NULL` before historical text matching.

That shortcut is unsafe because current live evidence proves predecessor wording differs from
terminal-head wording for all 119 retrieval-eligible predecessors. Pre-filtering would silently
destroy historical recall.

Do NOT return a superseded predecessor as current authority when a valid terminal head exists.

## Supersession-write invariant

Before `pandora_supersede_memory_record` can be generalized for correction/lifecycle work, the
replacement record MUST be validated before mutation.

Required replacement invariants:

- different ID from the old record,
- same `user_id`,
- same `namespace`,
- same `project_id`,
- same `memory_type`,
- active,
- `revoked_at IS NULL`,
- approved canonical,
- terminal/current,
- no self-link,
- no cycle or reverse-chain loop.

The mutation MUST preserve immutable version and approval-audit evidence.

Current production RPC does not yet enforce all of these invariants; therefore this contract
does not authorize lifecycle writes through it.

## Pruning and compression

- Pruning is a governed recommendation/workflow, not evidence deletion.
- `memory_pruning_candidates` is the existing pruning authority to reuse.
- Low-value or stale operational material may be suppressed/archived only through governed,
  reversible lifecycle state.
- Immutable `memory_items` history, `pandora_memory_record_versions`, and
  `pandora_approval_audits` must not be deleted or truncated merely to reduce retrieval noise.
- Retrieval compression must happen by effective-head resolution/deduplication, not by erasing
  historical nodes.

## Freshness

Age alone is not staleness.

Missing `review_due_at` is `policy_missing` / unbounded review policy, not proof that a record
is stale or current. Provider-sensitive facts require fresh provider/source readback before a
consequential action can treat them as current.

## No-duplication rule

Do not introduce parallel authorities such as:

- `memory_items_v2`
- `memory_lifecycle_v2`
- `memory_pruning_v2`
- a second generic Memory lifecycle/search Edge gateway

Extend existing authorities unless a later demonstrated capability gap is documented and
governed.

## Changed-migration adjudication

Any changed migration that replaces or alters `pandora_supersede_memory_record` must include,
in executable checks or explicit reviewed migration comments, all of:

- `lifecycle-adjudication`
- `scope-invariant`
- `replacement-invariant`
- `cycle-check`
- `rollback`

The migration must enforce the same-scope/current-terminal invariants above.

Lifecycle migrations must not use destructive cleanup against immutable core history.

## CI acceptance

The lifecycle verifier must:

- validate this contract and evidence manifest,
- run synthetic graph self-tests for alias recall, multi-hop resolution, head deduplication,
  missing targets, cycles, cross-scope successors, revoked/inactive/unapproved heads,
- reject a pre-match terminal-only filter in the canonical ProjectOS bridge,
- reject obvious duplicate lifecycle authorities,
- inspect changed migrations for destructive immutable-history cleanup,
- require the supersession adjudication markers when the supersede RPC is changed,
- run on the exact PR head.

## Explicit non-actions

- no production lifecycle mutation
- no production supersession/backfill
- no pruning execution
- no deletion of historical evidence
- no production RLS/grant/Auth/extension mutation
- no Edge deployment/deletion
- no Vercel production mutation
- no canonical Memory data mutation
- no migration execution

## Merge / rollout boundary

This contract is dependency-safe groundwork only. Task 41 still depends on Tasks 9–10 and
35–40; Task 42 still depends on Task 41. A later runtime implementation must re-read
authoritative main, production source/runtime, provider state, the supersession graph, and
fresh security/isolation evidence before changing retrieval or lifecycle writes.
