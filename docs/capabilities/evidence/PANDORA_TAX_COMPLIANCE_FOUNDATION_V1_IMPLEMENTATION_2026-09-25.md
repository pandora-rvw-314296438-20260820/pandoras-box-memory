# Pandora Tax & Compliance Foundation V1 — Implementation Evidence

Recorded: 2026-09-25
Status: merged source foundation; not live tax filing or payment proof.

## Verified result

- Implementation PR: #700
- Exact candidate head: 51a1e34e573ee083f1211a8d08f22c6fb3e5fe12
- Canonical merge SHA: 33009faf6c595fb0836ca4e405e86a0f248b8809
- PR #702 Meta OAuth Vercel fallback was included in the combined candidate and was also marked merged through the same canonical merge.
- The combined branch was based on the corrected PLP implementation with light/ivory pages and pure-black side panels.

## Tax foundation now in canonical source

The merged foundation contains organization-scoped tax evidence structures, tax periods and ledger structures, reconciliation and exception structures, deterministic versioned rule-pack authority, a fail-closed Philippines jurisdiction placeholder, calculation/obligation structures, review/approval structures, append-only audit design, RLS-scoped reads, owner/admin period preparation, and the read-only tax workspace projection.

No current tax rates, live filing, or tax-payment execution are enabled by this foundation.

## Governance hardening completed before merge

Approved rule packs require reviewer identity, review notes, and official-source provenance. Individual rules require deterministic specifications and source references. Approved and superseded rule history is immutable. Supersession requires a different approved replacement in the same jurisdiction. Authenticated clients cannot directly modify tax-rule authority.

## Exact-source verification

The final candidate passed Node 24, Engineering toolchain, Dependency Review, Windows Worker Contract, Canonical release evidence, Edge source artifact, mobile exact-source, PLP native Android exact-source, and CodeQL.

Final coordinator evidence:
- GitHub App: 4785021
- Generation: 3
- Check run: 107885789455
- Verdict: PASS
- Merge claim: e19a8953-3a95-4ea5-9ec5-f08eb640e0df
- Merge SHA: 33009faf6c595fb0836ca4e405e86a0f248b8809
- Coordinator completion: verified
- Repository fence after completion: idle

## Durable operational lesson

Two coordinator recovery cases occurred during integration.

First, the branch advanced after decision-begin. Provider publication was rejected with LIVE_IDENTITY_MISMATCH but the publication fence remained held. Recovery verified that no coordinator check had been published, preserved the failed generation, released only the orphaned publication fence, and published a fresh generation against the current exact head.

Second, a refresh returned CHECK_PROGRESS_READBACK_MISMATCH after GitHub had already updated the coordinator check. Recovery verified provider state, released only the orphaned publication fence, replayed the identical generation, accepted the idempotent provider readback, and only then claimed merge.

General rule: provider writes and local publication-state transitions must be reconciled from provider readback before retrying or advancing merge state. Failed generations are preserved rather than erased, and completion is never inferred.

## Next safe implementation slice

1. Evidence inbox and source hashing.
2. Controlled ingestion adapters.
3. Deterministic reconciliation and exception creation.
4. Philippines rule-pack governance and tests using current authoritative sources and professional review.
5. Tax & Compliance command-center UI and persistent Pandora orchestration.
