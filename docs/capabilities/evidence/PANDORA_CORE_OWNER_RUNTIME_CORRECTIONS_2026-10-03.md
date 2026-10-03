# Pandora Core owner runtime corrections — 3 October 2026

Status: pending review. This is a curated continuation record, not canonical Memory approval or a production-readiness attestation.

## Authority and prior boundary

OWNER DECISION: the owner requested continuation of the Pandora Core owner/operator system through actual CI, provider readback, deployment and owner/customer journeys. Customer accounts remain separate from Pandora's company operations. The persistent Pandora composer and explicit tenant context must remain intact.

VERIFIED FACT: this correction lane starts from product main `593d8f5db34da6fc727c0449e807174cd3d9835a`. The preceding implementation and source-only migration-history correction are retained in product PRs 944 and 945 and the earlier evidence document in this Memory PR. The currently serving canonical deployment at this checkpoint remains `dpl_9CTGq1Qn8YWzppZ5DcR3UAkWE9oT`.

Product PR: https://github.com/pandora-rvw-314296438-20260820/pandoras-box/pull/946

At 13:56 UTC, product main is unchanged. The bounded task branch head is `68e38909ab1a60721363d32f994c6f1695e6ada8`; 26 changed files were read back byte-for-byte. No direct-main or forced update was used. Active overlapping PLP changes were inspected and their separate test-list and session-evidence hunks were preserved.

## Actual owner failures and implemented corrections

The actual signed-in owner journey exposed poor contrast in enabled Core controls and invitation menus, a platform operator presented as a customer owner, false authorization demands for stale credentialless-provider evidence, obsolete Operations markers presented as actionable approvals, inappropriate model-catalog rows, and a correct attention answer hidden by automatic navigation.

The correction uses Pandora's existing dark theme and separate PLP content theme, preserves the existing authorization RPC's explicit operator classification, clears Team data after authorization revocation, and retains inspection answers with an explicit navigation action and accessible semantics. Restored history preserves only safe inspection metadata. Drawer Back and late responses preserve the exact tenant boundary.

The database correction reuses canonical provider/account/capability/scopes/receipt/Vault-marker evidence and the actual effective conversational-model predicate. Stale or incomplete evidence stays unverified. Stopped-pilot markers are not revived, and no model probe, credential change, membership grant or routing-policy change was performed.

PROVIDER EVIDENCE: the owner's PLP onboarding verification completed at 12:07:48 UTC, audit 20116, operation receipt `8444d425-53e2-484b-9767-bd44a173f33a`. Existing identity, administrator and capability checkpoints were verified; connections, routing, limits, billing and go-live stayed pending. The action did not invite a user or grant access.

PROVIDER EVIDENCE: the attention command at 12:30:20.731 UTC used `pandora_core / deterministic-core-owner-v1`, zero tokens and no model-run record. The correct answer persisted, with a completed Activity job, despite the frontend navigation defect.

The actual owner lacks customer membership for PLP. Workspace entry remained disabled; Manage Client was a separate authorized operator view. No customer membership, MFA state or session was fabricated for acceptance.

## Database exact readback

The single forward migration was applied once:

- Project: `jcyqixttuebxqqfkjonq`.
- Version/name: `20261003124340_pandora_core_owner_decision_health_v1`.
- SQL bytes: 23,787.
- SQL SHA-256: `8de51dd0108c38487f5828c2c516503e2d1077d943545d5eed54cf7744560e7d`.

Six prior-body/ACL fences passed before application. At 12:44:17.713263 UTC, all eight expected function observations matched, including security mode, ACLs, volatility and search paths. The two new helpers are private SECURITY INVOKER functions without anon, authenticated or service-role EXECUTE.

No table, RLS policy, index, credential, account membership or routing policy changed in this migration. Post-change advisors retained the same 311 security and 726 performance finding identities: zero additions and zero removals. These are inherited findings, not an all-clean claim.

At 13:41:10.667518 UTC, all 933 source/provider migration version and name pairs matched. The latest provider statement hash matched the exact source SQL. No migration was reapplied to align history.

## Test and CI evidence

The source correction passed 4,361 Node tests with one existing optional skip and all 52 worker tests. Focused SQL verification passed 115 tests, and the complete 933-migration replay passed with `provider_equivalence=false`.

All 134 focused Flutter tests passed across 16 files. The 13 changed Dart/source-test files were byte-identical before and after testing. Analyzer output was zero errors, three pre-existing Ask warnings and 23 informational findings, exit 1. The same warnings were reproduced on exact base 593. Supported Flutter analytics suppression was used after an initial automatically rejected tooling-telemetry attempt; the interrupted run was excluded.

Exact head `8945f15190212e8051c6ff14857ede2cf3862a99` passed the six required checks, the canonical Deno check for 19 entrypoints, full Flutter validation with 833 passing tests, web build, Android debug/profile builds and iOS validation. Its PLP installed-app job hung; these successes were not substituted for that missing acceptance.

