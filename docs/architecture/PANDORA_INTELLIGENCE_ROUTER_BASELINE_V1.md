# Pandora Intelligence Router baseline V1

Recorded: 2026-09-25. Classification: explicit owner architecture decision, not implementation or deployment proof.
Implementation repository: pandora-rvw-314296438-20260820/pandoras-box.
Canonical Memory repository: pandora-rvw-314296438-20260820/pandoras-box-memory.
Execution dependency: owner explicitly requires protected merge of Box PR #728 first, then remaining Operations Room upgrades and this service.

## Architecture frozen by the owner

ChatGPT -> Operations Room -> Specialist Worker -> Intelligence Router -> Model/Provider -> Verification -> Pandora Memory.

ChatGPT remains the primary reasoning, coding, synthesis, debugging and high-level coordination engine. Operations Room must increase ChatGPT's useful throughput rather than replace it with opaque coding agents. A worker label or Greek-god persona is not proof of a separately executing process or ChatGPT session.

Operations Room is the global work and resource scheduler: priorities, worker assignment, dependencies, concurrency, leases, GitHub work, Supabase/Vercel/RDP/emulator coordination, CI, release queues and acceptance.

The Pandora Intelligence Router is a SEPARATE platform inference service controlled by Operations Room. It owns model/provider selection for inference workloads, not a competing task scheduler. Specialist workers own domains and request capabilities; they do not scatter fixed model names across product code. Verification validates important outputs before completion. Pandora Memory compounds verified outcomes and informs later routing.

## Required routing order

1. Security and permission policy.
2. Explicit owner overrides.
3. Required capability.
4. Task risk and importance.
5. Historical verified performance from Pandora Memory.
6. Context-window and multimodal requirements.
7. Provider/model availability and health.
8. Latency.
9. Cost.
10. Execute.
11. Verify.
12. Escalate or fall back when necessary.
13. Record the verified outcome.

Eligibility constraints are mandatory, not trading weights. An owner override is deterministic within its authenticated scope and may not bypass security, permissions, capability, privacy, available context or budgets. Unavailable or ineligible forced choices return an explicit blocker unless an independently authorized fallback policy permits a specified alternative. A model saying it is capable, cheap, healthy or approved is not provider evidence.

## Capability classes

- deep_reasoning
- complex_coding
- fast_coding
- vision
- long_context
- research
- structured_extraction
- local_private
- cheap_bulk
- independent_verification

One versioned approved catalog maps these classes to suitable current models/providers. Model identities, capabilities, context/output/transport limits, configuration, approval status and evidence live centrally. Provider integrations are reused where appropriate rather than duplicating existing adapters. This baseline does not approve a new model, invent model availability, or authorize training.

## Risk and escalation

Do not route blindly cheapest-first. Security, migrations, architecture, production changes and difficult debugging may immediately use the strongest appropriate approved model. Lower-risk work may start with a suitable fast or phone-local model, verify, escalate to a stronger model, then a different approved provider if needed. Avoid repeating attempts on a known poor match. Permission denial, protected-data restrictions and safety refusals are not failures to evade by selecting another provider. local_private must not silently send private phone context to the cloud.

Retain bounded attempts, safe retry classification, per-request deadlines, cancellation, exact request identity and idempotency. Unknown provider outcome or billing is not a free retry or zero cost. Reconcile ambiguous outcomes before repeating consequential actions; inference success never grants permission for a downstream tool mutation.

## Valuable parallel intelligence only

Bounded multi-model execution is permitted when it offers a concrete benefit: competing diagnoses, difficult architecture decisions, code-review disagreement, security review and ambiguous failures. It is not an always-on model fan-out. Operations Room budgets the work; Router budgets and selects eligible inference attempts. ChatGPT synthesizes candidates and the verification layer determines acceptance. Majority agreement and builder self-attestation are not independent proof.

## Resilience requirements

