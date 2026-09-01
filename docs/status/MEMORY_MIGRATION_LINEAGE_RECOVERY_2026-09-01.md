# Memory Migration Lineage Recovery — 2026-09-01

## Checkpoint

This checkpoint restores a conservative-safe legacy migration tranche from the live Memory Supabase migration ledger into the canonical `pandoras-box-memory` recovery branch without replaying or mutating production.

- Memory Supabase project: `ivmvufhcsezyhczzondn`
- Live applied migrations: **85**
- Exact/replayable migration source now present: **55/85**
- Applied source still absent: **30/85**
- Pending unapplied migration files: **0**
- Source recovery commit: `e25f0dca1c67d0898efd0b05ec36c573a34ec064`
- Source recovery tree: `75b1c5e00e9f4d5bd54fbf2a84af9f4f25bebfa0`
- Exact migration subtree: `037b0f22dd02253ca33a19ca831533126bf1502f`
- Base `main` at source checkpoint: `9da819876037aa6427e745189f7b3949747b3bef`
- Production schema mutation: **false**
- Production replay authorized: **false**

## Conservative legacy boundary

The 52 pre-Vault applied migrations are frozen under the stronger conservative provider classification:

- candidate-safe: **40**
- quarantined: **12**
- candidate-safe restored in this checkpoint: **22**
- candidate-safe still pending: **18**

Provider-bound manifest evidence:

- full legacy manifest: `cd39ac8230a3644f3ff028471fb2b2874cd0050a8a4513d02f26d5ef6de73e6a`
- safe manifest: `c12bfeadb8753524d22020d7d4d82c0d5f1d6b4b1fc4ebff6e880a9d552a07f6`
- quarantine manifest: `9452c5cd5971011da16ff9c23510286f7e8e4fb62db1601f337bc4700476eb1c`
- restored-safe manifest: `2f0cf1f7a573d680f0bc42cff7d6f195024cb9ce73c9c4bd38b73ffb25dacc6d`
- remaining-safe manifest: `6502acd5688f9e0bf46205894e50f6247a6aae9c5864057088cbda2a26b5fa0b`

The 12 quarantined versions remain absent from Git source:

`20260623006600`, `20260627040000`, `20260731111248`, `20260801163126`,
`20260803111852`, `20260807055209`, `20260807081540`, `20260807082820`,
`20260807084620`, `20260807085215`, `20260807085935`, `20260807090844`.

No quarantined SQL body is recorded in this evidence artifact.

## What the gate proves

The dedicated lineage gate independently verifies:

1. the exact `supabase/migrations` Git tree;
2. all four previously known exact migrations;
3. all 22 restored legacy files by byte count, SHA-256, and Git blob SHA-1;
4. the provider-derived restored-safe manifest;
5. absence of every quarantined version;
6. the existing 29-file post-Vault replayable manifest;
7. the exact 55-file source set with no pending duplicate;
8. arithmetic `55 exact + 30 absent = 85 applied`;
9. that production mutation and replay remain disabled.

## Remaining open loop

The next migration-lineage action is to restore the remaining **18 conservative-safe** legacy migrations in bounded, byte-verified Git tranches. After that, the **12 quarantined** migrations require sanitized adjudication before any source reconstruction is considered.

This checkpoint does not claim Memory production source/runtime parity, deployment parity, or Phase 2 closed-loop production verification.
