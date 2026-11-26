# Pandora Memory migration inventory and isolation verification — 27 November 2026

## Canonical target decision

- **Canonical Memory database:** `ivmvufhcsezyhczzondn` (Sydney). This is the dedicated Memory source project with the existing public schema and migration history.
- **Control plane:** `jcyqixttuebxqqfkjonq` (kept separate).
- **Shared PLP / Pandora Connect project:** `xyefkykwuppbweabvvmk`. This is not an appropriate canonical Memory target. The earlier Tokyo restoration there was a staging experiment only. A new dedicated project is not required: the existing Sydney Memory database is the correct target; the failure was the Edge Functions invocation quota, not a database integrity problem.
- The supported replacement path is a server-side Vercel gateway using a server-only Supabase secret key against the Sydney project, with Vercel OIDC identity checks. Do not use the Tokyo native schema or role for production.

## Fresh source inventory

| Item | Verified |
|---|---:|
| Source public base tables | 81 |
| Source private base tables | 12 |
| Applied Supabase migrations | 143 |
| Selected durable-memory tables | 25 |
| Selected source rows | 12,763 |
| Archive rows | 12,763 |
| Destination imported rows (joined by original UUID) | 12,763 |
| Omitted public tables | 56 |
| Omitted public rows left on source | 14,139 |

The live source has 81 public base tables. The 25-table import was deliberately selective, not a whole-database clone. The source database and its omitted data remain intact.

## Exact imported table mapping and checksums

The native staging table name is identical to the source public table name. Per-row digest is MD5 of canonical JSONB text; the table checksum is SHA-256 over the concatenated per-row MD5 hex digests sorted by primary-key UUID. Archive rows store the per-row source hash. Imported destination checksums include only rows joined to the original archive IDs, excluding post-snapshot additions.

