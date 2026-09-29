# Pandora-native growth-learning bridge evidence — 2026-09-29

Status: source candidate; release remains governed by exact-head CI and provider readback.

Scope:
- Replaces the temporary ProjectOS growth-learning caller identity with the existing `pandora-mcpmaster-production` service principal.
- Routes typed growth-learning intake through `pandora-memory-bridge`.
- Keeps the Memory grant proposal-only: `can_propose=true`, `can_approve=false`.
- Requires intake receipts to remain `pending_review`, `review_required=true`, and `canonical_memory_written=false`.
- Does not promote, approve, or make any candidate retrievable as canonical Memory.

Source candidate before this registry entry:
- branch: `chatgpt/growth-learning-pandora-native-20260929`
- commit: `72e8b2bd71d08c80d97ec301d4645f2a76328a62`
- base: `fdc0348b27dec3ee514bada0db274a536b6ed9e5`
- pull request: #128

Provider preconditions verified before implementation:
- `pandora-mcpmaster-production` is active in production.
- It is granted read/propose for project `7c686cbd-d968-49d5-86cc-918f5e777bd2`.
- Its grant has `can_approve=false`.
- No ProjectOS runtime activation is authorized by this change.

Acceptance after merge requires:
1. exact-head CI terminal/acceptable;
2. migration applied to the canonical Memory Supabase project;
3. `pandora-memory-bridge` deployed from the merged source;
4. a typed growth-learning test receipt returns pending review without canonical write;
5. retrieval excludes the pending candidate until a separate human review/promotion action.
