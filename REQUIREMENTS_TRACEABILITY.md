# Requirements Traceability

Every PRD requirement, the task that delivers it, and the proof it works. `python tools/check_trace.py` fails CI if a PRD ID is missing here, or marked done without a test and evidence.

Status values (AI-02): NOT_STARTED, IN_PROGRESS, BLOCKED, IMPLEMENTED_UNVERIFIED, VERIFIED, OWNER_ACCEPTED.

| ID | Ch | Summary | Tasks | Status | Tests | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| UX-01 | 02 | Left side panel, replaces bottom tabs (D-027) | T04, T05 | IMPLEMENTED_UNVERIFIED | - | - |
| UX-02 | 02 | Onboarding | T05, T19 | IN_PROGRESS | - | - |
| UX-03 | 02 | Saaf labels | T05 | IMPLEMENTED_UNVERIFIED | - | - |
| UX-04 | 02 | Readability | T05 | IMPLEMENTED_UNVERIFIED | - | - |
| UX-05 | 02 | Kam typing | T10 | IMPLEMENTED_UNVERIFIED | TC-026 | - |
| UX-06 | 02 | Measurable usability test | T10 | NOT_STARTED | TC-031 | - |
| UX-07 | 02 | Save ki imaandari | T05 | IN_PROGRESS | TC-008 | - |
| AUTH-01 | 03 | Email/password primary login ho. Email verification, forgot-password, safe password | T19 | NOT_STARTED | - | - |
| AUTH-02 | 03 | Signup par immutable tenant ID bane. Naam, phone number | T19 | NOT_STARTED | TC-006 | - |
| AUTH-03 | 03 | Pehla signup, naya device login, password reset aur invite | T19 | NOT_STARTED | - | - |
| AUTH-04 | 03 | Har local database tenant/account boundary mein encrypted ho. Logout/account | T19 | NOT_STARTED | TC-014, TC-045 | - |
| AUTH-05 | 03 | Cloud tenant tables par Row Level Security aur membership | T19 | NOT_STARTED | TC-006 | - |
| AUTH-06 | 03 | App malik ke admin account par MFA lazmi ho | T19 | NOT_STARTED | - | - |
| AUTH-07 | 03 | Account deletion app aur web dono se request ki | T19 | NOT_STARTED | - | - |
| AUTH-08 | 03 | Production email login ke liye real SMTP/domain configuration aur | T19 | NOT_STARTED | - | - |
| MASTER-01 | 04 | Apni company | T07 | IMPLEMENTED_UNVERIFIED | - | - |
| MASTER-02 | 04 | Client | T07 | IMPLEMENTED_UNVERIFIED | - | - |
| MASTER-03 | 04 | Sites | T07 | IMPLEMENTED_UNVERIFIED | - | - |
| MASTER-04 | 04 | Worker | T07 | IMPLEMENTED_UNVERIFIED | - | - |
| MASTER-05 | 04 | Opening balances | T08 | IMPLEMENTED_UNVERIFIED | TC-030 | - |
| MASTER-06 | 04 | Rate cards | T08 | IMPLEMENTED_UNVERIFIED | - | - |
| MASTER-07 | 04 | Archive | T07 | IMPLEMENTED_UNVERIFIED | TC-029 | - |
| MASTER-08 | 04 | Import | T18 | NOT_STARTED | - | - |
| ATT-01 | 05 | Flow | T10 | IMPLEMENTED_UNVERIFIED | - | - |
| ATT-02 | 05 | Entry fields | T10 | IMPLEMENTED_UNVERIFIED | - | - |
| ATT-03 | 05 | Bulk apply | T10 | IMPLEMENTED_UNVERIFIED | TC-023 | - |
| ATT-04 | 05 | Exceptions | T10 | IMPLEMENTED_UNVERIFIED | TC-024 | - |
| ATT-05 | 05 | Duplication | T10 | IMPLEMENTED_UNVERIFIED | TC-008, TC-025 | - |
| ATT-06 | 05 | Midnight shift | T10 | IMPLEMENTED_UNVERIFIED | TC-018 | - |
| ATT-07 | 05 | Attendance states | T10 | IMPLEMENTED_UNVERIFIED | - | - |
| ATT-08 | 05 | Correction | T10 | IMPLEMENTED_UNVERIFIED | TC-027 | - |
| ATT-09 | 05 | Maaloomati summary | T10 | IMPLEMENTED_UNVERIFIED | TC-028 | - |
| CALC-01 | 06 | Duration integer minutes mein; amounts integer fils ya exact | T04, T09 | IN_PROGRESS | TC-015 | - |
| CALC-02 | 06 | Hourly | T09 | IMPLEMENTED_UNVERIFIED | TC-003, TC-016 | - |
| CALC-03 | 06 | Shift/day | T09 | IMPLEMENTED_UNVERIFIED | TC-017 | - |
| CALC-04 | 06 | Monthly | T09 | IMPLEMENTED_UNVERIFIED | TC-019 | - |
| CALC-05 | 06 | Monthly client billing | T09 | IMPLEMENTED_UNVERIFIED | TC-020 | - |
| CALC-06 | 06 | Rate priority | T09 | IMPLEMENTED_UNVERIFIED | TC-021 | - |
| CALC-07 | 06 | Overtime | T09 | IMPLEMENTED_UNVERIFIED | TC-022 | - |
| PAY-01 | 07 | Payroll cycle | T11 | IMPLEMENTED_UNVERIFIED | TC-036, TC-055 | `apps/mobile/test/payroll_test.dart` |
| PAY-02 | 07 | Do alag concepts | T11 | IMPLEMENTED_UNVERIFIED | TC-001, TC-054 | `packages/domain/test/payroll_test.dart` |
| PAY-03 | 07 | User ki misal | T11 | IMPLEMENTED_UNVERIFIED | TC-001 | `packages/domain/test/payroll_test.dart`, `apps/mobile/test/payroll_test.dart` |
| PAY-04 | 07 | Katoti ki misal | T11 | IMPLEMENTED_UNVERIFIED | TC-032 | `packages/domain/test/payroll_test.dart`, `apps/mobile/test/payroll_test.dart` |
| PAY-05 | 07 | Advance sub-ledger | T11, T12, T12a | IN_PROGRESS | TC-002, TC-035, TC-051 | - |
| PAY-06 | 07 | Salary payments | T12, T12a | IN_PROGRESS | TC-034, TC-051 | - |
| PAY-07 | 07 | Deductions | T11 | IMPLEMENTED_UNVERIFIED | TC-033 | `apps/mobile/test/payroll_test.dart` |
| PAY-08 | 07 | Compliance | T12 | NOT_STARTED | - | - |
| PAY-09 | 07 | Payslip | T14 | NOT_STARTED | - | - |
| TS-01 | 08 | Client/date range/site chunein aur approved attendance se timesheet banayein | T15 | NOT_STARTED | - | - |
| TS-02 | 08 | Columns | T15 | NOT_STARTED | TC-038 | - |
| TS-03 | 08 | Daily summary | T15 | NOT_STARTED | TC-039 | - |
| TS-04 | 08 | Lifecycle | T15 | NOT_STARTED | - | - |
| TS-05 | 08 | Invoice source | T15 | NOT_STARTED | TC-004 | - |
| TS-06 | 08 | Revision | T15 | NOT_STARTED | - | - |
| TS-07 | 08 | Output | T15 | NOT_STARTED | - | - |
| TS-08 | 08 | Monthly contracts | T15 | NOT_STARTED | TC-020 | - |
| INV-01 | 09 | Creation | T16 | NOT_STARTED | TC-041 | - |
| INV-02 | 09 | Minimum fields | T16 | NOT_STARTED | - | - |
| INV-03 | 09 | VAT | T16 | NOT_STARTED | TC-040 | - |
| INV-04 | 09 | Arithmetic | T16 | NOT_STARTED | TC-005, TC-040 | - |
| INV-05 | 09 | Receipt | T17 | NOT_STARTED | TC-005 | - |
| INV-06 | 09 | Corrections | T16 | NOT_STARTED | TC-004, TC-041 | - |
| INV-07 | 09 | Status | T17 | NOT_STARTED | - | - |
| INV-08 | 09 | Online/offline numbering | T16 | NOT_STARTED | - | - |
| INV-09 | 09 | e-Invoicing gate | T16 | NOT_STARTED | - | - |
| DOC-01 | 10 | Aik shared engine | T14 | NOT_STARTED | TC-009 | - |
| DOC-02 | 10 | Free basic identity | T14 | NOT_STARTED | - | - |
| DOC-03 | 10 | Layout | T14 | NOT_STARTED | TC-009 | - |
| DOC-04 | 10 | Images | T14 | NOT_STARTED | - | - |
| DOC-05 | 10 | Revision | T14 | NOT_STARTED | TC-042 | - |
| DOC-06 | 10 | Actions | T14 | NOT_STARTED | - | - |
| DOC-07 | 10 | Data safety | T14 | NOT_STARTED | - | - |
| DOC-08 | 10 | Tests | T14 | NOT_STARTED | TC-043 | - |
| REP-01 | 11 | Reports | T18 | NOT_STARTED | - | - |
| REP-02 | 11 | Hisaab ki separation | T18 | NOT_STARTED | TC-044 | - |
| REP-03 | 11 | Margin | T18 | NOT_STARTED | TC-044 | - |
| REP-04 | 11 | Closing | T13 | NOT_STARTED | TC-037 | - |
| REP-05 | 11 | Historical integrity | T13 | NOT_STARTED | - | - |
| REP-06 | 11 | Backup/export | T18 | NOT_STARTED | - | - |
| REP-07 | 11 | Expenses | T13, T12a | IN_PROGRESS | TC-052 | - |
| REP-08 | 11 | Ledger design | T11, T12a | IMPLEMENTED_UNVERIFIED | TC-036, TC-051, TC-055 | `apps/mobile/test/payroll_test.dart`, `apps/mobile/test/cash_test.dart` |
| PLAN-01 | 12 | Trial 14 din; Team feature trial owner ki clear | T24 | NOT_STARTED | - | - |
| PLAN-02 | 12 | Manager trial end par paid Team entitlement na ho | T24 | NOT_STARTED | - | - |
| PLAN-03 | 12 | Expiry par data delete, hidden balance ya mandatory ransom | T21 | NOT_STARTED | TC-012 | - |
| PLAN-04 | 12 | Active worker count ko payroll history se alag karein | T21 | NOT_STARTED | - | - |
| PLAN-05 | 12 | Optional annual Solo AED 490 / Team AED 990 | T24 | NOT_STARTED | - | - |
| PLAN-06 | 12 | Paid upgrade ka sabab real value ho: zyada workers/clients | T21 | NOT_STARTED | - | - |
| BILL-01 | 13 | Manual start | T22 | NOT_STARTED | - | - |
| BILL-02 | 13 | Activation | T21 | NOT_STARTED | - | - |
| BILL-03 | 13 | Safer design | T21 | NOT_STARTED | TC-047 | - |
| BILL-04 | 13 | Renewals | T22 | NOT_STARTED | - | - |
| BILL-05 | 13 | Offline | T21 | NOT_STARTED | TC-047 | - |
| BILL-06 | 13 | Tampering | T21 | NOT_STARTED | - | - |
| BILL-07 | 13 | Play Store policy | T26 | NOT_STARTED | - | - |
| BILL-08 | 13 | Distribution decision | T26 | NOT_STARTED | - | - |
| BILL-09 | 13 | Business licensing, invoice/tax treatment aur receiving bank-account permissions user | T26 | NOT_STARTED | - | - |
| ARCH-01 | 14 | Mobile | T03 | IMPLEMENTED_UNVERIFIED | TC-014 | - |
| ARCH-02 | 14 | Chhota control backend | T19 | NOT_STARTED | - | - |
| ARCH-03 | 14 | App malik web | T22 | NOT_STARTED | - | - |
| ARCH-04 | 14 | Paid Team | T25 | NOT_STARTED | - | - |
| ARCH-05 | 14 | Cost | T23 | NOT_STARTED | - | - |
| ARCH-06 | 14 | Budget controls | T23 | NOT_STARTED | - | - |
| ARCH-07 | 14 | Failure independence | T19 | NOT_STARTED | - | - |
| ARCH-08 | 14 | No-code ki wazahat | T01 | IMPLEMENTED_UNVERIFIED | - | - |
| TEAM-01 | 15 | Invite | T24 | NOT_STARTED | - | - |
| TEAM-02 | 15 | Permission presets | T24 | NOT_STARTED | - | - |
| TEAM-03 | 15 | Payload isolation | T24 | NOT_STARTED | TC-007 | - |
| TEAM-04 | 15 | Sync | T25 | IN_PROGRESS | TC-008 | - |
| TEAM-05 | 15 | Conflicts | T25 | NOT_STARTED | TC-048 | - |
| TEAM-06 | 15 | Revocation | T25 | NOT_STARTED | TC-048 | - |
| TEAM-07 | 15 | Team downgrade | T25 | NOT_STARTED | - | - |
| TEAM-08 | 15 | Pilot safety | T25 | NOT_STARTED | - | - |
| DATA-01 | 16 | Local database encryption key Android platform ke protected key | T03 | IN_PROGRESS | TC-014 | - |
| DATA-02 | 16 | Backup bundle | T20 | NOT_STARTED | - | - |
| DATA-03 | 16 | Owner warning | T20 | NOT_STARTED | - | - |
| DATA-04 | 16 | Local backup | T20 | NOT_STARTED | - | - |
| DATA-05 | 16 | Restore | T20 | NOT_STARTED | TC-010, TC-046 | - |
| DATA-06 | 16 | Phone change | T20 | NOT_STARTED | TC-010, TC-046 | - |
| DATA-07 | 16 | Key recovery | T20 | NOT_STARTED | - | - |
| DATA-08 | 16 | Retention | T20 | NOT_STARTED | - | - |
| ADMIN-01 | 17 | Navigation | T22 | NOT_STARTED | - | - |
| ADMIN-02 | 17 | Customer register | T22 | NOT_STARTED | - | - |
| ADMIN-03 | 17 | Subscription operations | T22 | NOT_STARTED | - | - |
| ADMIN-04 | 17 | Product funnel | T23 | NOT_STARTED | TC-011 | - |
| ADMIN-05 | 17 | Offline visibility | T23 | NOT_STARTED | - | - |
| ADMIN-06 | 17 | Health | T23 | NOT_STARTED | - | - |
| ADMIN-07 | 17 | Support | T23 | NOT_STARTED | - | - |
| ADMIN-08 | 17 | Access | T22 | NOT_STARTED | - | - |
| MET-01 | 18 | Dashboard fancy totals ke bajaye reproducible data de. Trial | T23 | NOT_STARTED | TC-011 | - |
| MET-02 | 18 | Manual renewals | T23 | NOT_STARTED | - | - |
| MET-03 | 18 | MRR bridge | T23 | NOT_STARTED | - | - |
| MET-04 | 18 | Costs | T23 | NOT_STARTED | - | - |
| MET-05 | 18 | Source of truth | T23 | NOT_STARTED | - | - |
| MET-06 | 18 | Investor pack | T23 | NOT_STARTED | - | - |
| MET-07 | 18 | Auditability | T23 | NOT_STARTED | - | - |
| OPS-01 | 19 | Privacy-first diagnostics | T23 | NOT_STARTED | - | - |
| OPS-02 | 19 | Telemetry contract | T23 | NOT_STARTED | - | - |
| OPS-03 | 19 | Initial alerts | T23 | NOT_STARTED | - | - |
| OPS-04 | 19 | Severity | T23 | NOT_STARTED | - | - |
| OPS-05 | 19 | Recovery runbook | T23 | NOT_STARTED | - | - |
| OPS-06 | 19 | Limits | T23 | NOT_STARTED | - | - |
| OPS-07 | 19 | Releases | T26 | NOT_STARTED | - | - |
| OPS-08 | 19 | Availability target | T23 | NOT_STARTED | - | - |
| MODEL-01 | 20 | Local operational groups | T04, T06 | IMPLEMENTED_UNVERIFIED | - | - |
| MODEL-02 | 20 | Cloud control groups | T19 | NOT_STARTED | - | - |
| MODEL-03 | 20 | Common keys | T04, T06 | IMPLEMENTED_UNVERIFIED | - | - |
| MODEL-04 | 20 | Constraints | T04, T06 | IMPLEMENTED_UNVERIFIED | TC-004 | - |
| MODEL-05 | 20 | Server-only actions | T19 | NOT_STARTED | TC-047 | - |
| MODEL-06 | 20 | Conceptual API contracts | T19 | NOT_STARTED | - | - |
| MODEL-07 | 20 | Financial boundary | T11 | IMPLEMENTED_UNVERIFIED | TC-036 | `apps/mobile/test/payroll_test.dart` |
| MODEL-08 | 20 | Migration | T06 | IMPLEMENTED_UNVERIFIED | - | - |
| BUILD-01 | 21 | Auth/tenant models P0 se architecture mein hon; P4 production | T04 | IN_PROGRESS | - | - |
| BUILD-02 | 21 | Solo pilot P5 ke baad sirf tested scope ke | T26 | NOT_STARTED | - | - |
| BUILD-03 | 21 | Owner ko test APK, sample documents, 5-minute walkthrough aur | T01 | IN_PROGRESS | - | - |
| BUILD-04 | 21 | Expected performance targets: reference low/mid-range Android device par 10-worker | T26 | NOT_STARTED | - | - |
| BUILD-05 | 21 | Launch capacity fixture 300 active workers, 24 months history | T26 | NOT_STARTED | - | - |
| BUILD-06 | 21 | Phase approval non-developer owner ki visual demo + automated | T26 | NOT_STARTED | - | - |
| AI-01 | 22 | Repo source of truth | T01 | IMPLEMENTED_UNVERIFIED | - | - |
| AI-02 | 22 | Work discipline | T01 | IN_PROGRESS | - | - |
| AI-03 | 22 | Done ka matlab | T01 | IN_PROGRESS | - | - |
| AI-04 | 22 | Session handover | T01 | IN_PROGRESS | - | - |
| AI-05 | 22 | GitHub, public by owner's choice (D-032) | T02 | IN_PROGRESS | - | - |
| AI-06 | 22 | CI gates | T02 | IMPLEMENTED_UNVERIFIED | - | - |
| AI-07 | 22 | No silent changes | T01 | IN_PROGRESS | - | - |
| AI-08 | 22 | Full ownership | T01 | IN_PROGRESS | - | - |
| QA-01 | 23 | Aik complete end-to-end test: signup > apni company > | T26 | NOT_STARTED | TC-013 | - |
