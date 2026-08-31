# Pandora Capability Registry V3 — current alignment overlay

Observed: 2026-09-01  
Status: **current evidence overlay; fail closed on missing runtime proof**

This registry supersedes `PANDORA_CAPABILITY_REGISTRY_V2.md` **for current-state decisions only**. V2 remains immutable recovery-era evidence and must not be rewritten as if its old SHAs or repository names were current.

## Authority

- Memory source: `pandora-rvw-314296438-20260820/pandoras-box-memory`, branch `main`.
- Control source: `pandora-rvw-314296438-20260820/pandoras-box`, branch `main`.
- Legacy `banataosystems/*` and `mbanatao/*` repository identities are evidence-only unless explicitly re-authorized by a newer owner decision.
- Runtime claims require fresh provider evidence bound to exact source SHA/tree.

## Capability proof state

| Capability | Source | Runtime | Current verdict |
| --- | --- | --- | --- |
| Durable Memory schema/migrations | recovered in canonical Memory repo | Supabase project `ivmvufhcsezyhczzondn` is `ACTIVE_HEALTHY` under current management readback | source present; database runtime reachable |
| Memory API/MCP routes | recovered in canonical Memory repo | public origin recorded | deployment/source parity unverified |
| ProjectOS → Memory bridge | bridge contract and URL documented | bridge active; production service principal rebound to Vercel team `mbanatao` / `team_3yw1CN59ce4pj5SwyQGCAqN3`; positive token round trip still pending fresh recovery-source Vercel production | partially verified |
| Health/search | contracts present | bridge runtime active; authenticated positive proof awaits recovery-source Vercel production | partially verified |
| Evidence intake/write | contracts present | authenticated production write proof missing | unverified |
| Canon promotion | gates present | promotion proof missing | unverified |
| Namespace isolation | tests/contracts present | fresh positive + negative identity run missing | unverified |
| Vercel production binding | recorded project/origin | recorded project is provider-visible under `team_3yw1CN59ce4pj5SwyQGCAqN3`, but production still serves old `banataosystems` lineage; direct exact-source deployment is currently blocked by Vercel daily deployment quota and Git auto-deploy did not fire after a no-content `main` trigger commit | blocked on production source parity |
| Supabase parity | recorded project ref | project readback healthy; bridge active; transferred Vercel workload identity rebound | provider identity aligned; authenticated positive journey pending Vercel production parity |

## Required evidence to move a capability to production_verified

1. exact source commit and tree;
2. exact runtime/provider identity;
3. authenticated positive journey;
4. negative identity/isolation journey where applicable;
5. immutable evidence receipt with observed time;
6. rollback/restoration evidence for mutable production changes.

No recovery document, green source gate, reachable public hostname, or old deployment receipt alone is sufficient to mark a capability production verified.
