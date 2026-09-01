# Memory Cross-Project Generalization & Zero-Leakage Contract

Status: source-readiness contract only. This document does **not** authorize production cross-project learning, new runtime authorities, schema changes, or cross-project retrieval.

## Purpose

Cross-project recurrence can be useful only after it is transformed into a privacy-safe, non-reversible abstraction. Source Memory rows remain bound to their original identity, namespace, project, grant, governance and evidence.

The permanent sequence is:

`same-project governed evidence -> verified same-project pattern -> privacy transform -> re-identification check -> generalized candidate -> review -> canon`

Never:

`project A record -> direct retrieval by project B`

## Authority and dependency boundary

- Fresh provider truth wins mutable external facts.
- Current exact-project Memory retrieval remains authoritative and must not be weakened.
- Existing candidate -> append-only review -> approved canonical governance is reused.
- Tasks 31-32 remain prerequisites for the future runtime source of verified same-project playbook/pattern eligibility.
- Tasks 39-42 remain prerequisites for production security/lifecycle readiness.
- This contract creates no generalization table, RPC, Edge Function, API route or alternate learning gateway.

## Source-only baseline

The 2026-09-01 aggregate snapshot proves:

- 3,496 capture candidates; 3,463 carry project identity and project key.
- 3,464 review items; all carry a project key, source reference and fingerprint; all are append-only and review-required; none are persisted.
- Privacy-safe ProjectOS learning has zero imported secrets, personal identifiers, raw arguments, raw results or raw errors.
- 13 error-fingerprint families recur across multiple projects (329 source episodes, up to 9 projects).
- 1 result-fingerprint family recurs across multiple projects (2,826 source episodes, 6 projects).
- There are zero exact content-hash groups duplicated across projects.
- There is no current table or routine named for generalization, playbooks, patterns or abstractions.

Fingerprint recurrence is a discovery signal only. It is not permission to reveal, retrieve, merge, promote or canonize source records across projects.

## Generalized candidate payload

A future generalized candidate may contain only normalized, non-customer-specific semantics such as:

- task class
- tool class
- risk class
- generalized failure class
- generalized action/repair family
- preconditions
- failure modes
- verification procedure
- confidence and aggregate sample count

The generalized payload must not contain source-project lineage or content that can identify a customer/project. Exact source provenance stays in governed audit/evidence authority and must not be exposed as cross-project Memory content.

## Forbidden in cross-project generalized content

Reject a generalized payload if it contains or preserves any source-specific value or field such as:

- user_id, customer_id, organization_id
- project_id, project_key, project name or project array
- namespace copied into generalized content
- source_ref, source_event_id, source_request_id, intake_id
- candidate/review/Memory record IDs
- raw_excerpt, raw_content, normalized_text copied from source, raw arguments/results/errors
- emails, phone numbers, customer names
- repository names/URLs, domains, deployment IDs, provider resource IDs
- exact commit/tree hashes or other provider-instance identifiers
- secrets, credentials, tokens, API keys, recovery codes
- customer-specific business facts or implementation details
- exact evidence/proof references intended for the source project's governance trail

## Scope rules

1. Source records are read only under their existing identity -> namespace -> project -> grant boundary.
2. A generalization worker may compare privacy-safe *derived signals* across projects only after source-side eligibility is independently established.
3. Generalization never broadens namespace authorization. Same-namespace is the default ceiling; cross-namespace reuse requires a separate explicit security design and approval.
4. The generalized candidate itself contains no source project identity.
5. Generalized candidates are review-required and never automatically canonical.
6. Re-identification failure rejects the candidate.
7. Unresolved contradiction/conflict rejects the candidate.
8. Missing same-project verified/governed source eligibility rejects the candidate.
9. If stripping identifiers destroys the meaning or verification procedure, do not generalize.
10. Source episodes and immutable evidence are retained; generalization never rewrites or deletes history.

## Zero-leakage acceptance

Before production Task 43-44 implementation can be accepted:

- wrong-project source retrieval must fail closed;
- wrong-namespace source retrieval must fail closed;
- generalized output must contain zero forbidden identifiers/content;
- project-specific source refs must be absent from the generalized payload;
- a generalized result must not allow reconstruction of a source customer/project;
- direct cross-project retrieval of original Memory records remains impossible;
- candidate -> review -> canon governance remains intact;
- adversarial fixtures for identifiers, URLs/domains, deployment IDs, hashes, raw excerpts, secrets, conflicts and missing source eligibility must be rejected.

Zero tolerated cross-customer leakage.

## Non-actions

This source milestone performs no production schema migration, no Edge deployment, no Memory row mutation, no cross-project retrieval, no cross-project write, no generalized candidate creation, no review decision, no canonical promotion, no historical rewrite and no provider mutation.
