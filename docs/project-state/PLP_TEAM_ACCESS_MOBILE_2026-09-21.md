# PLP Team & Access mobile implementation — 2026-09-21

## Scope

Implemented the PLP Boracay Team & Access mobile workspace in the canonical Pandora source repository `pandora-rvw-314296438-20260820/pandoras-box`, branch `fix/plp-mobile-command-center-20260920`, PR #654.

## Durable decisions

- Screenshot-driven enterprise UI must preserve the intended visual hierarchy and luxury PLP presentation without inventing operational truth.
- People shown in Team & Access must come from provider-backed staff identities or active PLP organization memberships. Do not hardcode screenshot identities.
- Membership `active` means active workspace access, not "on duty". Never infer duty/shift state without an authoritative duty source.
- The mobile bootstrap may expose bounded team identity and role data but must not expose staff email hints, email addresses, or phone numbers.
- QA/demo staff-task activity must remain visibly marked as QA/mock data.
- Add People remains governed through Pandora/Alfred rather than performing an unverified direct mutation from UI.

## Provider implementation and verification

Supabase project: `jcyqixttuebxqqfkjonq`.

Migrations:
- `20260921102000_plp_team_access_bootstrap_v3.sql`
- `20260921103500_plp_team_access_visible_count_v4.sql`

Live bootstrap schema after v4:
- `plp.enterprise.mobile-bootstrap.v4`
- `teamAccess.members`
- `teamAccess.recentActivity`
- `teamAccess.activeMemberCount`
- `teamAccess.currentUserRole`
- `teamAccess.canManageTeam`
- `teamAccess.accessModel`

Verified provider readback with an authenticated PLP owner context:
- visible team members: 2
- active visible member count: 2
- manage-team permission: true
- no `email` field in the returned bootstrap
- no `phone` field in the returned bootstrap
- recent QA task activity is tagged `isMock=true`

The initial v3 implementation exposed a count mismatch: the raw active membership count included a staging account while the visible member projection filtered it. v4 fixes this by deriving `activeMemberCount` from the final bounded visible member array.

## Mobile implementation

Primary source:
- `apps/pandora-mobile/lib/features/enterprise/plp_team_access_screen.dart`

Shell integration:
- `apps/pandora-mobile/lib/app/plp_enterprise_shell.dart`

Tests:
- `apps/pandora-mobile/test/features/enterprise/plp_team_access_screen_test.dart`

Workflow:
- `.github/workflows/plp-pandora-enterprise-android.yml`

Current exact-source candidate SHA:
- `9cd0c450c9b18886a86136cae469cc628de1160a`

The screen includes the PLP light luxury header, Our People hero, Team / Access / Activity tabs, provider-backed member rows, search, Add People handoff, access summary, recent activity, and a dedicated light Pandora Team & Access composer.

## Failure and correction

Exact-source cross-platform tests found real narrow-phone defects in the first implementation:
- hero vertical overflow at narrow widths
- tab-label horizontal overflow
- team-footer horizontal overflow

The corrective commit `9cd0c450c9b18886a86136cae469cc628de1160a` uses bounded text, `FittedBox`, flexible tab labels, smaller compact spacing, and a responsive footer.

## Verification evidence

PLP exact-source workflow run `35529513197` on SHA `9cd0c450c9b18886a86136cae469cc628de1160a`:
- exact source / isolation checks: PASS
- private-key literal scan: PASS
- dedicated PLP Flutter analysis: PASS
- PLP architecture and UI tests, including Team & Access narrow-phone tests: PASS
- exact APK build: in progress at time of this record
- artifact/signing/provider-locator verification: pending at time of this record

Do not promote this candidate to release-certified based on this record alone. Release status requires the remaining exact APK and artifact verification steps to complete successfully.

## Learning

For future PLP screenshot implementations, start with authoritative provider projections before visual population, distinguish access state from operational duty state, and include 320px/narrow-phone UI tests in the first implementation pass. This avoids hardcoded demo truth and catches layout defects before APK build.
