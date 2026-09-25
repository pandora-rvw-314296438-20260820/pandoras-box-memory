# PLP Tax Drawer Visibility - Verified Evidence

**Date:** 2026-09-25
**Status:** Verified merged implementation and exact-merge APK build
**Canonical repository:** `pandora-rvw-314296438-20260820/pandoras-box`

## Problem observed

On-device PLP navigation did not show Tax & Compliance. The tax operating core and dedicated tax screen existed, but the PLP drawer source did not include a tax destination.

## Correction

PR #707 added `Tax & Compliance` as a first-class PLP drawer item directly after `Overview` and before `Operations`.

The destination routes to the existing live `TaxComplianceScreen` with `enterprise_tax` context. Existing tax professional-review, filing, payment, and execution safety boundaries were not weakened.

## Source evidence

- PR: #707
- Final reviewed head: `52375c08b45e787b8f1d52f21517a310ec79a450`
- Final merge SHA: `119bea4536b43a9b9502c81b5c2fb943582f0024`
- Main provider readback: `119bea4536b43a9b9502c81b5c2fb943582f0024`
- Coordinator check run: `107927564871`
- Coordinator decision: PASS
- Coordinator merge claim: `4cca852f-24d8-4e57-9ecb-e3a436bf2057`
- Merge fence: released

## Verification

Exact PR head passed:
- Pandora Node 24
- Windows Worker Contract
- Dependency Review
- Pandora Edge source artifact
- Canonical release evidence
- Pandora mobile exact-source Android
- Pandora mobile exact-source iOS
- PLP Pandora Enterprise Android exact-source
- PLP architecture and UI tests

A fresh post-merge PLP Android build was then dispatched from canonical `main`.

Post-merge build evidence:
- Workflow run: `36089258736`
- Source SHA: `119bea4536b43a9b9502c81b5c2fb943582f0024`
- Source tree: `f74b088f8a960382133347148e73bd47d618fb96`
- Artifact ID: `10845316513`
- Artifact digest: `sha256:f63eb76ffd60780fdf7189cd07b32ff7d8170ee2c5878fd629c65deb2660c3bc`
- APK SHA-256: `669768cc724d40cc3e9179cf43e265d36ced9903099a629603eeaa7af1afb016`
- APK size: `70950105` bytes
- App version: `0.4.0-rc.14+21`
- Package: `com.banataosystems.pandora.plp`
- ABI: `arm64-v8a`
- Build mode: release

## Remaining acceptance boundary

The APK is release-mode but is still signed with the Android debug certificate. Physical-device verification remains false, and offline Qwen acceptance remains false. Do not represent either as completed until provider/device evidence exists.
