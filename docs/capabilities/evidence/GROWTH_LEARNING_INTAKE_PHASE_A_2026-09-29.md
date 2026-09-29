# Growth learning intake Phase A source evidence

Status: SOURCE ONLY / RELEASE AND RUNTIME HOLD.

PR #126 adds review-only intake for the envelope produced by Box PR #804. The adapter targets the existing signed learning route; it does not itself sign, deliver, promote or retrieve learning. The initial source commit is `f38e5129708fa5060410aa7177c034bb3096eb39`, based on Memory main `602e8d02293b7439934c45a8531688412712504e`.

## Source and authority

The frozen seven-file v3 package has SHA-256 `a4781ee70741540e0ffe7bc50fb340e78955ceb31b85c44aab97886777402ef1`; its content bundle is `7db49a57e9828d7f20d5602bac72f072a9b1d138bf70655553c1ea97b1547053`. A separate reviewer checked all file digests, production-schema compatibility, producer serialization, project/grant checks and service-only ACLs. The root coordinator independently executed the parser and SQL regressions.

The source is fixed to Pandora organization `2270b266-59da-4c39-bfd9-9f8d08352af0`, Box project `ee282126-3f61-4058-8c92-2fedbfcecf1f`, Memory project `7c686cbd-d968-49d5-86cc-918f5e777bd2`, namespace `real_life`, and principal `projectos-mcpmaster-production`. The existing active grant must allow proposals and deny approval. No project grant is created or widened.

One atomic service-only RPC verifies normalized content, complete context and deterministic request fingerprints, then creates an existing-model pending candidate and pending review item. Identical replay returns those same identities; conflicting semantics fail closed. The private serialization helpers are not executable by client roles or service_role directly. There is no canonical `memory_items` write.

## Observed verification

- Deno formatting, type check and 11 parser tests passed locally and in the initial exact-head Edge CI run.
- Independent actual Box producer to Memory parser: 18/18 cases passed across six epistemic classes, lowercase/uppercase/null provenance SHA and confidence `1e-7`.
- Independent actual producer to PostgreSQL content and context fingerprints: 18/18 matched.
- Independent reduced-schema PGlite baseline, migration and behavior checks passed with the actual pgcrypto extension and the standard SHA-256 `abc` known vector. The only harness adaptation removed the psql client-only `\set ON_ERROR_STOP on` directive.
- Exact-head GitHub PostgreSQL 16 job `109099114680` passed baseline, migration and behavior at initial commit `f38e5129708fa5060410aa7177c034bb3096eb39`.
- The forged-content regression recomputes the enclosing context and request identity but is rejected with zero candidate or review writes.

The reduced SQL baseline does not replay every production foreign key, RLS policy or trigger. Separate source comparison found the inserts compatible with the canonical schema and existing lineage triggers. These checks establish source behavior, not deployed runtime acceptance.

## CI corrections and historical evidence

Initial CI found a missing parent commit in the shallow checkout, omitted security-adjudication metadata, and missing source-evidence updates. The follow-up fetches two commits for the parent diff, records the completed source security review in migration comments, and appends current source bindings without overwriting historical deployment evidence. The SQL executable body and all three Edge files remain byte-identical to the reviewed v3 package.

At commit `de1a43c709a097010515b98b018d6d5052681d2a`, the unchanged bridge raw SHA-256 is `5e1f1bcdf5e18e96ac433ab836e97f4e532d1c5d11ce85da20ff5d5324eaf64b` and the learning-handler raw SHA-256 is `7bc75666158dacabf02f57720e1d0824b4900e99a8cde68e12d7ba1d504d0b1e`.

## Authenticated routing correction

A separate integration audit found that the existing HMAC binds `tool` and `context_hash`, but not the outer routing markers. Removing `learning_kind` from a signed growth envelope could therefore enter the generic aggregate path and lose the six-class proposal semantics. A disposable actual-handler request test reproduced that fallback; no deployed request or Memory write was performed.

The handler now checks marker consistency after signature validation and before any intake call. Any growth tool, growth binding property or growth kind requires the exact growth tool/kind and an object binding. Invalid markers return `growth_marker_mismatch`; the unchanged strict parser then authenticates the full nested binding against the signed context hash. Generic events without growth markers retain their prior route.

The final handler raw SHA-256 is `f9aad93caab86e216bb9cd94406d77cd9345db6b4b3cb7d50c810f5a2790669b`. Deno passes 12 tests with 13 request-level steps, including six valid classes, marker stripping, malformed bindings, signed-tool tampering, generic compatibility and fixed envelope fields. The harness replaces only the client, environment and listener boundaries of the actual handler. Its read permission is limited to this function directory; it makes no network or provider call. Formatting, type checking, literal-secret and diff checks pass. SQL and parser behavior are unchanged from the previously reviewed package.

## Remaining release boundary

Fresh final-head CI, independent release disposition, governed merge, explicit production activation and provider readback remain required. The future live flow must preserve candidate/review identity and distinguish delivered, reviewed, promoted and retrievable states. Phase B type mapping, reviewer-authorized promotion, expiry, supersession and retrieval are not implemented by this change.

Before activation, keep the growth transport held. If a separately authorized activation fails, stop only the new intake path, restore the verified previous Edge source as needed, and preserve candidates, reviews and existing grants. Do not perform a destructive down migration or retroactively alter historical evidence.
