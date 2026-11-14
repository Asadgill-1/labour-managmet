# Data Model

Conceptual model. T06 turns the local part into a versioned drift schema; T19 does the same for the cloud.

## Common columns (MODEL-03)

Every table: `id` (UUID), `tenant_id`, `created_at_utc`, `updated_at_utc`, `actor_id`, `version`, `source_operation_id`.  
Money records add `currency` and `posting_date`. An effective date is always separate from `created_at_utc`.

`tenant_id` stays on local tables even with one file per tenant, because sync and restore must check it (BUILD-01).

## Local operational data (MODEL-01)

| Group | Tables | Key rules |
| --- | --- | --- |
| Identity | `tenant_profile` | VAT status has an effective date (MASTER-01) |
| Masters | `clients`, `sites`, `workers` | Archive, never hard-delete with history. Worker code unique in tenant. No auto-merge by name (MASTER-07) |
| Contracts | `pay_contracts`, `billing_contracts` | Effective from and to. Basis, rate in fils, break rule, included minutes, overtime rate, partial-period method (MASTER-06). A monthly pay contract also has `cut_absence` and `off_weekdays` (D-057). A row scoped to a site or worker acts as the assignment rate (D-020) |
| Groups | `worker_groups`, `worker_group_members` | Optional company, site, daily wage and duty time. A member can have a rate set for this group, per day or per hour, which comes before their contract. The group's wage only reaches someone with no pay of their own. Attendance rows keep their own figures, so changing a group never changes approved work (D-029, D-042) |
| Attendance | `attendance_batches`, `attendance_entries` | Rate snapshot on each entry. Client and worker minutes stored separately. Corrections link to the revised entry (ATT-02, ATT-08) |
| Payroll | `payroll_runs`, `payroll_lines`, `payroll_items`, `attendance_entries.payroll_line_id` | Posted figures are immutable. Opening, earned, salary, adjustment, allowances, deductions, recovery, net and payable are stored at posting, and salary is already less `absence_fils`, cut for `absent_days` (D-057). An advance line carries `cash_entries.instalment_fils`, and only a recovery item can be 0. Paid and closing derive from later payments, using `paid_before_fils`. Undo only flags a line. Items are free to change until posted (PAY-01, D-033) |
| Cash book | `cash_entries` | One row per amount in or out, with a kind saying where it belongs: advance, salary, room rent paid or received, expense, advance returned, company receipt. Append-only by trigger. A reversal row cancels a mistake (D-030, REP-08) |
| Visa money | `cash_entries` kinds `visaPaid` and `visaReturned`, `workers.visa_instalment_fils`, `payroll_lines.visa_recovery_fils` | Left = paid - returned - recovered through standing payroll lines. Always derived (D-039) |
| Rooms | `rooms`, `workers.room_id` | Rent received and paid per room come from the cash book (D-031) |
| Worker money | `payroll_items`, `salary_allocations` | A salary payment's months, append-only: a row per month with its share, set aside when the payment is undone. `cash_entries.reference` and `receiver` hold the rest of PAY-06, and `tenant_profiles.wage_due_days` the company's own days to pay (D-043). Advance outstanding is opening + given - returned - recovered through posted payroll. A deduction or room charge carries a reason and authorization, enforced by a CHECK. For a room charge that is the worker's note, or the owner's own say-so when ticking them (PAY-05, PAY-07, D-041) |
| Timesheets | `timesheets`, `timesheet_revisions`, `timesheet_lines` | A draft holds no lines and reads attendance. Approval stores the lines, company side only, and they never change. A revision preserves the original, and `live` says which lines are current (TS-04, TS-06, D-049) |
| Receipts | `cash_entries` of kind `clientReceipt`, `invoice_allocations` | A company's receipt is a cash book line. Its shares say which invoice, or the balance from before the app, it settled. A row with no receipt is what the owner closed as lost, with a reason. A negative row gives some back. Only receipts still standing count, so nothing is ever edited (INV-05, D-048, D-052) |
| Billing links | `billed_allocations` | Which invoice charged which work. A monthly row is charged at 0, since its fee is on its own line. A credit note only flags its rows (TS-05, D-049, D-050) |
| Invoices | `invoices`, `invoice_lines` | A draft has no number and no lines: it reads its timesheets. Issuing stores the lines, both parties and the VAT as they stood. A draft also holds lines typed by hand in its JSON, stored on issue with basis `item`. A credit note is an `invoices` row of kind `credit` that takes back a whole invoice or an amount, and an invoice can have several. A fixed monthly contract's line keeps its month in `fee_month`, so the next invoice charges what is left of it (D-059). Stored as structured data for a later e-invoicing export (D-011, D-050, D-051) |
| Receipts | `receipts`, `receipt_allocations` | Unapplied credit allowed. Allocation cannot exceed outstanding (INV-05) |
| Costs | `cash_entries` | Expenses are cash book rows with a category, an optional site and a payment reference. Actual room cost is separate from room charge recovered from a worker (REP-07) |
| Documents | `document_assets`, `document_templates`, `issued_documents` | Images are kept for good. One template row says how papers look today. An issued paper holds its number, revision, file, what it said and how it looked, and never changes (DOC-05, D-047) |
| Closing | `period_locks`, `day_offs` | One row per closed month, with its last day. Everything up to the latest live row is locked. Opening a month again only flags its row, and the reason is in the audit log (REP-04, D-044). A day off is the owner's word that a worker had no work on a date, one row per worker and date, and moves no money (D-045) |
| Documents | `document_snapshots` | PDF plus data and template snapshot. Later logo changes never alter an issued copy (DOC-05) |
| Numbers | `number_floors` | The highest number of a kind given where this file has no record of it, set when a backup comes back: by the phone whose data it replaced, or after the backup elsewhere, as the owner said. The next number of that kind and year goes past it. Rows never change (DATA-06, D-070) |
| System | `audit_events`, `outbox` | See below. A backup carries its own label, in the file, and the phone keeps the last backup's time in its encrypted store, so no table holds backups (D-069) |

