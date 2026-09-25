
# Pandora Tax UI Visibility — PR #706 Evidence

**Date:** 2026-09-25  
**Status:** Verified merged implementation and exact-source Android artifact  
**Canonical implementation repository:** `pandora-rvw-314296438-20260820/pandoras-box`

## Outcome

Tax & Compliance is no longer discoverable only through an expanded workspace section list.

PR #706 added a persistent **Tax & Compliance** quick-entry to every enterprise workspace card and restored the PLP workspace as expanded by default. The quick-entry reads tenant-scoped readiness from `pandora_tax_command_center_v1` and routes into the existing full `TaxComplianceScreen`. Existing professional-review and legally significant action gates remain unchanged.

## Source evidence

- PR: #706 — `fix(ui): surface Tax & Compliance on workspace home`
- Exact verified head: `821a2c2283adb5fefd48d398b37f2fd2f2c62476`
- Canonical merge SHA: `432c0c68fd9be31fce3d12cb770b04172b04de97`
- Supabase-backed GitHub path used for branch/write/merge; credentials remained server-side/Vault-backed.
- Trusted coordinator check: `Pandora coordinator / integration` PASS, check run `107921585682`.

## Exact-head verification

The following exact-head gates completed successfully:

- Pandora Node 24
- PLP Pandora Enterprise Android exact-source
- Pandora mobile exact-source gate, including Android and iOS
- Dependency Review
- Pandora Edge source artifact
- Canonical release evidence
- Windows Worker Contract

## Android artifact

- Workflow run: `36086119914`
- Artifact: `plp-pandora-enterprise-821a2c2283adb5fefd48d398b37f2fd2f2c62476`
- App version: `0.4.0-rc.14+21`
- Package: `com.banataosystems.pandora.plp`
- APK bytes: `70,884,481`
- APK SHA-256: `f7ea78d1e7a7637e42cd201d089c85f43778a58fa29c811e2d803e2f7b407b37`
- APK Signature Scheme v2 verification: PASS
- Local model bundled: false
- Physical-device verification: not claimed
- Offline-Qwen acceptance: not claimed

## Product decision

Tax is a first-class operating surface and must not be buried behind deep navigation. Future enterprise workspace changes should preserve a visible Tax & Compliance entry point and live readiness state where tax capability is enabled.
