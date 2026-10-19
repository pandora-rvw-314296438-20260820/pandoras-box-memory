# Master audit status — 2026-10-10

Observed: 2026-10-10T07:30:00+08:00 (Asia/Manila)  
Classification: **master audit canonical status record**

Status vocabulary: PROPOSED (PR open), TESTED (local/CI evidence), MERGED (on main), DEPLOYED (provider shows it live), PROD-VERIFIED (readback against production proves behaviour), OBSERVED (fact read from GitHub or repository state, not production).

> **Notice:** Nothing in this audit is production-ready-claimed; no production DDL, deploys, or auth changes were made.

## Canonical authority

- Canonical repositories: `pandora-rvw-314296438-20260820/pandoras-box` and `pandora-rvw-314296438-20260820/pandoras-box-memory`.
- Blacklisted owners: `banataosystems/*` and `mbanatao/*` are blacklisted (historical evidence only, never current authority).

## Baseline

- `pandoras-box` `main` commit `a75a052c` (PR #981) — **MERGED**
- Supabase production project `jcyqixttuebxqqfkjonq`: 961 ledger versions, latest `20261009070802` — **PROD-VERIFIED**

## Supabase Preview root cause and fix

- Preview failure: Failing on every `main` push touching `supabase/` since at least 2026-10-04 (`735ca390`) through `a75a052c`: "Remote migration versions not found in local migrations directory." — **OBSERVED**
- Root cause: 25 versions applied to production with no repository file (`20261003190317` `pandora_direct_tenant_owner_access_v1`; 23 PayPal/PLP billing migrations `20261008093605`..`20261008202133`; `20261009070802` `plp_entitlement_v1`). Repository also had `20261009090000_plp_entitlement_v1` (byte-identical to prod `20261009070802`, misnumbered) and `20261009070000_plp_billing_live_paypal_closure` (never applied; differs from live `change_plan_v1`) — **PROD-VERIFIED**
- Parity fix candidate: PR #1009 (branch `grok/supabase-migration-parity`, head `6784f4f9`, was `de062f23`) adds exact prod bytes (md5/sha256 verified), renames, retires unapplied file, adds receipt and parity test — **PROPOSED**
- Fix candidate testing: Local replay 961 OK, parity test 5/5; CI: all 6 required checks green — **TESTED**
- Integration Edge deploy freeze: A second commit freezes integration Edge deploys: `supabase/config.toml` now declares the 11 previously undeclared function folders (`pandora-connections-broker`, `pandora-coordinator-gate`, `pandora-facebook-signup-hook`, `pandora-github-uiux-convergence-20260828`, `pandora-google-workspace-oauth`, `pandora-intelligence-review-attestation`, `pandora-intelligence-router`, `pandora-meta-oauth`, `pandora-operations-runtime`, `pandora-preview-content`, `pandora-source-files`) with `enabled = false`, lists them in `supabase/functions/DEPLOY_FROZEN.json`, and a test asserts every deployable folder is disabled. Expected effect of merging #1009: migrate step applies 0 migrations (961/961 parity); Edge deploy step deploys nothing (26 of 26 deployable folders disabled). Status: PROPOSED + TESTED (local config tests 58/58). Still NOT MERGED; owner approval required. Without that commit, merging would have deployed 11 functions from main, including 2 not in production (`pandora-facebook-signup-hook`, `pandora-meta-oauth`) while production is at the 100-function ceiling — **TESTED**
- Pipeline unblock gate: PR #1009 is NOT MERGED: merging re-enables the Supabase "deploy to production" pipeline (migrate -> edge functions), which has been blocked since 2026-10-04 -> owner approval required. PR-level Supabase Preview is "skipped" because per-PR preview branches are disabled in the integration — **RECOMMENDATION**
- PR #957 (draft, `20261003190317` source): superseded by #1009; its file is byte-identical — **PROPOSED**

## Security/advisors

Production readback 2026-10-10, nothing applied:

- `auth_leaked_password_protection`: disabled in Supabase Auth settings -> owner approval required — **RECOMMENDATION**
- `extension_in_public`: `pg_net` 0.20.4 (not relocatable; move = drop/recreate) -> owner decision, recommend accept-risk/defer — **RECOMMENDATION**
- `function_search_path_mutable`: `private.pandora_plp_billing_money(bigint)` -> fixed in PR #1010 (draft, DO NOT MERGE without approval) — **PROPOSED**
- Search path fix testing: PR #1010 local evidence: 962 migrations replayed OK, 11/11 tests pass — **TESTED**
- `authenticated_security_definer_function_executable`: 98 functions, all search_path pinned, none anon-executable, all gate on `auth.uid()`/helper authority -> intended RPC surface, no change — **PROD-VERIFIED**
- `rls_enabled_no_policy`: 215 (INFO): fail-closed service-role tables, intended — **PROD-VERIFIED**
- Performance (`auth_rls_initplan`): 21 policies -> fixed in PR #1010 — **PROPOSED**
- `auth_rls_initplan` fix testing: PR #1010 local evidence: 962 migrations replayed OK, 11/11 tests pass — **TESTED**
- Performance (`multiple_permissive_policies`): 9 `enterprise_vision_*` tables -> optional follow-up — **RECOMMENDATION**
- Performance (indexes): unindexed FK 440 / unused index 263 informational — **PROD-VERIFIED**
- Edge Functions: prod has 100 functions (provider ceiling), many one-off ops functions (e.g. `*-vault-*`, `merge-pr*`) with `verify_jwt=false` -> recommended cleanup review (owner approval required; deletion is prod change) — **RECOMMENDATION**

## Deployment parity

Vercel read-only readback (no deploys were made):

- `enterprise` project (`enterprise-omega-five.vercel.app`): serves `dpl_EC91eAEkyJ8kcowzfmGvp1YYkxYg` built from main `d21d6c55`; latest production-target enterprise deploys are ERROR (e.g. at `0e10cbeb`) — **DEPLOYED**
- `mcpmaster` project (`mcpmaster.vercel.app`, `pandoras-box-system.vercel.app`): serves `dpl_8PeA3Bee7fgjkN6denBDYiy94wHh` from main `82f664c4` (old) — **DEPLOYED**
- Deployment parity drift: main `a75a052c` is 6 commits ahead of `d21d6c55` (#1008, #999, #982, #979, #983, #981) -> `DEPLOYED != MERGED`; no deploys were made — **PROD-VERIFIED**

## PR disposition

Recommendations, no action taken:

- PR #1009 parity: merge after owner approval of the pipeline unblock — **RECOMMENDATION**
- PR #1010 advisor hardening: merge after #1009 + owner approval (applies DDL to prod) — **RECOMMENDATION**
- PR #957: close as superseded by #1009 after #1009 merges — **RECOMMENDATION**
- PR #950 (46 files, UX responsive check failing): rebase + fix failing check, or close — **RECOMMENDATION**
- PR #867: migration `20261001093000` is older than prod head (out-of-order) and node24 + PLP Android failing -> renumber/rebase or close — **RECOMMENDATION**
- PR #840: migration `20260930101500` collides with an existing version (`pandora_universal_core_registry_rls_v1`) -> must renumber or close — **RECOMMENDATION**
- PR #793: conflicting, migration `20260921110000` out-of-order, touches `apps/pandora-mobile` (Order 2 territory) -> close or hand to billing worker — **RECOMMENDATION**
- Billing PRs #1000-#1007, #991, #989, #985: all CLOSED 2026-10-09 (~03:17-03:18 Asia/Manila 10-10), head branches retained; Billing UI owned by Order 2 (`grok/plp-conversion-checkout`) — **OBSERVED**

## Governance findings (blacklisted references)

- `pandoras-box` `docs/status/OPEN_PR_TRIAGE.json`: `"repository": "banataosystems/Pandoras-box"`, snapshot 2026-08-23 (base `5a630893`). Its PR numbers refer to the blacklisted origin -> classify as historical snapshot; must not be cited as current triage. Consumed by `src/projectos/canonical-status-provider.js` and two tests (counts only) — **OBSERVED**
- `pandoras-box` `docs/supabase/recovery/jcyqixttuebxqqfkjonq/MIGRATION_PARITY_REPAIR_PLAN.md`: names `banataosystems/Pandoras-box` as canonical -> stale — **RECOMMENDATION**
- Vercel team slug is `"mbanatao"` (hosting account) -> note only — **OBSERVED**

## Tests

- Candidate `de062f23` (#1009), Node 24.21, box TZ Asia/Manila: `npm run check` PASS — **TESTED**
- Candidate `de062f23` (#1009), Node 24.21, box TZ Asia/Manila: `npm test` 4406 tests: 4402 pass, 3 fail, 1 skipped. The 3 failures are timezone-dependent (`pandora-chat-request-admission` `current_date`, `pandora-core-automation-titles` and `pandora-m2-008-activity-history-db` timestamp rendering) and pass 36/36 under `TZ=UTC` (CI runs UTC; CI node24 green on #1009) -> test fragility, not a regression — **TESTED**
- Flutter 3.47.0 (same as CI) on candidate de062f23, apps/pandora-mobile: flutter pub get OK; flutter analyze: 0 errors, 12 warnings, 164 infos (exit 1, pre-existing; #1009 changes no apps/ files); flutter test test/app test/features/enterprise: 304/304 pass; full flutter test: 940 pass, 23 fail = 21 golden pixel-diff failures (Linux rendering vs committed baselines) + 2 test/architecture/foundation_source_guard_test.dart failures (bootstrap file 93 lines vs limit 80; a feature widget imports supabase_flutter) — pre-existing on main, not caused by #1009 — **TESTED**
- Device/E2E tests: NOT PERFORMED (no device available) — **NOT PERFORMED**

## Blockers and approvals needed

- Owner approval required to unblock the Supabase "deploy to production" pipeline before merging PR #1009 (pipeline blocked since 2026-10-04) — **RECOMMENDATION**
- Owner approval required before applying production DDL via PR #1010 (`private.pandora_plp_billing_money` search path and 21 RLS initplan policies) — **RECOMMENDATION**
- Owner approval required to enable `auth_leaked_password_protection` in Supabase Auth settings — **RECOMMENDATION**
- Owner decision required on `extension_in_public` `pg_net` 0.20.4 (recommend accept-risk/defer) — **RECOMMENDATION**
- Owner approval required for Edge Functions cleanup review (production at 100 function provider ceiling; deletion is a prod change) — **RECOMMENDATION**
- Vercel production deployment pipeline blocked with ERROR state on enterprise project; main `a75a052c` is 6 commits ahead of deployed `d21d6c55` — **PROD-VERIFIED**

## Next actions

- Obtain owner approval for Supabase pipeline unblock and merge PR #1009 — **RECOMMENDATION**
- Monitor post-merge Supabase production deployment (migrate -> edge functions) for PR #1009 — **RECOMMENDATION**
- Obtain owner approval for PR #1010 and merge after #1009 merges (applies DDL to prod) — **RECOMMENDATION**
- Close superseded PR #957 after PR #1009 merges — **RECOMMENDATION**
- Resolve open stale/failing PRs per PR disposition: rebase + fix failing check or close #950, renumber/rebase or close #867 and #840, close or hand #793 to billing worker — **RECOMMENDATION**
- Conduct owner review of Auth leaked password protection and 100 Edge Functions (unverified JWT ops functions) — **RECOMMENDATION**
- Investigate and resolve Vercel enterprise build errors at `0e10cbeb` to restore deployment parity with `main` `a75a052c` — **RECOMMENDATION**
- Fix the 2 source-guard violations and decide golden baseline platform — **RECOMMENDATION**
