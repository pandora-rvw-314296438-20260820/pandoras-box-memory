
# Pandora Tax & Compliance Operating System — Master Plan V1

Status: Owner-approved architecture and implementation plan
Decision date: 2026-09-25
Canonical Memory project: pandoras-box-memory
Primary implementation repo: pandora-rvw-314296438-20260820/pandoras-box
Initial jurisdiction: Philippines, with jurisdiction adapters for expansion

## Product goal

Turn Pandora from a tax Q&A assistant into a supervised, evidence-backed tax and compliance operating system that continuously prepares, validates, explains, forecasts, and orchestrates tax work while keeping legally significant filing, payment, credential, OTP, signature, and professional-judgment steps behind explicit authorized-human approval.

Target user experience:

"Pandora, prepare my September taxes."

Pandora should gather and reconcile authorized business records, identify missing evidence, calculate supported tax obligations through deterministic rules, prepare the filing package, run validations, explain exceptions, route professional-review items to the accountant or authorized reviewer, and present the final filing/payment action for explicit approval where required.

## 1. Core principles

1. Deterministic calculations, AI-assisted interpretation.
AI may read and classify documents, extract fields, normalize counterparties, suggest categories, detect anomalies, summarize issues, and explain calculations. AI must not be the final arithmetic or rules authority.

A versioned deterministic rules engine must calculate tax bases, rates, thresholds, periods, credits, carryovers, withholding, penalties where supported, and filing totals. It must produce reproducible results, retain the exact rule-pack version used, and fail closed when required data or governing rules are missing.

2. Evidence before assertion.
Every material tax number must trace to source transaction/document, extraction/classification, accounting treatment, rule-pack version, calculation output, adjustments, and reviewer/owner approval when required.

3. Human approval at legal boundaries.
Pandora may autonomously prepare and validate work but must stop before legally binding filing, taxpayer declarations, OTP/MFA, signatures, tax payments, material tax elections, or aggressive/uncertain positions requiring professional judgment.

4. No fabricated compliance.
Pandora must never claim a filing or payment succeeded without external confirmation. It must never mark an obligation complete while required evidence is missing, or claim rules are current when the rule pack is stale/unverified.

5. Customer tax data stays out of canonical Memory.
Pandoras-box-memory stores architecture decisions, verified lessons, rule-source provenance, provider behavior, implementation evidence, and generalized learning. It must not store raw customer financial records, tax returns, receipts, payroll records, bank statements, KYC, taxpayer credentials, OTPs, or customer-specific regulated evidence. Operational tax data remains in the customer/business data plane with strict tenant isolation.

## 2. Architecture

The system has nine layers.

### A. Source ingestion
Authorized connectors ingest POS/booking revenue, invoices/receipts, supplier bills, banking/payment transactions, payroll summaries, accounting exports, withholding certificates, customs/import records where relevant, expense claims, email attachments, uploaded files, prior returns/payment confirmations, and government acknowledgements where accessible.

Each ingestion record stores tenant/workspace ID, source system, source object ID, retrieval timestamp, content hash, currency, document/transaction date, immutable provenance pointer, and ingestion status.

### B. Document understanding
Pipeline:
- classify document type;
- extract fields;
- attach confidence;
- normalize supplier/customer identities;
- detect duplicates;
- link evidence to payments/transactions;
- route low-confidence extraction to review.

Original evidence remains preserved and viewable by authorized users.

### C. Canonical tax ledger
Each ledger item records transaction ID, evidence IDs, counterparty, amounts, currency, accounting category, tax category, business purpose, tax period, deductible/non-deductible state where applicable, withholding state, input/output tax treatment where applicable, confidence, rule-pack version, reviewer state, and adjustment history.

The ledger must be reconstructable from source evidence.

### D. Reconciliation engine
Continuously checks invoice-to-payment, receipt-to-expense, sales-to-settlement, revenue subsystem-to-ledger, payroll-to-payments, withholding certificate-to-receivable/payable, tax ledger-to-prior filing, filing-to-payment confirmation, and prior-period closing-to-current opening balance.

Unmatched or inconsistent records become explicit exceptions.

