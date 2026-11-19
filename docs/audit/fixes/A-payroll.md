# Fixes A: payroll and money

Branch `audit/t01-t21`, nothing committed. Each item: failing test first, then the fix, then the test files around it.

## BUG-003 (F02-1): posting a later month first dropped an earlier month's salary

- Outcome: REPRODUCED, fixed.
- Tests, `apps/mobile/test/payroll_test.dart`, group `payroll month order`:
  - `BUG-003 a monthly worker never posted: a later month waits while an earlier month the account counts is not posted (D-033, D-042)`
  - `BUG-003 a contract dated years before any activity does not hold the first posting (D-042)`
- Setup: monthly AED 1,000 from 2020-01-01, one attendance row on 2020-09-15, nothing posted. The statement for October reads 2,000 (September and October). Post October.
- Failing output before the fix:

  ```
  BUG-003 a monthly worker never posted: ... [E]
    Expected: <200000>
      Actual: <100000>
    posting October first must not drop September's salary
    test\payroll_test.dart 484:9
  ```

- What changed:
  - `packages/domain/lib/payroll.dart` 148-149 (doc), 161 (new `String? firstMonth` parameter of `workerPayroll`), 185 (`checkFrom` = month after the last posted one, or `firstMonth` when nothing is posted), 205-206 (the `earlierMonthMissing` loop runs from `checkFrom`). With a posted line nothing changes.
  - `apps/mobile/lib/data/payroll.dart` 137-154: in `payrollFor`, cash entries undone in their own month are set aside (as `statementsFor` does), and one grouped query reads each worker's first item month (advance recoveries left out, as the statement does not count them as activity). 214-224: for a worker with no posted line, the account's first activity is the earliest of: unpaid attendance rows (all rows, since nothing is posted), first item, old balance, salary payment or advance given or returned. 239: passed as `firstMonth`. (Line numbers here and below are those of the final working tree.)
  - The check also keeps `_monthlyCovers`, so a contract dated from a hiring date years earlier blocks nothing before the first activity (second test).
