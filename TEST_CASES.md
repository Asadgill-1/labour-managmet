# Test Cases

TC-001 to TC-013 are the PRD's mandatory acceptance groups (ch. 23). TC-014 to TC-048 extend them to cover each phase; later tasks may add more.

Type: `domain` (`dart test`), `app` (`flutter test`), `backend` (`supabase test db`), `manual` (real phone or person). A case is VERIFIED only after an actual run (AI-03).

| TC | Phase | Req | Scenario | Expected | Type | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TC-001 | P2 | PAY-02, PAY-03 | September net 1,000, paid 500. October net 1,000, paid 0 | October total payable 1,500, closing 1,500, no duplicate wage expense | domain | VERIFIED |
| TC-002 | P2 | PAY-05 | Advance 300 issued, payroll recovers 100 | Advance outstanding 200, salary balance correct, neither is wage expense | domain | VERIFIED |
| TC-003 | P1 | CALC-02 | 10 workers, 12 clock hours, client and payroll breaks set independently | Client and payroll minutes differ as configured, PRD examples exact | domain | VERIFIED |
| TC-004 | P3 | TS-05, INV-06, MODEL-04 | Repeat the invoice action on already billed work | Same work is not charged twice | app | NOT_STARTED |
| TC-005 | P3 | INV-04, INV-05 | AED 1,100 at 5% VAT, then receipt of 500 | VAT 55, total 1,155, outstanding 655 | domain | NOT_STARTED |
| TC-006 | P4 | AUTH-02, AUTH-05 | Tenant A tries tenant B data through login, API, storage and restore | Every attempt denied | backend | NOT_STARTED |
| TC-007 | P6 | TEAM-03 | Attendance-only manager requests payroll data | Payroll payload never reaches the response or local DB | backend | NOT_STARTED |
| TC-008 | P1 | ATT-05, TEAM-04, UX-07 | App restart and repeated retry during a save | Entry neither lost nor duplicated | app | VERIFIED |
| TC-009 | P3 | DOC-01, DOC-03 | Export every document type, single and multi page | Correct tenant letterhead on every page | manual | NOT_STARTED |
| TC-010 | P4 | DATA-05, DATA-06 | Authorized restore on a new device | Totals and invoice history match the source | manual | NOT_STARTED |
| TC-011 | P5 | ADMIN-04, MET-01 | 1 tenant with 2 users on 2 devices | Counts as 1 customer, not 2 | backend | NOT_STARTED |
| TC-012 | P4 | PLAN-03 | Paid plan or trial expires | Data and basic export remain available | app | NOT_STARTED |
| TC-013 | P7 | QA-01 | Signup, company, 2 clients, mixed-pay workers, attendance, payroll, partial payment, timesheet, VAT invoice, partial receipt, PDF share, backup, restore | Full flow completes with correct totals | manual | NOT_STARTED |
| TC-014 | P0 | ARCH-01, DATA-01, AUTH-04 | Open tenant databases with real and wrong keys, inspect the raw file | No plaintext header or marker, wrong key and other tenant's key rejected, plain SQLite build refused | app | IN_PROGRESS |
| TC-015 | P0 | CALC-01 | Round values below, at and above half, and their negatives | Half-up on magnitude, a reversal is the exact negative | domain | VERIFIED |
| TC-016 | P1 | CALC-02 | 10 workers, 660 minutes, client AED 10 and payroll AED 8 per hour | 1,100 billed, 880 wage, 220 contribution | domain | VERIFIED |
| TC-017 | P1 | CALC-03 | Same client charge, worker on agreed full shift AED 70 | 700 wage, 400 contribution, fee not multiplied by hours | domain | VERIFIED |
| TC-018 | P1 | ATT-06 | Shift 20:00 to next-day 08:00, break longer than shift | 720 minutes, oversized break rejected | domain | VERIFIED |
| TC-019 | P1 | CALC-04 | Monthly worker with 26 attendance rows, then a mid-month joiner | Salary counted once per period. Partial period uses the contract's method and stops if none is set | domain | VERIFIED |
| TC-020 | P1 | CALC-05, TS-08 | Fixed monthly client contract with 10 workers attending | One fee, not multiplied by worker rows | domain | VERIFIED |
| TC-021 | P1 | CALC-06 | Rate lookup with override, assignment, contract and no rate. Contract changes after approval | Priority order holds, missing rate stops for review, approved row keeps its snapshot | domain | VERIFIED |
| TC-022 | P1 | CALC-07 | Extra hours on contracts with and without an overtime multiplier | Regular and overtime separate, multiplier only where contracted | domain | VERIFIED |
| TC-023 | P1 | ATT-03 | Group rate applied to mixed hourly and monthly workers | Billing rate applies, worker pay stays from each contract, no silent conversion | app | VERIFIED |
| TC-024 | P1 | ATT-04 | Batch of 10 with one invalid row, and a crash mid-save | Nothing half-saved, row error shown, no false success | app | VERIFIED |
| TC-025 | P1 | ATT-05 | Overlapping time at two sites, then two non-overlapping shifts on one day | Overlap needs an approval reason, valid second job allowed | app | VERIFIED |
| TC-026 | P1 | UX-05 | Copy yesterday's team | New entries are unapproved until the owner reviews them | app | VERIFIED |
| TC-027 | P1 | ATT-08 | Correct a posted entry that was on a shared timesheet | Original kept, revision trail exists, shared version preserved | app | VERIFIED |
| TC-028 | P1 | ATT-09 | One worker on two shifts in a day | Unique workers 1, shifts 2, not an amount input | domain | VERIFIED |
| TC-029 | P1 | MASTER-07 | Archive a worker with a balance, rehire with the same name | Balance and payslips stay available, no hard delete, no auto-merge | app | VERIFIED |
| TC-030 | P1 | MASTER-05 | Enter opening salary owed, opening advance and client receivable | Kept separate with source date, salary balance is not a wage expense | app | VERIFIED |
| TC-031 | P1 | UX-06 | 5 non-technical users enter 10 same-rate workers after setup | Under 60 seconds, at least 4 of 5 without a trainer | manual | NOT_STARTED |
| TC-032 | P2 | PAY-04 | Opening 500, gross 1,000, room 200, recovery 100, paid 600 | Total payable 1,200, closing 600 | domain | VERIFIED |
| TC-033 | P2 | PAY-07 | Deductions exceed gross, deduction without authorization | Posting blocked for review, no debt carried automatically | domain | VERIFIED |
| TC-034 | P2 | PAY-06 | Pay more than owed, pay against several open periods | Overpayment becomes advance or credit, allocation oldest first after confirmation | domain | NOT_STARTED |
| TC-035 | P2 | PAY-05 | Recover more than the outstanding advance | Rejected | domain | VERIFIED |
| TC-036 | P2 | PAY-01, MODEL-07 | Edit posted payroll, crash during posting | Edit refused, posting is all or nothing | app | VERIFIED |
| TC-037 | P2 | REP-04 | Change data in a locked period | Needs owner reason, recorded as a dated adjustment | app | NOT_STARTED |
| TC-038 | P3 | TS-02 | Generate commercial and non-commercial customer timesheets | Wage rate and salary deductions never appear, rates hidden in non-commercial | app | NOT_STARTED |
| TC-039 | P3 | TS-03 | Same date and site with different rates and units | Rows not merged into one ambiguous line | app | NOT_STARTED |
| TC-040 | P3 | INV-03, INV-04 | Inclusive AED 105 at 5%. Customer TRN entered, supplier not VAT registered | Net 100, VAT 5. TRN alone does not add tax | domain | NOT_STARTED |
| TC-041 | P3 | INV-01, INV-06 | Draft, issue, then correct an invoice | Draft has no legal number, sequence unique, credit note preserves the original | app | NOT_STARTED |
| TC-042 | P3 | DOC-05 | Change logo and address after issuing an invoice | Old copy unchanged, duplicate has the same number and a COPY label | app | NOT_STARTED |
| TC-043 | P3 | DOC-08 | Long names, large amounts, mixed rates, zero VAT, many pages | Headings repeat, no clipped rows, no blank last page, text selectable | manual | NOT_STARTED |
| TC-044 | P3 | REP-02, REP-03 | Month with VAT, advances, receipts and a room charge | VAT not revenue, advance not wage, contribution not called net profit | domain | NOT_STARTED |
| TC-045 | P4 | AUTH-04 | Company B logs in on a phone that held Company A | No A data, thumbnails, notifications or last-used PDF visible | manual | NOT_STARTED |
| TC-046 | P4 | DATA-05, DATA-06 | Restore wrong tenant, wrong key, corrupt file, newer schema, stale backup | All rejected, a stale backup cannot reissue used invoice numbers | app | NOT_STARTED |
| TC-047 | P4 | BILL-03, BILL-05, MODEL-05 | Set a paid flag locally, replay or tamper with a licence, let a lease expire | No paid access gained, expiry leaves safe read and export mode | backend | NOT_STARTED |
| TC-048 | P6 | TEAM-05, TEAM-06 | Owner and manager edit the same hours on 2 devices, then revoke the manager | Conflict goes to review, no last-write-wins on money, next server request blocked | manual | NOT_STARTED |
| TC-049 | P1 | ATT-01, ATT-03 | Mark attendance from a group: skip one member, add one outsider with a typed wage | Rows priced by own wage, group wage or typed wage. The group is unchanged next time | app | IMPLEMENTED_UNVERIFIED |
| TC-050 | P1 | ATT-03, CALC-06 | A monthly worker in a group with a daily wage | Stays monthly, with no daily amount on the row. A changed group wage reaches only unapproved rows | app | IMPLEMENTED_UNVERIFIED |
| TC-051 | P2 | PAY-05, PAY-06, REP-08 | Advance, return above outstanding, undo, undo twice, direct UPDATE or DELETE on the cash book | Return refused, undo keeps the original and cancels it exactly, second undo refused, direct change refused by trigger | app | IMPLEMENTED_UNVERIFIED |
| TC-052 | P2 | REP-07 | Rent paid for a room and rent received from a worker in that room | Each entry stays separate. The room shows received, paid and profit or loss, labelled for that room only | app | IMPLEMENTED_UNVERIFIED |
| TC-053 | P1 | MODEL-08 | Open a database from an earlier schema version holding workers and attendance | Upgrades in place, data kept, schema matches the latest snapshot | app | IMPLEMENTED_UNVERIFIED |
| TC-054 | P2 | ATT-08, PAY-02 | Correct a paid row twice, and approve a row after its month is posted | Next payroll holds only the difference, or the late amount, outside that month's net. Nothing paid twice or lost | app | VERIFIED |
| TC-055 | P2 | PAY-01, REP-08 | Undo a posted month, undo an earlier month with a later one posted, post the month again | Line stays on record with the reason, work and items are unpaid again, recovery no longer stands, money paid stays. An earlier month is refused until the later one is undone | app | VERIFIED |
