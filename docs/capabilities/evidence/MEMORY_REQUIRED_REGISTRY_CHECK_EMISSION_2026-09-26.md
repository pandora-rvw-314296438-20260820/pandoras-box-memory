# Memory required registry check emission — 2026-09-26

## Scope

Repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`

Ruleset: `22377711` — Pandora Memory main protection.

The ruleset requires the status context `Validate exact-head evidence registry` on every pull request. Before this correction, `.github/workflows/capability-registry-gate.yml` used PR-level path filters, so PRs outside those paths could never emit the required context and therefore could not merge even when every applicable check passed.

## Correction

The PR-level path filter is removed from the Capability Registry Gate so the required context exists on every pull request.

The job-level exact-head diff logic remains unchanged. It still:
- compares the candidate head to the PR base;
- detects tracked source changes;
- requires a registry, manifest, evidence, or roadmap co-change for tracked source changes;
- runs the capability-registry validator/self-test;
- emits exact-head content digests and an attestation artifact.

This evidence file is the required evidence co-change for the workflow governance correction itself.

## Non-changes

- Required approval count remains `0`.
- Latest-push approval remains disabled.
- Required review-thread resolution remains enabled.
- Required status checks remain enabled.
- Deletion and non-fast-forward protection remain enabled.
- No bypass actor is added.
- No Memory runtime, Supabase schema, provider credential, or production data is changed.

## Expected result

After merge, any PR can emit the required `Validate exact-head evidence registry` context. Whether registry evidence is required continues to be decided by the existing job-level diff policy rather than by suppressing the workflow entirely.
