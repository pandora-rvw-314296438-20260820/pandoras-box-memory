# Memory approved-canon retrieval gate — 2026-09-06

## Scope

This evidence record covers the review-gated change in PR #47 that prevents canonical Memory from being returned as authority unless the Memory item carries both an explicit approver receipt and approval timestamp.

## Source binding

- Repository: `pandora-rvw-314296438-20260820/pandoras-box-memory`
- Base main before this candidate: `1bd87da01b46773e1b6fbc43479b0274a3497757`
- Candidate bridge raw SHA-256: `76b678fec40064c3de0185d81830baf927e36395370a454c2e214d2054ed712e`
- Canonical Memory project: `mcpmaster-pandoras-box`
- Production principal: `projectos-mcpmaster-production`

## Candidate contract

- `pandora-projectos-bridge` filters active canonical Memory to rows with non-null `approved_by` and `approved_at`.
- `pandora-projectos-planning-context` applies the same explicit approval-receipt requirement.
- Migration `20260906041000_memory_approved_canon_retrieval_gate_v1.sql` updates `memory_context_pack_v2` to count and retrieve approval-backed canonical Memory only.
- No principal scope is broadened.
- No project grant is broadened.
- No automatic approval or canonical promotion is introduced.
- Legacy hard-canon rows without approval receipts remain durable history but are excluded from retrievable authority.

## Verification gate

The exact PR head must pass the Memory capability registry, evidence-intake activation, security adjudication, project-isolation, migration-lineage, lifecycle, quality, and generalization gates before merge.


## Production repair — 2026-09-06

Production readback after the first activation exposed two exact defects in `memory_context_pack_v2`: it referenced nonexistent `pandora_projects.name`, and three Memory-backed retrieval branches did not repeat the approval-receipt predicate used by the eligibility count.

- Provider duplicate receipt: `20260906043524_memory_approved_canon_retrieval_gate_v1`
- Production repair receipt: `20260906043655_memory_approved_canon_retrieval_gate_v1_repair`
- Repair uses `pandora_projects.canonical_name`.
- All four Memory-backed ContextPack branches require non-null `approved_by` and `approved_at`.
- Live post-repair proof returned only approval-backed canonical/negative Memory while active unapproved hard-canon rows remained present, proving exclusion rather than absence.
