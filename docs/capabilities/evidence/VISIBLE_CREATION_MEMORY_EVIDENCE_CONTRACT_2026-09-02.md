# Visible Creation Memory Evidence Contract — 2026-09-02

Status: SOURCE CANDIDATE / REVIEW-GATED. This file is source evidence for PR #28; it is not production deployment proof.

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
  - Git blob: `7f44960818e5626a4b96b01fca5a640dc5d798df`
  - Raw SHA-256: `6ae5f00523a656be01175b82d651f9b2cc05585f513293801c17522fc62b884a`
- `supabase/functions/pandora-projectos-learning/index.ts`
  - Git blob: `e9dfb0f7a6f693f9c984352ac9a08e27c9ceb9d9`
  - Raw SHA-256: `11bed5d2cdea9e02a2baba2c8d1d743157dd6b232cde98b661a0cccdc6813974`

Acceptance remains fail-closed until exact-head CI passes, PR #28 merges, the changed Edge functions are deployed from merged source, and live readback confirms the deployed contract.
