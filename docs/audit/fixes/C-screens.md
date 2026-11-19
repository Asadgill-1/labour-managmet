# Fixes C: screens and exports

Branch `audit/t01-t21`, nothing committed. Each item: failing test first, then the fix, then the test files around it. Line numbers are those of the working tree when written.

Progress: all eight bugs done, final checks passed (see the end).

## BUG-012 (F04-1): two companies with the same name shared one account

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/registers_test.dart`, `BUG-012 two companies with the same name keep their own accounts in every company register (F04-1, INV-07)`. Two more companies named "Emaar" (the seed has one): old balance AED 1,000.00 (with a TRN) and AED 500.00 (no TRN), each with one day of work in November. Checks the statement (band balance, one heading and own footer per company, rollup TRN, invoiced and balance on one row), aging (two groups, two rollup rows), work (two groups, no company split into two headings) and the owner's salary sheet for November (two groups, two heads, two by-company rows).
- Failing output before the fix:

  ```
  Expected: <150000>
    Actual: <50000>
  the band adds where each account ended
  test\registers_test.dart 250:5
  ```

- Root cause: every grouping, footer map and rollup map keyed by `c.name`, and `Clients.name` is not unique. `groupEntries` merged consecutive rows of same-named companies, `columnFigure` kept only the last balance per group, and `feet[c.name]` / `facts[c.name]` were overwritten by the last company.
- What changed:
  - `apps/mobile/lib/features/registers/register_defs.dart`: new public `companyLabels(Iterable<Client>)` (name alone when unique; repeated name plus its TRN, else plus a counter in the order the companies were added; a label already taken moves to the next counter, so labels never collide). `_Masters.clientLabels` holds it once per build. `_statement`, `_aging` and `_work` use the label for the group, the company cell, the footer key and the rollup key/name. `clientOptions` (the company filter on every register) shows the label too, so the two companies can be told apart in the filter.
  - `apps/mobile/lib/features/registers/salary_sheet.dart`: `clients` is now `companyLabels(...)` instead of `id -> name`; every key there (`byCompany`, `contractLines.company`, `contractBill`, `groupHeads`, group) already went through that map.
- Test file corrected while writing it (not an existing expectation): my first draft expected four statement groups; the seed's Meraas has no statement lines, so three is right.
- After the fix: `registers_test.dart` 21 of 21 passed.
- Sibling files run: `statement_test.dart` 18 passed, `reports_test.dart` 12 passed, `invoices_test.dart` 45 passed (all build statement, aging, work registers or the salary sheet with unique names, so labels equal names there).
- Sibling callers checked: `_companies` (date-grouped, keyed by site id) and the worker register (grouped by `name (code)`) are not affected. `siteOptions` still shows the bare company name next to a site; left alone (site names differ, and the filter value is the site id).
- Left: company names on invoices, the company list and elsewhere outside registers are unchanged; only register headings of repeated names change.

## BUG-013 (F04-2): payment terms and a company's due days took "-30" and words

- Outcome: REPRODUCED, fixed.
- Tests:
  - `apps/mobile/test/invoices_test.dart`, group `issuing`, `BUG-013 a stored negative due days never puts the due date before the issue date (F04-2)`: payment terms -30 stored on the profile, an invoice issued; then -30 stored on the company, another issued. Each must be due the day it issues.
  - `apps/mobile/test/masters_test.dart`, `BUG-013 payment terms and a company due days refuse a negative number or words at the field (F04-2, UX-04)`: Apni company, "Payment ke din" = "-30" then "30 days", Save; then Companies > add, "Kitne din baad payment" = "-30" then "30 days", Save. Each must show "0 se 90 tak poora number likhein." and save nothing; "30" and "45" then save.
- Failing output before the fix:

  ```
  invoices_test: Expected: '2026-11-17'  Actual: '2026-10-18'
    payment terms of -30 fall back to due the day it issues   (test\invoices_test.dart 217:7)
  masters_test:  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "0 se 90 tak poora number likhein.": []>
    -30   (test\masters_test.dart 168:7)
  ```

- Root cause: both fields had no validator and saved `int.tryParse(...)` (so "-30" stored -30 and "30 days" stored null), and `issueInvoice` added the days as stored.
- What changed:
  - `apps/mobile/lib/app/form_bits.dart`: new `checkDays(l10n, value)`, the wage-due-days validator moved out unchanged (empty, or a whole number 0 to 90; message `wageDueDaysError`, already "A whole number from 0 to 90." / "0 se 90 tak poora number likhein.", so no new strings).
  - `apps/mobile/lib/features/more/profile_form_screen.dart`: payment terms and wage due days both use `checkDays`.
  - `apps/mobile/lib/features/companies/client_form_screen.dart`: due days uses `checkDays`.
  - `apps/mobile/lib/data/invoices.dart` `issueInvoice`: the due days are clamped at 0 (the one data guard, which also covers CSV import's `dueDays` and old rows). Other fixers' changes in that file left as they were.
- After the fix: both new tests pass.
- Sibling files run: `invoices_test` 46, `masters_test` 7, `app_shell_test` 6, `account_flow_test` 27, `audit_journey_test` 1, `invoice_paper_test` 9, `reports_test` 12, `salary_payment_test` 27, all passed.
- Callers checked: the only reader of `paymentTermsDays` / `dueDays` for a date is `issueInvoice`. CSV import (`data/import.dart` 279) still stores a negative number as typed; the clamp makes it harmless, and the import screen was not in scope.
- For the auditor: payment terms are now capped at 90 days, the same maximum as the wage field (as asked). An owner with 120-day terms would be refused; widen `checkDays` if the owner wants more.

## BUG-014 (F04-3): a register showed, and could export, the last range's rows under new dates

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/registers_test.dart`, `BUG-014 a new date range never shows or exports the last range's rows while it loads, and an error shows as one (F04-3, REP-01)`. `LedgerScreen` pumped with `registerProvider` overridden: every date answers at once (4 rows), last month answers only when a `Completer` completes, and later the stream errors. Taps "Pichla mahina": the 4 rows must not show and Export must be disabled; complete: the rows and Export are back; then "Is mahine" with an error: the error text must show and the 4 rows must not.
- Failing output before the fix (late part):

  ```
  Expected: no matching candidates
    Actual: _TextWidgetFinder:<Found 1 widget with text "4 entries": [...]>
  every date's rows are not last month's   (test\registers_test.dart 660:5)
  ```

  With the late part removed for one run (then restored), the error part failed too: `Found 0 widgets with text "Aap ka data khul nahin saka. ..."` at line 672.
