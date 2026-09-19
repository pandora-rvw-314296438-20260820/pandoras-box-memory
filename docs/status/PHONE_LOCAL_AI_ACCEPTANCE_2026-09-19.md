# Phone-local AI acceptance state — 2026-09-20

## Classification
- **Status:** PARTIAL / PHYSICAL-DEVICE BLOCKED
- **Objective:** physical Android phone-local Pandora LLM with automatic approved-cloud escalation.
- **Canonical source:** `pandora-rvw-314296438-20260820/pandoras-box`
- **Acceptance branch:** `feat/phone-local-ai-acceptance-20260919`
- **Current exact source SHA:** `af5291e61b322d40534650ff447981473833985c`
- **Draft implementation PR:** #651
- **Memory evidence PR:** #70

## Verified implementation facts
- Android-local llama.cpp GGUF inference is integrated into the existing Pandora conversation.
- Local generation supports streaming, cancellation, reset, unload/reload, lazy warm, and app-private GGUF import.
- The visible stop control was corrected so an active local generation calls the native local cancellation path.
- Two-way local/cloud continuity was corrected with bounded recent-context bridging when the route changes.
- Model import captures model size and SHA-256 and checks storage headroom.
- Runtime diagnostics expose Android/device/SoC/ABI/CPU-core data where available, RAM/PSS/memory pressure, storage, battery/charging, thermal status, Vulkan exposure, model identity/load state, model-load time, TTFT, generation duration and output-event rate.
- Configured baseline remains arm64 CPU + llama.cpp + KleidiAI/OpenMP.
- GPU, NPU and NNAPI acceleration remain unverified and unused.
- Router guards include connected/live work, attachments/context, external actions, heavier coding/research, model availability, Android memory pressure, severe thermal pressure, and low unplugged battery.

## Build execution evidence
- Repository GitHub Actions was discovered disabled and was re-enabled through the Vault-backed canonical integration.
- After re-enable, exact-source Linux run `35454266157` and macOS fallback run `35454460519` instantiated jobs but GitHub assigned `runner_id=0`; no workflow step executed.
- A GitHub Codespaces **compiler-only** fallback was added. It does not host or execute Qwen inference.
- Exact source `146af7da4c375c02d423b87d11a63d6fdb47300c` reached the Codespaces build but failed before Flutter/Android setup because the base image carried a stale Yarn APT signing key: `NO_PUBKEY 62D54FD4003F6525`.
- That provider failure is recorded as a failed Build Theatre receipt; no APK or test result was produced from that attempt.
- Compiler bootstrap was corrected by removing only the stale Yarn APT source. Current exact source is `af5291e61b322d40534650ff447981473833985c`.
- Current compiler Codespace is `pandora-apk-phone-local-4qw7xxqxx5pg3755r`; compilation only.

## Evidence boundaries
- Supabase currently has zero registered physical Android observers, zero canonical physical Android receipts, and zero local-AI workers.
- No physical-phone Qwen model presence/load/generation result has been observed.
- No physical-phone load time, TTFT, tokens/sec, RAM, thermal, battery, context-limit, crash/OOM, cancellation, unload/reload or sustained-generation benchmark exists yet.
- RDP, AWS, Bedrock, desktop-hosted inference, Vercel inference, Supabase inference, or Codespaces inference do not count as phone-local evidence.
- A remote worker success or UI label such as “LOCAL” is not acceptance evidence.

## Durable decisions
- Do not merge implementation PR #651 until exact APK build evidence exists and the physical phone proves model presence, local generation, network/cloud exclusion for a forced-local turn, cancellation, unload/reload and runtime telemetry.
- CPU remains the only accepted baseline until a physical-device experiment proves actual GPU/NPU backend use and comparative measurements.
- Acceptance evidence must bind exact source SHA + APK SHA-256 + model identity/hash + physical device identity + backend + timestamp + runtime measurements.
- Build failures are canonical evidence: preserve the failure, root cause and correction instead of overwriting history.

## Next gate
1. Complete the exact-source Codespaces Android build for `af5291e61b322d40534650ff447981473833985c`.
2. Capture APK SHA-256, size, package/version, permissions/signature, analyzer result and focused router-test result.
3. Install that exact APK on the physical Android phone.
4. Import/verify Qwen2.5 3B Q4_K_M (or the exact technically appropriate Qwen2.5 3B GGUF) and capture model hash.
5. Execute forced-local offline acceptance, cancellation, unload/reload and routing-transition tests.
6. Measure CPU baseline before any GPU/NPU acceleration experiment.
