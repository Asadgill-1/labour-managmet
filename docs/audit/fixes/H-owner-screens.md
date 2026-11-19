# Fixes H: the owner's screen answers (D-080 (9), (10), (12), and the salary sheet after D-080 (3))

Branch `audit/t01-t21`, nothing committed, git state untouched. Each answer: a test seen failing for the right reason first, then the fix, then the test files around it. The billing and payroll fixers' changes (F, G) were left as they are; no record file was touched here except this report.

## D-080 (9), F02-9: a shift whose end equals its start is refused at the field

- Outcome: REPRODUCED (08:00 to 08:00 went through every screen with no word, to be paid as 24 hours), fixed.
- Tests: `apps/mobile/test/attendance_test.dart`, group `F02-9 a shift whose end equals its start is refused at the field, so a typo is not paid as 24 hours (D-080 (9))`:
  - `the day's attendance says so at the end field and does not go on`: a site whose usual times are 08:00 to 08:00 (as a site file can bring in); on Hazri lagayein, picking its company and site shows the message under the end field, and "Aage (1 mazdoor)" does not open the review.
  - `a row, a site and a group say so too and keep the screen open; an end before the start is still next day (ATT-06)`: the row editor with 08:00 to 08:00 shows the message and "Theek hai" hands nothing back; with 08:00 to 07:00 it hands the row back (23 hours, next day, unchanged). The site form and the group form opened on 08:00 to 08:00 show the message, and Save keeps the screen open with the row's version unchanged (nothing written).
- Failing output before the fix (both tests):

  ```
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "Shuru aur khatam ka waqt ek hi hai. Khatam
  ka waqt theek karein.": []>
     Which: means none were found but one was expected
  ```

- What changed:
  - `apps/mobile/lib/app/form_bits.dart`: `checkShiftEnd(start, end, {required error})`, next to `checkDays` and in its pattern: the error when both times are set and equal, else null. `TimeField` takes an optional `errorText`, shown under the field with `errorMaxLines: 4` so large text never cuts the message.
  - The four screens where start and end are typed, each the same three lines: the end `TimeField` gets `errorText: checkShiftEnd(...)` (said the moment the times match), the two-field `Row` aligns to the top so the start field does not drop when the message shows, and the save step refuses with the same words in the red message bar (`showFormError`), as `timesRequired` already does:
    - `features/today/attendance_entry_screen.dart` (`_next`), the day's attendance for a group or single workers. The times a site or group fills in land here, so a site or group holding equal times is stopped here too.
    - `features/today/row_editor_screen.dart` (`_apply`), one row, both before saving (from the review) and a saved row (`openAttendanceRow`). Only for a worked row; an absent row hides its times.
    - `features/companies/site_form_screen.dart` (`_save`), a site's usual times.
    - `features/groups/group_form_screen.dart` (`_save`), a group's usual times.
  - Strings: `timesSame`, "Start and end are the same. Fix the end time." / "Shuru aur khatam ka waqt ek hi hai. Khatam ka waqt theek karein."
  - `packages/domain/lib/calc.dart` `shiftTimes` is unchanged: an end at or before the start is still next day (ATT-06).
- Screens checked: every `TimeField` in `lib/` (`grep -rn "TimeField("`): the four above, nothing else. The timesheet's agreed-hours dialog takes hours and minutes, not times.
- Paths that are not screens and could still store equal times, as first reported (all three are closed in the follow-up section below):
  - Site import (`lib/data/import.dart`, `_siteLines`): a CSV's Start and End are read with no check, so a site can be saved 08:00 to 08:00. The site form then shows the message when opened, and attendance on that site is stopped at "Aage", so nothing is paid from it; the import itself still takes it.
  - The write path (`saveAttendanceBatch`, `editAttendance`, `previewRow`, `RowPreview.blocksSave`) has no check: anything handing it equal times stores 1,440 minutes. Only the screens above hand it times typed by a person.
  - `carryAgreedToAttendance` (`lib/data/timesheets.dart` ~349) works the end out as `(start + agreed minutes + unpaid break) % 1440`. When a company's agreed hours plus the unpaid break come to 0 (or 24 hours), the end equals the start. A throwaway probe (run, then deleted) confirmed it: an hourly row 08:00 to 18:00 with no break, agreed as present for 0 hours and carried to the attendance, is stored with `clockMinutes`, `clientBillableMinutes` and `workerPayableMinutes` all 1,440, and the worker is paid AED 240.00 (`workerAmountFils` 24000) where 0 was agreed. The timesheet's own row keeps the agreed 0. Not changed here (outside the four screens, and the brief said not to touch the arithmetic). The screen itself never offered that carry (see the correction under open points); the probe called the function directly.
  - `saveWorkerGroup` and `saveRow(sites)` take any times; only their screens check.

