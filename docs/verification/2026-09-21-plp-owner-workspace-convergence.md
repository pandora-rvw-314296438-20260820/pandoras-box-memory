# PLP Owner Workspace Convergence — 2026-09-21

## Verified outcome

Canonical system repository:
`pandora-rvw-314296438-20260820/pandoras-box`

PR: #654

Final PR head:
`663c89ca6416922a916dcdc0de717ee6ab861008`

Merged main SHA:
`4c0f4369f7b92be632bf403170dadcad8e7fc1c3`

Provider readback confirmed PR #654 merged, `main` points to the merge SHA, and the merged PLP navigation source contains the required owner-workspace hierarchy.

## Required PLP navigation state

PLP Boracay → Owner workspace is expanded by default and contains:

Home · Overview · Operations · Vision · Guest Experience · Team & Access · Revenue · Needs You · Activity · Settings

The separate BUSINESS section is absent. Recent chats and System / Developer remain separate.

## Failure and correction

A previously correct source state at `46f618f9996f58816c4ec82f598ad34d7d708c84` was later regressed on the active PR branch: BUSINESS returned, the owner workspace was collapsed, Vision was removed, and Guest Experience was renamed.

The correction restored the intended drawer hierarchy at the current branch head rather than treating the obsolete SHA as completion evidence.

Additional review findings surfaced during protected convergence and were repaired before merge: source-health key mismatch, command-dock accessibility semantics, local-AI generation stop ordering, stale warm-failure state, CI inference patch coverage, tenant snapshot ownership integrity, and inactive-room occupancy counting.

The already-applied PLP data migrations required a forward corrective migration rather than editing historical source only. Live Supabase readback confirmed the composite property/organization foreign key and corrected active-room occupancy projection.

## Verification evidence

Protected exact-head checks were green before merge, including:

- Exact source / Flutter / iOS
- Exact source / Flutter / Android
- Exact source / PLP native Android
- node24
- Dependency review
- Windows worker contract
- canonical-release-source-contract
- Engineering toolchain checks
- Gitleaks
- Trivy filesystem
- actionlint and ShellCheck
- edge-source-artifact

All PR review threads were resolved.

Coordinator protection required `Pandora coordinator / integration`. A generation-1 PASS was published for the exact PR head against authoritative coordinator snapshot generation 9 (`gdrive-revision-755`), producing check run `106152538266`. The coordinator merge fence was claimed, the provider merge completed, and the fence was released after GitHub readback.

## Durable lessons

1. Do not report a UI/navigation change as complete from an earlier SHA after the active branch has moved. Re-read the current PR head and assert the requested state there.
2. A correct historical commit is evidence of prior work, not evidence of current branch truth.
3. For already-applied Supabase migrations, repair production with a forward migration and separately correct historical source for clean replay.
4. Treat branch protection as part of the implementation path. Resolve review threads and every required producer, including coordinator checks, instead of bypassing or declaring completion early.
5. Final completion evidence must include provider readback of the merged PR, the exact main SHA, and the requested source assertions on that merged SHA.
