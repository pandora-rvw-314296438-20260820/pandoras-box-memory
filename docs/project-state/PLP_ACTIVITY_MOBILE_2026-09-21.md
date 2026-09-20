# PLP Activity mobile workspace — 2026-09-21

## Scope

Implemented the PLP Boracay Activity workspace in the canonical Pandora source repository `pandora-rvw-314296438-20260820/pandoras-box`, PR #654.

The page follows the approved light luxury PLP direction and adds a separate `Activity Logs` tab in addition to `All`, `Team`, and `Guests`.

## Durable product decision

The owner-facing Activity page has two intentionally different truth surfaces:

1. Resort activity is a quiet operational feed: guest, booking, staff-task, housekeeping, payment, and other PLP business activity.
2. Activity Logs is the detailed Pandora execution trail. It is not populated with screenshot/demo events. It reads current canonical Pandora runtime activity events.

Do not mix these concepts. Resort activity answers “what happened at the resort?” Activity Logs answers “what did Pandora actually do?”

## Data sources

### Resort activity

RPC: `public.plp_recent_business_activity_v1(integer)`

Bounded sources:
- `public.enterprise_business_activity`
- `plp_runtime.plp_staff_tasks`
- `plp_runtime.plp_bookings`
- `plp_runtime.plp_guests`

The projection classifies rows into `all`, `team`, and `guests`. QA/demo rows remain marked with `isMock=true`.

### Pandora Activity Logs

The first implementation read `public.audit_events`. Provider verification showed that this was the wrong primary source for the new screen: the latest Pandora-prefixed audit row was 2026-09-11, while `public.pandora_activity_events` had 915 current retained events through 2026-09-20 18:26 UTC.

The active client RPC is therefore:

`public.plp_pandora_activity_logs_v2(timestamptz,uuid,bigint,integer,text)`

It reads:
- `public.pandora_activity_events`
- `public.pandora_activity_jobs`
- bounded actor display names from `public.profiles`

The log feed exposes only bounded execution metadata:
- event id
- job id
- sequence
- state/status
- human-readable runtime message
- domain
- capability
- provenance source type
- request id
- actor label
- occurred-at timestamp

It does not expose raw model content, secrets, provider credentials, or arbitrary event payloads.

## Security boundary

Both projections require authenticated PLP membership.

The detailed Activity Logs projection adds a stricter owner/admin role check. The legacy `plp_pandora_activity_logs_v1` RPC was revoked from the `authenticated` role and retained for `service_role` only.

Supabase security advisor reports the new v2 function as an authenticated `SECURITY DEFINER` RPC. This exposure is intentional because the underlying canonical execution tables are not directly client-readable. The function itself enforces:
- `auth.uid()` present
- active PLP membership
- PLP role is owner or admin
- bounded output columns only
- empty search path

## Provider verification

Verified against live Supabase project `jcyqixttuebxqqfkjonq`:

- `plp.business-activity.v1` returns live resort activity.
- `plp.pandora-activity-logs.v2` returns current Pandora runtime events.
- first-page pagination returns a complete cursor: timestamp + job id + sequence.
- second-page readback succeeds.
- server-side search succeeds.
- current sample: `Response persisted and verified for this turn.`
- legacy authenticated execute privilege: false.
- v2 authenticated execute privilege: true, with owner/admin enforcement inside the function.

## Failures and corrections

### Audit source was stale for this UX

The first activity-log implementation used `audit_events`. It was valid historical audit data but not the current canonical runtime activity stream. The correction switched the page to `pandora_activity_events`, which is current and carries execution state, domain, capability, evidence/provenance context, and runtime messages.

### PostgreSQL enum/UUID projection defect

The legacy v1 read initially failed at runtime because `audit_events.actor_type` is an enum and `resource_id` is a UUID. PostgreSQL rejected `coalesce(enum,'')` / text-search expressions until explicit text casts were added.

Lesson: compiling a PL/pgSQL function is not enough. Invoke it under a real authenticated context after creation.

### CTE cursor-scope defect

The first v2 runtime function attempted to query a CTE named `page` in a later PL/pgSQL statement. Provider execution failed because CTE scope ends with the SQL statement. The correction derives the next cursor inside the same CTE statement.

Lesson: pagination must be provider-executed, not only syntax-checked.

## Mobile implementation

Primary screen:
- `apps/pandora-mobile/lib/features/enterprise/plp_activity_screen.dart`

Shell integration:
- `apps/pandora-mobile/lib/app/plp_enterprise_shell.dart`

Tests:
- `apps/pandora-mobile/test/features/enterprise/plp_activity_screen_test.dart`

PLP exact-source workflow includes the Activity tests.

The page includes:
- luxury light header / “Recent activity” hero
- All / Team / Guests / Activity Logs tabs
- Today / Earlier grouping
- search
- pull-to-refresh
- QA marking
- Activity Log search and load-more pagination
- dedicated `Ask Pandora about activity…` persistent composer
- quick commands for attention, guest activity, and team updates

## CI migration-parity failure and correction

The first full Node 24 run after the Activity migrations failed exactly one test: the Supabase migration-parity contract. The source repository contained nine provider-applied PLP forward migrations that were not yet admitted to the test's governed forward-migration inventories. The correction explicitly added those exact migration filenames to the governed-forward, appended-history, and post-snapshot allowlists rather than weakening or deleting the parity check.

Corrective source commit:
- `7e7c9542059411e736854ce63e0b37f852768a0d`

Exact provider result on that commit:
- Pandora Node 24 run `35531474410`: PASS
- canonical Node 24 gate: PASS

Lesson: every provider-applied migration must be immediately represented in source and in the explicit migration-parity governance inventory. Never weaken parity to make CI green.

## Current source candidate

At the time of this record, the latest activity-related source work is on PR #654. Exact-source CI for the final candidate is still running. Do not promote this implementation to release-certified from this document until the exact candidate SHA and CI outcome are appended after provider readback.
