# Pandora Memory evidence-candidate activation and rollback manifest

Status: **CURRENT LIVE BASELINE / REVIEW-GATED**

Observed during Task 5 / PR #8 preparation on 2026-09-01 (Asia/Manila). This document records provider readback and source invariants. It does not replace fresh provider verification before deployment.

## Current live provider baseline

- Canonical repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Pre-change Memory main: `ae5aeb6a8a98582df9b4905381d3cff3298cc887`
- Live Edge Function rollback baseline: `pandora-projectos-bridge@16`
- Live Edge status: `ACTIVE`
- Live Edge package SHA-256: `3c5857fa787cbfc039100722d32aacfea080743ba6c5b998fdf6854d3467a18b`
- Live Edge auth mode: `verify_jwt=false`; protected operations use the bridge's explicit Vercel OIDC verification and service-principal checks.
- Production principal: `projectos-mcpmaster-production`
- Principal scopes: `memory:health`, `memory:read`, `memory:write`
- Allowed namespace: `real_life`
- Canonical project key: `mcpmaster-pandoras-box`
- Canonical project UUID: `7c686cbd-d968-49d5-86cc-918f5e777bd2`
- Production grant: `can_read=true`, `can_propose=true`, `can_approve=false`, active, not revoked.
- Live migration history: `20260820113000` is absent from live migration history.

The recovered `check_memory_evidence_activation.mjs` previously assumed that the absent migration and its rollback file were the production activation authority. Fresh provider readback disproves that assumption: the current principal already has `memory:write`, the current project/grant binding is active, and the migration is not recorded as applied. The stale migration-dependent CI contract is therefore retired rather than recreated.

## Candidate source binding

- Candidate bridge raw SHA-256: `6ae5f00523a656be01175b82d651f9b2cc05585f513293801c17522fc62b884a`
- Task 5 source change is project-isolated Memory search only.
- Search requires explicit canonical project identity plus an active `can_read` project grant.
- Search returns exact-project `memory_items` only and omits namespace-wide profiles, open loops, events, and context packs when those tables cannot prove project ownership.
- Evidence-candidate intake remains review-gated and continues to require `memory:write` plus an active `can_propose` project grant.
- Candidate responses continue to state `canonical_memory_written=false`.
- No schema migration is introduced.
- **No scope mutation in this PR.**

The Box caller side is already live from merge `a996aa3e116f6ed9659040c2f42b72e7d83246fc` on `mcpmaster.vercel.app`, so strict Memory-side project enforcement can be deployed without a caller compatibility gap.

## Rollback baseline

Immediately before deployment, re-read the live Edge Function and require the expected pre-change identity `pandora-projectos-bridge@16` with package SHA-256 `3c5857fa787cbfc039100722d32aacfea080743ba6c5b998fdf6854d3467a18b`. If it has changed, stop and re-baseline rather than overwriting concurrent work.

If post-deployment verification fails:

1. Restore the pre-change bridge provider source corresponding to the v16 rollback baseline and verify provider readback.
2. Preserve the current principal scopes and project grant; do not run the stale never-applied activation rollback SQL.
3. Verify health and evidence-candidate intake still fail closed or remain review-gated as appropriate.
4. Preserve pending candidates/review items. Do not delete, rewrite, approve, or promote them automatically.
5. Record the failed deployment and rollback evidence before further changes.

## Authorization boundary

This manifest is an evidence and rollback contract, not an authorization to approve Memory candidates or promote canonical Memory. **No automatic canonical Memory promotion** is permitted. Fresh provider truth and the current owner execution instruction remain required for consequential production actions.