### E. Versioned tax rules engine
Separate deterministic service/library with jurisdiction-specific rule packs, effective dates, official-source provenance, change history, review status, automated regression tests, sample cases, and strict separation of verified rules from drafts.

The Philippines adapter is first. Additional jurisdictions are separate rule packs, not scattered conditionals.

### F. Tax position and forecasting engine
Maintains current estimated liabilities, credits/carryovers, expected filing dates, unresolved evidence, projected obligations, and expected cash requirement.

Forecasts distinguish booked actuals, estimated actuals, forecasts, and user-entered scenarios.

### G. Filing package builder
Builds calculated return figures, schedules, reconciliation, exception list, supporting-document index, reviewer notes, rule-pack version, calculation checksum, preparer identity, and approval state.

Where a verified supported filing interface exists, an adapter may submit after required approval. Otherwise Pandora produces a review-ready package and guides the authorized user through submission.

### H. Approval and professional review
States:
Draft
Data incomplete
Ready for internal review
Requires accountant/CPA judgment
Ready for owner/authorized-signatory approval
Approved for filing
Submitted
Accepted/acknowledged
Paid
Completed
Amended
Superseded

Every transition is auditable. Material adjustments record actor, old value, new value, reason, evidence, and timestamp.

### I. Audit, observability, and learning
Record real events for ingestion, extraction, classification, reconciliation, rule evaluation, calculation, exception creation, review, approval, submission, acknowledgement, payment, retry/failure, rollback, and amendment.

Build Theatre and Activity Theatre must use real execution events only.

## 3. Tax & Compliance command center

Lives under Finance / Sales & Finance and is accessible from persistent Message Pandora.

Main screen:
- Current estimated tax position
- Next deadline
- Ready-to-file obligations
- Items needing attention
- Missing evidence
- Outstanding tax payments
- Recent completed filings

Sections:
Tax Overview
Current Period
Reconciliation
Exceptions
Documents & Evidence
Returns & Filings
Payments
Certificates
Forecasting
Accountant Review
Compliance Calendar
Audit Trail
Rules & Jurisdiction

Natural-language commands:
- Prepare September taxes.
- How much tax do we currently expect to pay?
- Why did our tax payable increase?
- Find expenses missing receipts.
- Reconcile this month's sales.
- Show transactions with uncertain tax treatment.
- Prepare everything for our accountant.
- What filings are due in the next 30 days?
- Compare buying this equipment this month versus next quarter.
- Show me exactly where this number came from.
- What changed since the accountant's last review?
- Close the month for tax.

High-impact commands show an execution plan and live real state, then request approval only at the genuine approval boundary.

## 4. Logical data model

Source/evidence:
tax_source_connections
tax_source_objects
tax_documents
tax_document_extractions
tax_document_links
tax_evidence_hashes

Ledger/classification:
tax_ledger_entries
tax_entry_classifications
tax_entry_adjustments
tax_counterparties
tax_accounts
tax_periods

Rules:
tax_jurisdictions
tax_rule_packs
tax_rules
tax_rule_sources
tax_rule_tests
tax_rule_reviews

Reconciliation:
tax_reconciliation_runs
tax_reconciliation_matches
tax_exceptions
tax_exception_resolutions

Calculations/returns:
tax_calculation_runs
tax_calculation_lines
tax_obligations
tax_returns
tax_return_versions
tax_return_schedules
tax_filing_packages

Review:
tax_reviews
tax_review_comments
tax_approvals
tax_signatory_requirements

Submission/payment:
tax_filing_attempts
tax_filing_acknowledgements
tax_payment_intents
tax_payment_attempts
tax_payment_confirmations

Forecasting:
tax_forecasts
tax_forecast_assumptions
tax_scenarios

Audit:
tax_audit_events
tax_access_events
tax_rule_change_events

All customer-facing tables are tenant-scoped, RLS-protected, and denied by default.

## 5. AI vs deterministic responsibilities

Local/smaller models, only where performance is verified:
basic document classification, simple field extraction, merchant normalization, low-cost categorization suggestions, and plain-language formatting.

