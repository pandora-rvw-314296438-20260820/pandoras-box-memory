# Memory Production Migration Source Parity — 2026-10-01

Status: source-parity repair candidate; production migrations were not replayed by this change.

## Provider finding

Supabase project `ivmvufhcsezyhczzondn` reported 17 applied migration versions that were absent from canonical `pandoras-box-memory/main` at `e0e158ef3a7352696a9edd46aa1b05579265525f`.

The missing source files were reconstructed from the provider-retained `supabase_migrations.schema_migrations.statements` values. A secret-shape scan over all 17 provider-retained SQL payloads returned false for every migration before source synchronization.

## Scope

This repair restores the missing migration-version files on the task branch only. It does not execute, replay, roll back, or otherwise mutate those already-applied production migrations.

The security-sensitive repository-binding reconciliation migration includes the repository-required adjudication markers as source comments only; its SQL behavior remains unchanged.

## Acceptance

Required evidence:
- exact-head Memory CI;
- migration source-lineage verification;
- security adjudication;
- no-literal-secrets;
- Supabase Preview no longer reporting remote migration versions missing from local source;
- provider readback that canonical main contains all production migration versions after merge.

Source branch: `chatgpt/memory-prod-migration-parity-20261001`
Pull request: #137
