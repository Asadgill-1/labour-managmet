# Fixes G: the owner's payroll answers (D-080 (4) to (8))

Branch `audit/t01-t21`, nothing committed. Each answer: a test seen failing for the right reason first, then the fix, then the test files around it. No record file was touched (`DECISIONS.md` shows as changed in the working tree, but not by this work). The billing fixer's uncommitted files were left alone; the two ARB files are shared, and only new keys were added to them, next to `issueRecoveryAsk`.

## D-080 (7), F02-6: monthly contracts that cover a month between them share it by days

- Tests, `packages/domain/test/payroll_test.dart`, group `TC-019 monthly pay once per period (CALC-04)` > `D-080 (7) when monthly contracts cover the whole month between them, each part is its share of the month by its days`:
  - `the same salary either side of a change pays exactly one month, by a fixed divisor too`: divisor 30, October, AED 3,000 to the 15th and AED 3,000 from the 16th pays 300,000 fils; one contract for the whole month still pays 300,000.
  - `a raise in February pays between the two salaries`: divisor 30, 3,000 to 14 Feb, 3,300 from 15 Feb: 315,000.
  - `a month joined or left part way is still the contract's own rule, and calendar days pay as before`: divisor 30 from 22 Oct = 100,000; to 10 Oct = 100,000; 12 to 21 Oct at 3,000 then 6,000 from the 22nd (not whole) = 100,000 + 200,000; calendar days from 22 Oct at 3,100 = 100,000; calendar split 3,100 / 6,200 on the 22nd = 410,000.
- Failing output before the fix:

  ```
  ... the same salary either side of a change pays exactly one month, by a fixed divisor too [E]
    Expected: <300000>
      Actual: <310000>
  ... a raise in February pays between the two salaries [E]
    Expected: <315000>
      Actual: <294000>
  ```

  The third test passed before and after: it guards what must not change.
- What changed, `packages/domain/lib/payroll.dart`, `periodSalary`: `whole` is true when every day of the month is paid by some monthly contract. Then each part's share is `rate x days covered / days in month`; otherwise each part is priced at its own rule (`days in month` for calendar days, the divisor for a fixed divisor; no rule still returns null, D-102). See (8) for the rounding.

## D-080 (8), F02-7: part-month pay with a cut rounds once

- Test, same file, group `a day with no attendance on a monthly salary (D-057)`: `D-080 (8) a part month with a day cut rounds once, and the cut is the part pay less what is paid (D-101)`. 100,000 fils, calendar days, contract from 29 October (3 days), the 29th cut: paid 6,452, cut shown 9,677 - 6,452 = 3,225.
- Failing output before the fix:

  ```
  ... D-080 (8) a part month with a day cut rounds once, ... [E]
    Expected: (int, int):<(6452, 3225)>
      Actual: (int, int):<(6451, 3226)>
  ```