Cloud reasoning models:
complex document interpretation, ambiguous multi-document reconciliation, explaining exceptions, potential treatment candidates, long-document review, and accountant-facing summaries.

Deterministic code only:
arithmetic, period boundaries, rate application, thresholds, carryovers, return totals, checksums, filing-state transitions, permission checks, approval requirements, idempotency, and audit events.

Provider/model choices are measured by workload and recorded as verified provider evidence. No model becomes preferred because of one anecdotal success.

## 6. Rule governance

Every production tax rule requires:
- authoritative source or controlled professional interpretation;
- jurisdiction;
- effective date;
- supersession date where applicable;
- reviewer;
- test vectors;
- edge cases;
- version;
- change rationale;
- approval record.

Update workflow:
detect legal/regulatory change
capture source
draft rule change
independent review
historical/forward tests
approve
release new pack
monitor
preserve prior version

Historical tax rules are never overwritten.

## 7. Philippines-first adapter

The first adapter supports Philippine business tax workflows but must not hard-code current tax rates or filing mechanics into conversational prompts.

It represents:
registration profile and tax types
tax periods
VAT/non-VAT treatment where applicable
withholding obligations where applicable
income-tax computation inputs
payroll-related tax inputs where authorized
tax credits/certificates
statutory filing/payment deadlines
filing-channel capabilities
amendment workflows
evidence/retention requirements

Before live calculation or filing, each rule and provider integration must be validated against current authoritative guidance and, for material production use, reviewed by an authorized tax professional.

## 8. Integration strategy

Accounting/ERP:
normalize into canonical tax ledger instead of embedding provider assumptions.

Banking/payments:
read/reconciliation first. Tax payment execution is a separately privileged capability requiring explicit approval and strong authentication.

Email/document stores:
discover authorized evidence while preserving source links, permissions, and hashes.

Payroll:
minimum necessary fields only; narrower permissions than general finance.

Government filing systems:
adapter per verified channel with explicit capability flags:
read only
prepare only
submit
acknowledgement retrieval
payment
amendment

Never imply API support before verification.

## 9. Security

Minimum controls:
tenant isolation
RLS and least privilege
service-role access only inside protected server boundaries
vault-backed secrets
no secrets in GitHub, logs, prompts, client bundles, or Memory
encryption in transit and at rest
signed hashes
immutable audit for material actions
MFA/step-up auth for filing/payment
role-based approval
idempotency for submissions/payments
replay protection
rate limits
structured redaction
retention/deletion policy
audit export
incident response
privileged-action alerts

Suggested roles:
Owner
Finance Admin
Bookkeeper
Accountant/CPA Reviewer
Tax Preparer
Authorized Signatory
Read-only Auditor

No role silently bypasses required approval gates.

## 10. Accountant workspace

Optimized for exceptions, not redoing machine work.

Shows:
period summary
reconciliation status
material changes since last review
unresolved exceptions
uncertain classifications
draft calculations
rule/source references
evidence
prior-period comparison
proposed adjustments
sign-off control

Accountant corrections are structured adjustments. Repeated verified corrections may become candidate generalized learning, but not new tax rules without rule-governance review.

## 11. Exception management

Typed exceptions include:
Missing receipt
Duplicate invoice
Unmatched payment
Tax ID mismatch
Missing withholding certificate
Unknown tax category
Rule ambiguity
Period mismatch
Currency mismatch
Filing mismatch
Payment mismatch
Provider error
Stale tax rule
Required professional judgment

Each exception includes severity, amount at risk, deadline impact, responsible person, recommended next action, evidence, and resolution state.

Pandora prioritizes high-risk/high-value exceptions rather than a generic to-do list.

## 12. Forecasting

Support scenario analysis for:
capital purchase now vs later
seasonal revenue changes
staffing structure comparisons subject to review
large supplier prepayments
tax cash requirements
growth/threshold scenarios
late collections and cash impact

Each forecast states assumptions, data period, rule-pack version, uncertainty, and whether professional review is recommended.

## 13. Filing and payment orchestration