| Source / destination table | Source rows | Archive rows | Imported rows | Source SHA-256 | Archive SHA-256 | Imported SHA-256 | Mismatches |
|---|---:|---:|---:|---|---|---|---:|
| `evidence_items` | 12 | 12 | 12 | `a07acb8bc8e61712b9bdeb02ee3ac0144be3e352d67b7e0dea7d3556d8904b6c` | `a07acb8bc8e61712b9bdeb02ee3ac0144be3e352d67b7e0dea7d3556d8904b6c` | `a07acb8bc8e61712b9bdeb02ee3ac0144be3e352d67b7e0dea7d3556d8904b6c` | 0 |
| `memory_capture_candidates` | 3740 | 3740 | 3740 | `0de7f2358215c333c38595c0fad25cbc15b4c48513be1b477ef00ccd4ee658d6` | `0de7f2358215c333c38595c0fad25cbc15b4c48513be1b477ef00ccd4ee658d6` | `0de7f2358215c333c38595c0fad25cbc15b4c48513be1b477ef00ccd4ee658d6` | 0 |
| `memory_context_packs` | 9 | 9 | 9 | `e8dd6d621d89e8adeee509377c0fd393fea312f444b20813a683a658a366d62b` | `e8dd6d621d89e8adeee509377c0fd393fea312f444b20813a683a658a366d62b` | `e8dd6d621d89e8adeee509377c0fd393fea312f444b20813a683a658a366d62b` | 0 |
| `memory_events` | 13 | 13 | 13 | `c56cc5a5e298e91504d913deeed4b08055f52925b448460aca0c4b55f4be3615` | `c56cc5a5e298e91504d913deeed4b08055f52925b448460aca0c4b55f4be3615` | `c56cc5a5e298e91504d913deeed4b08055f52925b448460aca0c4b55f4be3615` | 0 |
| `memory_items` | 300 | 300 | 300 | `43bf8172a18db79b7cac253d1b63fddb61cdc296a480671a0816c1c756b5dce4` | `43bf8172a18db79b7cac253d1b63fddb61cdc296a480671a0816c1c756b5dce4` | `43bf8172a18db79b7cac253d1b63fddb61cdc296a480671a0816c1c756b5dce4` | 0 |
| `memory_open_loops` | 12 | 12 | 12 | `b66a516bbb9338f548e0463eec6b4444dfd374e8b6d6a34da9510e869449116a` | `b66a516bbb9338f548e0463eec6b4444dfd374e8b6d6a34da9510e869449116a` | `b66a516bbb9338f548e0463eec6b4444dfd374e8b6d6a34da9510e869449116a` | 0 |
| `memory_patches` | 2 | 2 | 2 | `66de4ff5e1a8552575614f9d8e8bb553d660d8044ab62a01d2650ed0dfeec818` | `66de4ff5e1a8552575614f9d8e8bb553d660d8044ab62a01d2650ed0dfeec818` | `66de4ff5e1a8552575614f9d8e8bb553d660d8044ab62a01d2650ed0dfeec818` | 0 |
| `memory_proposals` | 7 | 7 | 7 | `ff894b585243f6b625e04f896fe024f42a8b08bdc1beccbac856a849c73da846` | `ff894b585243f6b625e04f896fe024f42a8b08bdc1beccbac856a849c73da846` | `ff894b585243f6b625e04f896fe024f42a8b08bdc1beccbac856a849c73da846` | 0 |
| `memory_review_queue_decisions` | 6 | 6 | 6 | `b4924006e590845b00707297a1a81dfa11b4209d3689b972208f875f3834634b` | `b4924006e590845b00707297a1a81dfa11b4209d3689b972208f875f3834634b` | `b4924006e590845b00707297a1a81dfa11b4209d3689b972208f875f3834634b` | 0 |
| `memory_review_queue_items` | 3703 | 3703 | 3703 | `d2c5653e00e1237f2fc5e3019bf9a128366cc54a1cc3c30605ada3e62749f55c` | `d2c5653e00e1237f2fc5e3019bf9a128366cc54a1cc3c30605ada3e62749f55c` | `d2c5653e00e1237f2fc5e3019bf9a128366cc54a1cc3c30605ada3e62749f55c` | 0 |
| `memory_session_digests` | 3643 | 3643 | 3643 | `aabcf7fa4b39a90a9c8599f22d5a4ac7246743ab43eab8e00f4a8a448191d47e` | `aabcf7fa4b39a90a9c8599f22d5a4ac7246743ab43eab8e00f4a8a448191d47e` | `aabcf7fa4b39a90a9c8599f22d5a4ac7246743ab43eab8e00f4a8a448191d47e` | 0 |
| `memory_sources` | 39 | 39 | 39 | `6e8016ef3c6210cfd2a6fc7b47c760101e25dcc44f21c6fae5b91d1e097e278a` | `6e8016ef3c6210cfd2a6fc7b47c760101e25dcc44f21c6fae5b91d1e097e278a` | `6e8016ef3c6210cfd2a6fc7b47c760101e25dcc44f21c6fae5b91d1e097e278a` | 0 |
| `one_best_next_actions` | 2 | 2 | 2 | `56822dcf59d2803b1deb408efa294989313d4e0d4c0122721816f1507060e261` | `56822dcf59d2803b1deb408efa294989313d4e0d4c0122721816f1507060e261` | `56822dcf59d2803b1deb408efa294989313d4e0d4c0122721816f1507060e261` | 0 |
| `operating_project_artifacts` | 416 | 416 | 416 | `1404d87aa43dda356c9a4e9e0088cc6e460daa2f96a6aa0317ceebd15116951b` | `1404d87aa43dda356c9a4e9e0088cc6e460daa2f96a6aa0317ceebd15116951b` | `1404d87aa43dda356c9a4e9e0088cc6e460daa2f96a6aa0317ceebd15116951b` | 0 |
| `operating_project_constraints` | 72 | 72 | 72 | `37d9127009d4c87bee1b609ab34317c372ada7e009751d56368860d025f39c94` | `37d9127009d4c87bee1b609ab34317c372ada7e009751d56368860d025f39c94` | `37d9127009d4c87bee1b609ab34317c372ada7e009751d56368860d025f39c94` | 0 |
| `operating_project_decisions` | 92 | 92 | 92 | `1a80dbac2d4c00e3e1557c1c44b7be869d1795d99c61b997dec7d6f58f20582e` | `1a80dbac2d4c00e3e1557c1c44b7be869d1795d99c61b997dec7d6f58f20582e` | `1a80dbac2d4c00e3e1557c1c44b7be869d1795d99c61b997dec7d6f58f20582e` | 0 |
| `operating_project_open_loops` | 77 | 77 | 77 | `7de15351adbfde2ce46ffd8c2827e5c2489330991bc6ce3a083f08f3059fb3ec` | `7de15351adbfde2ce46ffd8c2827e5c2489330991bc6ce3a083f08f3059fb3ec` | `7de15351adbfde2ce46ffd8c2827e5c2489330991bc6ce3a083f08f3059fb3ec` | 0 |
| `operating_project_tasks` | 368 | 368 | 368 | `d12289fa3f4956634405967e3dd5cb5ba3f4ca2a877a96ca9d1296bd2256138f` | `d12289fa3f4956634405967e3dd5cb5ba3f4ca2a877a96ca9d1296bd2256138f` | `d12289fa3f4956634405967e3dd5cb5ba3f4ca2a877a96ca9d1296bd2256138f` | 0 |
| `operating_projects` | 23 | 23 | 23 | `686740c7fc4caf6869f70cb91f54d7b3a165c53eb8a40a80d353c3156eab304a` | `686740c7fc4caf6869f70cb91f54d7b3a165c53eb8a40a80d353c3156eab304a` | `686740c7fc4caf6869f70cb91f54d7b3a165c53eb8a40a80d353c3156eab304a` | 0 |
| `pandora_approval_audits` | 87 | 87 | 87 | `ed7ccc5bfe4c23af224460b99c3c48d8de9f8b8a5dbd15f5a0d4232f1addc5c5` | `ed7ccc5bfe4c23af224460b99c3c48d8de9f8b8a5dbd15f5a0d4232f1addc5c5` | `ed7ccc5bfe4c23af224460b99c3c48d8de9f8b8a5dbd15f5a0d4232f1addc5c5` | 0 |
| `pandora_memory_conflicts` | 1 | 1 | 1 | `369c440fba0351398d63ddbbc1013985a0ee7213850d7c39fc2c1dbf9d14f80d` | `369c440fba0351398d63ddbbc1013985a0ee7213850d7c39fc2c1dbf9d14f80d` | `369c440fba0351398d63ddbbc1013985a0ee7213850d7c39fc2c1dbf9d14f80d` | 0 |
| `pandora_memory_record_versions` | 59 | 59 | 59 | `1b76ddadecc130b2e35ddfed38940956629f6a88455cc77a85a5a8ad176df666` | `1b76ddadecc130b2e35ddfed38940956629f6a88455cc77a85a5a8ad176df666` | `1b76ddadecc130b2e35ddfed38940956629f6a88455cc77a85a5a8ad176df666` | 0 |
| `pandora_projects` | 23 | 23 | 23 | `d79a527275b0bb02c46a9251d4ec5cb60bd1205424b0e4069a7c91d84d32bd25` | `d79a527275b0bb02c46a9251d4ec5cb60bd1205424b0e4069a7c91d84d32bd25` | `d79a527275b0bb02c46a9251d4ec5cb60bd1205424b0e4069a7c91d84d32bd25` | 0 |
| `pandora_source_snapshots` | 56 | 56 | 56 | `a42dcc4607ff5c975a0ebea015167cc2b679d7279979fd5bd12a8e107ea8f4e4` | `a42dcc4607ff5c975a0ebea015167cc2b679d7279979fd5bd12a8e107ea8f4e4` | `a42dcc4607ff5c975a0ebea015167cc2b679d7279979fd5bd12a8e107ea8f4e4` | 0 |
| `priority_locks` | 1 | 1 | 1 | `6a9d60780a1a0fc68a16a0914ccbab4c8a10ecb096439c34c3d8f09a2059dc99` | `6a9d60780a1a0fc68a16a0914ccbab4c8a10ecb096439c34c3d8f09a2059dc99` | `6a9d60780a1a0fc68a16a0914ccbab4c8a10ecb096439c34c3d8f09a2059dc99` | 0 |

