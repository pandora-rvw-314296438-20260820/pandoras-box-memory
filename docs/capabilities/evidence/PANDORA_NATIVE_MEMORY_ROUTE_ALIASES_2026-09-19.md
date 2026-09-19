# Pandora-native Memory route aliases - 2026-09-19

Candidate source commit: 00079db0ce41579c59470f5c9149d9559ed455e6.

This change adds three neutral authenticated API surfaces backed by the existing Memory bridge:

- GET /api/pandora/health
- POST /api/pandora/memory/search
- POST /api/pandora/memory/evidence-candidates

The health alias normalizes a successful response status to pandora-connected. Search and evidence intake preserve the existing authentication, allowlist, payload-boundary, namespace, and backend behavior by reusing the existing route handlers.

Purpose: permit the canonical Pandora runtime to remove the retired route identity without breaking Memory health, retrieval, or evidence intake. No secrets, credentials, database grants, or storage schema are changed.

Verification authority: exact-head GitHub Actions web build/typecheck and repository capability/security gates. Merge remains blocked until those checks complete successfully.
