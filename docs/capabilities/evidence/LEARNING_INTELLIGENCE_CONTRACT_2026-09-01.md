# Pandora Learning Intelligence Contract — 2026-09-01

Status: **SOURCE-CONTROLLED SAFETY CONTRACT / NOT PRODUCTION VERIFICATION**

This contract freezes the dependency-safe design for Pandora Memory learning, outcome correlation, failure intelligence, proven repair-history retrieval, and governed playbook synthesis. It does not authorize a runtime deployment, schema mutation, replay of terminal learning failures, cross-project learning, or canonical promotion.

## Exact source baseline

- Canonical repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Authoritative Memory main at contract creation: `aa9294fe3d23f7dec515c4d559450422382d2768`
- Authoritative Memory main tree at contract creation: `790c4160131c8f2fb99feea43bfca667200a9643`
- Existing learning service: `supabase/functions/pandora-projectos-learning/index.ts`
- Existing learning privacy policy: `metadata_only_v1`
- Existing episode candidate authority: `memory_capture_candidates`
- Existing immutable review snapshot authority: `memory_review_queue_items`
- Existing canonical promotion authority: current candidate -> review -> canonical governance; no parallel promotion path is authorized.

Fresh provider truth remains authoritative for mutable facts. Memory records what happened, why it matters, and what should be checked; it does not replace GitHub, Supabase, Vercel, CI, deployment, or runtime readback.

## No-duplication decision

The current architecture is extended rather than replaced.

1. Reuse the Primary execution learning outbox and `pandora-projectos-learning`.
2. Reuse `memory_capture_candidates` as the stable ProjectOS episode anchor.
3. Reuse the one-to-one append-only `memory_review_queue_items` snapshot for immutable episode lineage.
4. Reuse existing provider verification/evidence/deployment authorities by reference.
5. Reuse current candidate/review/canonical governance for future playbook promotion.
6. No `memory_episodes` table is authorized now.
7. No separate playbook table is authorized now.
8. No `learning_gateway_v2`, `memory_learning_v2`, or playbook gateway is authorized.

A new table or service is permitted only after a demonstrated cardinality or governance capability gap cannot be represented by these existing authorities.

## Privacy-safe learning event contract

The current source already rejects unsupported schemas unless `privacy_policy` is `metadata_only_v1`. It accepts bounded structured identifiers/tokens, hashes/fingerprints, status, duration, project identity, tool/risk class, context status/hash, and timestamps. It persists `raw_excerpt: null` and explicit false attestations for importing raw arguments, raw results, raw errors, personal identifiers, and secrets.

Current safe fields include:

- project identity/key
- organization and intake references
- tool
- risk
- outcome status
- duration
- completed timestamp
- context status and context hash
- result fingerprint when applicable
- error fingerprint when applicable
- privacy policy and non-import attestations

Future enrichment may add only fields backed by exact authoritative structured data. Safe planned additions are:

- `task_class` from governed normalization of structured intake `request_type`
- `action_fingerprint` from the authoritative execution payload hash
- explicit verification/proof references from exact provider/dispatch lineage

The following remain nullable/unknown until exact per-plan authority exists:

- execution retry count
- human intervention
- approval-required classification
- rollback-required classification
- verification stage for historical ProjectOS episodes without exact proof linkage

Delivery retry attempts are transport telemetry and must never be relabeled as execution retries.

Forbidden learning payload content includes raw credentials, PAT values, OAuth secrets, service-role keys, signing secrets, complete tool payloads, complete provider responses, raw customer private content, raw error bodies, and unnecessary PII.

## Episode lineage contract

For a ProjectOS learning event, episode identity is the existing unique candidate tuple:

`(user_id, namespace, source='projectos-post-task', source_ref='projectos-plan:<plan-id>')`

The candidate is a mutable governance object. The append-only review item is the immutable lineage snapshot. The review snapshot is where the exact reference tuple should ultimately be preserved:

