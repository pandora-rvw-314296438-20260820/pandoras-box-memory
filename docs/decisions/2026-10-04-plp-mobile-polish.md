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
