
# Pandora Tax UI Discoverability — PR #706

Date: 2026-09-25
Repository: pandora-rvw-314296438-20260820/pandoras-box

## Verified problem

Tax Operating Core V1 was implemented and merged in PR #705, but Tax & Compliance was too easy to miss because access depended on navigating into the workspace section list.

## Correction

PR #706 surfaced Tax & Compliance directly on every enterprise workspace card and restored PLP as expanded by default. The persistent Tax & Compliance quick entry opens the existing tax workspace and reads live tenant-scoped readiness from pandora_tax_command_center_v1. Existing tax legal and professional approval boundaries were not weakened.

Exact PR head: 821a2c2283adb5fefd48d398b37f2fd2f2c62476
Merge commit: 432c0c68fd9be31fce3d12cb770b04172b04de97

## Verification

Required exact-head checks passed before merge:
- Pandora Node 24
- Windows Worker Contract
- Dependency Review
- Canonical release evidence
- Pandora Edge source artifact
- Pandora mobile exact-source gate
- PLP Pandora Enterprise Android exact-source

Dedicated PLP APK:
- Workflow run: 36086119914
- GitHub artifact: 10844460812
- Package: com.banataosystems.pandora.plp
- Version: 0.4.0-rc.14+21
- Size: 70,884,481 bytes
- APK SHA-256: f7ea78d1e7a7637e42cd201d089c85f43778a58fa29c811e2d803e2f7b407b37
- APK Signature Scheme v2 verified

Coordinator:
- Pandora coordinator / integration check: PASS
- Check run id: 107921585682
- Snapshot generation: 13
- Snapshot revision: gdrive-revision-772

## Durable lesson

High-value capabilities are not product-complete merely because their backend and deep workspace exist. They must be visible at the decision surface where the owner starts work. For Tax & Compliance, expose status and direct entry from Home/Overview while preserving the deeper dedicated workspace.

Verification should cover discoverability, not only backend existence and route reachability.

## Governance observation

At post-merge verification time, the coordinator state had not backfilled merged_sha/consumed_at even though GitHub had merged PR #706. Treat this as a coordinator reconciliation gap to repair separately; do not rewrite or downgrade the verified source/build evidence.