**Result:** All 25 tables match: counts, per-row source hashes, aggregate checksums and destination JSONB readback.

## Public tables deliberately omitted

These 56 public tables and 14,139 rows were not copied. They remain on the Sydney source. The exclusions are raw audit/retrieval telemetry, environment and gateway identity/security metadata, source snapshot file bodies, empty or unused operator/promotion workflow tables, and unrelated business/relationship/story-domain tables. Credential/key and identity-control tables were excluded rather than copied into a shared PLP database.

| Omitted source table | Rows left on source |
|---|---:|
| `au_character_states` | 0 |
| `au_characters` | 0 |
| `au_consequences` | 0 |
| `au_open_threads` | 0 |
| `au_quality_reviews` | 0 |
| `au_relationship_states` | 0 |
| `au_relationships` | 0 |
| `au_retcons` | 0 |
| `au_rules` | 0 |
| `au_scenes` | 0 |
| `au_worlds` | 0 |
| `audit_logs` | 3,675 |
| `business_deals` | 0 |
| `business_entities` | 0 |
| `decision_gates` | 0 |
| `decisions` | 0 |
| `env_audit_events` | 3 |
| `env_key_versions` | 1 |
| `env_managed_keys` | 3 |
| `env_managed_projects` | 1 |
| `gateway_audit_events` | 1,770 |
| `gateway_grants` | 10 |
| `gateway_principals` | 4 |
| `gateway_service_actions` | 19 |
| `idempotency_records` | 3 |
| `memory_embeddings` | 0 |
| `memory_feedback_events` | 0 |
| `memory_ingest_response_cache` | 0 |
| `memory_model_call_logs` | 0 |
| `memory_profiles` | 0 |
| `memory_pruning_candidates` | 0 |
| `memory_retrieval_logs` | 8,029 |
| `pandora_ingestion_failures` | 0 |
| `pandora_operator_action_events` | 0 |
| `pandora_operator_actions` | 0 |
| `pandora_project_grants` | 22 |
| `pandora_promotion_execution_events` | 0 |
| `pandora_promotion_executions` | 0 |
| `pandora_promotion_request_events` | 0 |
| `pandora_promotion_requests` | 0 |
| `pandora_service_principals` | 4 |
| `pandora_shadow_context_pack_events` | 0 |
| `pandora_shadow_context_packs` | 0 |
| `pandora_shadow_pack_preflight_events` | 0 |
| `pandora_shadow_pack_preflights` | 0 |
| `pandora_source_snapshot_files` | 595 |
| `pandora_sync_runs` | 0 |
| `people` | 0 |
| `promises` | 0 |
| `prompt_logs` | 0 |
| `raw_movement_items` | 0 |
| `relationship_events` | 0 |
| `relationships` | 0 |
| `retrieval_logs` | 0 |
| `risks` | 0 |
| `work_sessions` | 0 |

