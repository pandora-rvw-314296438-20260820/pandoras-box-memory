# Pandora Tax Foundation + Meta OAuth Combined Rollout Evidence — 2026-09-25

**Status:** Verified merged-source rollout evidence  
**Canonical implementation repository:** `pandora-rvw-314296438-20260820/pandoras-box`  
**Memory repository:** `pandora-rvw-314296438-20260820/pandoras-box-memory`

## Owner direction

The owner directed the Tax & Compliance implementation to continue and be merged with the concurrent Meta/Facebook integration work rather than remain as a separate isolated stream.

## Source convergence

The combined implementation was assembled on PR #700.

- Tax/Meta combined PR: **#700**
- Exact combined review head: `51a1e34e573ee083f1211a8d08f22c6fb3e5fe12`
- Canonical base at review: `42a678830b61237910eff9aae59e3e67820ecb47`
- PR #702 Meta OAuth Vercel fallback head incorporated: `f2170f70b30896fb0a1121483762134c64363829`
- Canonical merge SHA: `33009faf6c595fb0836ca4e405e86a0f248b8809`

The combined source contains the Tax & Compliance foundation plus the Meta OAuth callback fallback that routes through the existing `mcpmaster` Vercel runtime while keeping provider credentials and tokens server-side.

## Exact-head verification

All exact-head workflow families for the combined candidate completed successfully, including:

- Pandora Node 24
- Engineering toolchain
- Windows Worker Contract
- Dependency Review
- Canonical release evidence
- Pandora Edge source artifact
- Pandora mobile exact-source gate
- PLP Pandora Enterprise Android exact-source

The PLP native Android job was cancelled once by provider scheduling and completed successfully on rerun attempt 2. The completed result, not the cancelled attempt, is the release evidence.

CodeQL on the combined head also completed successfully.

## Independent review

A Vault-backed independent reviewer was used through the dedicated Worker E Gemini transport.

- Reviewer: `google-gemini-worker-e`
- Model requested: `gemini-3.1-flash-lite-preview`
- Provider HTTP result: 200
- Provider response ID: `Crq1apbcFJWA1e8P1bXAkQM`
- Review ID: `pandora-rvw-700-51a1e34e`
- Verdict: **PASS**
- Critical/high blocking findings: **none**

The review packet contained the exact seven-file combined candidate plus the already-live Meta OAuth support contract needed to validate one-time state and token-commit behavior.

Earlier independent-review attempts through other Vault-backed provider lanes encountered genuine provider states and were not falsely treated as reviews:
- Gemini Worker B: HTTP 429 quota exhaustion
- Kimi: HTTP 429 rate limit
- OpenAI transport: HTTP 429 credit-balance exhausted
- OpenRouter: HTTP 402 quota exhausted

## Governed merge evidence

Coordinator decision for PR #700:

- Decision generation: 3
- Decision: PASS
- Coordinator check run: `107885789455`
- Merge claim: `e19a8953-3a95-4ea5-9ec5-f08eb640e0df`
- Provider readback completed
- Canonical merged SHA recorded by coordinator: `33009faf6c595fb0836ca4e405e86a0f248b8809`
- Coordinator decision consumed successfully
- Repository fence returned to `idle`

No bypass actor or direct protected-branch write was used.

## Live Supabase rollout

Two migrations from exact merged main were applied to the live Pandora control project `jcyqixttuebxqqfkjonq`.

### Tax foundation

Source file:

`supabase/migrations/20260925010000_pandora_tax_compliance_foundation_v1.sql`

Merged-main Git blob:

`588b244bdd3df22c36e140fe6647e48e1a2ecd2c`

Live readback after migration:

- 16 public `tax_*` tables present
- `pandora_tax_prepare_period_v1(uuid,date,date,text,text)` present
- `pandora_tax_workspace_v1(uuid)` present
- Philippines jurisdiction status: `draft`
- Approved/available tax rule-pack count: 0

This is intentionally fail-closed. No production Philippine tax rates were activated.

### Meta OAuth Vercel callback

Source file:

`supabase/migrations/20260925070000_pandora_meta_oauth_vercel_callback_v1.sql`

Merged-main Git blob:

`57d90c84967ac99be343f11e166d0ce05160e9a2`

Live provider readback of `pandora_meta_oauth_prepare_v1` confirms the authorization redirect is now:

`https://mcpmaster.vercel.app/oauth/meta/callback`

The already-live support contract remains service-role-only, claims one-time OAuth state before material is returned, requires claimed/unconsumed/unexpired state on commit, stores Meta user/Page access tokens in Supabase Vault, strips page access tokens from public connection metadata, and marks state consumed after commit.

## Vercel production deployment

A production deployment was created through the Vault-backed Vercel deployment lane from exact merged main.

- Project: `mcpmaster`
- Vercel project ID: `prj_Y5rZVcq8xJVzHVt4uvfmg9wPvXMk`
- Deployment ID: `dpl_CpN2QxWqbKqgbygNd5bnNpcNkwgU`
- Exact Git source SHA: `33009faf6c595fb0836ca4e405e86a0f248b8809`
- Target: `production`
- Final state: **READY**
- Alias error: none

Production aliases assigned include:
- `mcpmaster.vercel.app`
- `pandoras-box-system.vercel.app`
- `mcpmaster-hazel.vercel.app`
- `mcpmaster-mbanatao.vercel.app`
- `mcpmaster-git-main-mbanatao.vercel.app`

Vercel project environment metadata confirms the production runtime has server-side Supabase URL and service-role/secret-key variables configured. Secret values were not read or exposed.

## Live Meta callback acceptance

Provider readback against:

`https://mcpmaster.vercel.app/oauth/meta/callback`

with no OAuth `state` or `code` returned:

- HTTP 400
- Title: `Invalid authorization response`
- Message states a valid one-time state and code are required
- `Cache-Control: no-store`
- security headers present

This is the expected safe response for an invalid callback and proves the new production route is live on the exact merged deployment.

## Tax truth boundary

This rollout does **not** prove Pandora can yet calculate, file, sign, or pay a real tax return.

The live tax foundation currently provides:
- tenant-scoped tax data structures;
- deterministic/versioned rule-pack authority;
- provenance and rule-history controls;
- reconciliation/calculation/review domain structures;
- approval and append-only audit boundaries;
- tax workspace/period orchestration primitives.

The Philippines jurisdiction remains draft and there are zero approved rule packs. Tax calculation therefore remains disabled/fail-closed.

## Meta truth boundary

The production Meta callback route and backend contracts are live and verified.

A complete real-user Meta OAuth connection is **not** claimed until an authorized user completes Meta authorization and Pandora receives provider identity/scopes/assets and commits the connection successfully.

## Next tax implementation slice

Work immediately continued on the next roadmap phase from canonical merge `33009faf6c595fb0836ca4e405e86a0f248b8809`:

- branch: `feature/tax-evidence-inbox-v1-20260925`
- evidence hashing/deduplication;
- canonical document/source linkage;
- provider extraction records;
- mandatory human verification boundary;
- evidence inbox projection;
- tighter fail-closed tax-data visibility until explicit finance/accountant roles are introduced.

This next slice is implementation-in-progress and is not yet merged or production evidence.
