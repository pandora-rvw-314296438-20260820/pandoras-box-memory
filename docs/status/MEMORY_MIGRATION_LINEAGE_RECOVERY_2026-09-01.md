# Memory migration lineage recovery — 2026-09-01

## Purpose

Restore deterministic source authority for the live Memory database without replaying or mutating production schema.

## Verified baseline

- Memory Supabase: `ivmvufhcsezyhczzondn`
- Source baseline: `aa9294fe3d23f7dec515c4d559450422382d2768`
- Source tree: `790c4160131c8f2fb99feea43bfca667200a9643`
- Live applied migration identities: **85**
- Source migration files before this checkpoint: **5**
- Exact applied files before repair: **3**
- Corrupted applied source files before repair: **1**
- Applied migrations absent from source: **81**
- Source-only pending migration: `20260901041000_rebind_projectos_vercel_oidc_identity.sql`

## Repair in this checkpoint

`20260808190813_add_gateway_workload_oidc.sql` existed as a zero-byte file in canonical source even though the live migration ledger records a 4,583-byte applied migration. This checkpoint reconstructs that file only from `supabase_migrations.schema_migrations.statements[]`.

Expected repaired SHA-256: `918ab4c000f37dada70b45e0f94bc2cfc81619f9e800daca6e698c14fa7d1c22`.

The live ledger was compacted to a version/name/bytes/SHA manifest of 10,379 bytes with SHA-256 `fcfaaa292e0c3ff6700b5a542fbb456ff17d39cd4bf59e0ab164725b737d052b`. The compact manifest itself is provider evidence used to derive this checkpoint; the checked-in JSON records the authority, counts and exact source hashes required for CI.

## Safety boundary

This is a **source-only recovery**. It does not execute SQL against production, mark unapplied migrations as applied, alter the live ledger, or authorize replay. The remaining 81 historical SQL files must be reconstructed only from the corresponding live `schema_migrations.statements[]` rows and independently hash-checked before source parity can be declared.

The dedicated CI gate intentionally freezes the current five-file migration source set. Any addition/removal/change must refresh live provider evidence first, preventing silent migration-source drift.

## Full parity acceptance

Full migration-source parity requires all 85 applied migrations to exist in canonical source with exact version/name/content hashes, zero applied migrations missing from source, the pending source migration explicitly adjudicated, and fresh Supabase readback after merge. Until then, migration lineage is **recovery-controlled**, not fully source-reproducible.

## 2026-09-01 follow-up milestone — post-Vault replayability and legacy quarantine

The recovery branch now contains 33 applied migration sources. The 29 post-Vault recovered files are provider-derived and replayable. Four multi-statement ledger rows required deterministic statement terminators during source serialization; their replayable file hashes are separately bound from the original provider statement-concatenation proof.

Post-Vault replayable manifest: 29 files, 4,340 manifest bytes, SHA-256 `3ec0292900d8f1337d99b7ff1bb346576ea73cf6c528101dad84c8f25333c6a0`. Original provider statement-concatenation manifest remains preserved as `03ce480d587bf767d60b565a18f3d462f9155a291952a8e93439eb3fa09b0a81`.

The remaining 52 applied legacy migrations were classified provider-side without exporting credential values. The frozen boundary is 44 candidate-safe and 8 quarantined. Full legacy manifest SHA-256: `60495c54adefd13bf72a1107c8a36141940e265f429b8e347b60fad4eb3ddb8e`; quarantine manifest SHA-256: `3ea4b7bff97cc3edbc68ba5067c1dff4b4f7768c05e9520f93ba013a6ee8bfa5`. Quarantined SQL must not be copied verbatim into source.

The source-only migration `20260901041000_rebind_projectos_vercel_oidc_identity.sql` was proven byte-identical to already-applied migration `20260831205808` (shared Git blob `a8657001cb445da1e725d8e502f7b07d7dcf970c`, 1,800 bytes) and absent from the live migration ledger. It was removed from the recovery branch to prevent a second application when Supabase Git migration convergence is restored.

No production schema mutation, migration replay, migration-ledger repair, Vercel mutation, or credential export occurred in this milestone. Supabase Git `main` remains fail-closed with `MIGRATIONS_FAILED` until the remaining historical source gap is safely resolved.
