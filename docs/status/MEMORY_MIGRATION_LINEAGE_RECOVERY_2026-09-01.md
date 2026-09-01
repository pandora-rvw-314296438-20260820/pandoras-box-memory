# Memory Migration Lineage Recovery — 2026-09-01

## Checkpoint

This checkpoint restores a conservative-safe legacy migration tranche from the live Memory Supabase migration ledger into the canonical `pandoras-box-memory` recovery branch without replaying or mutating production.

- Memory Supabase project: `ivmvufhcsezyhczzondn`
- Live applied migrations: **85**
- Exact/replayable migration source now present: **60/85**
- Applied source still absent: **25/85**
- Pending unapplied migration files: **0**
- Source recovery commit: `ed971e6853ea5b0c18a4998476283f531c3920a0`
- Source recovery tree: `e721deece04888fc1f985f109e45f42d3de80aa6`
- Exact migration subtree: `837f591b26c5e3ed93d7b0970c2e1b67ed77d0d6`
- Base `main` at source checkpoint: `9da819876037aa6427e745189f7b3949747b3bef`
- Production schema mutation: **false**
- Production replay authorized: **false**

## Conservative legacy boundary

The 52 pre-Vault applied migrations are frozen under the stronger conservative provider classification:

- candidate-safe: **40**
- quarantined: **12**
- candidate-safe restored in this checkpoint: **27**
- candidate-safe still pending: **13**

Provider-bound manifest evidence:

- full legacy manifest: `cd39ac8230a3644f3ff028471fb2b2874cd0050a8a4513d02f26d5ef6de73e6a`
- safe manifest: `c12bfeadb8753524d22020d7d4d82c0d5f1d6b4b1fc4ebff6e880a9d552a07f6`
- quarantine manifest: `9452c5cd5971011da16ff9c23510286f7e8e4fb62db1601f337bc4700476eb1c`
- restored-safe manifest: `1e2afc954228338fc78144367a9ff84951c6e583283f0adf376adb0ad1969986`
- remaining-safe manifest: `d530c2c268d771ae2973de0a485c53bd5239d3a31cbd5d6f0a647e145c1184df`

The 12 quarantined versions remain absent from Git source:

`20260623006600`, `20260627040000`, `20260731111248`, `20260801163126`,
`20260803111852`, `20260807055209`, `20260807081540`, `20260807082820`,
`20260807084620`, `20260807085215`, `20260807085935`, `20260807090844`.

No quarantined SQL body is recorded in this evidence artifact.

## What the gate proves

The dedicated lineage gate independently verifies:

1. the exact `supabase/migrations` Git tree;
2. all four previously known exact migrations;
3. all 27 restored legacy files by byte count, SHA-256, and Git blob SHA-1;
4. the provider-derived restored-safe manifest;
5. absence of every quarantined version;
6. the existing 29-file post-Vault replayable manifest;
7. the exact 60-file source set with no pending duplicate;
8. arithmetic `60 exact + 25 absent = 85 applied`;
9. that production mutation and replay remain disabled.

## Remaining open loop

The next migration-lineage action is to restore the remaining **13 conservative-safe** legacy migrations in bounded, byte-verified Git tranches. After that, the **12 quarantined** migrations require sanitized adjudication before any source reconstruction is considered.

This checkpoint does not claim Memory production source/runtime parity, deployment parity, or Phase 2 closed-loop production verification.
