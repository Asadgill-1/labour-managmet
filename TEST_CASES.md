# Test Cases

TC-001 to TC-013 are the PRD's mandatory acceptance groups (ch. 23). T04 expands this list to the full set.

Type: `domain` (`dart test`), `app` (`flutter test`), `backend` (`supabase test db`), `manual` (real phone or person). A case is VERIFIED only after an actual run (AI-03).

| TC | Phase | Req | Scenario | Expected | Type | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TC-001 | P2 | PAY-02, PAY-03 | September net 1,000, paid 500. October net 1,000, paid 0 | October total payable 1,500, closing 1,500, no duplicate wage expense | domain | NOT_STARTED |
| TC-002 | P2 | PAY-05 | Advance 300 issued, payroll recovers 100 | Advance outstanding 200, salary balance correct, neither is wage expense | domain | NOT_STARTED |
| TC-003 | P1 | CALC-02 | 10 workers, 12 clock hours, client and payroll breaks set independently | Client and payroll minutes differ as configured, PRD examples exact | domain | NOT_STARTED |
| TC-004 | P3 | TS-05, INV-06, MODEL-04 | Repeat the invoice action on already billed work | Same work is not charged twice | app | NOT_STARTED |
| TC-005 | P3 | INV-04, INV-05 | AED 1,100 at 5% VAT, then receipt of 500 | VAT 55, total 1,155, outstanding 655 | domain | NOT_STARTED |
| TC-006 | P4 | AUTH-02, AUTH-05 | Tenant A tries tenant B data through login, API, storage and restore | Every attempt denied | backend | NOT_STARTED |
| TC-007 | P6 | TEAM-03 | Attendance-only manager requests payroll data | Payroll payload never reaches the response or local DB | backend | NOT_STARTED |
| TC-008 | P1 | ATT-05, TEAM-04, UX-07 | App restart and repeated retry during a save | Entry neither lost nor duplicated | app | NOT_STARTED |
| TC-009 | P3 | DOC-01, DOC-03 | Export every document type, single and multi page | Correct tenant letterhead on every page | manual | NOT_STARTED |
| TC-010 | P4 | DATA-05, DATA-06 | Authorized restore on a new device | Totals and invoice history match the source | manual | NOT_STARTED |
| TC-011 | P5 | ADMIN-04, MET-01 | 1 tenant with 2 users on 2 devices | Counts as 1 customer, not 2 | backend | NOT_STARTED |
| TC-012 | P4 | PLAN-03 | Paid plan or trial expires | Data and basic export remain available | app | NOT_STARTED |
| TC-013 | P7 | QA-01 | Signup, company, 2 clients, mixed-pay workers, attendance, payroll, partial payment, timesheet, VAT invoice, partial receipt, PDF share, backup, restore | Full flow completes with correct totals | manual | NOT_STARTED |