- One choice to review: an old balance (`opening_balances`) counts as activity from the day after its as-of date, not from its own month. `statementsFor` (statement.dart:295) uses the as-of month. Reason: TC-032 (PRD deductions example, D-031) has a salary owed balance dated 2020-09-30 and posts October directly; using the as-of month would hold October for a September the old balance already holds, and TC-032 would fail. Side note for the orchestrator, not changed: before October is posted in TC-032's setup, the statement still counts September's salary on top of the end-of-September balance, because of that same line 295. That looks like a separate small finding (a balance dated the month's last day should probably start the account the next month).
- After the fix: `payroll_test.dart` 20 of 20 passed (`00:10 +20: All tests passed!`). Failing test now posts 0 for October with `earlierMonthMissing`, the balance stays 2,000, and posting September then October gives 2,000.
- Other test files run: `packages/domain` `dart test` 151 passed. `auto_cuts_test, changes_test, closing_test, registers_test, salary_payment_test, statement_test, timesheets_test, visa_test, audit_journey_test` together 156 passed.
- Callers of `workerPayroll`: only `payrollFor` in the app, and the domain tests (`payroll_test.dart`, `visa_test.dart`), which do not pass the new optional parameter.
- Regression risk as the review said: a first posting for a month after earlier activity is now held until the earlier month is posted or closed. No existing test needed changing.
- Existing expectations changed: none.

## BUG-004 (F02-3): an item behind a later posted month was never linked to a line

- Outcome: REPRODUCED, fixed.
- Tests, `apps/mobile/test/payroll_test.dart`, group `payroll month order`:
  - `BUG-004 an item left in an earlier month holds the later month, so it is never stranded behind it (PAY-02)`: daily worker AED 70, rows on 2020-09-15 and 2020-10-01, a September allowance of AED 100, October posted first, then September and October tried again; the statement must equal Tankhwah's closing.
  - `BUG-004 a month behind a later posted one offers no item to add (PAY-02)`: October posted, a September item written directly (as old data can hold); September has `laterMonthPosted`, `canAddItems` and `canAddRoomCharge` are false and `applyRoomCharges` adds nothing.
- Failing output before the fix:

  ```
  BUG-004 an item left in an earlier month holds the later month ... [E]
    Expected: <14000>
      Actual: <24000>
    the account and Tankhwah agree
  ```

  (the account counts the stranded AED 100 allowance, Tankhwah never will).
- What changed:
  - `packages/domain/lib/payroll.dart` 150 (doc), 162 (new `Set<String> itemMonths` parameter), 209-210: any earlier, not closed month in `itemMonths` raises `earlierMonthMissing`, for every pay basis.
  - `apps/mobile/lib/data/payroll.dart` 155-164: one distinct query of (worker, month) for items with no line dated before this month; 240: passed to `workerPayroll`. 67-70: new `WorkerPayroll.canAddItems` (not posted and no `laterMonthPosted`); `canAddRoomCharge` and `needsVisaInstalment` now build on it, so `applyRoomCharges`, `applyVisaInstalments`, the room charge screen and the visa count on the payroll screen all skip such a month.
  - `apps/mobile/lib/features/payroll/payroll_worker_screen.dart` 138: the add buttons show on `p.canAddItems` instead of `!p.posted`. Existing items stay tappable, so an old stranded item can still be opened and removed.
- After the fix: `payroll_test.dart` 22 of 22 passed.
- Existing expectation changed: `apps/mobile/test/closing_test.dart` `a deduction waiting on an earlier open month stops it too` expected one `payrollNotPosted` finding (2020-09-30). That test is F02-3's own scenario (September deduction, October posted). October is now held behind the deduction, so October is not posted either and there are two findings: `['2020-09-30', '2020-10-31']`. The test's point, that the September deduction stops October's closing, still holds.
- Other test files run: `packages/domain` `dart test` 151 passed; `closing_test.dart` 30 passed after the change; the nine neighbouring files of BUG-003 155 passed and 1 failed before the closing_test change (the one above).
- Not done, and why:
  - `savePayItem` does not refuse an item on a `laterMonthPosted` month at the data layer; the review asked for the buttons only. The form is reached only from those buttons and from an existing item.
  - The `recoveryNotAnswered` issue and the automatic instalment row on the worker screen still open the recovery form. On a `laterMonthPosted` month the salary is 0, so they show only if a daily worker's own rows give that month a net above 0. Left as is; a stranded recovery would now hold the next month and show there.
  - Data saved before this fix with an item already behind a posted month: the worker's next month is now held with `earlierMonthMissing` until that item is removed or the later posting undone. That is the intended visible state (the review's "held while such an item exists"), but the message names an earlier month that cannot post, so the owner has to open that month to remove the item.

## BUG-005 (F02-2), first part: a fully absent monthly worker dropped off the month's payroll

