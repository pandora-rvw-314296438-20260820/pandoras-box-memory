# Current operating identity

Observed: 2026-09-01  
Classification: **current operational identity**

## Canonical source

| Field | Value |
| --- | --- |
| GitHub repository | `pandora-rvw-314296438-20260820/pandoras-box-memory` |
| Branch | `main` |
| Recovery baseline before alignment | `888aec28865b88343694d8a2bae30ef6d5e35025` |
| Control-plane repository | `pandora-rvw-314296438-20260820/pandoras-box` |
| Project key | `memory` |

`banataosystems/pandoras-box-memory`, `banataosystems/Pandoras-box`, and every `mbanatao/*` repository are historical/recovery evidence only. They must not determine current source authority or receive normal new work.

## Recorded runtime identity

| Field | Value |
| --- | --- |
| Production origin | `https://pandorasbox-memory.vercel.app` |
| Recorded Vercel project ID | `prj_brg3BJDcHfSftHH84NhnFtDJAnDO` |
| Recorded Supabase project ref | `ivmvufhcsezyhczzondn` |
| ProjectOS bridge | `https://ivmvufhcsezyhczzondn.supabase.co/functions/v1/pandora-projectos-bridge` |

These are recorded runtime identities, not current provider-parity proof. On 2026-09-01 Vault-backed Vercel provider readback confirms the recorded Memory project under transferred team `team_3yw1CN59ce4pj5SwyQGCAqN3` and its Git link to the recovery repository. Supabase management readback now confirms project `ivmvufhcsezyhczzondn` is `ACTIVE_HEALTHY`, the `pandora-projectos-bridge` is active, and the production ProjectOS service principal has been rebound to Vercel team slug `mbanatao`, team ID `team_3yw1CN59ce4pj5SwyQGCAqN3`, project `mcpmaster`, and environment `production`. The promoted Vercel production deployment still points to the old `banataosystems` source lineage, so exact production source parity and an authenticated positive workload round trip remain **unverified until a fresh recovery-source production deployment succeeds**.

## Current truth rules

1. Git source authority is the recovery repository above.
2. Historical recovery/capability documents remain evidence and are not rewritten to manufacture current truth.
3. Runtime state is current only when fresh provider evidence binds the runtime to an exact source SHA/tree.
4. The Box authenticated operator-status surface remains the portfolio control-plane status surface; Memory exposes only Memory-scoped health/evidence surfaces.
5. Never return, log, commit, or copy Vault credentials into repository content or status evidence.

## Closure gates

- Vercel production deployment rebound to exact recovery `main` after quota/Git-trigger recovery;
- production Memory deployment bound to exact current `main` SHA;
- authenticated ProjectOS → Memory health/search/evidence round trip passes;
- negative identity/isolation tests pass;
- capability registry current overlay is updated with exact evidence;
- source/runtime parity and rollback evidence are captured.
