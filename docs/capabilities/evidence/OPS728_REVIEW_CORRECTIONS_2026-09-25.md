# PR #728 independent-review corrections

Evidence classification: tested source correction; independent review/merge/release still pending.
Recorded 2026-09-25 by ChatGPT OPS-ROUTER-20260925.
Repository: pandora-rvw-314296438-20260820/pandoras-box.
Operations Room: issue #714; continuation ACK comment5832042729; corrected-source handoff comment5832297702 on PR #728.

## Source and actual review

Original head: 42d6c3175e1f338fa90d320211a72b20cc63ae39.
Base: 6f20780765001d1a90ee31800a3948d043551afa.
Corrected head: 8cf811e2b3ce1fe4c164437868793fb84cf9cf3b.
Corrected tree: 5ab7d679049209ebfdb63c511b2bc542b15f372b.
Independent CodeRabbit review: 5317324772 / PRR_kwDOUDKgic8AAAABPO_v5A, COMMENTED at 2026-09-25T11:56:53Z; five actionable findings. COMMENTED is not a qualifying APPROVED review.

Five reviewed issues fixed inside the original PR's source area:
1. Main push workflow now watches verification-profile registry changes.
2. Supabase store preserves bounded OPS_* business error codes separately from SQLSTATE.
3. Full-project graph planning is no longer limited to the 5000-row intake batch; intake retains its bound.
4. Owner cancellation terminalizes lease-free queued/handed_off/verifying work, without discarding active ownership.
5. SQL independently enforces JSON numeric types, trimmed/control-free text including Unicode whitespace, duplicate rejection and exact source objects, consistent with JS task validation.

## Executed tests

25 new cases. The expanded 47-case DB suite first reproduced 23 failures with24 passes, then passed47/47 after correction. Two new cases already passed on the original code; they are retained as positive/control coverage. Full repository:2137/2137. Worker suite:52/52. The25 new cases are included in2137, not additional unique tests. Full npm run check passed, including source migration replay and Edge/type checks. No tests were silently skipped in these counts.

Authorized isolated RDP workspace: C:/Pandora/ops-upgrade-20260925-1000, existing SSM coding node i-0640ad78439133887 in ap-southeast-1. ChatGPT authored all corrections. No new compute was provisioned.
Actual SSM receipts: baseline5b67b339-9632-4360-9bd9-3d17fe4befd4; fixes/tests0d1f700a-5b3e-4aed-9b73-266a0812b5ab; fullcheck/tests5fa6f684-8394-4d07-8a82-a85645e6f8b8; exact checkpoint readback f050dbd1-901d-4c76-a3fd-5c904db5d2f2.

Six source file digests were computed from tested RDP bytes. Exact existing GitHub base content was patched through the already-approved server-side Vault Github_supabase broker only when all six resulting SHA256 values matched the tested bytes. Tree and commit creation returned201; nonforce ref update200. A subsequent public canonical Git fetch returned the corrected head, zero diff and matching tree; the isolated workspace is clean.

## Recovery lessons

A temporary optional source-upload command was blocked by tool safety checks and was not retried or disguised. No S3 source export from that command ran. The reduced workflow avoided that upload entirely: obtain non-secret local hashes and apply reviewed text patches to canonical GitHub content with exact-hash checks. No temporary/master credential was exported or recorded.

SSM API operation names in this connector must use PascalCase; lower-case operation failed before execution. SSM comments must be at most100 characters; an overlong comment failed validation before execution. PowerShell output redirection produced UTF16 logs; BOM-aware decoding was necessary to read actual counts. These are observed transport/tooling lessons, not universal claims about every AWS or shell interface.

The existing required one-approval/last-push/thread-resolution/check gates were never disabled, bypassed or reconfigured. A new CodeRabbit review request was sent after publication; the provider returned rate limited, not a completed fresh review. No approval was manufactured and no blanket resolve/approve command was used. Native coordinator read returned HTTP200 with null state for728, so no coordinator PASS or merge claim exists at this observation.

## Explicit non-claims

No merge, production Supabase migration, new Edge deployment, Vercel promotion, successful Antigravity review, new emulator acceptance or physical-device acceptance is claimed in this correction pass. Earlier82/2112/52 tests remain historical evidence for the old head and are not used to certify the new head. Current-head CI and independent review must be read back before release.

## What Pandora should learn

