# Pandora Core Copilot review and merge closeout — 2026-10-04

Status: **pending_review evidence only**. This record does not approve canonical Memory, production deployment, authenticated customer acceptance, or physical-device acceptance.

## Verified facts

- Canonical source repository: `pandora-rvw-314296438-20260820/pandoras-box`.
- Repository-wide GitHub Copilot instructions were created through the Supabase Vault-backed `Github_supabase` transport in PR #947.
- PR #947 merged to `main` as `9bb704efa926769f833155c4ff189d8f32e2bd5f`.
- The instructions live at `.github/copilot-instructions.md` and establish bounded-agent rules for secrets, Pandora Core invariants, state semantics, loading/error behavior, mobile interaction, exact-source evidence, and review discipline.
- PR #946 was reconciled onto that main so Copilot code review could read the instructions from the PR head branch.
- Copilot code review found one medium accessibility defect: assistant replies longer than 4,000 characters were visually complete while screen-reader semantics truncated the accessible reply.
- Product source fix commit: `e7118f9adc89a3b25fc642a9e20916cb5da7fdbe` (`fix: expose full assistant replies to screen readers`).
- A subsequent Copilot review reported **Findings: None** and the original accessibility review thread became resolved/outdated.
- The only source delta after that no-findings review was regression-test alignment at `a47a0f6a6a149f414b8f279054283172f6719536`; comparison against the reviewed reconciliation commit changed only:
  - `apps/pandora-mobile/test/app/pandora_core_inspect_handoff_test.dart`
  - `apps/pandora-mobile/test/features/simple/ask_pandora_activity_theatre_test.dart`
- The final requested Copilot re-review was not performed because the requesting account had reached its Copilot review quota. This quota result is not treated as a negative code finding.
- Exact head before merge: `a47a0f6a6a149f414b8f279054283172f6719536`.
- Exact base/main before merge: `9bb704efa926769f833155c4ff189d8f32e2bd5f`.
- All 15 observed exact-head workflow families completed successfully, including:
  - Pandora Node 24
  - Dependency Review
  - Pandora mobile exact-source gate
  - Pandora mobile UX behavior
  - PLP Pandora Enterprise Android exact-source
  - Euro-Fish Pandora Enterprise Android exact-source
  - Operations Memory client
  - Operations inference and live Theatre
  - Operations Room cloud connectors
  - Operations Runtime Seams
  - Pandora audit behavioral regression
  - Engineering toolchain
  - Pandora Edge source artifact
  - Canonical release evidence
  - Windows Worker Contract
- Final provider preflight observed 29 check runs on the exact head, with 0 pending and 0 failed.
- PR #946 was open, non-draft, clean, and exact-head/base aligned immediately before merge.
- PR #946 was merged through the Supabase Vault-backed GitHub transport with an exact-head SHA fence.
- Verified merge commit: `614d11bee20928075545c411dc5799537778127d`.
- Provider readback verified:
  - PR #946 is merged and closed.
  - canonical `main` is `614d11bee20928075545c411dc5799537778127d`.
  - the merge commit is GitHub-verified.
  - merge parent 1 is base `9bb704efa926769f833155c4ff189d8f32e2bd5f`.
  - merge parent 2 is exact PR head `a47a0f6a6a149f414b8f279054283172f6719536`.
- The Vault credential itself was never returned, printed, committed, or copied into model-visible source.

## Durable lessons

1. When the ChatGPT GitHub App can read but cannot write, use the existing governed Supabase Vault-backed GitHub transport instead of changing repositories, editing `main` directly, or exposing a PAT.
2. Put repository-wide Copilot review instructions in `.github/copilot-instructions.md`, but remember that Copilot code review reads instructions from the pull request **head branch**, not only from base/main.
3. Treat Copilot review as defect discovery, not release authorization. Green CI and a no-findings Copilot review still do not prove authenticated production journeys.
4. If a Copilot finding is fixed and the later head contains only test corrections, preserve the exact reviewed product-source boundary and verify the post-review delta explicitly rather than pretending the later head received the same review.
5. Do not use GitHub auto-merge when Pandora's internal acceptance contract is stricter than repository-required status checks. Wait for the complete exact-head evidence set intended by the release lane.
6. Preserve semantic separation between provider/deployment readiness, runtime verification, user-flow verification, and production verification.

## Explicitly not proven by this closeout

- canonical production deployment of merge `614d11bee20928075545c411dc5799537778127d`;
- authenticated owner or authenticated client runtime acceptance;
- physical-device production acceptance;
- production Android signing/distribution;
- complete remediation of every UX defect observed in recording `6555.mp4`.

This evidence records the GitHub/Copilot review-and-merge outcome only.
