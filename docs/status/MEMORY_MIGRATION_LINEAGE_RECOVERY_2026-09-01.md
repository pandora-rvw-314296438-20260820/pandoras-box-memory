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