Validate privileged SQL inputs independently of JS clients; keep intake-size limits separate from total-project graph limits; make cancellation terminal at each lease-free lifecycle state; preserve bounded domain error identity; and bind tested bytes to exact canonical source before requesting review. A green test suite or comment-only review must never be promoted into a missing formal approval, coordinator gate or deployed-success claim.


## Final recovery, independent review, coordinator PASS and merge

The earlier corrected head `8cf811e2b3ce1fe4c164437868793fb84cf9cf3b` is historical only. Concurrent shared-account writers later corrupted the #728 branch by replacing the complete DB test with placeholder/partial content. Operations Room froze the exact feature branch with temporary no-bypass ruleset `24000473`, required one exclusive recovery owner, restored the verified full test blob in detached commit `ff0ab60708898c1c858c41465dcffba2f1013145`, then prepared a native authorization correction before reopening the branch.

Final source candidate:
- exact head: `50dd5508bded271bda446dd23991a5e9d82065f7`
- exact tree: `fcb36ff0848cf3f17009cb0c95fda82c90b821ac`
- base/main at decision time: `6f20780765001d1a90ee31800a3948d043551afa`
- merge commit: `0974b2c4a671197711139dfa098f03c33903b0a3`
- merged at: 2026-09-25T14:49:39Z

The final recovery removes Operations authorization dependence on the retired ProjectOS-backed `public.pandora_projects` compatibility view. The migration now creates an explicit service-role-only `private.pandora_ops_project_bindings` registry with evidence references. Missing or revoked bindings fail closed at initialize, claim, dispatch and owner admission. Owner/browser calls cannot create project bindings, and the migration seeds none.

One publication defect was caught by CI during recovery: JavaScript replacement semantics collapsed intended PostgreSQL `$$` function delimiters to a single `$`, causing migration replay failure at detached/recovery head `df80c6c2ee06479999c53ed5a4c29d991647bcd8`. The correction used function-valued replacements, verified literal `$$` in provider-read-back source, and advanced to final head `50dd5508...`.

Final exact-head workflow runs all completed successfully:
- Edge source artifact `36148045637`
- mobile exact-source gate `36148045398`
- Dependency Review `36148045621`
- canonical release evidence `36148045418`
- Operations Room runtime `36148045372`
- Windows Worker Contract `36148045500`
- Engineering toolchain `36148045333`
- Node 24 `36148045610`
- PLP native Android exact-source `36148045456`

Independent Worker E review used the complete exact PR diff. Primary `gemini-3-flash-preview` returned provider HTTP 503 high demand and no verdict. Approved fallback `gemini-3.1-flash-lite-preview` returned HTTP 200, response ID `UIa2at-sGZ6pvr0PrMut-Ao`, exact candidate/tree match, verdict PASS, zero findings. The 503 is retained as provider-availability evidence rather than erased.

Coordinator generation 2 bound the final candidate to authoritative Sheet snapshot generation 14 / `gdrive-revision-781` / SHA-256 `40763b836d3ef4b104c67f70cb6ca495068a0ca0395a4de877759e5b80defac1`. GitHub App 4785021 published required check `108120640468` PASS. Governed merge claim `a51296eb-be19-44d2-92ae-7b7e66ad6bc9` revalidated exact head/base/snapshot/check identity. Vault-backed GitHub merge used expected head with no force/bypass. `completeMerge` provider readback recorded merge SHA `0974b2c4...` and released the merge fence.

## Updated Pandora lessons

- Shared canonical credentials do not identify the source writer. When competing writes corrupt a branch, freeze that exact branch, assign one exclusive recovery owner, prepare detached source, verify objects, then reopen only for a bounded non-force fast-forward.
- A neutral name does not make retired storage an acceptable authority dependency. Authorization must bind to an explicit current Pandora-owned authority surface.
- JavaScript replacement strings interpret `$$`; when source must literally contain `$$`, use a function replacement or another byte-safe construction and provider-read back the result before trusting it.
- Provider 503/high demand is no review verdict. Use only an approved fallback, on the same exact evidence, and preserve both attempts.
- Exact-head CI, independent source review, coordinator snapshot binding, merge claim, provider merge readback, and fence release are separate evidence layers. None substitutes for another.

## Final non-claims

PR #728 source is merged, but the Operations Room is not thereby fully deployed or all 42 upgrades live. No production migration apply, Edge deployment, automatic project binding, real ChatGPT worker pool, Router runtime implementation, physical-device acceptance, or canonical Memory promotion is implied by the source merge.