The 12 private source tables were also not copied: `flutterflow_credential_handoffs`, `flutterflow_github_oidc_attempts`, `flutterflow_github_oidc_grants`, `flutterflow_integration_credentials`, `flutterflow_project_snapshots`, `flutterflow_project_yaml_files`, `memory_pandora_planning_nonces`, `memory_project_binding_receipts`, `memory_projectos_planning_nonces`, `pandora_integration_credentials`, `pandora_ops_memory_receipts_v1`, `pandora_recovery_auth_changes`. They remain in the dedicated source project and were outside the 25-table durable-memory archive scope.

## Tokyo staging objects — live-only, not canonical

The following objects exist only live in project `xyefkykwuppbweabvvmk`; they are absent from the repository's 143 committed migration history. There is no committed SQL migration for them.

- Schema `pandora_memory_native`: 28 tables; RLS enabled on 28; disabled on 0.
- Schema `pandora_memory_migration`: 2 tables; RLS enabled on 2; disabled on 0.
- Archive `pandora_memory_migration.records`: 12,763 rows; verification receipt ledger: 7 rows.
- The 28 native tables consist of the 25 restored table names above plus runtime support tables `pandora_service_principals`, `pandora_project_grants`, and `pandora_ops_memory_receipts_v1`.
- Live support table counts: service principals 1; project grants 7; operation receipts 67.
- Two post-snapshot model-outcome candidates and their two review items were added to the staging copy after the archive. They are not part of the 12,763-row migration checksum and are not canonical source records:
  [{"id":"a7e7aedf-96df-4f94-af6c-1d68887fee36","created_at":"2026-11-24T23:01:46.717339+00:00","source_ref":"model-run:107b1ac3-4861-449a-bfcd-331adb046688"},{"id":"1f6f7fc8-ca03-40dc-92c1-f22af9b3eb6a","created_at":"2026-11-25T00:15:21.466076+00:00","source_ref":"model-run:9f624e47-21aa-41ab-9d1a-55c15262c417"}]
  [{"id":"03a73b13-7595-4a73-b163-37e74c074c52","status":"pending_review","created_at":"2026-11-24T23:01:46.717339+00:00","source_ref":"model-run:107b1ac3-4861-449a-bfcd-331adb046688"},{"id":"ef275b7c-cd27-4db9-8de6-1c8d892d82e2","status":"pending_review","created_at":"2026-11-25T00:15:21.466076+00:00","source_ref":"model-run:9f624e47-21aa-41ab-9d1a-55c15262c417"}]