Preparation: autonomous with permission.
Review: exceptions and judgments routed automatically.
Approval: explicit authorized-user action.
Submission: verified adapter or supervised process with exact confirmation.
Payment: separate explicit approval even after filing approval.
Completion: only after provider acknowledgement and, where relevant, payment confirmation.

Completed records retain final filing package hash, submission timestamp, acknowledgement/reference, payment state/reference, rule-pack version, and approval evidence.

## 14. Real theatre events

Allowed:
Source connected
Records imported
Document parsed
Reconciliation started/completed
Exception detected
Calculation started/completed
Review requested
Adjustment made
Approval requested/approved
Submission started/failed/retried/acknowledged
Payment approval requested
Payment initiated/confirmed
Period completed
Amendment opened/completed

No fake thinking, fake percentages, or simulated completion.

## 15. Implementation roadmap

Phase 0 — Architecture/contracts
Deliver domain model, threat model, permission model, event contract, rule-pack contract, provenance contract, UX information architecture, acceptance tests.
Exit: AI, deterministic, professional-judgment, submission, and payment boundaries explicit.

Phase 1 — Tax evidence inbox
Deliver uploads, authorized email/drive ingestion, receipt/invoice parsing, hashes, duplicate detection, review queue.
Exit: extracted fields trace to evidence; low-confidence fields reviewable.

Phase 2 — Canonical tax ledger
Deliver normalized transactions, classifications, adjustments, counterparties, period assignment, source linking.
Exit: ledger rebuilds from source and produces stable checksums.

Phase 3 — Reconciliation
Deliver invoice-payment, sales-payment, expense-evidence, filing-ledger comparison, exception workflow.
Exit: known datasets reconcile deterministically; differences remain explicit.

Phase 4 — Versioned Philippines rule engine
Deliver rule schema, official-source provenance, initial verified rules, unit/regression tests, historical replay.
Exit: calculations reproducible by rule version and independently reviewed.

Phase 5 — Tax command center
Deliver overview, periods, exceptions, evidence, calculations, accountant review, audit trail, persistent chat commands.
Exit: authorized user can reach a review-ready period inside Pandora.

Phase 6 — Filing package generation
Deliver return mapping, schedules, evidence index, review package, export artifacts.
Exit: professional reviewer can verify complete package from evidence trail.

Phase 7 — Supervised filing adapters
Only for verified channels: auth boundary, submission adapter, acknowledgement retrieval, idempotency, retry, recovery.
Exit: authorized test/production submission has exact provider confirmation.

Phase 8 — Tax payment orchestration
Deliver payment intent, approval, supported adapter, settlement confirmation, reconciliation.
Exit: explicit authorization and duplicate-payment protection proven.

Phase 9 — Forecasting/proactive compliance
Deliver live tax position, deadlines, cash forecast, scenario modeling, proactive missing-evidence alerts.
Exit: actual, estimated, and hypothetical clearly separated.

Phase 10 — Multi-jurisdiction framework
Deliver adapter SDK, jurisdiction registry, rule-pack publishing workflow, professional-review certification.
Exit: second jurisdiction added without modifying core ledger/reconciliation architecture.

## 16. Acceptance criteria for "Prepare my taxes"

A period is Ready for Approval only when:
- expected source syncs completed or explicitly waived;
- ingestion failures visible;
- duplicate detection ran;
- reconciliation ran;
- unresolved differences are within approved thresholds or reviewed;
- required evidence exists or missing evidence is disclosed;
- calculations use an approved current rule pack;
- material assumptions visible;
- professional-judgment exceptions have reviewer state;
- filing package versioned and hashed;
- every material total drills to supporting records;
- final approval is required before legally binding submission.

## 17. Testing

Unit:
rule calculations, rounding, boundaries, thresholds, carryovers, idempotency, permissions.

Golden tax cases:
approved synthetic examples with expected results per rule pack.

Reconciliation:
duplicates, partial payments, split transactions, refunds, reversals, foreign currency, amended records, late documents, period mismatches.

Security:
cross-tenant denial, role boundary denial, privilege escalation, secret leakage, replay attacks, duplicate payment/submission, prompt injection via documents.

Failure:
provider outage, partial ingestion, stale rules, unavailable government endpoint, lost acknowledgement, submission timeout, pending payment, duplicate webhook.

