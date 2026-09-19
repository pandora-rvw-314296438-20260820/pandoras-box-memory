# Phone-local AI acceptance state — 2026-09-20

## Classification
- **Status:** PARTIAL / PHYSICAL-DEVICE BLOCKED
- **Objective:** physical Android phone-local Pandora LLM with automatic approved-cloud escalation.
- **Canonical source repository:** `pandora-rvw-314296438-20260820/pandoras-box`
- **Acceptance branch:** `feat/phone-local-ai-acceptance-20260919`
- **Exact candidate SHA:** `b78f328c467b7d0f3312d1c88cdbe7c00be2c29d`
- **Implementation PR:** #651, draft/unmerged
- **Memory PR:** #70, draft/unmerged

## Verified exact-source APK build
- Build Theatre receipt: `athena-phone-local-b78f328c-20260920` = **passed**.
- APK SHA-256: `2775acce3eb32d2446d6541c4e92a338707d714fe66e0c0a536202f238074565`.
- APK size: `119941041` bytes.
- Package: `com.banataosystems.pandora_mobile`.
- Version: `0.4.0-rc.4+11`.
- Native ABI: `arm64-v8a`.
- Flutter: `3.47.0`.
- llama.cpp source SHA: `44be98f057e9f9902a8ee12630e181c7f8ec2953`.
- Configured backend: CPU.
- `flutter analyze`: exit 0 after changing the compiler gate so existing info/warning lint debt is recorded but analyzer errors remain fatal.
- Focused local-AI router test suite: 8/8 passed, exit 0.
- Kotlin/native Android compilation: passed.
- Badging, permissions and APK signing evidence captured.
- Evidence branch: `build/phone-local-ai-evidence-b78f328c467b-20260920`.
- Private GitHub prerelease asset ID: `575610524`.
- GitHub asset digest independently reports `sha256:2775acce3eb32d2446d6541c4e92a338707d714fe66e0c0a536202f238074565`.
- Prerelease tag: `phone-local-ai-b78f328c467b-20260920`.\n- Asset filename: `pandora-phone-local-b78f328c467b7d0f3312d1c88cdbe7c00be2c29d.apk`.

## Verified implementation facts
- Android-local llama.cpp GGUF inference is integrated into the existing Pandora conversation.
- Local generation supports streaming, cancellation, reset, unload/reload and lazy warm.
- The visible Stop control reaches native local cancellation.
- GGUF import copies into app-private storage and records model name/size/SHA-256.
- Two-way bounded context bridging preserves one visible conversation across local/cloud route changes.
- Router guards cover connected/live work, external actions, contextual/multimodal turns, heavier coding/research, model availability, Android memory pressure, severe thermal pressure and low unplugged battery.
- CPU baseline remains arm64 + llama.cpp + KleidiAI/OpenMP.
- GPU, NPU and NNAPI acceleration remain unverified and unused.
- Phone-side acceptance code computes the installed APK SHA-256 and requires it to match the provider-verified build.
- Physical acceptance requires offline network state, direct native local generation, non-emulator device, model SHA-256, hashed device identity, cancellation, unload/reload, TTFT/generation/token-event measurements and CPU backend facts.
- Immutable Supabase authority: `PHONE_LOCAL_AI_ACCEPTANCE_V1`.
- Supabase migrations `20260919171705` and `20260919171947` are live and committed.
- The acceptance path has no ProjectOS dependency.

## Provider/build history
- Repository GitHub Actions was found disabled and re-enabled through the Vault-backed canonical integration.
- Linux run `35454266157` and macOS fallback run `35454460519` instantiated jobs but GitHub assigned `runner_id=0` before source execution.
- Codespaces is used only for compilation/artifact handoff; Qwen inference never runs there.
- An obsolete Yarn APT signing key caused an early compiler bootstrap failure and was removed.
- Initial compiler gating treated existing analyzer info/warning debt as fatal; the gate was corrected while retaining fatal analyzer errors.
- Native compilation then exposed an invalid bare Kotlin `throw` in the cancellation acceptance test; it was corrected to rethrow the captured `CancellationException`.
- Exact source `b78f328c...` subsequently compiled successfully.
- APK handoff copied the built artifact from the compiler Codespace, recomputed the same SHA/size, and uploaded it as the draft GitHub Release asset above.

## Physical evidence boundary
- Current phone-local acceptance receipt count: **0**.
- Current acceptance challenge count at latest readback: **0**.
- No connected Android/ADB control channel is exposed to the current ChatGPT tool environment.
- No physical-phone proof exists yet for model presence/load/generation, offline local-only execution, cancellation, unload/reload, RAM, TTFT, sustained throughput, context limit, thermal behavior or battery draw.
- Qwen2.5 3B Q4_K_M remains the primary model candidate but is not yet proven installed or running on the handset.
- RDP, AWS/Bedrock, desktop compute, Codespaces inference, Vercel inference or Supabase inference do not count as phone-local evidence.

## Durable acceptance rule
Do not merge implementation PR #651 until the exact APK above is installed on the physical Android phone and `PHONE_LOCAL_AI_ACCEPTANCE_V1` produces an immutable verified receipt binding:
1. source SHA;
2. APK SHA-256;
3. model name and SHA-256;
4. physical device identity hash;
5. CPU runtime backend;
6. offline direct-local generation;
7. cancellation and unload/reload;
8. runtime measurements.

Only after CPU physical acceptance should GPU/NPU/NNAPI acceleration experiments begin.
