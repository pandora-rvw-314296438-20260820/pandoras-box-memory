# PLP luxury resort command-center canon — 2026-10-01

## Classification

This record contains two distinct evidence classes:

1. **Owner decision / design authority** — the owner's explicit October 1 correction of PLP mobile direction.
2. **Verified implementation evidence** — GitHub, Supabase, Vercel, CI and APK provider readback from the implemented correction.

Do not convert implementation evidence into claims about physical-device behavior that have not been verified.

## Owner decision — current PLP direction

The current PLP mobile product must not feel like reading a book. The prior implementation was too text-heavy, inconsistent between pages, confusing and boring.

The old PLP deployment remains the visual-emotional benchmark: calm ivory/off-white luxury, near-black typography, restrained olive/gold accent, generous whitespace, photography, precise hierarchy and minimal chrome. Preserve that visual soul without turning the operating product into long editorial prose.

PLP must behave like a luxury-resort operating system first. Pandora architecture should be mostly invisible and expressed through interaction rather than explanatory copy.

Primary resort workspaces are:

- Today
- Stays
- Rooms
- Guests
- Operations
- Revenue
- Experiences
- Team
- Activity

Technical/admin machinery such as Settings, Infrastructure, Vision, Tax & Compliance, Local AI and Developer diagnostics belongs under System rather than the main resort flow.

Pandora remains persistent and contextual. Object-level resort context should drive commands around rooms, stays, guests, operations, revenue and experiences.

## Supersession

This record supersedes older PLP Memory only where it conflicts with the October 1 owner correction.

In particular:

- older navigation that foregrounded Overview, Needs You, Tax, Infrastructure or other enterprise/system concepts is superseded;
- “editorial luxury” must not be interpreted as high reading burden;
- the abandoned 45-module/MFR proposal must not be revived as the primary PLP UX;
- Alfred remains the PLP assistant identity unless the owner explicitly changes it later.

The September 29 visual grammar remains useful where it does not conflict: light/ivory canvas, restrained black/gold language, serif display hierarchy, minimal/square geometry and persistent Pandora command access.

## Verified implementation evidence

Canonical source repository:
`pandora-rvw-314296438-20260820/pandoras-box`

Merged PR:
- PR #852 — `feat(plp): rebuild the luxury resort command center`
- exact PR head: `cd7ea6e297d3463d9b878294bc16bae25293d60a`
- source tree: `aed135b1c2bc8b9919b761d77714214e90773dbb`
- governed merge/main SHA: `f88d7a38548fadd7a672bdd6213beb7d8aa6aaaf`
- coordinator PASS check: `110129827270`
- merge claim: `3080cbbb-88d4-4e53-a8ba-3e111156a9fa`

Provider readback verified that the merge commit uses the same source tree as the tested PR head.

Obsolete proposal:
- PR #825 was closed unmerged as superseded.
- Its 45-module top-level catalog and MFR rename are not canonical PLP direction.

### Supabase

Production function `public.plp_resort_command_center_v1()` is live.

Verified properties:
- `SECURITY DEFINER`
- empty `search_path`
- execution allowed for authenticated/service-role/postgres, not anon/public
- projection uses existing PLP runtime and Universal hospitality truth
- direct guest contact details are intentionally excluded

### Vercel

Production deployment:
- project: `mcpmaster`
- deployment: `dpl_HJXBKZh77rUDAfU5feV3SKpeHW7Z`
- source SHA: `f88d7a38548fadd7a672bdd6213beb7d8aa6aaaf`
- state: `READY`
- public aliases include `mcpmaster.vercel.app` and `pandoras-box-system.vercel.app`
- health readback returned HTTP 200 / `healthy` on both production aliases

A duplicate exact-SHA deployment request was removed after Vercel's automatic production deployment for the same SHA was already building, leaving a single canonical production candidate.

### PLP APK

Exact-source CI artifact:
- workflow run: `36785097611`
- artifact ID: `11129886744`
- artifact name: `plp-pandora-enterprise-cd7ea6e297d3463d9b878294bc16bae25293d60a`
- artifact ZIP SHA-256: `3876d3db8edc71b9130fe24f7236d9e0bf0d68f21618cf95c4530864eb6e2e51`
- APK: `PLP-Pandora-Enterprise.apk`
- app version: `0.4.0-rc.14+21`
- Android package: `com.banataosystems.pandora.plp`
- APK bytes: `71083453`
- APK SHA-256: `98d278103ef312c164ef33da0e23e2e5a9312445ee7a317854c26ce1df65e075`
- ABI: `arm64-v8a`
- minimum SDK: 29
- target SDK: 36

Important release boundary:
- the APK is release-mode but signed with the Android Debug certificate;
- physical-device acceptance is not yet verified;
- offline Qwen acceptance is not yet verified;
- therefore this APK is an exact install/test artifact, **not** a production/store-signed release.

## Negative knowledge / never repeat

- Do not solve PLP depth by adding dozens of top-level modules.
- Do not expose Pandora provider/capability architecture as explanatory UI copy.
- Do not call a debug-signed APK production/store-signed.
- Do not report physical-device or offline-local-model acceptance without provider/device evidence.
- Do not revive PR #825/MFR unless the owner explicitly reverses the October 1 decision.