## D-080 (10), F04-8: large text is never cut off

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/registers_test.dart`, `F04-8 large text never cuts off a register's date chips or a sub-tab's name (D-080 (10))`. It loads the app's own Roboto (the test font's lines are shorter than a phone's, so it would hide the fault), pumps the attendance register (the `LedgerScreen` harness of the BUG-014 test) on a 360-wide phone at `TextScaler.linear(2.6)` (a phone's 2.0 under the app's 1.3), and checks that no exception is thrown, and that the "Is mahine" chip and the "Hazri register" sub-tab each have a text box no shorter than their text and lie inside their row or bar (`tester.getRect`, which includes the sub-tab's shrink). Then at scale 1 it checks the sub-tab name keeps its own size.
- Failing output before the fix, first the chip, then (with only the chip fixed) the sub-tab:

  ```
  Expected: a value greater than or equal to <51.99>
    Actual: <36.0>
  the text is clipped to a shorter box
  ...
  Expected: a value greater than or equal to <53.99>
    Actual: <43.0>
  the text is clipped to a shorter box
  ```

- What changed:
  - `apps/mobile/lib/features/registers/ledger_screen.dart` `_Strip` (the date chips and the filter chips): a horizontal `SingleChildScrollView` with a `Row` in place of a `SizedBox(height: 36)` around a horizontal `ListView`, so the row is as tall as its chips. Each chip keeps at least the old 36 high, so normal text looks as before.
  - `apps/mobile/lib/app/side_panel.dart` `_SubTab`: the label sits in `FittedBox(fit: BoxFit.scaleDown)`. The bar keeps its 46 (`SubTabs.preferredSize`, an AppBar `bottom`), and the name shrinks only when it would not fit.
- Callers checked: `_Strip` is used only by the register header (dates and filters); `SubTabs` by every screen with sub-tabs (registers, cash, closing, documents, letterhead, invoices, payroll, balances, rates, `RegisterScreen`), all through `_SubTab`.
- Not checked: other parts of the register header at 2.6 (the two date buttons, the figures) were not asked about; the test only shows they throw no overflow there.

## D-080 (12): the Backup page's question no longer says the copy is from another phone

- Outcome: changed as asked.
- Test: `apps/mobile/test/cloud_screens_test.dart`, `a new company keeps its backup password and sends its first cloud copy with nothing pressed; the Backup page asks before replacing another phone's copy (D-072, D-076)`. Its two old-text expectations now name the new words, and it also checks that "kisi aur phone" no longer shows.
- Failing output before the words changed:

  ```
  Expected: exactly one matching candidate
    Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing Cloud mein is company ke
  data ki copy pehle se rakhi hai. Pehle wo data yahan wapas laana hai: []>
  ```

- What changed (keys kept, words only, `app_en.arb` and `app_en_PK.arb`, then `flutter gen-l10n`):
  - `cloudOtherPhoneAsk`: "The cloud already has a copy of this company's data. Bring that data back here first, or send this phone's data in its place?" / "Cloud mein is company ke data ki copy pehle se rakhi hai. Pehle wo data yahan wapas laana hai, ya is phone ka data us ki jagah bhejna hai?"
  - `accountOtherPhoneCopy`: "The cloud already has a copy of this company's data. Choose on the Backup page." / "Cloud mein is company ke data ki copy pehle se rakhi hai. Backup ke page par chunein."
  - `cloudReplaceConfirm`: "This phone's data replaces the copy in the cloud. This can't be undone." / "Cloud mein rakhi copy ki jagah is phone ka data jayega. Ye wapas nahin hota."
