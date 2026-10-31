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
| Contracts | `pay_contracts`, `billing_contracts` | Effective from and to. Basis, rate in fils, break rule, included minutes, overtime rate, partial-period method (MASTER-06). A row scoped to a site or worker acts as the assignment rate (D-020) |
| Groups | `worker_groups`, `worker_group_members` | Optional company, site, daily wage and duty time. A member can have their own wage. Attendance rows keep their own figures, so changing a group never changes approved work (D-029) |
| Attendance | `attendance_batches`, `attendance_entries` | Rate snapshot on each entry. Client and worker minutes stored separately. Corrections link to the revised entry (ATT-02, ATT-08) |
| Payroll | `payroll_runs`, `payroll_lines` | Posted lines are immutable. Opening, gross, allowances, deductions, recovery, net, payable, paid and closing all stored (PAY-01) |
| Cash book | `cash_entries` | One row per amount in or out, with a kind saying where it belongs: advance, salary, room rent paid or received, expense, advance returned, company receipt. Append-only by trigger. A reversal row cancels a mistake (D-030, REP-08) |
| Rooms | `rooms`, `workers.room_id` | Rent received and paid per room come from the cash book (D-031) |
| Worker money | `deductions`, `salary_payment_allocations` | Advance outstanding is opening + given - returned, from the cash book, plus payroll recovery from T11. Deduction carries reason and authorization (PAY-05, PAY-07) |
| Timesheets | `timesheets`, `timesheet_revisions`, `timesheet_lines` | A revision preserves the original (TS-06) |
| Invoices | `invoices`, `invoice_lines`, `invoice_source_allocations`, `credit_notes` | Draft has no legal number. Stored as structured data for a later e-invoicing export (D-011) |
| Receipts | `receipts`, `receipt_allocations` | Unapplied credit allowed. Allocation cannot exceed outstanding (INV-05) |
| Costs | `cash_entries` | Expenses are cash book rows with a category and optional site. Actual room cost is separate from room charge recovered from a worker (REP-07) |
| Closing | `period_locks` | Change after lock needs an owner reason and a dated adjustment (REP-04) |
| Documents | `document_snapshots` | PDF plus data and template snapshot. Later logo changes never alter an issued copy (DOC-05) |
| System | `audit_events`, `outbox`, `backup_manifests` | See below |

## Balances (REP-08)

No table stores an editable balance. Current balances derive from posted payroll, payments, allocations and reversals. The only hand-entered figures are opening balances, kept as migration records with source date and owner confirmation: worker salary owed, worker advance and client receivable, separately (MASTER-05). The opening salary balance never becomes a wage expense.

## Constraints in the database (MODEL-04)

| Rule | Enforced by |
| --- | --- |
| Worker code unique in tenant | `UNIQUE (tenant_id, worker_code)` |
| Invoice number unique in tenant | `UNIQUE (tenant_id, invoice_number)`, null while draft |
| Duplicate operation rejected | Outbox primary key on `operation_id`, checked by `applyOperation` (D-021) |
| Break within shift | `CHECK (break_minutes BETWEEN 0 AND clock_minutes)` |
| Same work not billed twice | Guard over `invoice_source_allocations` per attendance entry and billed unit |
| Allocation within outstanding | Checked inside the posting transaction |
| Posted rows immutable | Triggers rejecting `UPDATE` and `DELETE` on posted payroll, issued invoices and allocations |
| Cross-tenant reference invalid | Cloud: composite foreign key on `(tenant_id, id)`. Local: impossible across files, and restore checks tenant identity |

## Transactions (MODEL-07)

Issuing an invoice or posting payroll writes the document, the ledger postings, the source links, the audit event and the outbox entry in one transaction. A crash leaves all or nothing. PDF rendering happens after commit from the snapshot, so a failed render retries without creating a second document.

## Outbox (TEAM-04)

Written from P1, in the same transaction as the change: `operation_id` (UUID, also the idempotency key), `tenant_id`, `entity`, `record_id`, `record_version`, `device_id`, `payload`, `created_at_utc`, `acked_at_utc`. Free and Solo never upload it (ARCH-02). It only sends when Team sync is on (T25).

## Local storage (D-005, D-016)

One encrypted file per tenant, `tenant_<uuid>.db` in app-private storage, with a random 256-bit key per tenant in Keystore-backed storage. Logout closes the handle, clears in-memory state and removes the PDF cache (AUTH-04).

## Cloud control data (MODEL-02)

Designed in T19: auth users, tenants, memberships, devices, plans and versions, subscriptions, entitlement leases, verified payments, activation redemptions, support tickets, diagnostic events, monthly metric snapshots, admin audit, Play import batches. Tenant operational tables are added for Team only (T25). Payroll and worker photos from Free and Solo are never uploaded automatically (ARCH-02).

Server-only actions (MODEL-05): tenant creation and membership, trial eligibility, licence issue and revoke, payment posting, Team final invoice numbers, metrics. A client can never grant itself a plan by setting a flag.
