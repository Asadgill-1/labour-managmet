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
| T05 | App shell with left side panel (D-027), l10n, readable UI (D-028), save statuses | UX-01..04, UX-07 | IMPLEMENTED_UNVERIFIED | `p1/t05-shell`, `p1/t05b-side-panel` |
| T06 | Schema v1, migrations harness, outbox, audit, local tenant | MODEL-01, MODEL-03, MODEL-04, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p1/t06-schema` |
| T07 | Company, clients, sites, workers, archive | MASTER-01..04, MASTER-07 | IMPLEMENTED_UNVERIFIED | `p1/t07-masters` |
| T08 | Rate cards and opening balances | MASTER-05, MASTER-06 | IMPLEMENTED_UNVERIFIED | `p1/t08-rates` |
| T09 | Calculation engine with PRD fixtures | CALC-01..07 | IMPLEMENTED_UNVERIFIED | `p1/t09-calc` |
| T10 | Bulk attendance, exceptions, duplicates, midnight shift, corrections | ATT-01..09, UX-05, UX-06 | IMPLEMENTED_UNVERIFIED | `p1/t10-attendance` |
| T10b | Worker groups, and attendance by group or by worker (owner's request, D-029) | ATT-01, ATT-03, CALC-06 | IMPLEMENTED_UNVERIFIED | `p1/t10b-worker-groups` |

**Gate:** Arithmetic, duplicate and offline-save tests pass. 10-worker entry shown on a phone.

## P2: Payroll and ledgers

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T12a | Daily cash book, rooms and room profit or loss (owner's request, D-030, D-031). Taken ahead of T11 | PAY-05, PAY-06, REP-07, REP-08 | IMPLEMENTED_UNVERIFIED | `p2/t12a-cash-book` |
| T11 | Payroll run, posting, carry-forward, deductions | PAY-01..04, PAY-07, REP-08, MODEL-07 | IMPLEMENTED_UNVERIFIED | `p2/t11-payroll` |
| T11b | New colours, main tabs and sub-tabs (owner's request, D-036, D-037) | UX-01, UX-03, UX-04 | IMPLEMENTED_UNVERIFIED | `p2/t11b-look-and-tabs` |
| T11f | Salary slip for WhatsApp, owner's salary sheet by company with profit, worker's own rate shown and changeable when making a group, and everything checked at 1,000 workers (D-042) | PAY-09, REP-01, REP-03, DOC-07, UX-05, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t11f-slip-and-sheet` |
| T11e | Owner's phone feedback: attendance counts in payroll with no approve step, a missing company rate no longer holds pay, room charge by ticking workers, worker register as an account, attendance register with sums (D-041) | ATT-07, PAY-07, CALC-06, REP-01, REP-08, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t11e-phone-feedback` |
| T11d | Three colour themes, chosen in Settings (owner's request, D-040) | UX-04 | IMPLEMENTED_UNVERIFIED | `p2/t11d-themes` |
| T11c | Visa money with monthly instalment through payroll (owner's request, D-039) | PAY-01, REP-08, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t11c-visa` |
| T18a | Eight registers with filters, and PDF, Excel and WhatsApp export (owner's request, D-038) | REP-01, DOC-01, DOC-03, DOC-06, DOC-07 | IMPLEMENTED_UNVERIFIED | `p2/t18a-registers` |
| T12 | Advance sub-ledger, salary payments and allocations, overdue alerts (D-043) | PAY-05, PAY-06, PAY-08, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t12-salary-allocations` |
| T13 | Expenses and period close (D-044) | REP-04, REP-05, REP-07, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t13-period-close` |
| T13c | The whole app redesigned with Hallmark as a bound account book (owner's request, D-046) | UX-01, UX-03, UX-04 | IMPLEMENTED_UNVERIFIED | `p2/t13b-closing-pending` |
| T13b | Nothing closes while anything is left, and what is left shows date by date (owner's request, D-045) | REP-04, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p2/t13b-closing-pending` |

**Gate:** PRD examples and month-close reconciliation pass.

## P3: Timesheets, invoices, documents

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T14 | Shared document engine: letterhead, snapshots, share sheet, payslip (D-047) | DOC-01..08, PAY-09 | IMPLEMENTED_UNVERIFIED | `p3/t14-document-engine` |
| T15 | Timesheets, revisions, billed allocation (D-049) | TS-01..08 | IMPLEMENTED_UNVERIFIED | `p3/t15-timesheets` |
| T16 | Invoices, VAT, numbering, credit notes, e-invoice labelling and structured export, "send with timesheet" (TS-07), a month stopped by work with no invoice (D-048, D-050), lines typed by hand, credit notes for an amount, and a month stopped by work changed after it was invoiced (D-051) | INV-01..04, INV-06, INV-08, INV-09 | IMPLEMENTED_UNVERIFIED | `p3/t16-invoices` |
| T17 | Receipts, status, client statement. An overdue invoice stops a month until paid or closed with a reason (D-048, D-052) | INV-05, INV-07 | IMPLEMENTED_UNVERIFIED | `p3/t17-receipts` |
| T18 | Tenant reports, export, CSV import (D-053). The import screen asks for a backup first since T20a (D-069) | REP-01..03, REP-06, MASTER-08 | IMPLEMENTED_UNVERIFIED | `p3/t18-reports` |
| T18b | Edit and delete everywhere: a Delete tab, an edited colour, the app's note and the user's note, closed months reopened by an edit, and a one-step invoice edit (owner's request, D-056). All three parts are built and tested: attendance, the cash book, workers, companies, sites, rooms, groups, rates, pay items, opening balances, the Delete tab and the one-step invoice edit. Not tried on a phone | ATT-08, REP-08, MODEL-08, MASTER-02, MASTER-04, MASTER-05, MASTER-06, MASTER-07, INV-06 | IMPLEMENTED_UNVERIFIED | `p3/t18b-edit-delete` |
| T18c | Owner's answers of 2026-11-07 (D-057): a monthly salary cut by itself for days with no attendance, by the contract's own part-month rule, with weekly off days and a switch on each contract; advance recovered by itself by an instalment typed when it is given, or by an amount the payroll asks for; and a company's fewer hours carried into the worker's attendance after asking. Built and tested. Run on a Windows build on 2026-11-08, with old October data, and what it found fixed (TC-133 to TC-137, D-058). The owner's answer of 2026-11-08 (D-059): a fixed contract's month invoiced in parts charges the rest on the next invoice (TC-138 to TC-141), run on the laptop. Not tried on a phone | CALC-04, PAY-04, PAY-05, TS-06, ATT-08, TS-08, MODEL-08 | IMPLEMENTED_UNVERIFIED | `p3/t18c-owner-answers` |

**Gate:** PDF review, duplicate-billing and numbering tests pass.

**Gate run, 2026-11-06,** on `p3/gate`: the tests and the paper review pass on this computer. The duplicate-billing tests found a monthly fee charged twice when its month was invoiced in parts, now fixed (D-054). Numbering gained tests for a new year, a failure part way and the database refusing a number twice. 19 papers were drawn through the app's own issue paths, with words only, a letterhead image with signature and stamp, and pre-printed paper, and read by eye. The owner's phone test of T14 to T18 is still open, so the phase is not OWNER_ACCEPTED.

## P4: Auth, isolation, backup, Solo licence

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T19 | Supabase schema, RLS, two-tenant tests, SMTP, signup, device unlock, deletion. In slices: T19a cloud tables, row level security and two-company tests, done on 2026-11-08 (D-060, TC-142), and on the owner's live project the same day (D-061, TC-143); T19b signup, login, verify, reset, device registration and offline PIN or fingerprint unlock, of which signup, login, the email step, device registration and logout were built on 2026-11-09 (D-062, TC-144, TC-145), then one account per phone (D-063, TC-147 to TC-149) and the PIN or fingerprint lock (D-064, TC-149, TC-150) the same day, made the user's choice with 8 tries on the owner's answer (D-065, TC-152), with reset by code waiting for T19d's emails; T19c account deletion from the app, built on 2026-11-09 (D-066, TC-153 to TC-156), confirmed on 2026-11-10 with the web way by request, confirmed by the platform owner, left for T22 and T26 (D-067); T19d real SMTP through Resend (D-068), BLOCKED until the owner has a domain | AUTH-01..08, ARCH-02, ARCH-07, MODEL-02, MODEL-05, MODEL-06, UX-02 | IN_PROGRESS | `p4/t19c-delete-account` |
| T20 | Encrypted backup, restore, device change, sequence reconciliation. In slices: T20a the backup file, its password, save or send, the reminder and the warning, built on 2026-11-10 (D-069, TC-159 to TC-164); T20b bringing a backup back with its number check, a backup of the data on the phone first (D-071) and the copy it keeps, moving to a new phone by it, and the retention note, built on 2026-11-10 (D-070, TC-165 to TC-168); T20c turning the old phone off from the new one, free, built on 2026-11-11 (D-072, D-073, TC-170 to TC-174), its migration run on the live project the same day; T20d the cloud backup, the paid add-on, designed with the owner on 2026-11-14 (D-072, D-075, `docs/superpowers/specs/2026-11-14-t20d-cloud-backup-design.md`), in three slices: T20d-a the cloud's bucket, copies, add-on periods and the `backup` function, built on 2026-11-15 (D-076, TC-190 to TC-193), waiting for the owner's yes to go live (TC-194); T20d-b sending, with the backup password asked at signup, the copy sent by itself and the platform's offline recovery key with the owner's tool, built on 2026-11-15 (D-077, TC-195 to TC-198), its phone test after the live run (TC-199); T20d-c getting a copy back, with the add-on on Plan lein and in Settings, the cloud's list in the restore, the help for a forgotten password and the new phone's offer, built on 2026-11-15 (D-078, TC-200 to TC-203), its two-phone test after the live run (TC-204) | DATA-02..08 | IN_PROGRESS | `p4/t20d-c-restore` |
| T21 | Signed entitlements, offline lease, versioned plan config, safe expiry. Designed with the owner and approved on 2026-11-11 (D-074), planned in `docs/superpowers/plans/2026-11-11-t21-plans-licence.md`. In slices: T21a the cloud's plans, trial, payment slips, the platform's accept and refuse, and the `licence` function, built on 2026-11-11 (TC-175 to TC-178), live on the project the same day (TC-179); T21b the app's licence check, Plan lein with the bank details and the slip, the plan in Settings and the trial note, built on 2026-11-11 (TC-180 to TC-183), its phone test waiting on the bank details (TC-184); T21c the limits and safe mode at the single write path, and the over-limit chooser, built on 2026-11-13 (TC-185 to TC-188), its phone test with a throwaway company (TC-189). What each later task owes is in `docs/LATER.md` | BILL-02, BILL-03, BILL-05, BILL-06, PLAN-03, PLAN-04, PLAN-06 | IMPLEMENTED_UNVERIFIED | `p4/t21-plans` |

**Gate:** Two-tenant security, SMTP and device-restore tests pass.

## P5: Owner dashboard

| Task | Title | Requirements | Status | Branch / PR |
| --- | --- | --- | --- | --- |
| T22 | Admin web with MFA, customers, manual payments, renewals, audit log. In parts (D-081): part 1 the dashboard on today's cloud data, part 2 the books in the cloud with the customer's consent; design approved on 2026-11-24 (D-081). Part 1 in slices: T22a the cloud side (admins, MFA check, audit log, the owner's actions, holds and overrides in the licence, the pages' reads), built 2026-11-24 (D-082, TC-217); T22b the app's side of holds and its version, built 2026-11-24 (TC-218); T22c the web dashboard (`apps/admin`), the `admin` function that copies a block into Supabase Auth, and plans changed from now, built 2026-11-26 (D-083, TC-220 to TC-222). Part 2, T22d, the consent page and the books in the cloud, built 2026-11-26 (D-084, TC-224 to TC-227). Parts 3 and 4 wait (`docs/LATER.md`) | ADMIN-01..04, ADMIN-08, BILL-01, BILL-04, ARCH-03, MET-01 | IN_PROGRESS | `p5/t22-dashboard` |
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

**Audit:** an independent audit of T01 to T21 ran on 2026-11-15 to 2026-11-20, on branch `audit/t01-t21` (`docs/audit/`, D-079, and the owner's answers to its questions, D-080; PR #2). It counts toward T26's independent reviews; it is not T26.
