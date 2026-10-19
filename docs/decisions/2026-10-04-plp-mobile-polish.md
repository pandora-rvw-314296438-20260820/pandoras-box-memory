# PLP mobile production-polish: owner decision and verified lessons

Date: 2026-10-04 (Asia/Manila). Namespace: real_life. Project: Pandora / PLP Enterprise.
Classification: user decisions plus provider evidence; implementation lessons are model conclusions tied to the evidence below. This source record is proposed for Memory review, not self-approved execution authority.

## Locked owner decision

Preserve the working PLP ivory/black/gold business workspace, navigation, drawer and contextual Pandora command layer. Do not replace it with a generic chat or rebuild it. The active workspace identity is Pueblo La Perla Boracay with Luxury Resort as its only subtitle; its shell identity must remain borderless. Individual operational pages have one contextual title beside the hamburger. Today uses RESORT STATUS in the former resort-name serif, dark, 21px, weight-500 treatment, not a bronze eyebrow. Removing duplicate headings must pull meaningful content upward, without overlapping navigation. New Admin panels must inherit the PLP design; the separate Admin duplicate is not authorization to redesign PLP.

Production trust: unknown/loading is not zero; test/mock/synthetic history must not appear as verified customer history. Parent Activity and its detailed feed must share one filtered source. Child Back returns to its originating parent. The command bar stays stable and contextual. Cached information must be labeled and must not turn an unconnected source into live truth. Do not slow the app with duplicate loads or startup-only work that belongs to an unopened page.

## Source and evidence

Canonical implementation PR: https://github.com/pandora-rvw-314296438-20260820/pandoras-box/pull/958
Branch: chatgpt/plp-production-polish-20261004.
Latest implementation candidate at this record: c5458eb82c882116c103b3a6aee82b62c60b9e70. This head was written and provider-readback verified; its full CI, merge, deployment, and physical-device acceptance are not asserted here.

Earlier tested checkpoint eec224c880e95e776b693e3b3f8c3f7137a6f9b1 passed Node 24 run 37155307823 and mobile UX run 37155307755, including the strict chat golden comparisons. The subsequent header-clearance/unknown-queue regression identified a remaining numeric zero in the queue badge and an overly broad test finder matching a retained parent title; c5458eb corrects those specific issues without reducing the unknown-is-not-zero assertion.

Supabase project jcyqixttuebxqqfkjonq has migration 20261003201314_plp_production_activity_isolation_v1 applied. The migration source is in PR #958. It excludes tagged test rows before feed pagination and preserves authentication, tenant-entry, and owner/admin guards. Raw test records were not deleted. A customer-context RPC verification attempt returned CLIENT_ENTRY_REQUIRED; that is not authenticated production acceptance and must not be bypassed to claim success.

The earlier merged owner-approved cube-menu change is PR #954, main commit 81ced6e3c900b978e28b09f6b44dd7125bbc1769. It changed the compact composer controls but left old screenshots. PR #958 did not change ask_pandora_screen.dart to satisfy those obsolete images. Provider artifact 11284244218 from run 37153683719 at fb0b0dfd84d167207e471e4bfc1e81361885ac08 supplied the reviewed captures. Archive SHA-256: b788937940864d859bfe4dfc8951645e7068ee454445804aedfb48a5b5edf686. Pixel inspection localized five 350-pixel differences and one 3,032-pixel difference to the approved composer controls. Six exact PNG baselines were reconciled; strict comparison was retained. Temporary importer run 37154947469 created content-addressed blobs only and its workflow was removed. No chat redesign, comparison tolerance, or test skip was introduced.

## Reusable implementation lessons