- Root cause: `data = asked.value ?? _last` used the previous family key's value for any new key, and the error state fell back to it too; Export was enabled whenever `data != null`.
- What changed: `apps/mobile/lib/features/registers/ledger_screen.dart` 48-50 and 109-113: `_last` stores the query with the data; the screen shows `_last` only when its query is the one asked and the state is not an error. Otherwise the body shows the spinner (loading) or the existing `databaseError` state, and Export is disabled because `data` is null. As the review said, the band and chips give way to the spinner while a new range loads.
- After the fix: `registers_test.dart` 22 of 22 passed.
- Sibling files run (all open a register): `reports_test` 12, `changes_test` 12, `payroll_test` 22, `app_shell_test` 6, all passed.

## BUG-017 (F04-6): onBusy called setState after the register was closed

- Outcome: fixed by reading, no test (the caller asked for the one-line fix; a test would need to dispose the screen in the middle of a file being made).
- What changed: `apps/mobile/lib/features/registers/ledger_screen.dart` 103-105: `onBusy: (busy) { if (mounted) setState(() => _busy = busy); }`.
- Sibling callers checked: every other `onBusy` that calls `setState` already guards with `mounted` (`payroll_screen.dart` 80, `payroll_worker_screen.dart` 211, `invoice_screen.dart` 46 `_setBusy`, `reports_screen.dart` 46, `documents_screen.dart` 36, `timesheet_screen.dart` `_setBusy`); `cash_row.dart` passes a no-op.
- Tests run: the same files as BUG-014, after this change.

## BUG-018 (F04-7): the Excel writer kept characters XML forbids

