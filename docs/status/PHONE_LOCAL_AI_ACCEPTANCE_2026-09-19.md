# Phone-local AI acceptance state — 2026-09-19

## Classification
- **Status:** PARTIAL / BLOCKED
- **Objective:** physical Android phone-local Pandora LLM with automatic cloud escalation.
- **Canonical source:** `pandora-rvw-314296438-20260820/pandoras-box`
- **Acceptance branch:** `feat/phone-local-ai-acceptance-20260919`
- **Exact source SHA:** `5306331b3164a1a4246f79bdc4662c0b6131dad4`
- **Draft PR:** #651

## Verified facts
- Source implements an Android-local llama.cpp path that loads a user-selected GGUF from app-private phone storage, streams generated output into the existing Pandora chat, and supports cancel/reset/unload.
- Model import records file size and SHA-256 and now checks safe free-storage headroom.
- The native build is configured for arm64 CPU inference with KleidiAI/OpenMP. GPU, NPU, and NNAPI acceleration are not configured or verified.
- Android-exposed diagnostics now include device/Android/SoC/ABI/CPU-core data where available, RAM and memory pressure, storage, battery/charging, thermal status, Vulkan feature exposure, model path/hash/load state, model-load time, first-token latency, generation duration, and inference-flow emission rate.
- Automatic routing keeps live/connected data, attachments/multimodal context, external actions, heavier coding/research cues, Android memory pressure, and severe-or-higher thermal pressure off the local path. Routine eligible prompts can use the local path.
- Eager app-start model warming was removed; the model warms lazily for an eligible local turn or explicitly in settings.
- The settings copy that called Qwen2.5 3B Q4_K_M a “benchmarked sweet spot” was corrected. It is only the current primary candidate until physical-device benchmarking exists.

## Evidence boundaries
- GitHub exact-source workflow run `35453147233` for SHA `5306331b3164a1a4246f79bdc4662c0b6131dad4` is queued with zero jobs allocated. No workflow step has executed; there is no APK hash from this source yet.
- Supabase `canonical_physical_android_receipts` is empty. No Artemis-grade physical-device receipt exists.
- A prior `pandora_local_ai_jobs` success used worker `rdp-ec2amaz-spae2vg`; it is invalid evidence for phone-local inference and must never be promoted as local-phone acceptance.
- The surviving physical-Android attestation path is coupled to retired ProjectOS proof/identity concepts and must not be used for this workstream.
- No measured physical-phone load time, TTFT, tokens/sec, RAM, thermal, battery, context limit, crash/OOM, or sustained-generation result exists yet.

## Durable decisions
- Do not merge PR #651 until the Android build executes and a physical phone proves model presence, local generation, no cloud use for the acceptance prompt, cancellation, unload/reload, and measured runtime telemetry.
- CPU remains the only configured baseline. Treat GPU/NPU acceleration as unverified until a physical-device experiment shows actual backend use and comparative measurements.
- A response label such as “LOCAL” or a remote worker success is not acceptance evidence. Future acceptance must bind exact source SHA + APK hash + model identity/hash + physical device identity + backend + timestamp + runtime measurements.
- Do not use ProjectOS, RDP, AWS, Bedrock, desktop-hosted inference, or the blacklisted repository as substitutes.

## Next gate
1. Obtain an exact-source Android APK for SHA `5306331b3164a1a4246f79bdc4662c0b6131dad4`.
2. Install that APK on the physical Android phone.
3. Import/verify Qwen2.5 3B Q4_K_M (or the exact technically appropriate Qwen2.5 3B GGUF).
4. Execute a forced-local acceptance turn with network/cloud exclusion evidence.
5. Capture device capability and CPU baseline metrics.
6. Only then probe Vulkan/GPU/NPU paths individually and compare against CPU.
