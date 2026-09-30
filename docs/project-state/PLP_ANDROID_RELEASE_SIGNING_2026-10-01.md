# PLP Android release-signing evidence — 2026-10-01

## Classification

Verified implementation/security evidence. This record supersedes only the signing-key availability boundary in the earlier October 1 PLP command-center record. It does not alter the product/design decisions in that record.

## Source binding

- Canonical product repository: `pandora-rvw-314296438-20260820/pandoras-box`
- Tested PR head: `cd7ea6e297d3463d9b878294bc16bae25293d60a`
- Governed merge/main SHA: `f88d7a38548fadd7a672bdd6213beb7d8aa6aaaf`
- Source APK SHA-256: `98d278103ef312c164ef33da0e23e2e5a9312445ee7a317854c26ce1df65e075`
- Package: `com.banataosystems.pandora.plp`
- Version: `0.4.0-rc.14+21`

The final signing operation used the exact CI-built APK from the green PLP exact-source workflow. It did not rebuild application code.

## Dedicated PLP release signer

A dedicated PLP Android release identity now exists.

Public certificate:
- subject: `CN=PLP Pandora Enterprise Release,OU=Banatao Systems,O=RED-APPLE TECHNOLOGY AND DIGITAL SERVICES,C=PH`
- certificate SHA-256: `ba4c1df95b0f0858bb510dab90b412dd18724205f5ff3dfbb7c7c56c9931202e`
- validity: 2026-09-30 through 2036-09-27
- APK signing scheme: v2
- signature algorithm: RSASSA-PKCS1-v1_5 with SHA2-256 / Android algorithm ID `0x0103`

Long-lived private signing material is not committed to either canonical repository and was not placed in the APK.

Supabase Vault contains the durable signing material under these fixed names:
- `plp_android_release_keystore_pkcs12_v1`
- `plp_android_release_keystore_password_v1`
- `plp_android_release_certificate_pem_v1`

The encrypted PKCS#12 value read back from Vault has SHA-256:
`bca99277fc4a45cd62afda2d32cef41bbcf9785e93af50b8e144e456fd435bac`

Do not copy these Vault values into source, client code, logs, screenshots, chat output, ordinary GitHub Actions secrets, or Memory.

## Final signed APK

- filename: `PLP-Pandora-Enterprise-v0.4.0-rc.14+21-release-signed.apk`
- size: `71084669` bytes
- SHA-256: `a2d436d6cd1f7ced23da5db627675f5dd259683303c98b2307f5b7d3ed1a89bd`
- Android v2 signature cryptographically verified: **true**
- Android content digest SHA-256: `b7609f9a08d1c34f323618081e51f948cde1340d46b830bc2c2385221876d11b`

Payload-preservation evidence:
- APK signing-block start unchanged: true
- payload bytes before signing block identical: true
- central-directory bytes identical: true
- payload prefix SHA-256: `9df514f3e21d171664cb1e999171d634d621fcf51ea5d8843b1c94d045525019`
- central-directory SHA-256: `a68b88e67a0d7009a0085c12c8861bc8b0f2f54b02d5bab9879efe03c08021e4`

The signing operation therefore changed signer identity without changing the tested PLP application payload.

## Supersession

The statement in `PLP_LUXURY_RESORT_COMMAND_CENTER_CANON_2026-10-01.md` that no Android release keystore existed is superseded by this verified evidence.

The older CI artifact remains a debug-signed validation candidate. The final signed APK identified above is the current dedicated PLP release-signed artifact.

## Remaining non-claims

These are still not verified and must not be inferred from signing:

- physical Redmi/device installation;
- Wi-Fi and mobile-data physical journeys;
- protected-app/telephony/HyperOS acceptance;
- offline Qwen acceptance;
- rollback/recovery on physical hardware;
- Play Store/App Store distribution acceptance.

Signing evidence is not physical-device evidence.