- project identity
- task class
- context hash/status
- action fingerprint or normalized action reference
- outcome status/fingerprint
- proof stage
- provider/evidence references
- failure class reference when applicable

Independent proof artifacts remain in provider/evidence authorities and are referenced rather than copied into Memory.

## Proof-stage contract

Memory may report a proof stage only from exact authority joins.

- `documented`: episode lineage exists, but independent execution/provider proof is absent or incomplete.
- `tested`: exact project/source verification run is `PASS` and has independent verification evidence.
- `deployed`: exact project/provider deployment for the referenced source is ready.
- `production_verified`: exact production source/deployment identity is independently live-verified **and** every applicable release policy/receipt requirement is satisfied, including verified receipt, health readback, and rollback identity when that policy applies.

A plan status of `completed` is not proof. A deployment state of `live_verified` is necessary but not sufficient for the strongest proof stage when an applicable release receipt chain is missing or mismatched. `FAIL`, `BLOCKED`, `STALE`, failed deployment, missing receipt, source mismatch, or provider mismatch cannot promote proof.

Historical ProjectOS learning with no exact dispatch/provider proof linkage remains unverified; it must not be backfilled by inference.

## Failure intelligence contract

The current safe project-scoped failure class key is:

`project_id + task_class + tool + risk + error_fingerprint`

`action_fingerprint` is a trajectory/attempt dimension, not the root failure-class key.

Current evidence baseline at contract creation:

- 634 failed learning episodes have complete safe clustering features.
- Fingerprint-only grouping produces 57 classes and crosses project/tool/risk boundaries.
- Project-scoped context grouping produces 98 classes.
- 47 project-scoped classes recur at least twice.
- 16 project-scoped classes recur at least five times.
- 45 project-scoped classes contain multiple distinct action fingerprints.

Therefore recurrence is an investigation signal, not proof that the same repair applies.

Cross-project generalized clusters may be computed only as future privacy-safe abstraction candidates. They are not currently shareable learning and must not enter retrieval or playbook promotion until project isolation and privacy-safe generalization gates are proven adversarially.

## Proven repair-history retrieval contract

Task 30 must distinguish prior occurrence from proven repair.

A request is scoped to the exact current project and the safe failure-class dimensions above. Cross-project retrieval is prohibited.

The response contract should expose only privacy-safe references and aggregates such as:

- `seen_before`
- `failure_class_fingerprint`
- `occurrence_count`
- `attempted_action_fingerprints`
- `normalized_repair_sequence` when a governed normalization exists
- `proof_stage`
- `evidence_refs`
- `successful_verified_instances`
- `proven_repair`
- `confidence`
- `last_verified_at`

Critical semantic invariant: `seen_before=true does not imply proven_repair=true`.

If the class recurred but no independently verified successful repair sequence can be joined to exact evidence, return `seen_before=true` and `proven_repair=false`. Pandora may say the class has been observed before, but it may not present an unverified repair as a proven fix.

If multiple action trajectories exist, preserve them separately. Do not collapse them into one repair merely because the final error fingerprint matches.

## Playbook-candidate synthesis gate

A reusable playbook candidate requires all of the following:

1. `>= 3 comparable` same-project episodes under a stable failure/task context.
2. `>= 2 independently verified` successful instances using the same governed normalized repair/execution sequence.
3. Explicit preconditions.
4. Explicit known failure modes and stop conditions.
5. An exact verification procedure and proof references.
6. No unresolved material contradiction against newer verified evidence.
7. Sufficient confidence derived from verified cases, not raw recurrence count.
8. Review-required candidate status; never automatic canonicalization.

One success cannot become policy. A recurring failure with no verified successful repair cannot become a playbook. A playbook candidate is not canonical until approved through existing governance.

## Governed promotion capability gap

The existing candidate -> review -> canonical path is the correct authority, but current `memory_execute_approved_review_persistence` flattens approved review items into `memory_items.memory_type='observation'` and records the source as `user_statement`. The current `memory_type` enum has no playbook knowledge kind.

