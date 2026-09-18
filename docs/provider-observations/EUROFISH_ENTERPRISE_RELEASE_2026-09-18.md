# Euro-Fish Enterprise production release receipt — 2026-09-18

## Identity

- Project key: `enterprise-eurofish`
- Memory namespace: `real_life`
- Canonical source repository: `pandora-rvw-314296438-20260820/pandoras-box`
- Canonical source branch: `enterprise-ui-business-1`
- Exact released source SHA: `3ce7a580076ed6858ed337835ec70867eb998ecc`
- Canonical Memory repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Memory branch: `enterprise-eurofish-memory-20260918`

## Exact-source verification

The Windows RDP node was used only as a disposable exact-source build/test worker. GitHub remained source authority.

- Flutter: 3.47.0
- Dart: 3.13.0
- `flutter analyze`: PASS, zero issues
- Full Flutter test suite: 518 passed, 4 intentional skips, 0 failures
- Architecture guard: PASS
- Euro-Fish workspace API contract tests: PASS
- Exact-source local web compile: PASS
- Local `main.dart.js` SHA-256: `d81d41b89f5144eab81796303da07e16c7546d4f32c7012a47bdc7b83b1c8b01`
- Local `index.html` SHA-256: `e0633ed7cafad794b82b6653ac1b1c7d52490faf9f0f691f255adef208c03748`

The local hashes are compile evidence only. Production artifact identity is taken from the provider-generated release manifest below.

## Defects corrected before release

1. Euro-Fish screen symbol collision: `_panel` was used for both a color constant and widget helper.
2. The Euro-Fish Supabase client was under the feature layer and violated the architecture guard; it was moved to `core/data`, the feature-layer copy removed, and imports/tests updated.
3. A final import-order lint was corrected.
4. The RDP initially lacked `PROGRAMFILES(X86)` for Flutter test bootstrap. This was a worker-environment defect, not a source defect. The test-process environment was repaired and the full suite passed.

## Production deployment

- Vercel project: `pandora-enterprise-business-1`
- Vercel project ID: `prj_4SmL34fR5vxArnqhNZDeSLrsP7JJ`
- Deployment ID: `dpl_9oncbCwZbooZ1XgdRNyjheeiE9US`
- Production URL: `https://pandora-enterprise-business-1.vercel.app/`
- Provider state: `READY`
- Provider substate: `PROMOTED`
- Provider source ref: `enterprise-ui-business-1`
- Provider source SHA: `3ce7a580076ed6858ed337835ec70867eb998ecc`

Automatic Git deployment is disabled in the repository contract. The production release was created through the governed Vault-backed Vercel route using the canonical Git source and exact branch head.

## Production runtime readback

Provider/server-side HTTP verification after promotion:

- Production root: HTTP 200
- Root contains the expected `/pandora-web/` base href
- `/health`: HTTP 200 and reports `pandora-runtime` healthy
- `/pandora-web/pandora-web-release-manifest.txt`: HTTP 200

Live release manifest:

```text
source_sha=3ce7a580076ed6858ed337835ec70867eb998ecc
app_version=0.4.0-rc.4+11
flutter_version=3.47.0
web_tree_sha256=56e874ce5d19dc3f976f224314744f032f9d874642e4dfe1e9bc998694787258
artifact_class=production-candidate
production_release=true
```

## Evidence interpretation

- GitHub source, Vercel deployment source, production alias, and live release manifest converge on the same exact SHA.
- This verifies the Euro-Fish Business-1 production release.
- This receipt does not claim unrelated physical-device accessibility acceptance or customer-identity acceptance that requires separate evidence.
- No credentials, provider tokens, decrypted secrets, or secret-bearing environment values are recorded here.