- Outcome: REPRODUCED (the path is real), fixed.
- Path check: a typed field keeps a pasted control character (Flutter's text field does not strip them, and `trim()` keeps U+0001). CSV import keeps one too: `import_screen.dart` decodes with `allowMalformed: true` (U+0001 is valid UTF-8 anyway), `parseCsv` writes every character other than the separator, quotes and line breaks into the cell, and `_Cell.raw` only trims. The test proves the import path end to end.
- Test: `apps/mobile/test/registers_test.dart`, group `Excel`, `BUG-018 a control character imported into a name never reaches the sheet, so Excel still opens it (F04-7)`. Imports `Code,Name,Trade` / `W9,Ali\u0001,Helper`, checks the stored name is `Ali\u0001`, gives W9 a day of attendance, exports the attendance register (with its rollups) through `registerXlsx`, and checks no part of the zip holds `[\x00-\x08\x0B\x0C\x0E-\x1F]` while `>Ali<` is still in sheet1.
- Failing output before the fix:

  ```
  Expected: false
    Actual: <true>
  xl/worksheets/sheet1.xml holds a character XML forbids   (test\registers_test.dart 506:9)
  ```

- Root cause: `_escape` in `register_xlsx.dart` replaced only `& < > "`.
- What changed: `apps/mobile/lib/features/registers/register_xlsx.dart` 26-30: `_escape` first drops `[\x00-\x08\x0B\x0C\x0E-\x1F]`. Every text cell (`_textCell`), sheet name and print-title name goes through `_escape` (checked by grep), so one change covers them.
- After the fix: `registers_test.dart` 23 of 23 passed. Sibling files that export Excel: `statement_test` 18, `plan_guard_test` 16, passed.
- Left: the stored name still holds the character (the PDF shows it as a box or nothing). Stripping on input or import was not asked.

## BUG-015 (F04-4): the side panel listed Plan under "Jald aa raha hai"

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/app_shell_test.dart`, existing test `the side panel stays hidden until asked for, lists every section and hides again`: new assertions after the soon row opens: "Team" and "Madad" are there once each, "Plan" is not. No existing assertion changed.
- Failing output before the fix:

  ```
  Expected: no matching candidates
    Actual: _TextWidgetFinder:<Found 1 widget with text "Plan": [Text("Plan", ...)]>
  ```

- What changed: `apps/mobile/lib/app/side_panel.dart` 296-299: `l10n.menuPlan` removed from the soon row (no new menu entry; Plan still opens from Settings). `menuPlan` had no other user, so the key was removed from `app_en.arb` and `app_en_PK.arb` (regenerated with BUG-016). `docs/SCREEN_FLOW.md` line 16 split into "Reports, Documents (P3), Plan (P4, opens from Settings) | Built" and "Help (P5), Team (P6) | Jald"; line 35 (the Jald sub-tab row) now "Team, Help".
- Left: SCREEN_FLOW line 15 still lists "Paisay mile (P3)" as Jald (the review's same drift; not asked).
- After the fix: `app_shell_test.dart` 6 of 6 passed.

## BUG-016 (F04-5): English plurals

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/timesheet_paper_test.dart`, group `a monthly contract on paper`, `BUG-016 in English one worker on the contract reads "1 person", and a slip "1 day" (F04-5)`: a fixed monthly contract with one worker, the paper made in English, priced and hours only; the slip's day count for 1 and 2; and the Roman Urdu paper still says "1 log".
- How it failed first: the fix had already been applied to `app_en.arb` before the test was written, so the old English text was put back for one run (a script reversing exactly these replacements, then `flutter gen-l10n`), the test run, and the fixed file restored and regenerated. Output with the old text:

  ```
  Expected: contains ', 1 person.'
    Actual: 'Per month, fixed contract, AED 3,000.00: 06-10-2020 to 06-10-2020, 1 people. The contract amount goes on the invoice by the month, not from these rows.'
  priced: true   (test\timesheet_paper_test.dart 237:9)
  ```

- What changed: `apps/mobile/lib/l10n/app_en.arb` only: `tsMonthlyLine`, `tsMonthlyLinePlain`, `saveWithCount`, `nextWithCount`, `membersCount`, `payrollPosted`, `roomChargesApplied`, `importSave`, `importSummary` (the `total`), `sheetCompanyHead` (workers and sites), `missingWorkers` ("1 worker has" / "n workers have"), `backupDueDays`, `slipDayCount` are ICU plurals in the `tsPeople` style (`=1{...} other{...}`). Every key already had int placeholders in its metadata, so `app_en_PK.arb` needed nothing; its wording is unchanged. `flutter gen-l10n` regenerated `app_localizations.dart` and `app_localizations_en.dart`; the Roman Urdu methods are unchanged.
- After the fix: `timesheet_paper_test.dart` 20 of 20 passed. No test asserted the old English text (grep).
- Left, not in the list: other English messages with the same "1 workers / 1 days" pattern, for example `countsLine`, `payrollPostBody`, `findingNoWorkerRate`, `findingNotPosted`, `findingNoHazri`, `findingOverlap`, `findingNoMonth`, `visaInstalmentsApplied`, `roomChargeSave`, `slipWorkBasis` (on a slip), `tsDaysValue` and `tsShiftsValue` (on a timesheet), `planWorkerLimit`, `planWorkersOver`, `planKeepClients`.

## BUG-019 (F04-9): text controllers never disposed

- Outcome: fixed by reading, no test (as asked).
- What changed:
  - `apps/mobile/lib/features/more/profile_form_screen.dart`: `dispose()` disposes the twelve controllers.
  - `apps/mobile/lib/features/documents/letterhead_screen.dart` `_BlankSpaceState`: `dispose()` disposes `_top` and `_bottom`.
  - `apps/mobile/lib/app/form_bits.dart` `askReason` and `askDailyWage` (now `async`, same return type): the text is read when the dialog's future completes, and the controller is disposed in a post-frame callback, so it outlives the frame the dialog's field may still draw in. Note for the auditor: `askDeleteNote` does not dispose at all (its comment says why); this follows the review's "after the future plus a frame". Checked against the SDK in use (Flutter 3.47.7): the pop schedules the focus change as a microtask, so the field's `clearComposing()` on losing focus runs before that frame, while the controller is alive; `EditableText.dispose` only calls `removeListener`, which `ChangeNotifier` allows after dispose.
- Left: `client_form_screen.dart` also never disposes its controllers (not in the list).
- Checks: `flutter analyze` clean; the test files that open these dialogs and screens are in the full run below.

## Final checks

- `cd apps/mobile && flutter analyze`: `No issues found! (ran in 91.2s)`, after the last code change.
- Every committed app test file (`git ls-files 'test/*_test.dart'`, `zz_*` left out), one `flutter test <file>` process at a time, after the last code change: 38 of 38 files passed, 513 tests passed, 1 skipped (`cloud_restore_test`, already skipped before). `scale_test` took 84 s, so it was not skipped. Per file: account_flow 27, account 21, app_lock 2, app_shell 6, attendance 16, auto_cuts 6, backup 5, cash 8, changes 12, closing 30, cloud_copy 9, cloud_restore 3 (+1 skipped), cloud_screens 4, documents 25, drift/tenant/migration 16, groups 9, invoice_edit 6, invoice_paper 9, invoices 46, licence 17, masters 7, payroll 22, plan_guard 16, plans 8, rates 5, records 8, recovery 6, registers 23, reports 12, restore 5, salary_payment 27, scale 1, spike_checks 1, statement 18, timesheet_paper 20, timesheets 39, visa 9, write_path 9.
- The untracked `audit_journey_test.dart` (another fixer's) also passed during the BUG-013 sibling run.
- Existing expectations changed: none. Assertions were only added (the app_shell soon row).
- Files changed by this work: `apps/mobile/lib/features/registers/register_defs.dart`, `salary_sheet.dart`, `ledger_screen.dart`, `register_xlsx.dart`; `apps/mobile/lib/app/side_panel.dart`, `form_bits.dart`; `apps/mobile/lib/features/more/profile_form_screen.dart`; `apps/mobile/lib/features/companies/client_form_screen.dart`; `apps/mobile/lib/features/documents/letterhead_screen.dart`; `apps/mobile/lib/data/invoices.dart` (one hunk in `issueInvoice`); `apps/mobile/lib/l10n/app_en.arb`, `app_en_PK.arb` (only `menuPlan` removed), and the generated `app_localizations.dart` / `app_localizations_en.dart`; `docs/SCREEN_FLOW.md`; tests `registers_test`, `invoices_test`, `masters_test`, `app_shell_test`, `timesheet_paper_test`. Other fixers' changes in shared files (invoices.dart, the ARB files, invoices_test) were left as they were.
- Not done here (for the orchestrator): PROGRESS.md, TASKS.md, REQUIREMENTS_TRACEABILITY.md and the graph were not updated; nothing committed.
