# Operations Room Maximum-Throughput Architecture V1

**Recorded:** 2026-09-25  
**Status:** Owner-approved target architecture; not implementation or release proof  
**Canonical implementation repository:** `pandora-rvw-314296438-20260820/pandoras-box`  
**Canonical Memory repository:** `pandora-rvw-314296438-20260820/pandoras-box-memory`  
**Owner decision:** Upgrade Pandora Operations Room into the global autonomous scheduler while keeping ChatGPT as the primary engineering workforce.

## Core operating model

`Owner -> ATHENA / Operations Room -> parallel ChatGPT engineering workers -> GitHub + Supabase + Vercel + RDP + Android Emulator -> ARTEMIS independent verification -> Pandora Memory`

Operations Room coordinates, schedules, leases resources, routes failures, observes provider truth, and closes work. ChatGPT continues to do the majority of coding, debugging, architecture, UI/UX, migrations, tests, CI repair, conflict resolution, and technical reasoning.

Greek-god identities are responsibility and authority roles, not substitutes for ChatGPT engineering. Providers and machines execute bounded actions; they are not the planning brain.

## P0 upgrades

1. ATHENA becomes the global scheduler for intake, decomposition, prioritization, dependencies, assignment, monitoring, rebalancing, verification routing, and closure.
2. Add spreadsheet-to-execution intake so Google Sheets/XLSX rows can become durable tasks with priority, dependencies, subsystem, acceptance criteria, worker, PR, SHA, CI, deployment, verification, and blocker state.
3. Add two-way spreadsheet synchronization so owner-facing task status remains current.
4. Build a durable global dependency graph rather than a flat queue.
5. Run at maximum safe parallelism: start every genuinely independent task that available capacity can support.
6. Use adaptive concurrency: add workers while throughput improves and reduce concurrency when CI congestion, merge conflicts, provider limits, verification backlog, or resource contention make more parallelism counterproductive.
7. Use dynamic ChatGPT worker pools for Web, Backend/AI, Mobile, Growth, Reliability, Release, and future lanes instead of one fixed worker per category.
8. Add critical-path prioritization so tasks that unlock the most downstream work are favored.
9. Add automatic work stealing and rebalancing so compatible idle workers take runnable work.
10. Add durable leases for tasks, files/code areas, migrations, environments, provider mutation targets, RDP machines, emulators, and other shared resources.
11. Add conflict detection for code overlap, schema/API ownership, migration ordering, deployment targets, and shared execution resources.
12. Add ARES — Device & Execution Operations — as the dedicated RDP/emulator execution-resource lane.
13. Re-authorize RDP as governed build/test/diagnostic infrastructure while preserving GitHub as canonical source. RDP must use exact-source work, must not become an independent source of truth, and must not host Pandora LLM inference.
14. Give ARES governed RDP actions for builds, Flutter/Dart analysis, tests, terminal/process work, diagnostics, artifact generation, Android tooling, logs, and machine health.
15. Give ARES full Android emulator control: start/reset/stop, ADB health, APK install/uninstall, launch/force-stop, clear state, permissions, taps/types/swipes, screenshots/video, logcat/crash capture, UI/integration tests, network tests, and package/version/hash readback.
16. Preserve the boundary that emulator PASS is not physical-device PASS. Redmi/real-device HyperOS, protected-app, telephony, real-network, and hardware acceptance remain separate.
17. Make GitHub a first-class scheduler resource for exact SHA, branches, commits, PRs, reviews, checks, merge state, and source readback.
18. Keep GitHub canonical for source; worker sessions, RDP, and emulators never become competing source authorities.
19. Make Supabase P0 Operations Room infrastructure for project/schema/table/RPC/function/migration/RLS/Edge Function/log/advisor/provider-health reads and orchestration state.
20. Add governed Supabase mutations for schema/RLS/migrations/RPCs/functions/Edge Functions and bounded data changes through Tool Gateway/policy, leases, rollback safeguards, and provider readback rather than unrestricted model SQL.
21. Use Supabase as the durable scheduler state layer for task state, dependency state, leases, worker state, retries, execution events, and receipts so work survives chat/session interruption.
22. Keep `pandoras-box-memory` integrated for decision/failure/lesson retrieval before major architecture, security, provider, debugging, and deployment choices.
23. Make Vercel a first-class Operations Room resource for project/deployment reads, previews, build/runtime logs, exact-SHA binding, preview verification, production promotion, aliases/domains, runtime readback, and governed rollback.
24. Add production deployment leases so competing production mutations are serialized even when candidate builds proceed in parallel.
25. Automate implementation-to-Release handoff: a builder finishes, the PR enters Release, and the builder immediately receives its next compatible task.
26. Scale ARTEMIS/Release as a pool of independent ChatGPT verification workers for exact-head CI, review, merge, Supabase parity, Vercel deployment, provider/runtime readback, emulator acceptance, and physical-device gates where required.
27. Route failed CI automatically to Reliability/CI while the original implementation worker continues other safe work.
28. Route failures by domain automatically: Android to Mobile + ARES, database to Backend/Demeter/Themis, CI to Reliability, security to Themis, deployment to Release/Hephaestus, and ambiguous provider mutations to reconciliation rather than blind retry.
29. Make scheduling event-driven: CI green wakes Release; CI failure wakes Reliability; merge wakes deployment; deployment READY wakes runtime verification; emulator availability wakes the next Android task.
30. Add crash/reconnect recovery so ATHENA reconstructs active work and leases from durable state.
31. Add task execution budgets for worker capacity, provider/API usage, CI, retries, elapsed execution, cost, and scarce resources.
32. Add risk tiers: read/analysis; source-change/PR; preview/runtime; production/database/security; destructive/high-risk. Higher tiers require stronger leases, proof, and owner boundaries where applicable.
33. Add live health awareness for ChatGPT worker capacity, CI, Supabase, Vercel, RDP, emulator, and Release queues.
34. Expand Operations Room beyond `operations.room.read` and `operations.room.coordinate` into governed task creation, dispatch, lease management, GitHub actions, Supabase actions, Vercel actions, RDP actions, emulator actions, CI dispatch, Release dispatch, evidence capture, and Memory promotion.
35. Add owner override commands such as `PLP is P0`, `pause task 82`, `no production deployments`, `maximum Android capacity`, and `finish everything safe`; ATHENA must recompute the plan immediately.
36. Build an Operations Theatre showing real workers, queues, dependency graph, leases, PRs, CI, Supabase work, Vercel deployments, RDP/emulator state, Release queue, blockers, and completed work.
37. Keep Build Theatre real-event-only: claimed -> executing -> tested -> PR -> CI -> verified -> merged -> deployed -> accepted. Never fabricate progress.
38. Retrieve relevant Pandora Memory before material architecture/provider/security/debugging/deployment decisions.
39. After meaningful verified work, promote only high-signal lessons: what worked, what failed, why, the successful fix, provider/model performance, architecture outcomes, and repeat-failure prevention. Keep polling/retry noise in raw operational history.
40. Preserve credential isolation. ATHENA and ChatGPT workers must not receive raw GitHub PATs, Supabase service credentials, Vercel tokens, or other master secrets. Use governed capability -> policy/Tool Gateway -> Vault/provider adapter -> provider readback -> independent verification.
41. Give ATHENA a global optimization objective: maximize verified useful output subject to priority, downstream unlock value, worker capacity, conflict risk, execution risk, cost, provider limits, and verification capacity.
42. Do not add additional Greek-god roles unless a genuinely new authority boundary appears. Scheduler intelligence, resource management, execution adapters, and verification should be improved before adding personas.

