# Review 04: screens and exports

## Files read in full
- docs/SCREEN_FLOW.md
- PRD_Roman_Urdu.md chapters 02, 08, 09, 10, 11 (lines 95-295)
- apps/mobile/lib/app/app.dart
- apps/mobile/lib/app/side_panel.dart
- apps/mobile/lib/app/register_screen.dart
- apps/mobile/lib/app/form_bits.dart
- apps/mobile/lib/documents/document_frame.dart
- apps/mobile/lib/features/registers/register_model.dart
- apps/mobile/lib/features/registers/register_defs.dart
- apps/mobile/lib/features/registers/ledger_screen.dart
- apps/mobile/lib/features/registers/export_flow.dart
- apps/mobile/lib/features/registers/register_export.dart
- apps/mobile/lib/features/registers/register_pdf.dart
- apps/mobile/lib/features/registers/register_xlsx.dart
- apps/mobile/lib/features/registers/salary_sheet.dart
- apps/mobile/lib/features/registers/reports_screen.dart
- apps/mobile/lib/features/documents/documents_screen.dart
- apps/mobile/lib/features/documents/document_preview_screen.dart
- apps/mobile/lib/features/documents/document_render.dart
- apps/mobile/lib/features/documents/letterhead_screen.dart
- apps/mobile/lib/features/documents/receipt.dart
- apps/mobile/lib/features/timesheets/timesheets_screen.dart
- apps/mobile/lib/features/timesheets/timesheet_screen.dart
- apps/mobile/lib/features/timesheets/timesheet_paper.dart
- apps/mobile/lib/features/invoices/invoices_screen.dart
- apps/mobile/lib/features/invoices/invoice_screen.dart
- apps/mobile/lib/features/invoices/invoice_paper.dart
- apps/mobile/lib/features/changes/change_notes.dart
- apps/mobile/lib/features/more/import_screen.dart
- apps/mobile/lib/features/more/profile_form_screen.dart

## Files not fully read
- apps/mobile/lib/app/theme.dart: skimmed only, as instructed (visual style is out of scope).
- apps/mobile/lib/l10n/app_en.arb and app_en_PK.arb: not read line by line (4,400 lines). Instead every key, placeholder and plural was compared by a script, and the strings behind each register, report and paper in scope were read. Result: 46 `invP*` keys exist only in English, which is intended (papers are English, D-050). No placeholder mismatches beyond plural syntax. Missing keys used in code are impossible because `gen-l10n` would not compile.
- Context files, read only where a finding needed them: data/attendance.dart (lines 300-500), data/cash.dart (20-130), data/invoices.dart (560-680, 868-910), data/timesheets.dart (160-270), data/statement.dart (grep), data/tables.dart (40-95). data/receipts.dart and data/documents.dart were not opened.
- Tests: only test names and targeted greps in registers_test, reports_test, documents_test, timesheet_paper_test, invoice_paper_test and app_shell_test, to check coverage. Tests were not run (forbidden for this review).

