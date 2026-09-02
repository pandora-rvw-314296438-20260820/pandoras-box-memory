# Visible Creation Memory Evidence Contract — 2026-09-02

Status: SOURCE CANDIDATE / REVIEW-GATED. This file is source evidence for PR #29; it is not production deployment proof.

## Authority and isolation

- Canonical Memory project: `7c686cbd-d968-49d5-86cc-918f5e777bd2` / `mcpmaster-pandoras-box` / namespace `real_life`.
- Service principal: `projectos-mcpmaster-production` with an active production project grant and `can_propose=true`.
- Candidate intake never writes canonical Memory directly. `canonical_memory_written=false` and human review remains required.
- The automatic lifecycle path reuses the existing HMAC-authenticated ProjectOS learning transport and additionally binds typed lifecycle fields into a recomputed SHA-256 context hash.

## Governed evidence kinds

`verified_build`, `verified_preview`, `verified_publish`, `verified_repair`, and `repeated_failure` are the only Visible Creation evidence kinds accepted by source.

Verified build/preview/publish/repair evidence requires authoritative lifecycle identifiers and SHA-256 source/artifact digests appropriate to its proof stage. `verified_publish` requires `production_verified`. `repeated_failure` requires a bounded failure fingerprint and recurrence count rather than raw provider errors.

## Privacy boundary

The lifecycle payload contains only bounded enums, UUIDs, timestamps, counters and cryptographic digests. It does not contain raw prompts, source chunks, environment values, credentials, raw provider arguments/results/errors, or customer text. Existing Memory privacy scanning and project/grant authorization remain in force.

## Exact source binding

- `supabase/functions/pandora-projectos-bridge/index.ts`
  - Git blob: `83afdfe047796ee1e5bc4be0d975a39b9623994e`
  - Raw SHA-256: `92faeacdfd4b5a63f1594e3f7542911c06a2f9bc738abdcc3ecb6feb74ad05b8`
- `supabase/functions/pandora-projectos-learning/index.ts`
  - Git blob: `c0089b13e5489802fb8985fda4b57f0d5fcac57f`
  - Raw SHA-256: `9e5e62ede8cf07330797f4855ae223fc78592b88daad51b0a13d378b3a6c0204`

Acceptance remains fail-closed until exact-head CI passes, PR #22 merges, the changed Edge functions are deployed from merged source, and live readback confirms the deployed contract.
