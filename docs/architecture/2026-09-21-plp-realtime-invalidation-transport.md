# PLP realtime invalidation transport — 2026-09-21

## Decision

PLP enterprise screens use a safe, organization-scoped Supabase Realtime invalidation transport rather than exposing raw operational rows over Realtime.

The transport table is `public.enterprise_realtime_signals`. A signal contains only an id, organization id, optional property id, bounded topic, and occurrence time. The mobile client receives the signal and refetches the existing protected RPC projections. Protected RPCs remain the source of business data truth.

Topics currently emitted:

- bookings
- guests
- staff_tasks
- hospitality
- business_activity
- source_health
- pandora_activity

This avoids replicating guest PII, provider secrets, AI request content, provider/model routing, or raw audit payloads to clients.

## Source provenance

Canonical repository: `pandora-rvw-314296438-20260820/pandoras-box`

Implementation is carried on PR #654, branch `fix/plp-mobile-command-center-20260920`.

Core source:
- `supabase/migrations/20260921112000_plp_realtime_resort_updates_v1.sql`
- `apps/pandora-mobile/lib/app/plp_enterprise_shell.dart`
- `apps/pandora-mobile/lib/features/enterprise/plp_activity_screen.dart`
- `test/plp-realtime-resort-updates-contract.test.js`
- `test/supabase-migration-parity.test.js`

The shell subscribes to `enterprise_realtime_signals` and debounces protected bootstrap refetches. The PLP Activity page independently refetches business activity and Pandora activity/log projections when a matching organization signal arrives.

## Live provider verification

Supabase project: `jcyqixttuebxqqfkjonq`.

The migration `plp_realtime_resort_updates_v1` was applied successfully through the Supabase provider.

Provider readback after apply:
- `public.enterprise_realtime_signals` is present in `supabase_realtime`.
- Seven intended trigger names are present.
- RLS is enabled.
- `enterprise_realtime_signals_member_read` exists.
- authenticated role can SELECT but cannot INSERT.
- anon role cannot SELECT.

No synthetic user/business record was created for verification.

## Failures, corrections, and lessons

1. Direct GitHub connector writes returned 403. Correction: use the existing Vault-backed `Github_supabase` transport through `private.pandora_integration_github_api_20260825`; never expose the credential.

2. Clean migration replay first failed because `public.enterprise_business_activity` was absent in the replay environment. Correction: environment-dependent trigger installation is guarded by catalog/`to_regclass` checks and dynamic DDL.

3. Replay then failed because PGlite did not have the `supabase_realtime` publication. Correction: publication mutation is conditional on publication existence.

4. An intermediate source edit produced a malformed dollar delimiter in the publication block. Correction: use a named `$publication$` delimiter and verify provider source readback after write.

5. The security contract test matched a forbidden word that appeared only in a comment. Correction: use unambiguous comments and prefer structure-aware security assertions where feasible.

6. Supabase migration parity tests require every governed forward migration to be registered in all relevant expected chains. Correction: update each parity list together with the new migration.

## Durable architecture lesson

For Pandora realtime UI, prefer narrow invalidation events plus authorized refetch over streaming sensitive domain rows. It preserves live UX while keeping authorization and data shaping in the existing protected RPC layer.

Any migration touching provider-specific objects must remain replay-safe in reduced CI environments. Test both live provider catalog state and clean replay; neither is a substitute for the other.

## Verification state

Live Supabase backend: VERIFIED.

Exact-source CI for the final PR head is still running at the time of this record. Final CI status should be appended after the exact head settles.