Release proof:
production claims require tests against the exact source/build/deployment released, with provider readback where applicable.

## 18. Observability

Measure:
ingestion success/failure
extraction accuracy after review
classification correction rate
reconciliation match rate
exception aging
calculation duration
rule error rate
filing success/failure
payment success/failure
duplicate-prevention activations
time saved per period
accountant adjustments per period
provider/model performance by workload
cost per processed document/period

Do not optimize by hiding uncertainty.

## 19. Memory learning contract

After meaningful tax work, ask:
"What should Pandora learn from this so the next decision is better?"

Eligible durable learning:
provider reliability
model performance by document type
independently verified reconciliation heuristics
implementation failures and fixes
verified architecture decisions
rule-engine lessons
workflow bottlenecks
filing-adapter behavior
test cases from confirmed defects
professional-review patterns safe to generalize

Not eligible:
raw receipts
customer transaction details
taxpayer IDs
tax return contents
payroll
bank details
credentials
OTPs
unreviewed model guesses
one-off customer facts with no generalized value

Retain provenance and classify verified fact, owner decision, provider evidence, professional interpretation, model inference, assumption, and superseded information.

## 20. Rollout

Stage A — Internal/synthetic.
Stage B — Shadow mode: real authorized records, no submission; compare to accountant results.
Stage C — Assisted preparation: Pandora package; accountant/owner files through existing process.
Stage D — Supervised submission through independently verified channels after explicit approval.
Stage E — Supervised payment only after separate security and duplicate-prevention proof.
Stage F — Proactive operation: continuously prepare obligations and surface exceptions/approval gates.

No stage is skipped because a demo looks successful.

## 21. V1 definition of done

For an authorized Philippine business workspace Pandora can:
- ingest agreed source records;
- preserve evidence provenance;
- build canonical tax ledger;
- reconcile period;
- prioritize exceptions;
- calculate supported obligations with reviewed deterministic rule pack;
- drill from material totals to evidence;
- generate review-ready filing package;
- provide accountant review;
- enforce signatory approval;
- retain immutable audit trail;
- prove cross-tenant isolation;
- survive provider failures without false completion;
- reproduce old calculations from historical rule versions;
- record real Build/Activity Theatre events;
- pass exact-source acceptance tests.

Live filing and payment are optional V1 unless provider contracts are verified. UI alone is not proof.

## 22. First engineering sequence

1. Tax domain schema and RLS.
2. Evidence inbox and hashing.
3. Canonical tax ledger.
4. Reconciliation engine.
5. Exception model.
6. Versioned rules-engine interface.
7. Philippines rule-pack governance/test harness.
8. Tax command-center read UI.
9. Prepare-period orchestration.
10. Accountant review.
11. Filing-package export.
12. Verified filing adapter only after provider proof.
13. Payment orchestration only after separate approval/security proof.
14. Forecasting and proactive compliance.
15. Cross-jurisdiction adapter SDK.

## 23. Non-negotiables

Do not use LLM arithmetic as tax authority.
Do not hard-code tax law in prompts.
Do not mark filing/payment complete without external confirmation.
Do not store customer financial/tax data in canonical Pandora Memory.
Do not expose credentials/secrets.
Do not bypass accountants/signatories where professional/legal approval is required.
Do not overwrite historical rules or filings.
Do not allow cross-tenant leakage.
Do not fake Build Theatre or Activity Theatre.
Do not deploy tax rules without tests and provenance.
Do not let a model promote its own unverified interpretation into canonical rules.

## 24. Product outcome

The finished product behaves like a continuously operating tax department: it knows what records exist, what is missing, reconciles continuously, calculates from versioned rules, traces every material number, prepares before deadlines, escalates only genuine exceptions/judgment calls, gives accountants a review surface rather than a pile of documents, obtains human approval at correct legal boundaries, and learns from verified outcomes.

The user experience remains simple:

"Pandora, prepare September taxes."

Pandora performs the operational work, returns unresolved exceptions, shows estimated liability and evidence trail, and advances the filing only to the next authorized state without overstating completion.
