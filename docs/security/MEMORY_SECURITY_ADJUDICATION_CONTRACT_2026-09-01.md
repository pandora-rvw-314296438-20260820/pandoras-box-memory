# Memory Security Adjudication Contract - 2026-09-01

## Purpose

This contract governs Task 39 security changes before any production RLS, schema-privilege, function-execute, Auth, extension, or service-access mutation. It is a source-readiness control, not a claim that production security has been changed.

Fresh provider readback wins for mutable security state. Do not blindly enable RLS. Do not blindly disable RLS. Do not make an advisor warning disappear by breaking the service-only access path.

## Current Memory private-schema boundary

Live readback from Memory Supabase `ivmvufhcsezyhczzondn` on 2026-09-01 established:

- eight `private` tables;
- six currently have RLS disabled and two have RLS enabled;
- `anon` has no `USAGE` on schema `private`;
- `authenticated` has no `USAGE` on schema `private`;
- neither `anon` nor `authenticated` has direct table privileges on any of the eight private tables;
- twelve public/private SECURITY DEFINER routines exist and zero are executable by `anon` or `authenticated`;
- service access is intentionally mediated by owners/SECURITY DEFINER paths and narrowly granted service-role table access where present.

Therefore RLS-off on a private relation is not, by itself, evidence of client exposure. Any RLS change must preserve the effective service-only boundary and prove the real access path before and after.

## Current Primary pg_net boundary

Live readback from Primary Supabase `jcyqixttuebxqqfkjonq` established that `anon` and `authenticated` currently have schema `net` USAGE and EXECUTE on `net.http_get`, `net.http_post`, and `net.http_delete`.

This is an excess-client-privilege candidate, not authorization for an immediate production revoke. A future revoke must first prove that no supported client path depends on these grants, use a source-controlled migration, run before/after regression tests, preserve a rollback path, and re-read the provider state after deployment.

## Mandatory migration adjudication markers

Any changed migration that alters RLS on a `private` table or changes grants/revokes touching `private` or `net` must include all of these comments:

- `PANDORA_SECURITY_ADJUDICATION: reviewed`
- `PANDORA_SECURITY_ACCESS_PATH:`
- `PANDORA_SECURITY_TEST_PLAN:`
- `PANDORA_SECURITY_ROLLBACK:`
- `PANDORA_SECURITY_OWNER:`

The marker values must be non-empty. The CI gate treats their absence as an incomplete security change.

## Hard-fail client privilege rules

Changed migrations fail the gate if they directly grant any of the following to `anon`, `authenticated`, or `public`:

1. `USAGE` on schema `private`;
2. table privileges on `private.*` or all tables in schema `private`;
3. `USAGE` on schema `net`;
4. EXECUTE on `net.http_get`, `net.http_post`, or `net.http_delete`.

A future architecture that genuinely requires one of these capabilities must first amend this contract and gate under explicit review; a migration cannot silently bypass it.

## Required proof before a live security mutation

For every affected object, record:

1. current RLS state and policies;
2. schema exposure and effective grants;
3. actual service/client callers;
4. SECURITY DEFINER or custom-auth behavior where applicable;
5. before-change positive and negative tests;
6. proposed migration/config change;
7. rollback procedure;
8. after-change positive and negative tests;
9. exact provider readback;
10. source/runtime identity used for verification.

## Explicit non-actions for this milestone

- no production RLS mutation;
- no production grant or revoke;
- no Auth or extension mutation;
- no Edge deployment or deletion;
- no Vercel production mutation;
- no Memory data or canonical-state mutation;
- no migration execution.

## Production boundary

At this milestone, canonical Memory `main` is `9da819876037aa6427e745189f7b3949747b3bef`. Memory production Vercel remains deployment `dpl_BEexxMqWK6LYmzvbGHb9emd8HAX4` sourced from `ae5aeb6a8a98582df9b4905381d3cff3298cc887`. PR #12 is independently recovering migration lineage and is not modified by this lane.

No production database, RLS, grant, Auth, extension, Edge Function, Vercel alias, Memory data, or canonical Memory state is mutated by this contract milestone.
