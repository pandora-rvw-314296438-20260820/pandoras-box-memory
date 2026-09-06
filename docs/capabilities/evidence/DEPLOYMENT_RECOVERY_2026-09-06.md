# Deployment recovery evidence — 2026-09-06

Scope: `pandoras-box-memory`.

Observed before repair:
- Vercel commit status failed at the Hobby build-rate-limit gate.
- Supabase Preview reported remote migration versions missing from the local migrations directory.

Repair:
- Added `vercel.json` with non-main automatic deployments disabled and `main` preserved for production deployment.
- Added no-op provider-history receipts for remote migration versions `20260902023147`, `20260902023434`, `20260902083833`, and `20260906024019`.
- Updated the migration-lineage verifier so those provider receipts are classified as non-replayable history receipts rather than executable source.

Security:
- No provider credential is stored in source.
- Credential-bearing or already-live provider migrations are not replayed.