The bounded Memory workflow needed the existing locked dependencies before the new compiled API test could run. Adding `npm ci --ignore-scripts` fixed the observed missing-TypeScript failure without removing tests.

## Live API correction before promotion

PROVIDER EVIDENCE: actual production Operations events returned 503 repeatedly around 12:11–12:12 UTC, and the owner Memory POST returned 503 at 12:24 UTC. The earlier empty error-scan window is superseded by these later real-user failures.

The source fix preserves native ESM loading through Vercel's emitted CommonJS entrypoints with fixed traced module paths. Regression tests execute the compiled handlers, including a run with synchronous require(ESM) disabled.

An unpromoted production-target candidate was built with automatic custom-domain assignment disabled:

- Deployment: `dpl_BmWXvgRW5i4gN6x5z5iKB9kc3JWc`.
- Source: `accf27adfdf8b833464c2f6022860f8eaaeff67b`.
- URL: https://mcpmaster-kywny7xs5-mbanatao.vercel.app/
- READY and canonical-target separation read back at 13:52:08.964138 UTC.
- Served manifest web SHA-256: `7a23a94b2f597fb3ccf93695cfc7dd5c25cdb4f0aa7dc28d663746fde8c6f69e`.
- Effective framework/build: Express, Node 24.x, canonical Node and Flutter web build script.

At 13:52:51.739208 UTC, actual candidate endpoints returned the expected responses:

| Request | Status | Exact error |
|---|---:|---|
| Operations events GET | 405 | INFERENCE_METHOD_DENIED |
| Operations events POST without credentials | 401 | INFERENCE_AUTH_REQUIRED |
| Owner Memory POST without credentials | 403 | OPS_MEMORY_OWNER_AUTH_REQUIRED |

Health returned 200. These prove the emitted endpoints load and enforce their unauthenticated boundary. They do not prove a signed-in owner or customer journey.

The build-time Memory canary used Vercel workload OIDC, returned available context and retained a delivered/readback-matched pending-review outcome. `canonicalMemoryWritten=false`; performance history remained insufficient and no paid model probe was requested.

The newer 68e head changes only the PLP workflow relative to accf. The API and Flutter source bytes are unchanged. Final-head CI and a merged-source deployment still require their own evidence.

## Android failure diagnosis

PROVIDER EVIDENCE: an inherited unbounded `adb wait-for-device` occurred before the boot deadline. Earlier PLP jobs waited until their 80-minute job cancellation rather than reporting why the emulator exited.

The correction bounds readiness calls, checks process liveness, requires both Android boot completion and a responsive Package Manager, adds an outer step timeout, and preserves emulator diagnostics. Local injected process-exit and Package Manager recovery checks passed; an independent same-family agent review found no blocker. This is not different-vendor or Android-runtime acceptance.

The next actual run, `37126796923`, job `111213676819`, failed between 13:48:40 and 13:48:43 UTC with exit 40 and Android emulator 37.2.12.0. Retained stderr identified an unknown AVD name and a missing registry file in the emulator's default directory. Diagnostic artifact `11275478880` is 620 bytes with SHA-256 `384aae3a9599f9dd6b7e67093baa53f81b6aec39484a07234d3e0f826b2e0a82`.

The current workflow shares an explicit AVD/user/emulator directory across SDK tools, sets the AVD path and checks registry/discovery before launch. The real retry is still running at this checkpoint. No installed-app acceptance is asserted.

Official tool references: https://developer.android.com/tools/variables and https://developer.android.com/tools/avdmanager

## Session policy and remaining evidence

VERIFIED FACT: canonical commit `2704ec3e4b3e267eedc4c48913aed6c64fc410d5` deliberately removed Core web session persistence. Core uses `EmptyLocalStorage`; the deliberate refresh returned to sign-in. This source history is not a newly discovered owner approval for that UX. The correction preserves the security policy and stores no credential. Final authenticated verification requires a new secure sign-in after the final deployment is loaded.

The corrected signed-in owner journey, a real customer session with deliberate cross-tenant denial, and physical Android release acceptance remain open. No production signing, physical install/launch, local-model behavior or production readiness is claimed from an APK build or emulator alone.

MEMORY LESSON — pending review: compiled entrypoint tests, actual user navigation and provider readback cover different failure boundaries. A READY deployment, healthy generic endpoint, passing service-module tests or old zero-error interval cannot stand in for the real owner route. A CI timeout must retain diagnostics and bound discovery itself, not merely the readiness loop after discovery.

## Recovery and supersession

Keep the serving 593 deployment as the assessed Vercel rollback target for the eventual promotion. This additive SQL correction has no data migration to undo; database recovery uses a reviewed forward fix and preserves tenant data, grants, audit and migration history.

This record preserves earlier historical evidence while superseding any inference that the prior build/READY state established actual owner acceptance. It does not change approved Memory, approve an access request, restart a stopped pilot or authorize spending. Later final-source deployment and journey receipts must be recorded as a subsequent, explicit observation.