Therefore the genuine future capability gap is **type-preserving governed persistence**, not a parallel playbook database.

Before playbook promotion can be implemented, the governed persistence path must preserve an explicitly approved knowledge kind/type and provenance while retaining:

- authenticated user/namespace/project scope
- append-only behavior
- approved decision binding
- idempotency
- evidence snapshot requirement
- immutable audit/version lineage
- no overwrite/delete path

No schema or RPC mutation is authorized by this contract itself.

## Retrieval feedback and causal-learning boundary

Retrieval usefulness cannot be scored causally until telemetry can join:

`retrieval -> exact resolved Memory head(s) -> use/feedback -> downstream execution -> verification -> final outcome`

Current retrieval logs are privacy-safe but do not record exact returned/used Memory head identities, and current feedback does not bind retrieval to downstream outcomes. Until that link exists, Memory-assisted success lift and causal ranking changes remain `unknown`; correlation must not be labeled causation.

## Replay/backfill boundary

Terminal learning delivery failures must not be manually reset in place. A governed replay/backfill mechanism must preserve original failure history and create an auditable retry transition while relying on existing candidate source-ref uniqueness for idempotency.

Historical pre-trigger completions are backfill debt, not evidence of a current enqueue regression. No replay is authorized while learning runtime/source authority or production dependencies remain unresolved.

## Release gate for future implementation

Any implementation that changes learning, failure intelligence, repair-history retrieval, or playbook promotion must pass all of these gates before production use:

1. re-read exact current Memory `main` and provider state;
2. prove no duplicate learning/episode/playbook authority was introduced;
3. preserve `metadata_only_v1` or introduce a separately reviewed privacy contract with equal-or-stronger guarantees;
4. prove candidate/review remains review-required and `canonical_memory_written=false` at ingestion;
5. prove exact project and namespace isolation, including wrong-project/wrong-namespace negative tests;
6. prove proof-stage derivation uses exact provider/evidence lineage and fails closed on missing/mismatched proof;
7. prove `seen_before` is separate from `proven_repair`;
8. prove playbook synthesis thresholds and contradiction gates;
9. run literal-secret scanning;
10. bind CI to the exact candidate SHA;
11. preserve rollback identity;
12. after merge, re-read `main`, Supabase function/source state, Vercel deployment source, production alias, and runtime behavior before claiming deployment or production verification.

## Current external production blocker

At contract creation, current Memory main is `aa9294fe3d23f7dec515c4d559450422382d2768`, but the READY production Vercel deployment remains `dpl_BEexxMqWK6LYmzvbGHb9emd8HAX4` sourced from older main `ae5aeb6a8a98582df9b4905381d3cff3298cc887`. A READY preview exists for PR #8 source, but preview deployment is not production authority.

The Vercel Hobby-team deployment quota is currently exhausted; the tracker records reset around 2026-09-02 13:38 Asia/Manila. Therefore this milestone is intentionally source-controlled only. It must not be reported as deployed or production_verified, and the strict Memory Edge rollout remains ordered after the exact-main Vercel route is live.

## CI-enforced invariants

`scripts/verify_learning_intelligence_contract.py` and `.github/workflows/learning-intelligence-contract.yml` enforce the contract against the real learning source. The gate must fail when:

- the learning service stops requiring `metadata_only_v1`;
- raw excerpt or secret/raw-import protections disappear;
- review-required or `canonical_memory_written=false` safeguards disappear;
- a prohibited duplicate Memory learning/episode gateway path is introduced;
- this contract loses project-scoped failure identity;
- `seen_before` and `proven_repair` semantics are conflated;
- playbook synthesis thresholds are weakened below the frozen evidence-backed minimum;
- source formatting/type checks or literal-secret scanning fail.

This gate is a source safety invariant. It is not evidence that production has already adopted the future learning model.
