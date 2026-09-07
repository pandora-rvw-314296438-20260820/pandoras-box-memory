# Visible Creation Memory Evidence Contract — 2026-09-02

Status: SOURCE CANDIDATE / REVIEW-GATED. This file is source evidence for PR #30; it is not production deployment proof.

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
  - Git blob: `27e1a1d6ef2658343add4b927ffcd9211a6e1ef2`
  - Raw SHA-256: `3733beca22f535a6bbe061aed072319bac22f1b4b9fb3cee82757bcc5d380a03`
- `supabase/migrations/20260907051800_memory_projectos_indexed_search_v1.sql`
  - Git blob: `1c95c8a81a7c9872ce6180eef77ad0825f9ee794`
  - Raw SHA-256: `8a75a5e61e47dec4ec021805e5340ae2cd989621c5b0b2ecd64dbc732634092e`
  - Scope: service-role-only exact-project indexed retrieval; no broader authorization.
- `supabase/functions/pandora-projectos-learning/index.ts`
  - Git blob: `1ee821c8e362a1fd240af80611c8286f287c3131`
  - Raw SHA-256: `1b0856d71c679e824051f2ef03a9be0561da58901c3bfae9b4789499de33f554`

Acceptance remains fail-closed until exact-head CI passes, PR #22 merges, the changed Edge functions are deployed from merged source, and live readback confirms the deployed contract.