- The staging runtime role has NOLOGIN, NOINHERIT and NOBYPASSRLS; it is not a member of service_role or anon. Its table-level grants are restricted to the native schema:
  [{"table":"memory_capture_candidates","schema":"pandora_memory_native","privilege":"INSERT"},{"table":"memory_capture_candidates","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"memory_items","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"memory_review_queue_items","schema":"pandora_memory_native","privilege":"INSERT"},{"table":"memory_review_queue_items","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"operating_project_constraints","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"operating_project_decisions","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"operating_project_open_loops","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"pandora_memory_conflicts","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"pandora_ops_memory_receipts_v1","schema":"pandora_memory_native","privilege":"INSERT"},{"table":"pandora_ops_memory_receipts_v1","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"pandora_project_grants","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"pandora_projects","schema":"pandora_memory_native","privilege":"SELECT"},{"table":"pandora_service_principals","schema":"pandora_memory_native","privilege":"SELECT"}]
- No source-of-truth SQL migration has been committed for these live-only staging objects. The repo README explicitly marks the Tokyo function snapshots as NOT CANONICAL and not deployable.

## PLP / Pandora Connect isolation

| Existing schema group | Tables | RLS enabled | RLS disabled | Tables accessible to pandora_memory_runtime |
|---|---:|---:|---:|---:|
| `pandora_connect` | 14 | 14 | 0 | 0 |
| `plp_runtime` | 1 | 1 | 0 | 0 |
| `public` | 17 | 17 | 0 | 0 |

The Memory runtime role has zero table privileges across these existing PLP / Pandora Connect objects. The migration/restoration DDL created only the isolated Memory staging schemas/role and grants; it did not alter PLP or Pandora Connect tables, policies, roles or grants. The new production plan avoids this shared project entirely.

## Operational decision

Use `ivmvufhcsezyhczzondn` for Memory. Keep control plane `jcyqixttuebxqqfkjonq` separate. Keep `xyefkykwuppbweabvvmk` dedicated to its existing PLP / Pandora Connect responsibilities. Do not promote the Tokyo staging schema or deploy the Tokyo edge snapshots.