- What changed, `periodSalary` (the same rewrite as (7)): every part is put over one common denominator `units` (the least common multiple of the month's days and each contract's own unit; for one calendar-days contract it is simply the days in the month). Per part, `share = rate x days x units / per` and what is left after the cut is `max(0, share - rate x days cut x units / unit)`, so a fixed divisor below the month's days still never cuts more than the part pays. Then `paid = divRoundHalfUp(sum of what is left, units)` and `cut shown = divRoundHalfUp(sum of shares, units) - paid`. Two roundings in all, one per figure, through the one rounding function (CALC-01); no `double`.
- Why this way: the parts are never rounded on their own, so they cannot drift a fil from the month. One contract over the whole month is `rate x days / days`, its amount exactly, as CALC-04 requires. A cut on a whole month by a fixed divisor is `rate x (1 - days cut / divisor)`, as before.
- Shared helpers taken out of `periodSalary` for closing (4): `salaryContractOn(contracts, day)` (the contract that pays a day: a general one before a site's, then the latest start, as the old sort did) and `cutsOn(contract, day)` (the contract cuts absence and the day is no weekly day off).

### What `docs/CALCULATION_SPEC.md` should now say (for the orchestrator)

In `## Payroll (PAY-02)`, the bullet "Monthly salary splits by days when a contract changes mid-month. Each day goes to one contract, so overlapping contracts never pay twice." becomes:

```text
- Monthly salary (CALC-04, D-080 (7)). Each day goes to one monthly contract: a general one before a site's, then the
  latest start, so overlapping contracts never pay twice.
  - Contracts that cover every day of the month between them: each part is its share of the month by its days,
    salary = sum(rate x days covered) / days in month. One contract for the whole month is its amount exactly; the same
    salary either side of a change is one month exactly; a raise pays between the two.
  - A month the worker joins or leaves in (a day no monthly contract covers): each part by its contract's own rule,
    calendar days rate x days / days in month, fixed divisor rate x days / divisor. No rule: stop for review (D-102).
  - A day cut for absence (D-057) is priced by the contract's own rule, rate / days in month or rate / divisor, and never
    takes more than its part pays.
  - Rounding (D-101, D-080 (8)): the parts are summed exactly over one denominator, then rounded once:
      paid       = round(sum over parts of max(0, share - rate x days cut / unit))
      cut shown  = round(sum of shares) - paid
    Example: AED 1,000 by calendar days from the 29th of a 31-day month, one day cut: paid round(100,000 x 2 / 31) =
    6,452 fils, cut shown 9,677 - 6,452 = 3,225.
```

and, after the D-104 bullet, two new bullets for (5) and (6):

```text
- Attendance added after posting for a day a posted salary cut gives that day's cut back in the next payroll, in the
  adjustment, as late work does (ATT-08, D-080 (5)). Each day gives back the cut on the days still missing before it less
  the cut after it, so all the days together give back exactly the posted cut. An absent row gives nothing back. The slip
  and the worker register count it in the month it was cut, as they count late work.
- A month with no work and no item of its own, whose only figure is a late correction taking money back, posts nothing
  and makes no debt (D-104). It does not stop closing; the minus waits and comes off the next pay (D-080 (6)).
```

## D-080 (5), F02-4: attendance added late gives a posted cut back

- Tests:
  - `packages/domain/test/payroll_test.dart`, `D-080 (5) attendance added late gives each cut day back, and all of them give back exactly the cut, never a fil more`: 100,000 fils from 29 October, the 29th and 30th cut, posted cut 6,451. Both days back give 3,226 + 3,225 = 6,451 (a day priced alone is 3,226, twice would be 6,452); a day never cut gives nothing; a day given back already is not given twice.
  - `apps/mobile/test/auto_cuts_test.dart`, `D-080 (5) attendance added late for a day a posted salary cut gives that day back in the next payroll, once, and an absent row gives nothing`: Karim, AED 3,100 by calendar days, Fridays off, October posted with the 5th, 12th and 26th cut (300.00). A row added late for the 5th and an absent row for the 12th: November's adjustment is 10,000 (one day). The October slip now reads salary 2,900, cut 200, days 12 and 26. November posts with adjustment 10,000; December gives nothing more back; the slip still says 2,900.
  - `apps/mobile/test/registers_test.dart`, `D-080 (5) a day a posted salary cut, worked after all, gives its cut back on the account, so the balance still equals pay owed`: 3,000 calendar, the 5th cut (9,677 fils), worked later. The worker register shows "Absence cut given back, 1 day: 5" earning 9,677, and its balance equals November's payable on Tankhwah (REP-08).
- Failing output before the fix:

  ```
  auto_cuts_test ... D-080 (5) attendance added late ... [E]
    Expected: <10000>
      Actual: <0>
  registers_test ... D-080 (5) a day a posted salary cut, worked after all, ... [E]
    Bad state: No element
  payroll_test (domain) ... D-080 (5) ... [E]   (with a stub cutGivenBack returning {}; the posted cut was 6,452 before (8))
    Expected: (int, List<String>):<(6451, [2026-10-29, 2026-10-30])>
      Actual: (int, List<String>):<(6452, [2026-10-29, 2026-10-30])>
  ```

- How a posted cut is recorded: `payroll_lines.absence_fils` and `absent_days` (comma list), written at posting. No schema change was needed.
- What changed:
  - `packages/domain/lib/payroll.dart`: `cutGivenBack(contracts, month, cutFils:, cutDays:, back:, worked:)` gives, day by day in date order, the cut on the days still missing before the day less the cut after it, priced by `periodSalary` with only the missing days absent. The first day starts from the posted `cutFils` itself, so giving every day back returns exactly the posted cut, never a fil more or less.
  - `apps/mobile/lib/data/payroll.dart`:
    - `_cutDaysPaidBack`: worked rows dated in a month and linked to a later month's line, by worker (one join). These days were given back by a posting already. A row corrected since still counts, so a day is never given back twice; undoing that later line unlinks its rows, so the day is given back again on the next posting, as it should.
    - `payrollFor`: for each posted line with cut days, `cutGivenBack(back: paid back, worked: this preview's unpaid, priced, non-absent rows)`. Each day's amount is added to the `WorkLine` of that day's first row, so it lands in `adjustmentFils` ("Earlier work", the label late work already has) and posts with the row. The worker's full contract list is used, not the active-only one, so an archived worker's give-back is priced too.
    - `cutsGivenBack({workerId})`: per worker, month and day, what each posted cut has given back or will at the next posting (paid back days plus unpaid worked rows, priced from the posted cut). Used by the statement and the register.
  - `apps/mobile/lib/data/statement.dart`: a posted month's salary is raised, and its cut and cut days lowered, by `cutsGivenBack`, the way late work counts in its own month.
  - `apps/mobile/lib/features/registers/register_defs.dart`, worker register: one line per posted month with a give-back, "Absence cut given back, N days: 5, 12", dated on the month's last day, so the balance still equals pay owed plus work not posted (REP-08).
  - Strings: `payrollCutBack`, "Absence cut given back, {count, plural, =1{1 day} other{{count} days}}: {days}" / "{count} din ki chhutti ki katoti wapas: {days}".

## D-080 (6), F02-5: a minus with nothing else waits, and does not stop closing

- Tests:
  - `packages/domain/test/payroll_test.dart`, `D-080 (6) a month with no work and no item of its own, only a late correction taking money back, waits for the next pay`: a correction of -100 alone gives `takesBackLater`; with 150 of work it posts; with an allowance or a salary of its own it is still `negativeNet`.
  - `apps/mobile/test/closing_test.dart`, `D-080 (6) a worker whose only pay is a late correction taking money back does not stop closing, and it comes off the next pay`: Asif's paid 5 October row deleted in November, no November work, a visa instalment of 50 set with 500 of visa money. November shows `takesBackLater`, the list text is "AED 90.00 to take back from the next pay.", no visa instalment is offered, closing November finds nothing and closes; December with two days of work posts net 180.00 and adjustment -90.00.
- Failing output before the fix (the visa guard first, then, with the closing skip turned off for the run, the closing block):

  ```
  ... D-080 (6) a worker whose only pay is a late correction ... [E]
    Expected: false
      Actual: <true>
  ... D-080 (6) a worker whose only pay is a late correction ... [E]
    Expected: empty
      Actual: [Instance of 'ClosingFinding']
  ```

  and in the domain test: `Expected: {PayrollIssue.takesBackLater}`, `Actual: {PayrollIssue.negativeNet}`.

  Two of the new domain assertions first compared a record holding a list or a set, which Dart compares by identity, so they also failed after the fix with equal-looking output. They were split (the set on its own) or joined to a string, as the file's other tests do; the failures quoted here show the real difference seen before the fix.
- The exact condition, `workerPayroll`: net or net + adjustment below zero, and nothing earned in the month, no salary (null counts as one, so an unpriced salary still stops), and no item of the month's own: `takesBackLater`. Any other negative net is `negativeNet`, as before. The issue still keeps the month from posting, so nothing negative is posted and no debt or advance is made (D-104).
- What changed:
  - `packages/domain/lib/payroll.dart`: `PayrollIssue.takesBackLater`.
  - `apps/mobile/lib/data/closing.dart`: `payrollNotPosted` is not raised for a worker whose issues contain `takesBackLater` and who has no unpriced rows.
  - `apps/mobile/lib/data/payroll.dart`: `needsVisaInstalment` is false on such a month, so "Add visa instalments" cannot turn a waiting minus into a block that stops closing. A room charge the owner ticks still can: that is the owner's own item, and it stops as today.
  - `apps/mobile/lib/features/payroll/payroll_screen.dart`: `issueText` says "{amount} to take back from the next pay." / "{amount} agli tankhwah se kaat liya jayega.", and the payroll list shows it in the quiet colour, not the warning one.
- Checked that the minus really comes off the next pay: the unpaid correction row stays unpaid (dated before every later month, so it is in each later month's adjustment), its month can close, and a closed row can still be linked to a later posting (trigger `closed_entry_no_edit` allows the link). December above posts it.

## D-080 (4), F02-2: closing asks about a cutting monthly worker's missing days

- Test, `apps/mobile/test/closing_test.dart`, group `attendance left out shows date by date (D-045)`: `D-080 (4) a monthly worker whose contract cuts absence is asked about exactly the days payroll cuts`. Bilal, known since August, AED 3,000 by calendar days from 2020-01-01 with the cut on and Fridays off; a row on 10 September, an absent row on the 15th, a day off on the 16th. August, before his account starts, is not on payroll and not asked about. September's cut is 24 days (30 less four Fridays, the day worked and the day off); closing asks exactly those, less the 15th, already answered by its absent row. After September posts, October's closing still asks the same September days, so attendance left out can still come in and give its cut back (5). The existing test `a worker on a monthly salary is paid whatever the register says, so their days are not asked for` (cut off) still passes unchanged.
- Failing output before the fix:

  ```
  ... D-080 (4) a monthly worker whose contract cuts absence ... [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
  ```

  After the closing change, the first run asked about every August day but the Fridays: payroll listed August for Bilal, with 4 Fridays' pay and 27 days cut, because the rule that hides a month before the account start only hid a month with no pay at all. So the test gained the assertion that August is not on payroll, which failed:

  ```
    Expected: empty
      Actual: WhereIterable<WorkerPayroll>:[Instance of 'WorkerPayroll']
  ```

- What changed:
  - `apps/mobile/lib/data/closing.dart`, `_findGaps`: a day with no row and no day off is reported at once for a worker no monthly contract pays that day (as before). For a day a monthly contract pays, it is a candidate only if `cutsOn` that contract (cut on, not a weekly day off); a cut-off contract is still never asked. Candidates are then kept only if that month's payroll (`payrollFor`, the month's own read reused) has the day in the worker's `absentDays`: the posted line's days for a posted month, the preview's for an open one. So closing asks exactly the days payroll cuts, with payroll's own account start, month order, closed months, archived workers, day offs, weekly days off and up-to-yesterday rule.
  - `apps/mobile/lib/data/payroll.dart`, `payrollFor`, the never-posted worker's month before the first activity: "only a cut" is now "a cut, and nothing earned and no adjustment or item", instead of "no pay at all". Weekly days off are never cut, so a month with nothing of its own could keep their pay and still be listed. This is D-079 (3)'s rule ("a month before the first activity that holds only a whole-month cut is not listed") applied to contracts with days off; it changes no month that has a row, an item or an old balance, and no contract with the cut off.

### Follow-up: a monthly worker with nothing recorded at all

The orchestrator's answer to the open point (D-080 (4)): a worker whose contract cuts absence and who has nothing recorded at all is asked about as a daily worker is (D-045 (2)). Payroll's listing stays as built above.

- Test, `apps/mobile/test/closing_test.dart`, same group: `D-080 (4) a monthly worker with nothing recorded at all is asked about as a daily worker is, from the day the app knew them`. Nadeem is added on 15 September 2020, with joining date 2018-01-01 and a contract from 2018-01-01 (cut on, Fridays off). This is the BUG-030 shape: a hiring date years before the app. A day off is marked on the 22nd. Payroll still lists no September for him. Closing September asks about 15 to 30 September less the two Fridays and the day off: nothing before the day the app knew him, and nothing from 2018. Once a row on the 28th starts his account, the days asked are payroll's cut days, the same list less the 28th.
- Failing output before the fix:

  ```
  ... D-080 (4) a monthly worker with nothing recorded at all is asked about as a daily worker is, ... [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
  ```

- What changed:
  - `apps/mobile/lib/data/payroll.dart`:
    - New `workersWithoutAccount()`: workers with no live payroll line and none of the activity payroll counts a salary from. That activity is a live attendance row (deleted corrections included), an item other than an advance recovery, a salary-owed or advance old balance, or salary paid, advance given or advance returned that was not undone in its own month.
    - The cash rule moved out of `payrollFor` into `_accountCash`, so both use one definition. `payrollFor` behaves the same; it only reads the set from the helper.
  - `apps/mobile/lib/data/closing.dart`, `_findGaps`: a candidate day of such a worker is reported directly; everyone else still goes through payroll's `absentDays`. The candidates are unchanged, so these rules all still hold:
    - The start is closing's existing one: the later of the day the app first knew the worker (`createdAtUtc`) and the joining date, so a hiring date years back moves nothing.
    - Asking runs up to yesterday.
    - Archived workers, day offs, weekly days off and contracts with the cut off are not asked.
  - `workersWithoutAccount()` is only read when there is such a candidate day.

## Callers checked

- `periodSalary`: `workerPayroll` (domain), `cutGivenBack` (domain), `statementsFor` (`lib/data/statement.dart`). `workerPayroll`: `payrollFor` only in the app (and so `postPayroll`, `applyVisaInstalments`, `applyRoomCharges`, closing, the payroll screens), plus domain `payroll_test` and `visa_test`. The salary sheet (`salary_sheet.dart`), Wages due and the cash form's month shares read `statementsFor`; the pay register reads posted lines as stored (their adjustment includes a posted give-back). The worker register reads posted salary itself, so it got the give-back line.
- `monthlySalary` (`packages/domain/lib/calc.dart`) is no longer called from `lib`; only `calc_test.dart`'s TC-019 tests use it. Left in place rather than delete those assertions; it can go with them when TC-019's calc tests are moved to `periodSalary`.
- `PayrollIssue` switches: only `issueText` (exhaustive, so the analyzer guards it). Other uses: `canAddItems`, `needsVisaInstalment`, the worker screen's recovery tap, closing.
- Changed but unchanged in result for existing tests: the D-057 fixtures, BUG-005, TC-019, TC-001, TC-033, visa and every test file below.

## Test runs after the fixes

Domain from `packages/domain`; app files one at a time from `apps/mobile`, after `flutter gen-l10n`.

| Check | Result |
| --- | --- |
| `dart test` (domain, all files) | 158 passed (payroll_test 29: 23 before, plus 3 new tests and a new group of 3) |
| `dart analyze --fatal-infos` (domain) | No issues found |
| `test/closing_test.dart` | 33 passed (30 before, plus 3 new, the third from the follow-up) |
| `test/auto_cuts_test.dart` | 8 passed (7 before, plus 1 new) |
| `test/registers_test.dart` | 24 passed (23 before, plus 1 new) |
| `test/payroll_test.dart` | 23 passed |
| `test/salary_payment_test.dart` | 27 passed |
| `test/statement_test.dart` | 18 passed |
| `test/attendance_test.dart` | 16 passed |
| `test/reports_test.dart` | 12 passed |
| `test/documents_test.dart` | 25 passed |
| `test/changes_test.dart` | 12 passed |
| `test/audit_journey_test.dart` | 1 passed |
| `test/visa_test.dart` | 9 passed |
| `test/cash_test.dart` | 8 passed |
| `test/scale_test.dart` | 1 passed (1:25) |
| `test/invoices_test.dart` | 50 passed |
| `test/plan_guard_test.dart` | 16 passed |
| `test/records_test.dart` | 8 passed |
| `test/timesheets_test.dart` | 39 passed |
| `flutter analyze` | No issues found |
| `python tools/check_trace.py` | OK: 166 PRD requirements traced |

No existing test or assertion was changed or deleted. Line endings kept per file (CRLF files stay CRLF); `dart format` not run.

After the follow-up: `closing_test` 33, `payroll_test` 23, `auto_cuts_test` 8, `audit_journey_test` 1, all passed; `flutter analyze` no issues.

## Open points for the owner and the orchestrator

- (4) narrows how D-079 (3) is built: a never-posted worker's month before the first activity is now hidden when it holds a cut and nothing of its own, even if weekly days off keep some pay. Before, with Fridays off and nothing recorded, such a month was listed: AED 3,000 by calendar days in August 2020 showed AED 387.10 for 4 Fridays and 27 days cut (AED 2,612.90), could be posted, and closing would now have asked 27 questions about it. To record with D-080 (4) or D-079 (3).
- Resolved in the follow-up above: a monthly worker with the cut on and nothing recorded at all is now asked about at closing as a daily worker is. Payroll still does not list them until one row (or item, old balance or money) starts their account.
- A day given back and later corrected to absent, or deleted, keeps its give-back: the posted salary is not cut again. With Karim, the 100.00 given back for 5 October stays if that row is then deleted. A daily worker's deleted row is taken back. Taking it back needs the give-back recorded per row (the amount is not stored on the row), so it was left.
- A day off marked after posting on a cut day gives nothing back: only attendance does, as the answer says.
- The give-back shows on the next month's Tankhwah as part of "Earlier work", with no line naming the days. The cut month's slip and the worker register name them.
- If a contract is edited after its month posted, the first give-back is still measured from the posted cut; a second, partial one is priced with the contract as it is then.
- A month the monthly contracts cover whole no longer needs a part-month method for its pay (it is shared by days); before, a split month whose contracts had no method stopped for review. A day cut still needs the method.
- Rounding moves by at most one fil in two cases besides F02-7: a whole month with a cut at an exact half fil (AED 1,000.05, divisor 30, one day: 96,672 now, 96,671 before), and a month with two parts each at its own rule, now summed before rounding.
- Closing reads payroll once more for each earlier open month that has a missing day for such a worker (marked `ponytail:`). Cheap while months close in turn; an owner who leaves many months open pays a payroll read per month.
- The one-denominator sum stays inside 64 bits up to about AED 10^12 a month with mixed divisors (marked `ponytail:`).
- Not checked on a phone or in the running app.
