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