## Balances (REP-08)

No table stores an editable balance. Current balances derive from posted payroll, payments, allocations and reversals. The only hand-entered figures are opening balances, kept as migration records with source date and owner confirmation: worker salary owed, worker advance and client receivable, separately (MASTER-05). The opening salary balance never becomes a wage expense.

## Constraints in the database (MODEL-04)

| Rule | Enforced by |
| --- | --- |
| Worker code unique in tenant | `UNIQUE (tenant_id, worker_code)` |
| Invoice number unique in tenant | `UNIQUE (tenant_id, kind, year, seq)`, null while draft. Credit notes per invoice are limited by its total in the issuing transaction, since v14 dropped the one-credit-note index (D-051) |
| Duplicate operation rejected | Outbox primary key on `operation_id`, checked by `applyOperation` (D-021) |
| A write the company's plan does not allow is refused, and leaves nothing | `TenantDatabase.guard`, asked in `applyOperation` inside the transaction, after the retry check; the rule is `planRefusal` in `plan_guard.dart` (T21c, D-074) |
| Break within shift | `CHECK (break_minutes BETWEEN 0 AND clock_minutes)` |
| Same work on one current timesheet | Partial unique index on `timesheet_lines (work_key)` where live. `work_key` is the first row of a correction chain, so a corrected row is the same work |
| Same work not billed twice | Partial unique index on `billed_allocations (work_key)` where not released |
| Allocation within outstanding | Checked inside the posting transaction |
| Posted rows immutable | Triggers rejecting `UPDATE` and `DELETE` on posted payroll, issued invoices, approved timesheet lines and allocations |
| What a payment settled never changes | Triggers rejecting `UPDATE` and `DELETE` on `salary_allocations`. One row per payment and month, `UNIQUE (payment_id, month)` |
| A closed month stays as it was | Triggers rejecting writes dated up to the latest live `period_locks.last_day` on `cash_entries`, `attendance_entries`, `payroll_items`, `payroll_lines` and `opening_balances`. Linking a closed row to a later posting or a timesheet changes no figure, and is allowed. `applyOperation` turns the refusal into `PeriodLocked` |
| One worker paid once per month | Partial unique index on `payroll_lines (worker_id, period_from)` where not reversed |
| Cross-tenant reference invalid | Cloud: composite foreign key on `(tenant_id, id)`. Local: impossible across files, and restore checks tenant identity |

