# Memory Migration Source Parity — 2026-09-01

## Final source state
- Live applied migration versions: **85**
- Replayable exact source migrations: **73**
- Sanitized historical migration anchors: **12**
- Missing applied migration versions: **0**
- Production schema mutation/replay during recovery: **none**

## Exact source
- Base signed main: `9f9a05b7880f87ea06390846abaa59e93eb7414e`
- Source commit: `24c8ff1c1f9f51ac6194e2f585e0c706feb8d04f`
- Source tree: `58dcbd11f807b8c5a6a148500713590bfbc0f603`
- Migration subtree: `9c3570fb8a9eb833ff3ec23d8370815410a228b2`

## Security adjudication
- The 12 formerly quarantined versions were re-scanned for direct credentials, PII, token/JWT/private-key signatures, credential-bearing URLs, and unclassified high-entropy literals.
- Historical credential/provider literals were not copied into Git.
- Each sensitive history is represented by a non-replayable sanitized anchor containing only version/name identity and explicit security disposition.
- Provider statement counts and hashes are retained in `MEMORY_MIGRATION_SANITIZED_ANCHORS_2026-09-01.json`.
