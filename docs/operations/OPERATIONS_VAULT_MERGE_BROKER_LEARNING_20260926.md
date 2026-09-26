
# Verified learning — Vault-backed governed GitHub merge broker

Observed 2026-09-26 in the canonical Pandora control plane.

## Verified problem

The connected ChatGPT GitHub integration could read the canonical repository but GitHub rejected branch/merge writes with 403 Resource not accessible by integration. The correct response was not to reduce task risk, bypass coordinator policy, or mark scheduler work complete.

## Durable architecture

The canonical write path for governed merges is:

Operations / coordinator decision -> exact merge claim -> Supabase Vault-backed merge broker -> GitHub provider mutation -> provider readback -> coordinator claim completion -> immutable receipt.

The broker uses Github_supabase only inside Supabase Vault. The credential is not returned, logged into receipts, or committed.

A merge is admitted only when the canonical repository is fixed, the current coordinator decision is PASS, the exact trusted coordinator check is completed/success, a live merge claim exists, the repository fence and authoritative sheet snapshot match, PR head/base are exact and clean, observed non-superseded checks are terminal/acceptable, and main has not moved from the claimed base.

After mutation, the broker requires provider readback: PR merged, signed merge commit verified, exact PR head and base present as parents, main equals or contains the merge, coordinator completion consumes the exact claim, and the fence is released. Every successful merge writes an immutable receipt. A one-minute Supabase-native cron processes eligible claims. Manual execution is service-role-only.

## Failure handling learned

1. Ambiguous mutation responses require provider readback, never blind retry.
2. GitHub may return merge_commit_sha null on an already merged PR. Never invent the SHA; verify the signed commit and PR-head parent relationship.
3. Expired coordinator claims fail closed and must be renewed.
4. Superseded coordinator check runs must not poison a newer exact-head PASS; only the current coordinator check is authoritative.
5. Source generated from pg_get_functiondef must append a SQL terminator. Migration replay CI caught the first missing semicolon before merge.
6. Production database success is not durable enough by itself; live migrations must be source-tracked and replay-tested.

## Production evidence

- PR 754 exercise head: 5b0b2b3ad91f4cc73744709f24f4ab1c07ebe82d
- PR 754 merge: d5694d853e90d1350fa0fdda0f5ecd6db704fabb
- PR 754 broker receipt: a41ee0d5-fc63-4dc1-9a29-5e51420703e3
- PR 755 source-sync head: 9311eef155a286324fe7a83ebd9f25ea9b01131f
- PR 755 merge: d636e11e4da09ffb129a2038b799e1ecbcca42ee
- PR 755 broker receipt: 3cb6f1f7-6681-44f9-ae52-07b642f150a4
- Whole-sheet verification: 9065882e-4381-4265-bc61-7bb03f77a2c3
- Memory adoption verification: 65098fa1-9a9f-4b44-bfbf-c54fc20897da
- Final Operations state: zero queued tasks and zero active leases.

## Decision rule

If an agent or plugin lacks GitHub merge permission, do not route around governance. Obtain or reuse a current coordinator PASS and exact merge claim, then let the Vault-backed broker execute. A successful provider call is still only a claim until exact provider readback and an immutable receipt exist.