1. Use a lazy shell-owned, bounded activity read model. Coalesce concurrent reads, share it between summary and detail, preserve successful evidence on refresh error, and distinguish absent data from a verified empty list. Constructing the model must do no I/O. The new model tests cover these states, disposal, and production-row filtering.
2. Do not add Activity to the startup bootstrap. Read independent additive projections concurrently with timeouts; serialize only the room-operation merge that depends on both results. Coalesce overlapping bootstrap refreshes. This is an architecture change, not a measured physical-device performance claim.
3. Keep parent route pages in the navigator and guard page-removal callbacks against the current route key. Otherwise programmatic removal can pop the restored parent again. Bind contextual conversation state after navigation and rebuild routed pages from the latest workspace snapshot rather than a captured old map.
4. Preserve last loaded Team counts on refresh errors, not merely the initial counts passed by the parent. Queue labels and badges must obey the same unknown-data rule as metric cards.
5. Blind class/range string replacements previously created a duplicate class and unbalanced widget/class boundaries. Source-string assertions did not detect compilation failure. Require real Flutter analysis/tests, exact-head provenance, and production-widget journey assertions before reporting a fix as tested.
6. An outdated golden is not permission to revert an owner-approved design. Inspect the actual pixel differences and source lineage, update only reviewed baselines, and keep the strict test.
7. The GitHub App read path and Vault-backed write path are separate permissions. After a real App 403, use the existing guarded Vault transport on the canonical task branch, never a lookalike repository, main write, force push, or exposed PAT. The attempted extra Supabase helper function hit the project function-count limit; no plan/spend change or revival of a retired function was made.

## Limits and next acceptance

Documented, implemented, tested, built, merged, deployed, runtime verified, and production verified remain separate. Verify the latest exact head and run the authenticated continuous PLP journey, including unavailable sources, Activity Back, Team loading, drawer/keyboard/composer geometry, and Android system-bar contrast. Physical Redmi/Android performance and authenticated runtime acceptance were not obtained in this record. The Memory connector retrieval failed during this continuation; this GitHub record is a durable recovery source, not a claim that semantic Memory ingestion is healthy. Preserve history and supersede this record with newer provider evidence rather than deleting it.


## Verified convergence and delivery — 2026-10-04 06:29 Asia/Manila

Classification: provider evidence unless explicitly described as a lesson or limitation. This update supersedes the earlier candidate-status paragraph above without deleting its history.

### Repository and test outcome

Another authorized lane merged PR #960 as 130f8915dd78647dd2c5174ef752297fa166f171 while #958 was in progress. Provider tree comparisons showed #960 included the earlier visual correction and approved chat goldens, but not the later shared-state fixes. Closed #958 was not reopened. A scoped follow-up, PR #961, carried forward those missing fixes on the new main without overwriting its newer UI or touching Admin.

PR #961 was normally squash-merged at 2026-10-03T22:22:21Z as **1eca94fdcc5dad0dc10192a5aa9c74f03171c4d3**. Tested head: **f940a402553ee32865be5d1bd8d6c6498f49012e**. Provider readback verified both commits have the identical source tree **9a35c3173fcd24f025d4052067a7ac5269a24ba9**. The follow-up changed 11 scoped source/test/evidence files. It did not change the separate chat implementation, approved golden PNGs, Admin duplicate, dependencies, or CI configuration.

Exact-head results: Node 24 run 37157432203 succeeded; full Android/iOS validation run 37157432140 succeeded, including formatting, analysis, tests, Web build, Android build and iOS simulator build; mobile UX/golden run 37157432114 succeeded. CodeQL, Gitleaks, Trivy, source-contract and other required protected-branch checks were read back green before merge. No protection setting, bypass actor, or force update was used. CodeRabbit's green status was a skipped automatic review, not evidence of an independent review.

### Live Web delivery

Vercel production deployment **dpl_4kEHcxrzTc5i4D75oG7mC8HTdvuH** reached READY from exact merged SHA 1eca94fdcc5dad0dc10192a5aa9c74f03171c4d3. Project: prj_Y5rZVcq8xJVzHVt4uvfmg9wPvXMk. Deployment URL: mcpmaster-kry284uyu-mbanatao.vercel.app. Existing production aliases mcpmaster.vercel.app and pandoras-box-system.vercel.app were assigned successfully.

