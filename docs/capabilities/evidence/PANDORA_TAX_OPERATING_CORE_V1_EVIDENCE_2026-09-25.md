# Pandora Tax Operating Core V1 — Merge and Live Evidence

**Date:** 2026-09-25  
**Status:** Verified merged implementation and live Supabase rollout  
**Canonical implementation repository:** `pandora-rvw-314296438-20260820/pandoras-box`

## Source convergence

- Pull request: **#705**
- Exact reviewed head: `69aa2abbf1484928502208f43d059c3286da4e13`
- Base main: `e376e5bde912e42e5f8fc822da7c7a085a6f7ebc`
- Final merge SHA: `2aaa6f1eb84958bf0f297c5f2d1754f162017853`
- Exact merged migration blob: `0f0918b41063206f49744edfae7c3a620c498be1`
- Migration path: `supabase/migrations/20260925090000_pandora_tax_operating_core_v1.sql`

PR #704 was superseded without merge after a Gitleaks false positive in development history. #705 was rebuilt from canonical main and the final clean history passed secret scanning.

## Exact-head verification

The exact PR #705 head passed all required workflow families and security checks:

- Pandora Node 24
- Engineering toolchain
- Windows Worker Contract
- Dependency Review
- Canonical release evidence
- Pandora Edge source artifact
- Pandora mobile exact-source Android
- Pandora mobile exact-source iOS
- PLP Pandora Enterprise Android exact-source
- CodeQL
- Trivy filesystem
- Gitleaks
- actionlint / ShellCheck
- Project toolchain smoke

## Review and governed merge

An exact-source GPT-5.6 Sol review covered the final seven-file candidate and found no CRITICAL/HIGH merge blocker in tenant isolation, RLS/authorization, service-role boundaries, SQL integrity/replay, rule governance, ledger/reconciliation, deterministic calculation gates, filing-package integrity, tax chat routing, or mobile secret exposure.

Provider-backed reviewer attempts were also made before merge but were unavailable at the time:
- Worker E Gemini 3.1 Flash Lite: provider HTTP 503 high demand
- Worker E Gemini 3 Flash: provider HTTP 503 high demand
- Kimi: provider HTTP 429 rate limit
- Gemini 3.1 Pro through Worker B: quota unavailable

These unavailable provider attempts were **not** represented as successful reviews.

Coordinator evidence:
- Decision: **PASS**
- Coordinator check run: `107912855920`
- Decision generation: 1
- Review ID: `pr705-openai-sol-69aa2abb`
- Reviewer vendor recorded: `openai-gpt-5.6-sol`
- Merge claim: `1e53eb2a-f68c-4e12-9f47-5ea37d2a47c0`
- Final merge SHA: `2aaa6f1eb84958bf0f297c5f2d1754f162017853`
- Repository fence returned to `idle`

## Live Supabase rollout

The exact merged Tax Operating Core migration was applied to live Pandora Supabase project `jcyqixttuebxqqfkjonq`.

Live readback confirms:
- `pandora_tax_operating_core_v1` migration is applied.
- Philippines rule pack `ph-2026-authoritative-draft-v1` remains `in_review`.
- Approved PH rule-pack count remains **0**.
- `pandora_tax_record_rule_review_v1` is service-role executable and authenticated clients are denied.
- `pandora_tax_run_rule_tests_v1` is service-role executable and authenticated clients are denied.
- Rule-pack immutability trigger is installed.
- Rule immutability trigger is installed.
- Official-source support immutability trigger is installed.
- Rule-test support immutability trigger is installed.

## Live intelligence runtime

The existing `pandora-intelligence-chat` Edge Function was updated rather than creating a new function.

- Live version: **70**
- Status: **ACTIVE**
- JWT verification: **enabled**
- Git merge SHA: `2aaa6f1eb84958bf0f297c5f2d1754f162017853`
- `index.ts` Git blob: `e1f55b031719c797d0d2aad25b352b9320da2880`
- `activity.ts` Git blob: `87b0e73b882c6d50fb90ec0a13904d33f986e5bc`
- Live provider readback is byte-for-byte equal to the exact merged Git source for both files.
- `enterprise_tax` is admitted in the live runtime.
- verified tax command-center hydration is present in the live runtime.

## Capability now implemented

Tax Operating Core V1 now provides:

- canonical tenant-scoped tax ledger structures;
- idempotent ledger posting and human treatment review;
- evidence-linked ledger provenance;
- deterministic reconciliation;
- explicit exception generation and controlled resolution;
- versioned rule packs, rules, official source registry, deterministic rule tests and professional-review evidence;
- immutability after rule approval/terminal state;
- deterministic calculation engine that requires an approved rule pack and verified ledger state;
- eligibility fail-closed behavior;
- filing-package creation with package hashes and evidence index;
- professional review bound to the reviewed package hash;
- owner approval after professional review;
- package-tamper detection before owner approval;
- Tax & Compliance command-center backend;
- Tax & Compliance mobile workspace across all enterprise workspaces;
- guarded tax commands through Ask Pandora;
- verified tax command-center context available to the intelligence layer.

## Philippine tax truth boundary

The official BIR source references currently embedded in the PH pack are an **authoritative-source draft**, not an activated production tax determination.

Current live safety state:
- PH pack status: `in_review`
- Approved PH production packs: **0**
- Live PH deterministic calculation: **disabled**
- Filing submission: **disabled**
- Signature / OTP execution: **disabled**
- Tax payment execution: **disabled**

Professional source review, source hashes, passing deterministic tests, taxpayer-specific eligibility/configuration, and professional approval are required before a PH rule pack may become authoritative.

## Deliberately incomplete external actions

This milestone does not claim:
- a credentialed CPA has approved the current PH pack;
- Pandora has filed a return with BIR;
- Pandora can sign or satisfy OTP/declaration requirements;
- Pandora can execute tax payments;
- bank/accounting/Gmail/Drive connectors are fully wired into tax ingestion.

Those remain separately verifiable future adapters and operating steps.

## Memory artifact

Pandora operating-memory artifact:

`4538a460-db17-4496-9799-7eea680b1c46`

This record contains implementation evidence only and does not store customer tax records or material taxpayer data.