- Checked: the three keys are used in `backup_screen.dart` (question, confirm) and `account_screens.dart` (`cloudProblemText`). No other test matched the old words (`grep` for "kisi aur phone", "another phone", "doosre phone"); `cloud_restore_test` and the uncommitted `zz_t20dc_test` match only "Pehle wo data wapas laayein", unchanged. The buttons `cloudBringBack` / `cloudKeepThis` still read right after the new question. Code comments in `backup_screen.dart` still say "the other phone's copy"; left as they are.

## The salary sheet shows the month's contract amount the invoice charges (after D-080 (3))

- Outcome: REPRODUCED (AED 11,000 where the invoice charges 6,000), fixed.
- Test: `apps/mobile/test/reports_test.dart`, `the owner's sheet counts a monthly contract whose rate changes inside the month once, at the newest rate, as the invoice charges it (D-080 (3))`. Two companies, each with a rate from 2020-01-01 and a new one from 2020-10-16, work by Asif and Bilal before and by Asif after: "Fixed", 5,000 then 6,000, must show 6,000 once; "Crew", 2,000 then 2,500 a worker, must show Bilal at 2,000 and Asif once at 2,500, 4,500. It checks the by-company rollup, the contract lines in the detail, the bill, and then makes each company's invoice and checks it charges the same 6,000 and 4,500.
- Failing output before the fix:

  ```
  Expected: {'Crew': 450000, 'Fixed': 600000}
    Actual: {'Crew': 650000, 'Fixed': 1100000}
     Which: at location ['Crew'] is <650000> instead of <450000>
  ```

- What changed: `apps/mobile/lib/features/registers/salary_sheet.dart` `buildSalarySheet`. It first keeps the newest monthly row of each fee's cover, using the invoice's own key, `feeCover` (`lib/data/timesheets.dart`: company and month for a fixed amount, plus the worker for a fee per worker), and the invoice's rule (the latest work date wins). Only then does it group by company, basis and rate. A fixed amount is one line at the newest rate; a fee per worker counts each worker once at their newest rate, one line per rate, as the invoice's lines are.
- Reuse: the cover key is shared. The two lines that keep the newest row are written again rather than moved into a shared helper, because the invoice's copy (`_draftLines` in `lib/data/invoices.dart`) is the billing fixer's uncommitted work, which I was told to leave alone. The two can be joined into one helper next to `feeCover` when that work is committed.
- Callers checked: `buildSalarySheet` is called by the salary sheet register (`register_defs.dart`) and by tests (`reports_test`, `registers_test`, `statement_test`, `scale_test`).

## Runs

Each file run alone with `flutter test test/<file>.dart`, after all four fixes, on 2026-11-19/20 (Windows, `source /c/dev/env.sh`):

| File | Result |
| --- | --- |
| `attendance_test.dart` | +18, all passed (2 new) |
| `registers_test.dart` | +25, all passed (1 new) |
| `reports_test.dart` | +13, all passed (1 new) |
| `cloud_screens_test.dart` | +4, all passed (1 changed) |
| `app_shell_test.dart` | +6, all passed |
| `groups_test.dart` | +9, all passed |
| `cloud_copy_test.dart` | +9, all passed |
| `cloud_restore_test.dart` | +3, 1 skipped (its own `skip: !playStoreBuild`), all passed |
| `account_flow_test.dart` | +27, all passed |
| `documents_test.dart` | +25, all passed |
| `masters_test.dart` | +7, all passed (site form) |
| `statement_test.dart` | +18, all passed (salary sheet) |

