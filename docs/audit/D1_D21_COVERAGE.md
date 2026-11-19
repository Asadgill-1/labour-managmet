# Coverage of stages T01 to T21

The request's "D1 to D21" are taken as the repo's tasks T01 to T21 (`TASKS.md`); see `AUDIT_STATUS.md`. Requirement IDs are the PRD's, from `REQUIREMENTS_TRACEABILITY.md`.

What the status words mean here:

- **VERIFIED:** built; its automated tests ran on this computer during the audit and passed; its code was read in a review; no finding is open against it. It says nothing about a phone: nothing in this audit ran on Android.
- **PARTIAL:** built, with a finding still open, or with a part this audit could not run (the cloud's SQL, a live service).
- **BLOCKED:** waits on something outside the repo.
- **MISSING:** not built.
- A previous session's "IMPLEMENTED_UNVERIFIED" was not taken as proof either way.

"Tests" are `apps/mobile/test/*_test.dart` unless a path says otherwise. "Journey" is `test/audit_journey_test.dart` (QA-01). Reviews are `docs/audit/reviews/01` to `04`. Bug numbers are in `BUG_REGISTER.md`.

Statuses below are as of the triage on 2026-11-16, before the fixes; the last section of this file records the state after them.

## P0 Foundation

| Stage | Requirement and source | Implementation | Verification | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| T01 | Repo as source of truth, traceability, handover (AI-01..04, AI-07, AI-08, ARCH-08, BUILD-03) | Root `.md` files, `tools/check_trace.py` | `check_trace.py` run: pass, 166 IDs. Tool read in full | PARTIAL | BUG-015 (`SCREEN_FLOW.md` behind the code), OBS-005 |
| T02 | CI gates, secret scanning, lockfiles (AI-05, AI-06) | `.github/workflows/ci.yml`, `.gitignore`, lockfiles | Workflow read (auditor, review 01). Tracked files and git history searched for secrets and key files: none. CI itself not run by this audit | PARTIAL | BUG-027. The Android job runs only on a PR. Branch protection is off (`PROGRESS.md`) |
| T03 | Encrypted file per company, key in Keystore (ARCH-01, DATA-01) | `lib/data/tenant_database.dart` (`openTenantDatabase`, `tenantKey`), `lib/spike_checks.dart` | Journey and `backup_test`, `restore_test` run on encrypted files with their keys. Read in full | PARTIAL | Android Keystore never checked on a phone (open since P0) |
| T04 | Calculation spec, data model, screen flow (UX-01, CALC-01, MODEL-01, MODEL-03, MODEL-04, BUILD-01) | `docs/CALCULATION_SPEC.md`, `DATA_MODEL.md`, `SCREEN_FLOW.md` | Used as the audit's yardstick; every formula checked against the code in review 02 and the VAT rules in review 03 | PARTIAL | OBS-005 (`DATA_MODEL.md` says the cloud backup is not built) |

## P1 Masters, attendance, rates

| Stage | Requirement and source | Implementation | Verification | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| T05, T05b | Side panel, labels, readability, honest save states (UX-01..04, UX-07) | `lib/app/*.dart`, `lib/l10n/*.arb` | `app_shell_test` passes. Review 04: every panel entry opens a real screen | PARTIAL | BUG-015, BUG-016, BUG-019; F04-8 suspected |
| T06 | Schema, migrations, outbox, audit, one write path (MODEL-01, MODEL-03, MODEL-04, MODEL-08) | `lib/data/tenant_database.dart`, `tables.dart`, `triggers.drift` | `write_path_test`, `drift/tenant/migration_test` (v1 to v19) pass. Review 03: no write outside `applyOperation`; each row of the constraints table has its trigger or index. The generated `steps.dart` was not read line by line | PARTIAL | BUG-010 |
| T07 | Company, clients, sites, workers, archive (MASTER-01..04, MASTER-07) | `lib/data/masters.dart`, `features/companies`, `features/labour`, `features/more/profile_form_screen.dart` | `masters_test`, `records_test` pass. Reviews 02 and 04. Labour, companies and rooms screens were searched for writes and parsing, not read in full | PARTIAL | BUG-013, BUG-019 |
| T08 | Rate cards, opening balances (MASTER-05, MASTER-06) | `features/rates`, tables `pay_contracts`, `billing_contracts`, `opening_balances` | `rates_test`, `records_test` pass. Review 02 | PARTIAL | BUG-009 |
| T09 | Calculation engine (CALC-01..07) | `packages/domain/lib/*.dart` | `dart test`: 151 pass, PRD fixtures included. Journey: hourly, daily and monthly pay and both billing bases match hand figures. Review 02 worked each formula with its own numbers | PARTIAL | BUG-002 fixed. F02-6, F02-7 for the accountant |
| T10 | Bulk attendance, exceptions, duplicates, midnight shift, corrections (ATT-01..09, UX-05, UX-06) | `lib/data/attendance.dart`, `features/today` | `attendance_test` passes. Journey: a second tap of one save adds nothing. Review 02 | PARTIAL | BUG-006, BUG-008; F02-9 for the owner. UX-06's timed usability test was never run |
| T10b | Worker groups (ATT-01, ATT-03, CALC-06) | `features/groups`, `masters.dart` `saveWorkerGroup` | `groups_test` passes. Review 02 | VERIFIED | None |

## P2 Payroll and ledgers

| Stage | Requirement and source | Implementation | Verification | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| T12a | Cash book, rooms (PAY-05, PAY-06, REP-07, REP-08) | `lib/data/cash.dart`, `features/cash`, `features/rooms` | `cash_test` passes. Review 02 (`cash.dart` in full; rooms screens searched only) | VERIFIED | None |
| T11 | Payroll run, posting, carry-forward, deductions (PAY-01..04, PAY-07, REP-08, MODEL-07) | `lib/data/payroll.dart`, `packages/domain/lib/payroll.dart`, `features/payroll` | `payroll_test` passes. Journey: posting and a part payment. Review 02 | PARTIAL | BUG-003, BUG-004; F02-5 for the owner |
| T11b, T11d, T13c | Tabs, themes, the redesign (UX-01, UX-03, UX-04) | `lib/app/theme.dart`, `side_panel.dart` | `app_shell_test` passes. Looks are the owner's to judge and were not reviewed | VERIFIED | None on navigation |
| T11c | Visa money (PAY-01, REP-08) | `lib/data/visa.dart`, `features/visa` | `visa_test` (app and domain) pass. Review 02 | VERIFIED | None |
| T11e | Owner's phone feedback (ATT-07, PAY-07, CALC-06, REP-01, REP-08) | `payroll.dart`, `features/payroll/room_charge_screen.dart`, registers | `payroll_test`, `registers_test` pass | VERIFIED | None |
| T11f | Salary slip, owner's sheet, 1,000 workers (PAY-09, REP-01, REP-03, DOC-07) | `features/payroll/salary_slip.dart`, `features/registers/salary_sheet.dart` | `statement_test`, `scale_test` pass. Review 04 | PARTIAL | BUG-012 (the sheet groups companies by name) |
| T18a | Eight registers, PDF, Excel, WhatsApp (REP-01, DOC-01, DOC-03, DOC-06, DOC-07) | `features/registers/*` | `registers_test` passes. Review 04 read each register's query against its columns and totals | PARTIAL | BUG-012, BUG-014, BUG-017, BUG-018 |
| T12 | Advance sub-ledger, salary payments by month, wages due (PAY-05, PAY-06, PAY-08) | `lib/data/statement.dart`, `features/cash/cash_entry_form_screen.dart`, `features/payroll/wages_due_screen.dart` | `salary_payment_test` passes. Journey: a part payment on its month. Review 02 | PARTIAL | BUG-007 suspected |
| T13, T13b | Expenses, month close, nothing closes while anything is left (REP-04, REP-05, REP-07) | `lib/data/closing.dart`, `features/closing` | `closing_test` passes. Review 02 | PARTIAL | BUG-004 blocks a closing; F02-2's second part for the owner |

## P3 Timesheets, invoices, documents

| Stage | Requirement and source | Implementation | Verification | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| T14 | Document engine, letterhead, stored papers (DOC-01..08, PAY-09) | `lib/data/documents.dart`, `lib/documents/document_frame.dart`, `features/documents` | `documents_test` passes. Journey: a paper comes back from a backup byte for byte. Reviews 03 and 04 | VERIFIED | None. The image picker, print and share were never run on a phone |
| T15 | Timesheets, revisions, billed allocation (TS-01..08) | `lib/data/timesheets.dart`, `features/timesheets` | `timesheets_test`, `timesheet_paper_test` pass. Journey. Review 03: no wage reaches a company's paper | PARTIAL | BUG-010, BUG-016 |
| T16 | Invoices, VAT, numbering, credit notes (INV-01..04, INV-06, INV-08, INV-09) | `lib/data/invoices.dart`, `packages/domain/lib/invoice.dart`, `features/invoices` | `invoices_test`, `invoice_paper_test` pass. Journey: VAT to the fil, numbers 0001 to 0003 across a restore, the same work refused twice. Review 03 worked VAT exclusive, inclusive, zero-rated and discount by hand | PARTIAL | BUG-013. F03-1 (High), F03-2, F03-3 wait for the owner |
| T17 | Receipts, status, company statement (INV-05, INV-07) | `lib/data/receipts.dart` | `invoices_test` receipts group passes. Journey: a part receipt, and one above what is owed refused. Review 03 | PARTIAL | BUG-009 |
| T18 | Reports, export, CSV import (REP-01..03, REP-06, MASTER-08) | `features/registers/register_defs.dart`, `lib/data/import.dart`, `packages/domain/lib/csv.dart` | `reports_test` passes. Reviews 03 and 04 | PARTIAL | BUG-011, BUG-012 |
| T18b | Edit and delete everywhere (ATT-08, REP-08, MASTER-02..07, INV-06) | `lib/data/changes.dart`, `features/changes` | `changes_test`, `records_test`, `invoice_edit_test` pass. Reviews 02 and 03 | PARTIAL | BUG-008, BUG-009 |
| T18c | Absence cut, advance instalments, a company's fewer hours (CALC-04, PAY-04, PAY-05, TS-06, TS-08) | `packages/domain/lib/payroll.dart` `periodSalary`, `payroll.dart`, `timesheets.dart` | `auto_cuts_test` passes. Review 02 | PARTIAL | BUG-005; F02-4 for the owner |

## P4 Accounts, backup, licence

| Stage | Requirement and source | Implementation | Verification | Status | Findings |
| --- | --- | --- | --- | --- | --- |
| T19a | Cloud tables, row level security, two-company tests (AUTH-05, MODEL-02, MODEL-05) | `supabase/migrations/20261108120000_cloud_tenants.sql`, `supabase/tests/database/tenants.test.sql` | Review 01 read every table's policies and every definer function. SQL tests NOT run here (no Docker); the repo records CI run 43664625445 passing | PARTIAL | None found. Not run by this audit |
| T19b | Signup, login, one account per phone, PIN or fingerprint (AUTH-01..04, UX-02) | `lib/data/account.dart`, `app_lock.dart`, `features/account`, `lib/app/root.dart` | `account_test`, `account_flow_test`, `app_lock_test` pass against stand-ins for Supabase. Review 01. Never run against the live project or on a phone | PARTIAL | BUG-001 fixed (a release build could not reach the internet) |
| T19c | Account deletion (AUTH-07) | `supabase/migrations/20261109130000_delete_account.sql`, `account.dart` `deleteAccount`, `root.dart` | App tests pass. SQL read (auditor, review 01): the password must have been typed in the last 10 minutes | PARTIAL | BUG-021 |
| T19d | Real email through the app's own domain (AUTH-08) | Not built | None | BLOCKED | Waits for the owner's domain and Resend account (D-068). Until then no customer can sign up, and "forgot password" is unavailable |
| T20a | Backup file, its password, the reminder (DATA-02..04) | `lib/data/backup.dart`, `features/backup/backup_screen.dart` | `backup_test` passes. Journey: a backup that opens, and a wrong password refused. Review 01 | VERIFIED | None |
| T20b | Restore, number check, moving phones (DATA-05, DATA-06) | `lib/data/restore.dart`, `features/backup/restore_screen.dart` | `restore_test` passes. Journey: restore under another phone's key, every figure the same, the next number in order. Review 01 | VERIFIED | None |
| T20c | Turning an old phone off (DATA-06) | `supabase/migrations/20261111120000_phone_off.sql`, `account.dart`, `root.dart` `_closeIfOff` | App tests pass. SQL read by the auditor. SQL tests not run here | PARTIAL | BUG-023 (High), BUG-024 |
| T20d-a | Cloud backup: bucket, copies, add-on, `backup` function (DATA-06, DATA-08) | `supabase/migrations/20261114120000_cloud_backup.sql`, `supabase/functions/backup/` | Review 01. Not run here; not live | PARTIAL | BUG-025 |
| T20d-b | Sending the copy, recovery key (DATA-07) | `lib/data/cloud_copy.dart`, `recovery.dart`, `tool/recovery_key.dart` | `cloud_copy_test` (8), `recovery_test`, `cloud_screens_test` pass. Review 01 | PARTIAL | BUG-020 (High) |
| T20d-c | Bringing a cloud copy back, the add-on on Plan lein | `features/backup/cloud_copies_screen.dart`, `features/plans/plan_screen.dart` | `cloud_restore_test` passes; its Play Store case is run by CI only | VERIFIED | None. `plan_screen.dart` and `plan_lock.dart` were read by search, not in full |
| T21a | Plans, trial, slips, the signed licence (BILL-02..06, PLAN-04, PLAN-06) | `supabase/migrations/20261111130000_plans_licence.sql`, `supabase/functions/licence/` | Review 01. Not run here. Live on the project since 2026-11-11 per the repo | PARTIAL | BUG-026, BUG-027 |
| T21b | The app's licence check, Plan lein, slip upload | `lib/data/licence.dart`, `plans.dart`, `features/plans` | `licence_test`, `plans_test` pass. Review 01 | PARTIAL | BUG-022 |
| T21c | Limits and safe mode at the write path (PLAN-03, PLAN-04) | `lib/data/plan_guard.dart`, `tenant_database.dart` `guard`, `features/plans/plan_lock.dart` | `plan_guard_test`, `write_path_test` pass. Review 03 confirmed the guard sits inside the one write path | VERIFIED | None |

## Not built (outside T01 to T21)

| Stage | What | Status |
| --- | --- | --- |
| T22 | Owner's web dashboard with MFA, customers, payments (ADMIN-01..03, ADMIN-08, AUTH-06, ARCH-03) | MISSING. Slips are accepted by SQL from `docs/RUNBOOK.md` until then |
| T23 | Telemetry, metrics, support, alerts (ADMIN-04..07, MET-01..07, OPS-01..06, OPS-08) | MISSING |
| T24 | Managers, invites, permissions (TEAM-01..03, PLAN-01, PLAN-02, PLAN-05) | MISSING |
| T25 | Sync between devices (TEAM-04..08, ARCH-04) | MISSING. The outbox is written and never sent |
| T26 | Release readiness, store forms, benchmarks, full regression (BILL-07..09, BUILD-02, BUILD-04..06, OPS-07, QA-01) | MISSING. This audit's journey test covers QA-01 at the data layer only. Release signing, the app's name and id are still the template's (OBS-003) |

## After the fixes (2026-11-17)

The state once every fix was in and the full re-runs were done (`VERIFICATION.md`; the second, on 2026-11-19, all passing). Only rows that changed, or that still wait on something, are listed; every other row stands as above. "Owner" means a question in `BUG_REGISTER.md` that no code change should settle, and D-079 lists the fixes that change what the app allows, for the owner to confirm.

| Stage | Status now | What changed, what is left |
| --- | --- | --- |
| T01 | VERIFIED | BUG-015's `SCREEN_FLOW.md` lines and OBS-005's `DATA_MODEL.md` line corrected |
| T02 | PARTIAL | BUG-027 written, not run. CI itself not run by this audit |
| T03 | PARTIAL | Unchanged: the Keystore never checked on a phone |
| T04 | VERIFIED | OBS-005 corrected |
| T05, T05b | PARTIAL | BUG-015, BUG-016, BUG-019 fixed. F04-8 (large text) still not checked in a running app |
| T06 | VERIFIED | BUG-010 fixed at the root, `applyOperation` |
| T07 | VERIFIED | BUG-013, BUG-019 fixed. D-079 (8)'s 365-day ceiling for the owner |
| T08 | VERIFIED | BUG-009 fixed |
| T09 | PARTIAL | F02-6, F02-7 for the accountant |
| T10 | PARTIAL | BUG-006, BUG-008 fixed. F02-9 for the owner; UX-06's timed test never run |
| T11 | PARTIAL | BUG-003, BUG-004 fixed. F02-5 for the owner |
| T11f | VERIFIED | BUG-012 fixed |
| T18a | VERIFIED | BUG-012, BUG-014, BUG-017, BUG-018 fixed. Sharing never run on a phone |
| T12 | VERIFIED | BUG-007 fixed; BUG-028 fixed in the statement |
| T13, T13b | PARTIAL | BUG-004 fixed. F02-2's second part for the owner |
| T15 | VERIFIED | BUG-010, BUG-016 fixed |
| T16 | PARTIAL | BUG-013 fixed. F03-1 (High), F03-2, F03-3 for the owner |
| T17 | VERIFIED | BUG-009 fixed |
| T18 | VERIFIED | BUG-011, BUG-012 fixed |
| T18b | VERIFIED | BUG-008, BUG-009 fixed |
| T18c | PARTIAL | BUG-005 fixed. F02-4 for the owner |
| T19a | PARTIAL | Unchanged: the SQL tests not run here |
| T19b | PARTIAL | BUG-001 fixed and the release APK's manifest read, but no release build has logged in on a phone. BUG-024's app side fixed |
| T19c | PARTIAL | BUG-021 fixed, except a retry after the app restarts. The SQL not run here |
| T19d | BLOCKED | Unchanged |
| T20c | PARTIAL | BUG-023, BUG-024: app side fixed and run; cloud side written, not run, not live |
| T20d-a | PARTIAL | BUG-025 for the owner. Not run here, not live |
| T20d-b | PARTIAL | BUG-020 fixed. The Backup page's words after a reinstall for the owner |
| T21a | PARTIAL | BUG-026, BUG-027 written, not run |
| T21b | VERIFIED | BUG-022 fixed |

Review 05 of the fixes found five more, all fixed on 2026-11-19: BUG-029 and BUG-030 (T11, T18c: payroll items and listing), BUG-031 (T18a: the register's header), BUG-032 (T10: the stale-correction message), BUG-033 (T18: imported due days). No row's status changes for them; T11 and T18c stay PARTIAL for the owner's questions.