## ChatGPT heavy-lifting rule

ChatGPT remains Pandora's primary implementation engine.

- ATHENA schedules and coordinates.
- ChatGPT specialist workers write and review most code, design architecture, debug, create migrations, build UI/UX, write tests, resolve failures, and prepare PRs.
- ARES operates RDP/emulator/device execution resources under scheduler leases.
- GitHub, Supabase, and Vercel execute and store provider truth.
- ARTEMIS independently verifies consequential implementation and release outcomes.
- Pandora Memory supplies relevant prior decisions and records verified lessons for future ChatGPT workers.

The same implementation context must not be the sole authority that marks its consequential work verified.

## Supersession and compatibility

This owner decision supersedes the architectural assumption that Operations Room must be limited to a `github-supabase-vercel-only` execution-resource policy.

The replacement rule is:

- GitHub + Supabase + Vercel remain authoritative provider/source/control infrastructure.
- RDP + Android emulator are authorized governed execution and verification resources when connected and leased.
- RDP is not canonical source and is not an LLM host.
- Physical Android verification remains distinct from emulator verification.
- Existing security, exact-source, approval, rollback, secret-isolation, and independent-verification requirements remain in force.

## Owner experience target

The intended owner command is:

> Execute this spreadsheet at maximum safe parallelism and continue until every executable task is verified complete.

Operations Room should then keep all useful ChatGPT and infrastructure capacity saturated until only genuinely blocked work remains.

## Truth boundary

This document records the approved architecture and operating decision. It does **not** claim these capabilities are already implemented, connected, deployed, or production-verified. Each upgrade requires source implementation, exact-head verification, provider/runtime readback, and release evidence before its implementation status can be promoted.
