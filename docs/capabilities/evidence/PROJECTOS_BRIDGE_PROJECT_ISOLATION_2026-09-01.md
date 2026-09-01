# ProjectOS Bridge Project Isolation — 2026-09-01

Status: source candidate evidence only; production verification remains pending merge, ordered deployment, and runtime readback.

Authoritative base: `pandoras-box-memory` main `ae5aeb6a8a98582df9b4905381d3cff3298cc887`.

This foundation repair changes ProjectOS Memory retrieval from namespace-wide selection to explicit project-scoped selection. Search requires a valid `project_key`, resolves an active `pandora_projects` record, verifies the production service principal has an active non-revoked `can_read` grant for that exact project, and filters `memory_items.project_id` to the canonical project UUID.

Fail-closed rule: profiles, open loops, events, and context packs are not returned by ProjectOS search because those tables do not currently carry enforceable first-class project identity. They may be reintroduced only after a governed project lineage exists for those record types.

Retrieval telemetry records `project_id`, `project_key`, and `unscoped_components_omitted=true`; the retrieval query hash also binds the canonical project UUID.

Verification contract: `scripts/verify_projectos_bridge_project_scope.py` rejects any ProjectOS search implementation that queries the unscoped component tables or omits project/grant/data filters. `.github/workflows/projectos-bridge-project-isolation.yml` binds that verifier, Deno format/type checks, and the Next.js typecheck to the exact candidate SHA.

Deployment order is intentionally Box caller first, Memory enforcement second, to avoid a production compatibility gap.