Provider and model fallback; quota/rate-limit handling; provider-health awareness; timeout escalation; bounded concurrency; task and inference budgets; Vault-backed credentials; circuit breakers; deterministic owner overrides. Circuit half-open probes and resource/budget reservations must be coordinated durably across workers, not only in a process-local map. Route selection must not create imaginary workers or automatic ChatGPT UI sessions.

The trusted execution adapter uses credentials server-side. GitHub PATs, Supabase service credentials, Vercel tokens and model keys are not model inputs, logs, source, screenshots, learning payloads or public events. Canonical credentials and existing approved transports remain in place; no credential value is copied to this record.

## Verified learning

For meaningful executions capture task class, selected model/provider and relevant configuration/version; latency; usage and cost when known; success/failure; attempts/retries; independent verification evidence; final outcome. Unknown usage/cost stays explicitly unknown rather than zero. Distinguish provider acceptance, valid structured response, domain correctness and verified downstream result.

Use Pandora's own scoped, sufficiently fresh, verified history rather than static brand assumptions. Track sample size, model/config revision, task class and confidence to avoid treating a small or mismatched sample as a reliable ranking. Proposals, stale records, unreviewed observations and model inference do not become authorization or approved routing policy. Evaluate policy changes against a deterministic baseline, then shadow/canary evidence before wider promotion. Preserve prior decisions and failed alternatives instead of deleting history.

Reuse canonical model-run, cost, verification, task and Memory lineage where compatible. Raw attempt events remain operational history. Review-gated high-signal outcomes become durable Memory: what worked, what failed, why, which fix succeeded and how to avoid repeating the failure.

## Build Theatre

Only real execution events:
CLASSIFIED -> ROUTED -> EXECUTING -> VERIFYING -> ESCALATED/FALLBACK (only when real) -> VERIFIED -> COMPLETE.

Preserve request/job identity, generation, event sequence and source provenance. Project events through the existing canonical Activity/Build Theatre admission contract; do not create a second success authority. Completion must state its scope: an inference result is not a merged PR, successful deployment, emulator pass or physical-device acceptance. UI progress is never fabricated from a timer.

## Existing architecture retained

GitHub remains canonical source; Supabase is durable state and a governed provider; Vercel is governed preview/deployment infrastructure. ARES owns leased RDP/Android emulator execution, not primary reasoning. RDP is a build/test/diagnostic resource, not Pandora's local LLM host. Phone-local inference means the physical phone. Emulator proof remains separate from physical Redmi, HyperOS, telephony and protected-app acceptance. ProjectOS remains retired.

The explicit owner baseline supersedes a simplistic cheapest-first routing assumption, not security, independent review, exact-source, privacy, rollback, budget or approval boundaries. Operations Room owns work/resources. Intelligence Router owns inference. Pandora Memory owns verified compounding learning. ChatGPT remains primary heavy-lifting intelligence.

## Acceptance before calling this implemented

Prove authenticated service reachability and exact tenant/job/worker binding; all ten capability classes; central approval and deterministic override behavior; high-risk selection; context/multimodal eligibility; verified-history ranking with stale/unapproved rejection; quota/timeout/provider fallback; durable budget/concurrency/circuit probe races; cancellation/reconnect/idempotency; local-private data isolation; bounded comparison plus synthesis; independent output-bound verification; truthful event replay; and review-gated Memory round trip. Publish exact source and CI evidence, then separate provider/runtime readback. Documentation alone passes none of these runtime gates.

## Current implementation boundary

At recording, PR #728 foundation is corrected and tested at 8cf811e2b3ce1fe4c164437868793fb84cf9cf3b but unmerged. Intelligence Router source implementation and remaining end-to-end Operations Room integrations have not started under the owner's merge-first sequence. Tracker task INTELLIGENCE-ROUTER-V1-001 explicitly records the prerequisite. This record freezes the requested baseline without falsely claiming activation.
