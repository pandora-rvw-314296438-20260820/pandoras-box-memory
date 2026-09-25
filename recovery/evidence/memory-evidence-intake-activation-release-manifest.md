# Pandora Memory evidence-candidate activation and rollback manifest

Status: **CURRENT LIVE BASELINE / REVIEW-GATED**

Observed September 25, 2026 through the Supabase provider and the exact-source Vault-backed release transport. This records component evidence, not deployment or review authority for the candidate below.

## Current live provider baseline

- Canonical repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Live source commit: `1215efacf47acb08aa463e0863efa51c616a43b3`
- Live Edge Function rollback baseline: `pandora-projectos-bridge@28`
- Live Edge status: `ACTIVE`
- Live Edge package SHA-256: `9aaf8151db2fbea0686191cea06a60adb5158e15adbe5b3b3851cdb0b0a13e13`
- Live index raw SHA-256: `5e1f1bcdf5e18e96ac433ab836e97f4e532d1c5d11ce85da20ff5d5324eaf64b`
- Live Edge auth mode: `verify_jwt=false`; protected operations use explicit Vercel OIDC signature, principal, and project-grant validation.
- Compatibility production principal: `projectos-mcpmaster-production`
- Principal scopes: `memory:health`, `memory:read`, `memory:write`
- Allowed namespace: `real_life`
- Provider-verified Box project key: `mcpmaster-pandoras-box`; Memory project key: `memory`. These identities are not interchangeable with repository names.
- Canonical project UUID: `7c686cbd-d968-49d5-86cc-918f5e777bd2`
- Production Box grant: `can_read=true`, `can_propose=true`, `can_approve=false`, active and not revoked.
- Historical migration observation: `20260820113000` is absent from live migration history; it is not the activation authority.

## Candidate source binding

- Candidate bridge raw SHA-256: `8906e952f3f9cbb6b1a31f716d9b8331dbf810497c22d9e309b6c8b29d2e22c0`
- The candidate is not yet deployed. Typed results and approved legacy results are deduplicated and limited by count and UTF-8 bytes. Omitted records are reported as truncation, not absent knowledge.
- `memory_task_context_v1` retains typed scope, validity, revocation and authority separation. `memory_projectos_search_scoped_v1` independently restricts the legacy path to approved, current, project/namespace/user/grant-matching records.
- Existing review-gated evidence intake is preserved. Candidate receipts still state `canonical_memory_written=false`.
- **No scope mutation in this PR.** Typed grants must not be expanded before the reviewed compatibility fix is merged, deployed, and verified.

## Rollback and concurrent-change safety

Immediately before deployment re-read `pandora-projectos-bridge@28` and its package digest. Stop and re-baseline if another release changed it. Keep the last verified provider source and config; restore that exact bundle only after a demonstrated regression. Never substitute a superseded historical named baseline for the actual preceding release.

Preserve current principal scopes and project grants. Do not run stale activation rollback SQL. Verify missing identity, wrong project, wrong namespace, revoked grants, unapproved records and expired records remain denied or omitted. Preserve candidates and review items; never delete or bulk approve them as part of deployment.

## Historical evidence retained

The September 1 manifest previously used `pandora-projectos-bridge@16`, package `3c5857fa787cbfc039100722d32aacfea080743ba6c5b998fdf6854d3467a18b`. That was a historical observation, not the September 25 live state. Version 27 was observed during the audit, then superseded by the exact-source v28 release. Git history preserves the earlier manifest and rollback instructions.

## Authorization boundary

**No automatic canonical Memory promotion** is permitted. A genuine independent exact-head review, fresh provider verification, and the current owner instruction are separate requirements. A successful component deployment does not prove beneficial decision influence or physical-device acceptance.
