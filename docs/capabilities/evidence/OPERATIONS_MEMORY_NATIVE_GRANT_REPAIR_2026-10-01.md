# Pandora native Operations Memory grant repair — 2026-10-01

Status: production-readiness repair candidate.

## Verified failure

After canonical Memory source parity was restored and the previously source-only migrations replayed, migration `20260919153000_pandora_native_memory_bridge_v1` re-established the `pandora-mcpmaster-production` grant from its older baseline. That removed the later additive record types required by current Operations Memory.

The live production Vercel build for canonical `pandoras-box/main` SHA `04babd987e28287f6073c0222c0472a42462c752` failed closed with `OPS_MEMORY_PERFORMANCE_GRANT_DENIED`.

Provider readback showed the production grant still had `can_read=true`, `can_propose=true`, `can_approve=false`, but no longer contained `provider_performance`, `model_outcome`, `outcome`, `fact`, `pattern`, `procedure`, or `failure_lesson`.

## Repair

Migration `20261001073505_restore_pandora_native_operations_memory_grant_v1.sql` is forward-only and additive. It preserves the exact principal, user/project/environment boundary and restores only the record types already required by the deployed Operations and advisory Memory contracts:

- `fact`
- `pattern`
- `procedure`
- `failure_lesson`
- `outcome`
- `model_outcome`
- `provider_performance`

It does not grant approval authority, broaden namespaces, add a principal, or reactivate ProjectOS.

## Acceptance

Before production application:
- transactionally rehearse the exact migration and roll it back;
- verify the exact grant row contains the seven required record types and still has `can_approve=false`;
- require exact-head Memory CI, including security adjudication, source lineage, hardening, isolation, evidence registry, and secret scan.

After production application:
- provider read back the exact grant;
- rerun the canonical Pandora production deployment whose build canary exercises context read, performance read, review-only outcome proposal, and exact readback;
- keep canonical Memory authority review-bound: no candidate becomes canonical Memory through this repair.
