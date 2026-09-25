# Pandora Tax Evidence Inbox V1 — Merge and Live Evidence

**Date:** 2026-09-25  
**Status:** Verified merged implementation and live Supabase rollout  
**Canonical implementation repository:** `pandora-rvw-314296438-20260820/pandoras-box`

## Source

- Pull request: **#703**
- Exact reviewed head: `4d8d4d2ab97725497fde22cb652bddf89cf91e36`
- Base main: `33009faf6c595fb0836ca4e405e86a0f248b8809`
- Final merge SHA: `e376e5bde912e42e5f8fc822da7c7a085a6f7ebc`
- Exact merged migration blob: `d2b39c8952156a230bf31a22e1543f7c1e69c790`
- Migration path: `supabase/migrations/20260925073000_pandora_tax_evidence_inbox_v1.sql`

## Exact-head verification

The exact PR #703 head passed:

- Pandora Node 24
- Engineering toolchain
- Windows Worker Contract
- Dependency Review
- Canonical release evidence
- Pandora Edge source artifact
- Pandora mobile exact-source gate
- PLP Pandora Enterprise Android exact-source
- CodeQL
- Trivy filesystem
- Gitleaks
- actionlint and ShellCheck
- Project toolchain smoke

## Independent review

A Vault-backed Worker E review was run against the exact PR #703 source plus the already-merged Tax Compliance Foundation V1 support contract.

- Reviewer: `google-gemini-worker-e`
- Requested model: `gemini-3.1-flash-lite-preview`
- Provider HTTP status: 200
- Provider response ID: `FsG1apTtDuz01e8Pm5ubmAM`
- Review ID: `pandora-tax-evidence-inbox-v1-703`
- Verdict: **PASS**
- Critical/high blocking findings: **none**

The reviewer confirmed the service-role evidence/extraction boundaries, tenant isolation, mandatory human verification, exclusion of raw extracted fields from the inbox projection, and the absence of tax filing/payment capability.

## Governed merge

Coordinator evidence:

- Decision: PASS
- Decision generation: 1
- Coordinator check run: `107895238199`
- Merge claim: `ada403fe-c6bd-4def-8fe8-1826c99ef4de`
- Provider check readback: success
- Final merged SHA: `e376e5bde912e42e5f8fc822da7c7a085a6f7ebc`
- Repository fence returned to `idle`

## Live Supabase rollout

The exact merged migration was applied to live Pandora Supabase project `jcyqixttuebxqqfkjonq`.

Live readback confirms RLS is enabled on:

- `tax_ingestion_batches`
- `tax_evidence_hashes`
- `tax_document_links`
- `tax_document_extractions`
- `tax_document_reviews`

Live function privilege readback confirms:

- `pandora_tax_register_evidence_v1`: service_role executable, authenticated denied
- `pandora_tax_commit_document_extraction_v1`: service_role executable, authenticated denied
- `pandora_tax_review_document_extraction_v1`: authenticated callable with internal owner/admin authorization
- `pandora_tax_evidence_inbox_v1`: authenticated callable with internal owner/admin authorization
- `pandora_tax_can_read_org_v1`: active owner/admin tax-read boundary

## Capability now live

The backend can now represent and control:

- SHA-256 evidence identity
- tenant-scoped duplicate detection
- one canonical tax document per organization/content hash
- multiple source links to one canonical document
- extraction provider/model/parser provenance
- confidence data
- mandatory human review
- verified/rejected extraction decisions
- evidence inbox summary
- audit events for evidence registration, extraction, and review

Model/OCR output cannot self-promote to verified tax evidence.

## Truth boundary

This milestone does **not** mean Pandora can yet calculate or file a real Philippine tax return.

Current live tax safety state remains:

- Philippines jurisdiction: `draft`
- Approved production tax rule packs: **0**
- Current tax rates/formulas: not activated
- Filing: not enabled
- Signing: not enabled
- Tax payment execution: not enabled

Those capabilities remain fail-closed pending authoritative rule-pack work, professional review, and separately verified filing/payment adapters.

## Memory reference

Pandora Memory implementation artifact:

`c1f69578-54b4-4b8d-8f96-300a839eb9ef`

This record is provider-backed implementation evidence, not a broader claim that the full Tax & Compliance roadmap is complete.