## Transactions (MODEL-07)

Issuing an invoice or posting payroll writes the document, the ledger postings, the source links, the audit event and the outbox entry in one transaction. A crash leaves all or nothing. PDF rendering happens after commit from the snapshot, so a failed render retries without creating a second document.

## Outbox (TEAM-04)

Written from P1, in the same transaction as the change: `operation_id` (UUID, also the idempotency key), `tenant_id`, `entity`, `record_id`, `record_version`, `device_id`, `payload`, `created_at_utc`, `acked_at_utc`. Free and Solo never upload it (ARCH-02). It only sends when Team sync is on (T25).

## Local storage (D-005, D-016)

One encrypted file per tenant, `tenant_<uuid>.db` in app-private storage, with a random 256-bit key per tenant in Keystore-backed storage. Logout closes the handle, clears in-memory state and removes the PDF cache (AUTH-04). The same storage keeps the signed-in session, so the licence renews after a restart, and the latest licence with the latest time the phone has seen (T21b, D-074); logout removes the session.

## Cloud control data (MODEL-02)

Built in T19a (`supabase/migrations/`, D-060): `tenants` (its `tenant_id` is the id every local row carries), `memberships` (owner or manager, revoked rows kept) and `devices`. Members read only their company's rows under row level security; only `create_tenant` and `register_device` write, taking the user from the session. Built in T21a (D-074): `plans` (versioned, in fils), `platform_settings` (the bank details, filled only on the live project), `payment_slips` with the private `payment-slips` bucket, `subscriptions` (the trial and one row per accepted slip), and in `private` the trial claims and each company's latest counts. A licence is signed on request and not stored. Still to come: auth users' other groups, activation redemptions, support tickets, diagnostic events, monthly metric snapshots, admin audit, Play import batches. Tenant operational tables are added for Team only (T25). Payroll and worker photos from Free and Solo are never uploaded automatically (ARCH-02).

Server-only actions (MODEL-05): tenant creation and membership, trial eligibility, licence issue and revoke, payment posting, Team final invoice numbers, metrics. A client can never grant itself a plan by setting a flag.

## Retention (DATA-08)

Proposed, for the owner and an accountant to confirm (D-070).

| What | Where | How long |
| --- | --- | --- |
| A company's records | The phone, in its encrypted file | Until the owner deletes them or the account (AUTH-07). The app deletes nothing by age, and sets no default for how long tax and payroll records must be kept: that is the law's and the company's question |
| Backups | Where the owner saves them | The app keeps none. The file it hands over sits in its share folder, which empties after a day and at logout (D-069) |
| The copy a restore keeps | The phone, under the company's key | Until the next restore or the account's deletion (D-070) |
| The cloud backup | The cloud, locked with the backup password and with the platform's recovery key, whose private half stays offline | Not built yet (T20d). The latest copy always, with the add-on the copies the plan keeps too. After the account is deleted the latest copy stays 60 days, then goes (D-072) |
| The company, its members and devices | The cloud | While the account lives; deleted with it (D-066) |
| Plan periods, payment slips and their files, the counts each licence check sends | The cloud | While the account lives; deleted with it (D-066, D-074), the slip files by the app first (T21b). Whether the platform keeps payment records for its own books is for the owner and an accountant |
| Trial claims: a hash of the owner's email and of each phone's id | The cloud | Kept after the account is deleted, so nobody gets a second trial (D-074); in the privacy policy (T26) |
| Crash reports and diagnostics | Not sent yet | 30 days, once T23 adds them |
| Support uploads | None yet | 30 days after the ticket closes, once T23 adds them |

The phone's file and every backup are encrypted with keys only the company holds. The cloud's tables are encrypted at rest by Supabase, which can read them, so they are not end-to-end encrypted.