- Outcome: REPRODUCED, fixed (payroll side only; closing's `_findGaps` not touched).
- Test: `apps/mobile/test/auto_cuts_test.dart`, `a monthly salary cut for days with no attendance (D-057) BUG-005 a whole month with no attendance still shows, cut day by day, and posts, so the next month is not held`. Monthly AED 3,100, calendar days, cut on, no weekly off days; one row on 2020-09-10, September posted; no rows in October.
- Failing output before the fix:

  ```
  BUG-005 a whole month with no attendance still shows ... [E]
    Expected: not null
      Actual: <null>
    the cut shows on the payroll line day by day (D-057)
  ```

- What changed: `packages/domain/lib/payroll.dart` 85-86: `PayrollFigures.isEmpty` also needs `absenceFils == 0`. Callers of `isEmpty`: `WorkerPayroll.canPost` and the skip in `payrollFor` (apps/mobile/lib/data/payroll.dart 65 and 273), and the `payrollNotPosted` finding in `apps/mobile/lib/data/closing.dart:109`.
- After the fix: the worker is in October's list with salary 0, cut AED 3,100 over 31 days, `canPost` true; posting stores a line with `absenceFils` 310,000, and November has no `earlierMonthMissing`. `auto_cuts_test.dart` 6 of 6 passed.
- Other test files run: `packages/domain` `dart test` 151 passed; `payroll_test, closing_test, statement_test, salary_payment_test, visa_test, registers_test, audit_journey_test` all passed in the same run (130 passed, the only failure was this new test's own matcher typo, fixed and rerun).
- What the owner now sees in the "forgot to end the contract" case (worker gone, monthly contract left open, cut on, no off days, no rows): each later month lists the worker on Tankhwah with salary AED 0, "31 din chhutti kaat kar (1, 2, ... 31)" and net 0, counted in "Tankhwah post karein (n)". Posting writes a zero line with the days cut. Before, the worker was hidden, and the month after their last posted month was held with `earlierMonthMissing` for a month with nothing to post. Because of `closing.dart:109`, an unposted fully absent month now also shows "pay not posted" in that month's closing, which is cleared by posting the zero line. The closing's missing-attendance check (`_findGaps`, D-045 (2)) still does not ask about monthly workers: that is the owner's decision and was left alone. In the current month, only days up to yesterday are cut, as before. A contract with the cut off still pays the whole salary, as before.
- Existing expectations changed: none.

## BUG-006 (F02-10): the row editor crashed on Apply with Absent and a cleared break field

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/changes_test.dart`, `BUG-006 the row editor applies Absent after the break field was cleared (F02-10)` (widget test, same flow as the D-056 screen test beside it: open today's saved row, clear the break, choose Absent, Apply).
- Failing output before the fix:

  ```
  The following FormatException was thrown while handling a gesture:
  Invalid number (at character 1)
  #1      int.parse (dart:core-patch/integers_patch.dart:71:14)
  Expected: (String, int):<(absent, 0)>
    Actual: (String, int):<(present, 60)>
  ```

- What changed: `apps/mobile/lib/features/today/row_editor_screen.dart` 100-101: `int.tryParse(_break.text.trim()) ?? 0` with a one-line comment. When the row is not absent, the field's validator still refuses a blank or bad value before this line runs, so only the absent case reaches the fallback. An absent row whose break field was left alone keeps its number, as before.
- Callers: `RowEditorScreen` is opened from `openAttendanceRow` in the same file and from `apps/mobile/lib/features/today/attendance_review_screen.dart`; both go through the same `_apply`.
- After the fix: `changes_test.dart` and `attendance_test.dart` together 27 passed.
- Existing expectations changed: none.

## BUG-008 (F03-7): a correction from a stale row object forked the correction chain

- Outcome: REPRODUCED (at the data layer), fixed.
- Test: `apps/mobile/test/changes_test.dart`, `attendance (D-056) BUG-008 a row already corrected cannot be corrected again from a stale copy, so one piece of work keeps one row (ATT-08)`. An approved row is read once; `correctEntry` is called with that copy (left at 15:00), then again with the same copy as a delete.
- First try: the second correction as another timed edit (left at 13:00) was already refused, by `AttendanceInvalid`: `previewRow` sees the first correction as an overlap with no reason. So a timed edit does not fork; a delete (absent, no times) or an edit that carries an overlap reason does. The test uses the delete.
- Failing output before the fix:

  ```
  BUG-008 a row already corrected cannot be corrected again from a stale copy ... [E]
    Actual: [
      AttendanceEntry(... endUtc: 2020-10-05 15:00 ... revisesEntryId: 38514f5a-..., superseded: false, deleted: false ...),
      AttendanceEntry(... attendanceStatus: absent ... revisesEntryId: 38514f5a-..., superseded: false, deleted: true ...)
    ]
    Which: has length of <2>
  ```

- What changed: `apps/mobile/lib/data/attendance.dart` 45-48: new `EntryChanged` exception. 330-331: first thing in `correctEntry`'s `change`, the row is read again by id and `EntryChanged` is thrown if it is already superseded. The whole operation rolls back, as any failed `applyOperation` does. A retry with the same operation id never reaches `change` (`_applyOnce` returns on a seen operation id), so the check does not break idempotent retries.
- Callers checked: `correctEntry` is called only by `editAttendance` and `deleteAttendance` (`apps/mobile/lib/data/changes.dart` 366, 391) and directly by tests. Those are called from `openAttendanceRow` (`row_editor_screen.dart` 32-33, which ends in `catch (e) => showSaveError`) and `carryAgreedToAttendance` (`timesheets.dart` 351, reached through `saveOrExplain` on the timesheet screen). Both show the general "save failed" message (`saveErrorText` falls to `l10n.saveFailed`), with nothing written. No new string was added; a specific "this row changed, open it again" message would need ARB strings in every language and was left out as not asked.
- After the fix: `changes_test, attendance_test, timesheets_test, auto_cuts_test, payroll_test` together 94 passed.
- Existing expectations changed: none.

## BUG-007 (F02-8): a salary payment saved before its months loaded went whole on the advance

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/salary_payment_test.dart`, `BUG-007 a salary payment cannot be saved before its months have loaded, so none of it goes on the advance by mistake (D-043)`. Worker owed AED 270 (90 in September, 180 in October). The form is opened as Pay now does (salary, the worker, AED 270) while a test transaction keeps the database busy, Save is tapped, then the database is let go and Save is tapped again.
- What I tried first: tapping Save one or two frames after the form opens, with no busy database. The in-memory test database answers within the same pump, so the months were always loaded and nothing went wrong. Holding a transaction open (`app.transaction(() => busy.future)`) makes the form's `statementsFor` wait, as a slow phone would.
- Failing output before the fix:

  ```
  Expected: no matching candidates
    Actual: _TextWidgetFinder:<Found 1 widget with text "AED 270.00 baqi se zyada hai": [...]>
  the whole payment would go on the advance
  ```

  (the extra dialog offered the whole AED 270 as extra; a yes would write it all as an advance).
- What changed: `apps/mobile/lib/features/cash/cash_entry_form_screen.dart` 79-80: new `_loadingUnpaid` flag. 100-101: set when a salary payment's months start loading (set without `setState`, since `_loadUnpaid` also runs from `initState`; the kind, worker and date changes call `setState` just before it). 115: cleared in the `setState` that applies the loaded months; a stale load that is thrown away leaves it to the newer one. 381: Save's `onPressed` is null for a salary payment while it loads, so the button shows disabled.
- After the fix: `salary_payment_test.dart` and `cash_test.dart` together 35 passed. The existing reminder-to-payment widget test in the same file still passes.
- Not done: if `statementsFor` ever throws, Save stays disabled for a salary payment on that form (closing and reopening the form loads again). Before, it saved the whole amount as extra after a yes. Left as is.
- Existing expectations changed: none.

## Final checks

- `cd apps/mobile && flutter analyze`: `No issues found! (ran in 31.0s)`.
- `cd packages/domain && dart analyze --fatal-infos`: `No issues found!`. `dart test`: `+151: All tests passed!`.
- Whole app suite once, `flutter test` (about 11 minutes): 496 passed, 1 skipped, 13 failed. All 13 failures are in `zz_*` files (`zz_t20b`, `zz_t20c`, `zz_t20d`, `zz_t20dc`, `zz_t21b`, `zz_t21c`: restore, phones, backup, plan and trial screens). The ones read are golden image mismatches (for example `zz/t20c_2_phones.png` 14.62% diff, `zz/t20b_4_wrong_password.png` 0.02%) and finders failing after them. None of those files touch payroll, statement, cash form, row editor or attendance code (grep). I did not open or change them, as instructed. Every non-`zz` test file passed, including all files named above. Golden diff images went to `apps/mobile/test/failures/`, which `.gitignore` ignores.
- Not mine: `git status` also shows changes under `supabase/` (four test SQL files and an untracked migration `20261117120000_audit_fixes.sql`) that this work did not make or touch.