`flutter analyze` (in `apps/mobile`, after all changes, with the F and G work in the tree): "No issues found! (ran in 269.9s)".

`flutter gen-l10n` was run after each string change. Line endings are as before in every file touched (CRLF: the four screens, `ledger_screen.dart`, `side_panel.dart`, `reports_test.dart`, `cloud_screens_test.dart`; LF: `form_bits.dart`, `salary_sheet.dart`, both ARB files, `attendance_test.dart`, `registers_test.dart`). No `dart format`. No existing assertion was weakened or removed: the two in `cloud_screens_test` now name the new words, and a third checks that the old words are gone.

## Follow-up: equal times closed behind the screens too (asked by the coordinator after the first report)

Same rules: each test seen failing first, no `dart format`, line endings kept, no record file touched.

### 1. The agreement dialog refuses 0 hours on a worked row

- Test: `apps/mobile/test/timesheet_paper_test.dart`, `from a company and dates to an accepted timesheet and a new revision, through the screens`. Before the agreed 8 hours, new steps type 0 hours and save. The test expects the message at the hours field, no "cut the worker's hours too?" question, the sheet still open, and no agreement stored on the revision. The flow then goes on as before.
- Failing output before the fix: `Found 0 widgets with text "0 ghante ka matlab hai koi kaam nahin. Kuch charge na karna ho to "Bill nahin" chunein."`
- What changed:
  - In `features/timesheets/timesheet_screen.dart`, `_AdjustSheet`, the "Billable hours" field's validator is now `whole(v) ?? (_typedMinutes == 0 ? l10n.tsZeroHours : null)`. It runs whenever the hours fields show, so for a present row and for a half day. An absent ("Not charged") row hides them.
  - New string `tsZeroHours`: "0 hours means no work. To charge nothing, choose "Not charged"." / "0 ghante ka matlab hai koi kaam nahin. Kuch charge na karna ho to "Bill nahin" chunein." The words name the dialog's own button. The dialog's absent option is labelled "Not charged" / "Bill nahin", not "absent".
  - In `app/form_bits.dart`, `Field` now has `errorMaxLines: 4`, as it already had for help text. A message under a half-width field wraps instead of being cut to one line. This affects every form's error text, which before showed one line with "...".

### 2. The attendance write path refuses a worked row whose end equals its start

- Tests:
  - `apps/mobile/test/attendance_test.dart`, group `saving a batch`, `D-080 (9) a worked row whose end equals its start is never written, new, edited or corrected; absent, or an end before the start, is`. A batch of 08:00 to 08:00 rows is refused and nothing is stored. An absent row with equal times, and 20:00 to 08:00 (12 hours, next day), save. Editing the 20:00 row to 08:00 to 08:00 is refused before approval (`updateUnapprovedEntry`) and after it (`correctEntry`), and nothing changes. `saveErrorText` gives `timesSame` in English and Roman Urdu.
  - `apps/mobile/test/auto_cuts_test.dart`, group `a company's fewer hours carried into the worker's attendance (D-057)`, `D-080 (9) 0 hours agreed on a worked row with no unpaid break is refused, never stored or paid as 24 hours`. This is the throwaway probe made real: an hourly row 08:00 to 18:00 with no break, and 0 hours agreed as present and carried. It throws `SameStartEnd`, and the only row is still 600 minutes, AED 100.00.
- Failing output before the fix:

  ```
  Expected: throws <Instance of 'SameStartEnd'>
    Actual: <Instance of 'Future<String>'>          (attendance_test, the batch)
    Actual: <Instance of 'Future<void>'>            (auto_cuts_test, the carry)
  ```

- What changed:
  - In `data/attendance.dart`: the exception `SameStartEnd`, and `_refuseSameTimes(ShiftInput)`, which throws it for a status other than absent with `startMinute != null && startMinute == endMinute`. It is called first inside the `change:` of the three functions that write typed times: `saveAttendanceBatch` (every input), `updateUnapprovedEntry` and `correctEntry`. A throw there rolls the whole operation back, with nothing written.
  - In `app/theme.dart`, `saveErrorText` maps `SameStartEnd()` to `timesSame`.
