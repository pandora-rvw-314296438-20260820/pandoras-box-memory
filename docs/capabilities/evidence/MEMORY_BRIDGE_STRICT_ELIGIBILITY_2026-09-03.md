# Memory Bridge Strict Eligibility — 2026-09-03

Scope: P5 Tasks 41–42, existing `pandora-projectos-bridge` only.

Exact candidate bridge raw SHA-256: `2e7286035cf90fd324454cddf0d7d55c33d7da5ffaf569b71b53ef79896e7569`.

Verified live schema authority:
- `pandora_project_grants.allowed_record_types` is `text[]`.
- `memory_items` has first-class `project_id`, `record_type`, `canon_status`, `superseded_at`, and `revoked_at`.
- `memory_retrieval_logs.memory_item_ids` is `uuid[]` and is bound to the final approved eligible result set.

Candidate invariants:
- exact project + namespace + active production grant remain mandatory;
- normal ProjectOS retrieval permits only `hard_canon` and `soft_canon`, never `draft`;
- grant `allowed_record_types` is enforced in the storage query and an empty/malformed allowlist fails closed;
- superseded and revoked records are excluded in the storage query;
- retrieval logs contain only IDs from the final eligible approved records;
- unscoped profiles, open loops, events and legacy context packs remain omitted.

Independent scheduled review:
- Kimi job `00cd269c-205d-4cc1-8163-37abac0b2421`: terminal `succeeded`; corroborated grant/type/current-head authorization and no draft leakage.
- Gemini job `dc2b75bf-9e89-4658-a371-24c5c77c0e44`: terminal `succeeded`; regression matrix retained after mapping to the actual live schema; invented table/function names rejected.

No credential material is recorded here. Provider/runtime verification remains required after merge and deployment.
