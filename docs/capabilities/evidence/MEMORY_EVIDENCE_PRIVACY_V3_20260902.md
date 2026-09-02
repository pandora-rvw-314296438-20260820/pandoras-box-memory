# Memory evidence privacy v3 — Task 94

Candidate scope: evidence-candidate metadata only; no canonical Memory auto-promotion.

Exact candidate bridge SHA-256: `92faeacdfd4b5a63f1594e3f7542911c06a2f9bc738abdcc3ecb6feb74ad05b8`

The `evidence_privacy_v3` classifier rejects before database I/O:

- direct identifiers and credential signatures already covered by v2;
- raw fenced source/code blocks (`raw_source_code_block`);
- conservative unfenced multi-line source chunks (`raw_source_multiline`);
- system/developer/user/assistant prompt transcripts (`prompt_transcript`);
- dotenv-style and JSON configuration dumps (`env_config_dump`);
- percent-encoded and Unicode-normalized variants through the existing decode/normalization boundary.

Behavioral regression: `scripts/test_memory_evidence_intake_behavior.mjs` asserts every rejected case performs zero `FakeAdmin` calls and that a bounded technical outcome summary still reaches the normal project/grant/review-gated persistence path.

Deployment remains separately governed. This evidence file records candidate behavior; it does not claim production deployment or production verification.
