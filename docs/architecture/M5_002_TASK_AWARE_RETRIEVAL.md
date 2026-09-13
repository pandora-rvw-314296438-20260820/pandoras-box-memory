# M5-002 Task-Aware Memory Retrieval Contract

Status: **SOURCE IMPLEMENTATION CANDIDATE — PRODUCTION ROLLOUT NOT YET AUTHORIZED**

Task: `M5-002` from the Pandora Device execution plan.

## Purpose

Retrieve only task-relevant, grant-scoped, current Memory before meaningful decisions/actions instead of dumping broad history into prompts.

The retrieval input is aligned directly to the frozen M1-002 universal resolver contract:

- `communication`
- `research`
- `coding_building`
- `files`
- `device_operations`
- `business`
- `travel`
- `scheduling`
- `future_capability`
- `general_assistance`

It also consumes M1 `actionMode` (`no_action`, `read_only`, `state_change`), the consequential flag, bounded task terms, required capabilities and requested canonical statuses.

## Authority boundary

Retrieval never grants execution authority.

`policy` Memory is returned in `policyMemory`, separate from `advisoryMemory`. A retrieved policy is only a candidate input to the standing-authority evaluator and carries:

- its exact `authorityKind`;
- its exact `authorityRef`;
- `requiresRuntimeAuthorizationValidation=true`;
- `authorizationEffect=requires_exact_runtime_scope_validity_revocation_validation`.

Facts, patterns, procedures, failure lessons, outcomes and provider-performance records always carry `authorizationEffect=none`.

Similarity, recency, confidence, model output, prior success, procedures and learned patterns cannot create permission.

## Scope and grant enforcement

`memory_task_context_v1` revalidates:

- exact Memory user;
- namespace;
- project ID and active project state;
- service principal;
- environment;
- active non-revoked `can_read` project grant;
- the grant's `allowed_record_types`.

The function never expands a legacy grant. If a project grant has no M5 typed classes, the result is an empty typed pack with an explicit warning. Grant expansion is a separate authorization decision.

Revoked and superseded Memory is excluded by default.

## Task-aware ranking

When task terms exist, advisory Memory must text-match the task. The ranking then adds class-aware priority, confidence and recency without allowing any score to affect authority.

For state-changing/consequential work, verified `failure_lesson` and `procedure` records receive the highest advisory class priority so prior failure/correction evidence is considered before similar risky work.

For read/planning/personalization-oriented work, verified facts/outcomes and confidence-weighted patterns can rank higher according to the resolved intent.

Policies remain separately ordered and bounded; a state-changing request may include a small policy fallback set even when lexical task matching is weak, but those rows are never treated as authorization.

## Bounded context

The pack is capped at 4 KiB–16 KiB, with 12 advisory records and four policy records as hard pre-budget maxima. Each title, summary and promotion basis is truncated before packing. If the byte budget is exceeded, the lowest-ranked advisory records are removed first, then policy records. Raw runtime events are never included.

The pack reports eligible/returned counts, omitted counts, degradation state, byte size and an integrity SHA-256.

## Compatibility and rollout

- `memory_items` remains canonical Memory.
- M5-001 typed columns/classes are required.
- `memory_context_pack_v2` remains available for existing project decisions/open loops/conflicts.
- Existing legacy keyword retrieval remains a compatibility lane until a project is explicitly granted M5 typed classes.
- Production grants are **not** expanded by this task.
- Production M5-001/M5-002 migrations are **not** applied by the source PR.
- Bridge deployment is a separate governed release action after source merge and provider migration/readback evidence.

## Acceptance

Source acceptance requires:

1. exact M1 intent-domain parity;
2. strict project/principal/environment/grant isolation;
3. no grant expansion;
4. policy/advisory separation;
5. no revoked/superseded retrieval;
6. failure-lesson priority for consequential/state-changing tasks;
7. bounded byte output;
8. cross-project exclusion;
9. disposable PostgreSQL migration/behavior proof;
10. exact-head CI, independent authority review, governed merge and main readback.
