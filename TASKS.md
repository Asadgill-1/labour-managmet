# Tasks

One small task at a time: requirement ID, GitHub issue, branch, implementation, test, evidence, PR (AI-02). Done means AI-03: wired, persisted, permissioned, offline and error states handled, tests run, docs updated, runnable build.

Every phase also delivers a test APK, sample documents, a 5-minute walkthrough and a Roman Urdu checklist (BUILD-03).

## P0: Foundation

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T01 | Repo, PRD Markdown, AI-01 docs, traceability matrix | AI-01..04, AI-07, AI-08, ARCH-08, BUILD-03 | IMPLEMENTED_UNVERIFIED | `p0/t01-repo-docs` |
| T02 | GitHub Actions, secret scanning, lockfiles, gitignore | AI-05, AI-06 | IMPLEMENTED_UNVERIFIED | `p0/t02-ci` |
| T03 | Spike on a real phone: Flutter shell, encrypted per-tenant DB, Keystore key | ARCH-01, DATA-01 | IMPLEMENTED_UNVERIFIED | `p0/t03-encrypted-db-spike` |
| T04 | Calculation spec, data model, screen flow, ADRs, full test scenarios | UX-01, CALC-01, MODEL-01, MODEL-03, MODEL-04, BUILD-01 | OWNER_ACCEPTED | `p0/t04-specs` |

**Gate:** Assumptions recorded, no hidden scope, policy defaults signed off.

## P1: Local masters, attendance, rates

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T05 | Five-tab shell, l10n, readable UI, save statuses | UX-01..04, UX-07 | IMPLEMENTED_UNVERIFIED | `p1/t05-shell` |
| T06 | Schema v1, migrations harness, outbox, audit, local tenant | MODEL-01, MODEL-03, MODEL-04, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p1/t06-schema` |
| T07 | Company, clients, sites, workers, archive | MASTER-01..04, MASTER-07 | NOT_STARTED | - |
| T08 | Rate cards and opening balances | MASTER-05, MASTER-06 | NOT_STARTED | - |
| T09 | Calculation engine with PRD fixtures | CALC-01..07 | NOT_STARTED | - |
| T10 | Bulk attendance, exceptions, duplicates, midnight shift, corrections | ATT-01..09, UX-05, UX-06 | NOT_STARTED | - |

**Gate:** Arithmetic, duplicate and offline-save tests pass. 10-worker entry shown on a phone.

## P2: Payroll and ledgers

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T11 | Payroll run, posting, carry-forward, deductions | PAY-01..04, PAY-07, REP-08, MODEL-07 | NOT_STARTED | - |
| T12 | Advance sub-ledger, salary payments and allocations, overdue alerts | PAY-05, PAY-06, PAY-08 | NOT_STARTED | - |
| T13 | Expenses and period close | REP-04, REP-05, REP-07 | NOT_STARTED | - |

**Gate:** PRD examples and month-close reconciliation pass.

## P3: Timesheets, invoices, documents

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T14 | Shared document engine: letterhead, snapshots, share sheet, payslip | DOC-01..08, PAY-09 | NOT_STARTED | - |
| T15 | Timesheets, revisions, billed allocation | TS-01..08 | NOT_STARTED | - |
| T16 | Invoices, VAT, numbering, credit notes, e-invoice labelling and structured export | INV-01..04, INV-06, INV-08, INV-09 | NOT_STARTED | - |
| T17 | Receipts, status, client statement | INV-05, INV-07 | NOT_STARTED | - |
| T18 | Tenant reports, export, CSV import | REP-01..03, REP-06, MASTER-08 | NOT_STARTED | - |

**Gate:** PDF review, duplicate-billing and numbering tests pass.

## P4: Auth, isolation, backup, Solo licence

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T19 | Supabase schema, RLS, two-tenant tests, SMTP, signup, device unlock, deletion | AUTH-01..08, ARCH-02, ARCH-07, MODEL-02, MODEL-05, MODEL-06, UX-02 | NOT_STARTED | - |
| T20 | Encrypted backup, restore, device change, sequence reconciliation | DATA-02..08 | NOT_STARTED | - |
| T21 | Signed entitlements, offline lease, versioned plan config, safe expiry | BILL-02, BILL-03, BILL-05, BILL-06, PLAN-03, PLAN-04, PLAN-06 | NOT_STARTED | - |

**Gate:** Two-tenant security, SMTP and device-restore tests pass.

## P5: Owner dashboard

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T22 | Admin web with MFA, customers, manual payments, renewals, audit log | ADMIN-01..03, ADMIN-08, BILL-01, BILL-04, ARCH-03 | NOT_STARTED | - |
| T23 | Telemetry, investor metrics, health, support tickets, alerts, budget limits | ADMIN-04..07, MET-01..07, OPS-01..06, OPS-08, ARCH-05, ARCH-06 | NOT_STARTED | - |

**Gate:** Real-source metrics, admin MFA and error-ticket tests pass. Solo pilot allowed from here.

## P6: Manager and paid sync

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T24 | Invites, permission presets, payload isolation, trial | TEAM-01..03, PLAN-01, PLAN-02, PLAN-05 | NOT_STARTED | - |
| T25 | Sync ADR, two-device sync, conflicts, revocation, downgrade, server numbering | TEAM-04..08, ARCH-04 | NOT_STARTED | - |

**Gate:** Two-device conflict, revoke and restore tests pass. No manager upsell before this.

## P7: Release readiness

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T26 | Independent reviews, pilot fixes, benchmarks, store forms, full regression | BILL-07..09, BUILD-02, BUILD-04..06, OPS-07, QA-01 | NOT_STARTED | - |

**Gate:** Store, billing and privacy gates plus full regression pass. Only now a release candidate.