- Callers checked (grep):
  - `saveAttendanceBatch` is called by the review screen (`attendance_review_screen.dart` `_save`), which shows any error but `AttendanceInvalid` through `showSaveError`.
  - `editAttendance` and `deleteAttendance` (`data/changes.dart`) go through `updateUnapprovedEntry` or `correctEntry`. A delete writes an absent row, so the check passes it.
  - `openAttendanceRow` (row editor) shows other errors through `showSaveError`.
  - `carryAgreedToAttendance` writes only through `editAttendance`, so it is covered, and the timesheet screen shows the error through `saveOrExplain`.
  - `approveEntries` and `_repriced` re-price stored rows and are not checked, so an old stored row never blocks approval or posting.
- Tests and seeds: no test or seed writes a worked row with equal start and end. A scan of every `startMinute: X, endMinute: X` in `lib/`, `test/` and `packages/` found only the new tests. The full runs below pass with no assertion changed.

### 3. The site import refuses equal times

- Test: `apps/mobile/test/reports_test.dart`, group `CSV import (MASTER-08)`, `a site whose start and end are the same is a row problem, so it never comes in as a 24-hour day (D-080 (9))`. In the file, Gate 08:00 to 08:00 is row 2's problem `sameTimes`, at End, in the words of `timesSame`. Yard 20:00 to 08:00 is fine. The plan is not ready, saving throws, and no Gate site exists.
- Failing output before the fix: `Expected: ['2 sameTimes', '3']  Actual: ['2', '3']`.
- What changed:
  - In `data/import.dart`, `ImportProblem.sameTimes`, and in `_siteLines`, `if (start != null && start == end) cell.problem(ImportProblem.sameTimes, ImportField.end);`.
  - In `features/more/import_screen.dart`, `importProblemText` maps it to `timesSame` ("Start and end are the same. Fix the end time."), so no new string was needed.

### 4. Backup comments

- In `features/backup/backup_screen.dart`, two comments now say "the copy already in the cloud" in place of "the other phone's copy". This was comments only.

### Runs after the follow-up

Each file alone:

| File | Result |
| --- | --- |
| `attendance_test.dart` | +19, all passed |
| `timesheets_test.dart` | +39, all passed |
| `invoices_test.dart` | +50, all passed |
| `reports_test.dart` | +14, all passed |
| `registers_test.dart` | +25, all passed |
| `groups_test.dart` | +9, all passed |
| `changes_test.dart` | +12, all passed |
| `write_path_test.dart` | +9, all passed |
| `audit_journey_test.dart` | +1, all passed |
| `closing_test.dart` | +33, all passed |
| `payroll_test.dart` | +23, all passed |
| `auto_cuts_test.dart` | +9, all passed |
| `timesheet_paper_test.dart` | +20, all passed |
| `masters_test.dart` | +7, all passed |
| `cloud_screens_test.dart` | +4, all passed |

`flutter analyze` (in `apps/mobile`, after the follow-up): "No issues found! (ran in 42.2s)".

## Open points for the owner

- Done in the follow-up below: the site import now refuses equal times, the agreement dialog refuses 0 hours, and the attendance write path refuses a worked row whose end equals its start.
- Correction to the first report: the 0-hour carry was reached by calling `carryAgreedToAttendance` directly. The timesheet screen offers to carry only when the agreed minutes are above 0 and below the row's (`_adjust`, `fewer`), and then agreed minutes plus the unpaid break stay between 0 and 1,440, so through the screens the end never equalled the start. The guard now holds for any direct call too.
- The newest-row rule for a monthly fee is written twice: once in the invoice (`_draftLines`) and once in the salary sheet. Both use `feeCover`. Left as it is, as asked; it can become one helper once the billing fixer's work is committed.
- The register header's other parts (date buttons, figures) were not checked at large text beyond "no overflow".