## Rules checked
| Route, register or rule | Source | Built where | Result |
| --- | --- | --- | --- |
| Every `Section` opens a screen | D-027, D-036 | app.dart `_screen` (exhaustive switch) | SOUND |
| Main tabs and sub-tabs match the table | SCREEN_FLOW lines 23-36 | side_panel.dart `mainTabs` | SOUND |
| "Jald" rows do nothing and say so | AI-07, SCREEN_FLOW line 16 | side_panel.dart `_SubRow` with no onTap | SOUND, but see F04-4 (Plan is built) |
| Register shape: dates with quick choices, multi-value filters, band totals, grouped rows, one export | D-038, SCREEN_FLOW line 38 | ledger_screen.dart | SOUND, but see F04-3 |
| From after to cannot happen; both ends inclusive | task step 5 | ledger_screen.dart `_pick`, register_defs.dart `_inRange` | SOUND |
| Screen, PDF and Excel come from the same rows and rollups | D-038 | export_flow.dart `exportRegister` | SOUND |
| Attendance register: live rows only, sums by worker and site | REP-01 | register_defs.dart `_attendance` | SOUND |
| Company register: per date and site; difference note discloses monthly salaries | REP-01 | `_companies` | SOUND |
| Worker register: brought forward, balance = earned - advance - cuts - paid, derives | D-041, D-042, REP-08 | `_workers` | SOUND |
| Cash register: deleted line and its reversal leave the list, totals cancel | D-056, REP-08 | `_cash`, cash_row.dart `liveCash` | SOUND |
| Advance and visa registers: running "left" over all history | PAY-05, D-039 | `_advance`, `_visa`, `_account` | SOUND |
| Payroll register: posted lines only, paid derived between postings | D-033 | `_payroll` | SOUND |
| Company statement: opening, invoices incl. VAT, credit notes, receipts and reversals, lost and un-lost, brought forward | INV-07, REP-08 | `_statement` | DEFECT, F04-1 |
| Invoice register: credit notes signed negative, record not e-invoice | INV-09, D-011 | `_invoices` | SOUND |
| Aging register: by due date, credit-only company still shown | REP-01 | `_aging` | SOUND except F04-1 footer |
| Work register: worth, invoiced, still to bill, no-rate days apart | REP-01, D-048 | `_work`, data/invoices.dart `workCharges` | SOUND |
| Owner's sheet: VAT out of bill, advances and visa not costs, room in and out apart, estimate wording | REP-02, REP-03, REP-07 | salary_sheet.dart | SOUND (tested in reports_test) |
| Deleted tabs: by delete day, facts as they were, blank clarification column | D-056 | `_deleted*` | SOUND |
| Timesheet paper never shows a worker wage; rates only when chosen | TS-02 | timesheet_paper.dart, data/timesheets.dart (client fields only) | SOUND (tested) |
| Invoice paper says it is not a UAE e-invoice; register says the same | INV-09 | invoice_paper.dart `invPNotEInvoice`, `regInvoiceNote` | SOUND (tested) |
| Tax Invoice title only for a VAT-registered supplier; issue blocked without TRN | INV-02 | `invoiceTitle`, invoice_screen.dart `needsTrn`, data `issueInvoice` | SOUND |
| COPY mark keeps the number; draft preview marked DRAFT with no number | DOC-05, INV-01 | document_render.dart `issuedBytes`, invoice_paper.dart `draftPdf` | SOUND |
| Images limited in height on paper | DOC-03, DOC-04 | document_frame.dart `placedImage` maxHeight on header, footer, logo, signature, stamp; crop sliders capped at 40% each | SOUND |
| Long tables slice; no blank last page | DOC-08 | register_pdf.dart, timesheet_paper.dart `_sliceRows` | SOUND (tested) |
| Excel formula injection | task step 6 | register_xlsx.dart: all text is `t="inlineStr"` | SOUND (tested: registers_test line 426) |
| Fils to Excel without a double | CALC-01 | register_xlsx.dart `_decimal` | SOUND |
| Share never shown as delivered | DOC-07, SCREEN_FLOW line 84 | register_export.dart `runExport`, export_flow.dart | SOUND |
| Share files expire after a day | DOC-07 | register_export.dart `writeExportFile` | SOUND |
| Forms in lazy lists | task step 5 | form_bits.dart `FormBody` is a Column in a SingleChildScrollView | SOUND |
| Double tap on create screens | task step 5 | timesheet, invoice and profile forms hold one operation ID per screen, so a retry is idempotent | SOUND |
| Money parsing | CALC-01 | domain `parseAed`: non-negative, at most 13 digits, 2 decimals | SOUND |
| Silent `catch (_) {}` | task step 3 | every catch in scope shows a message | SOUND |
| Icon buttons without tooltip | UX-04 | only one IconButton in scope, and it has a tooltip | SOUND |
| Large text | UX-04 | app.dart `_textSize` | UNTESTED at large system scale, F04-8 |

## Findings