Both production aliases returned HTTP 200 for /pandora-web/pandora-web-release-manifest.txt with source_sha=1eca94fdcc5dad0dc10192a5aa9c74f03171c4d3, app_version=0.4.0-rc.14+21, flutter_version=3.47.0, and web_tree_sha256=3b910aad71a74717a202203995116b6fad5cca91d2c679729b41d50165abe46d. This establishes deployed source delivery, not an authenticated resort journey or a measured performance result.

### Android artifact and installed-app evidence

Dedicated PLP Android run **37157432082**, job **111303633264**, succeeded. Artifact **11287290117** contains the arm64-v8a PLP Pandora Enterprise APK, package com.banataosystems.pandora.plp, version 0.4.0-rc.14+21, size 71,476,849 bytes, SHA-256 **7cb7a019298580f8b549a3b09dac0f71565f7a7d1cb2901087fdf4aeeb050678**. Source is f940a402553ee32865be5d1bd8d6c6498f49012e, the exact source tree merged in #961. Downloaded archive and APK hashes were independently checked against the provider artifact/manifest.

Artifact **11286621151** records API-35 x86_64 installed-app acceptance: launch, drawn-window readiness, sign-in semantics, empty-submit validation, background/foreground, rotation, process restart and unauthenticated return to sign-in all passed; crash buffer was clear. Authenticated session restoration was explicitly not tested.

The ARM APK manifest is **validation-candidate**, production_release=false and production_signer_verified=false. It has a debug certificate despite release compilation. Do not call it a production-signed update, recommend uninstalling an existing app to force installation, or infer physical-device/local-model acceptance. No local model is bundled. Physical Android/Redmi performance, authenticated continuous PLP acceptance and offline Qwen acceptance remain unverified.

### Production-history precision

Applied and source-reconciled migration **20261003215433_plp_activity_test_marker_precision_v2** replaces broad substring suppression with explicit root/nested flags, bounded legacy test-source prefixes, [MOCK QA] markers and MOCK booking references. Both public activity functions were read back using the helper while preserving authentication and tenant-entry guards. Definition MD5s: business feed 754c951d867446c1e7342f5fe1463f9e; Pandora logs 3b092124e13d59d9febf76944bd2cd07.

Read-only aggregate inspection found 3 booking and 4 staff-task seed records: all seven raw rows remained stored, all seven were classified as test-only, and no production-eligible rows were manufactured. This is provider-table/filter evidence, not a customer-authenticated RPC acceptance. Non-persistent SQL assertions verified that a QA manager, Mockingbird PMS and a request for synthetic pillows are not test provenance. Matching Dart tests cover all ten root/nested flags, true encodings and legacy prefix/false-positive cases.

### Lessons promoted from actual failures

- Character-count-based hint wrapping is not width-safe. The merged conditional cap produced a real 42-pixel dock jump, 109px versus 67px, in the continuous journey. Capping every placeholder to one line fixed it while retaining multiline typed input. The strict cross-page rectangle equality and screenshot comparisons stayed enabled.
- Test isolation must use provenance rather than ordinary words. Broad matches for qa/mock/synthetic can hide real staff, suppliers or product descriptions. Share the classifier between summary, counts, detail, operational lists and the provider boundary; filter before pagination.
- Reconcile against a newer merged tree, not an old conversation's branch state. A successor can contain the visual work while omitting later state fixes. Preserve the new authoritative changes and carry only the missing deltas.
- A five-second GitHub HTTP transport timeout is not proof that the repository or Vault credential is unwritable. After confirming no branch publication, a transaction-local http.curlopt_timeout_ms=20000 recovered the bounded request. No credential was exposed, permanent database timeout changed, or protection weakened. Do not repeat ambiguous writes without provider readback.

Memory ingestion remains separate: this durable GitHub record is in review PR #143, not a claim that the failing Memory connector or semantic canonical ingestion has recovered. Keep future status updates evidence-backed and avoid saving polling events.