### F04-1: Two companies with the same name share one account on the statement, so its balance, footer and summary are wrong
- Severity: High (a wrong money figure shown and exported)
- Status: CONFIRMED by tracing the code; no test covers it
- Where: apps/mobile/lib/features/registers/register_defs.dart:1159-1195 `_statement` (group `c.name`, `feet[c.name]`, `facts[c.name]`); register_model.dart:168-176 `columnFigure`; also `_aging` 1549-1570 (`feet[c.name]`), `_work` 1667, salary_sheet.dart 63-66 and 79 (`byCompany` and `contractBill` keyed by name)
- Expected: each company's account stands alone and the band, PDF total, footer and "All companies" table agree with each company's own balance (INV-07, REP-08). Actual: the `Clients` table has no unique name (tables.dart:42), and CSV import treats a repeated name only as a warning (import.dart:107, 213). Every row of both companies gets the same group string, so `groupEntries` merges them into one group. `columnFigure` for the closing Balance column keeps only the last value per group, so the first company's balance drops out of the band figure and the PDF and Excel totals. `feet[c.name]` and `facts[c.name]` are overwritten by the second company, so the footer ("Company owes ...") and the TRN and Balance in the rollup belong to the second company while Invoiced and Received in the same rollup row add both.
- Reproduction: create company A "Emaar" (invoice AED 1,000 issued) and company B "Emaar" (invoice AED 500 issued). Open Company ka hisaab with All dates. The band Balance shows AED 500, not AED 1,500. The footer under the merged group says "owes AED 500". Filter to company A only: its rows show, but the footer under them still says AED 500 (B's figure). The rollup row shows Invoiced AED 1,500 with Balance AED 500. Regression test belongs in apps/mobile/test/registers_test.dart.
- Proposed minimal fix: give each company a unique group label in these registers, for example the name plus its TRN or a short counter when the name repeats (one helper used by `_statement`, `_aging`, `_work` and `buildSalarySheet`). Regression risk is low: only the heading text of the repeated companies changes; the worker register is already safe because it groups by `name (code)` and codes are unique.

### F04-2: Payment terms and a company's due days accept a negative number or words, so an invoice can be overdue the day it is issued
- Severity: Medium
- Status: CONFIRMED by tracing the code; no test covers it
- Where: apps/mobile/lib/features/more/profile_form_screen.dart:62 and 131 (`paymentTermsDays: Value(int.tryParse(...))`, no validator); the same pattern in features/companies/client_form_screen.dart:57 and 106 (outside this slice, named because it shares the cause); used at data/invoices.dart:663-670 `issueInvoice`
- Expected: the due date never falls before the issue date (the comment at invoices.dart:669 says so), and a typed value that is not a number is refused next to the field (UX-04). Actual: "-30" is stored as -30, so `addDays(today, -30)` makes the due date a month before the issue date and the invoice shows Overdue in the list, the invoice screen, the statement footer and the aging register from the first day. "30 days" or "30 din" is silently stored as null, which clears an existing value, and the invoice is then due the day it is issued.
- Reproduction: Apni company > Payment terms "-30" > Save (accepted, no message). Issue an invoice for a company with no due days of its own. The invoice reads Overdue at once and the aging register puts it in 1-30 days late. Regression test belongs in apps/mobile/test/invoices_test.dart (data guard) and a widget check in app_shell_test.dart or masters_test.dart.
- Proposed minimal fix: add the same validator the wage-due-days field already has (whole number, 0 to a sane maximum) to both fields, and clamp `dueDays` at 0 in `issueInvoice` as the one shared guard. Regression risk is low.

### F04-3: A register shows the old date range's rows and totals under the new dates while it loads, and can export them
- Severity: Medium
- Status: CONFIRMED by reading (Riverpod 3 gives a new family key a fresh loading state with no value); not reproduced on a device
- Where: apps/mobile/lib/features/registers/ledger_screen.dart:107-121 (`data = asked.value ?? _last`; export enabled whenever `data != null`)
- Expected: figures under a date range belong to that range, and a file says which dates it shows (REP-01, D-038). Actual: after tapping "Pichla mahina" or picking a date, the band buttons show the new dates at once, but `asked.value` is null until the new register is built, so the band totals and rows are the previous range's. The export button stays enabled, and `_export` writes the new dates into the file name and the filter line over the old rows. For a large tenant the build takes seconds (the code reads attendance in 2,000-row slices for this reason). The same fallback hides a failed rebuild: with `_last` set, an error shows the old figures with no error text.
- Reproduction: open Hazri register on This month with many rows, tap Last month, and tap Export before the list changes. The PDF is named and headed with last month's dates but holds this month's rows and totals. Regression test belongs in apps/mobile/test/registers_test.dart (widget test with a slow provider).
- Proposed minimal fix: keep `_last` only for the same query (store the query with it), or disable export and dim the band while `asked.isLoading`. Regression risk is low; the list may flash a spinner on range change.

### F04-4: The side panel says Plan is coming soon, but the Plan screen is built and opens from Settings
- Severity: Low
- Status: CONFIRMED
- Where: apps/mobile/lib/app/side_panel.dart:291-303 (`l10n.menuPlan` under "Jald aa raha hai"); features/plans/plan_screen.dart and settings_screen.dart import it; docs/SCREEN_FLOW.md line 16 also lists Reports and Documents as "Jald" although both are built and listed at lines 32 and 34
- Expected: a "soon" row means the feature does not exist (AI-07), and PROGRESS.md "Open" line 77 says a built Jald section leaves that row. Actual: the owner reads "Plan: soon" in the menu while plans, trials and the add-on are live elsewhere.
- Reproduction: open the menu, expand "Jald aa raha hai": Plan shows "soon"; then Settings opens the Plan screen. Regression test belongs in apps/mobile/test/app_shell_test.dart.
- Proposed minimal fix: drop Plan from the Jald row (or make it open the Plan screen like Settings does), and correct SCREEN_FLOW line 16. Regression risk is none.

### F04-5: English plural mistakes, including "1 people" on a paper that goes to the client company
- Severity: Low
- Status: CONFIRMED from the ARB text
- Where: apps/mobile/lib/l10n/app_en.arb keys `tsMonthlyLine` and `tsMonthlyLinePlain` ("{count} people"), printed by features/timesheets/timesheet_paper.dart:171-176; also `saveWithCount`, `nextWithCount`, `membersCount`, `payrollPosted`, `roomChargesApplied`, `importSave` ("Save 1 lines"), `importSummary`, `sheetCompanyHead` ("1 workers, 1 sites"), `missingWorkers`, `backupDueDays` ("1 days"), `slipDayCount` ("1 days" on a salary slip)
- Expected: `tsPeople` already uses a plural; the others should too. Actual: with the app in English, a monthly contract covering one worker prints "1 people" on the client's timesheet, and slips can print "1 days". Roman Urdu is unaffected ("log", "din" do not change).
- Reproduction: switch language to English, make a timesheet for a site with one worker on a monthly contract, and issue the paper. Regression test belongs in apps/mobile/test/timesheet_paper_test.dart.
- Proposed minimal fix: turn those placeholders into ICU plurals in app_en.arb only, then `gen-l10n`. Regression risk is none.

### F04-6: A register's busy flag calls setState without a mounted check, after the owner has left the screen
- Severity: Low
- Status: CONFIRMED by reading
- Where: apps/mobile/lib/features/registers/ledger_screen.dart:101 (`onBusy: (busy) => setState(...)`); called from export_flow.dart:93 in `finally`
- Expected: every other caller guards with `if (mounted)` (reports_screen.dart:47, documents_screen.dart:37, timesheet_screen.dart:42). Actual: a LedgerScreen pushed on top of another screen (a company's statement, or Reports > receipts or expenses) is disposed if the owner goes back while a file is being made, and `onBusy(false)` then calls `setState` on a disposed State, which throws.
- Reproduction: Reports > Raseedein (pushed cash register) > Export > Excel > Save, then press Back at once on a long register. Regression test belongs in apps/mobile/test/registers_test.dart.
- Proposed minimal fix: `onBusy: (busy) { if (mounted) setState(() => _busy = busy); }`. Regression risk is none.

### F04-7: The Excel writer does not remove characters XML forbids, so a pasted name or note can make the whole file unreadable
- Severity: Low
- Status: SUSPECTED
- Where: apps/mobile/lib/features/registers/register_xlsx.dart:26 `_escape`, used by `_textCell` and sheet names
- Expected: any text the owner typed or imported exports. Actual: `_escape` handles `& < > "` only. XML 1.0 forbids control characters below U+0020 other than tab, line feed and carriage return, and Excel refuses a sheet that contains one ("We found a problem with some content"). What I could not establish: whether the input fields or CSV import (`utf8.decode(..., allowMalformed: true)` in import_screen.dart:86 keeps control bytes) ever let such a character into a stored name or note.
- Reproduction: put "Ali\u0001" in a worker name via CSV, then export the worker register to Excel and open it. Regression test belongs in apps/mobile/test/registers_test.dart next to the formula-injection test.
- Proposed minimal fix: in `_escape`, drop `[\u0000-\u0008\u000B\u000C\u000E-\u001F]`. Regression risk is none.

### F04-8: Fixed-height bars may clip text at the largest text sizes
- Severity: Low
- Status: SUSPECTED
- Where: apps/mobile/lib/features/registers/ledger_screen.dart:247 `_Strip` (height 36, chip text 14), app/side_panel.dart:145 and 171 `SubTabs` (height 46, text 14.5)
- Expected: layouts survive large text (UX-04). Actual: the app's own large-text setting multiplies the phone's scale by 1.3 (app.dart:125), and these rows have fixed heights. At a phone scale of 1.5 or more, the chip text height approaches or exceeds 36 points. What I could not establish: how much Android's non-linear font scaling caps this; I did not run the app.
- Reproduction: phone font size at maximum, Settings > large text on, open any register: check whether the quick-date and filter chips are cut off. Regression test belongs in apps/mobile/test/app_shell_test.dart (pump with `TextScaler.linear(2.6)` and expect no overflow).
- Proposed minimal fix: size these rows from `MediaQuery.textScalerOf(context)` as `BandFigure` already does. Regression risk is low.

### F04-9: Text controllers that are never disposed
- Severity: Low
- Status: CONFIRMED
- Where: apps/mobile/lib/features/more/profile_form_screen.dart:29-40 (12 controllers, no `dispose`); app/form_bits.dart:192 `askReason` and 519 `askDailyWage`; features/documents/letterhead_screen.dart:157-158 `_BlankSpaceState`
- Expected: controllers are disposed with their State, as the timesheet and invoice sheets do. Actual: each opening of Apni company leaks twelve controllers; each reason or wage dialog leaks one. The leak is small; it is listed because the task asks for it.
- Reproduction: open and close Apni company repeatedly with the Flutter memory view open. Regression test: none needed.
- Proposed minimal fix: add `dispose` overrides in the two States; for the dialogs, dispose after the dialog future completes plus a frame, as `askDeleteNote` explains. Regression risk is none.

## Missing versus spec
- DOC-03's "Page X of Y" and document number are on every paper; DOC-04's "separate header and footer position adjustable" exists only as scale, alignment and crop, with no vertical offset. Not a defect; noted for the owner.
- REP-01 lists "site-wise deployment" and "deductions" as reports. Site-wise figures exist inside the attendance and company registers and deductions inside the worker and payroll registers, but there is no report of either by itself on the Reports screen.
- SCREEN_FLOW line 15 still lists "Paisay mile (P3)" as Jald; receipts are built through the cash form and the invoice screen (D-052). This is the same doc drift as F04-4.

## Known-deferred noticed
- PROGRESS "Open": a register's date line can sit alone at the foot of a page (line 81); invoice and receipt papers are English while the timesheet sent with them follows the app language (line 82); "Send with timesheet" only compiled (line 93); a timesheet has no Excel (line 98); PDF memory at 26,000 rows (line 105); Roboto has no Urdu or Arabic script (line 111, also in the task's known list).
- Rows written within one second sort in read order (task's known list; PROGRESS line 92).
- Worker lists sort by plain text (task's known list).
- The worker register and the owner's sheet count allowances and deductions before their month is posted, the same as data/statement.dart does, so this is a consistent choice and not reported.
- A cash line in a closed month is reversed today, so a closed month's cash register still shows the original line (REP-04 by design, data/cash.dart:90-92).
