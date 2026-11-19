# Review 02: payroll and money

## Files read in full

- docs/CALCULATION_SPEC.md
- DECISIONS.md rows D-020, D-024, D-029 to D-034, D-039, D-041 to D-045, D-057, D-101 to D-105
- packages/domain/lib/money.dart, validation.dart, dates.dart, cash.dart, calc.dart, payroll.dart, statement.dart, invoice.dart, csv.dart, timesheet.dart
- packages/domain/test/payroll_test.dart (and the test names of every other domain test file, checked against the rules below)
- apps/mobile/lib/data/payroll.dart, attendance.dart, cash.dart, visa.dart, closing.dart, statement.dart, masters.dart
- apps/mobile/lib/data/tenant_database.dart (context: applyOperation, lockedThrough, migrations)
- apps/mobile/lib/data/triggers.drift lines 88 to 215, tables.dart lines 100 to 160 and 420 to 660 (context)
- apps/mobile/lib/data/changes.dart lines 300 to 445 (deleteRecord, openMonthsFrom, editAttendance, deleteAttendance, deleteCash, replaceCash), read because every cash and attendance delete in scope goes through it
- apps/mobile/lib/features/payroll/payroll_screen.dart, payroll_worker_screen.dart, pay_item_form_screen.dart, room_charge_screen.dart, wages_due_screen.dart
- apps/mobile/lib/features/payroll/salary_slip.dart lines 1 to 242 (content model and figures)
- apps/mobile/lib/features/cash/cash_entry_form_screen.dart, cash_row.dart
- apps/mobile/lib/features/today/row_editor_screen.dart

## Files not fully read

- packages/domain/test/*.dart other than payroll_test.dart: test names read and matched to rules, bodies not read line by line.
- apps/mobile/test/*.dart: only the test names of payroll_test.dart were read, and a grep confirmed no app test covers `earlierMonthMissing` or `laterMonthPosted`. The other listed test files were not opened (time).
- apps/mobile/lib/features/payroll/salary_slip.dart lines 244 to 355: PDF layout only, no figures.
- apps/mobile/lib/features/today/attendance_entry_screen.dart (lines 175 to 235 read, rest grepped), attendance_review_screen.dart and today_screen.dart (grepped for save paths and operation ids only).
- apps/mobile/lib/features/groups/group_form_screen.dart (lines 75 to 120 read, rest grepped), groups_screen.dart (not opened).
- apps/mobile/lib/features/rates/contract_form_screen.dart (lines 88 to 290 read, rest grepped), opening_balance_form_screen.dart (lines 40 to 70 read), rates_screen.dart, rate_sections.dart, balances_screen.dart, rate_labels.dart (grepped only).
- apps/mobile/lib/features/closing/closing_screen.dart (lines 55 to 125 read).
- apps/mobile/lib/features/cash/cash_screen.dart, worker_money_section.dart; labour/*, companies/*, rooms/*, visa/visa_screen.dart; visa/visa_worker_screen.dart lines 20 to 60 only. These were grepped for parse calls, operation ids and write paths; none showed money arithmetic of its own.

## Rules checked

| Rule | Source | Implemented where | Test | Verdict |
| --- | --- | --- | --- | --- |
| One rounding function, half-up on magnitude, reversal is exact negative | SPEC Units, D-101 | packages/domain/lib/money.dart:4 `divRoundHalfUp` | domain money_test "a reversal is the exact negative" | SOUND |
| No `double` near money | CALC-01 | grep of all scoped files finds none (only PDF layout widths) | none needed | SOUND |
| Clock minutes `end - start`, end at or before start is next day; 20:00 to 08:00 = 720 | SPEC line 16, ATT-06 | calc.dart:73 `shiftTimes`, :80 | calc_test TC-018 | SOUND (see F02-9 for start equal to end) |
| `0 <= break <= clock`, else rejected | SPEC line 17 | calc.dart:82, attendance.dart:33 `blocksSave`, DB CHECK tables.dart:582 | calc_test TC-018, "oversized break" | SOUND. Break equal to shift gives 0 minutes, valid, hourly pay 0, day pay full fee, as specified |
| Client and worker minutes independent | CALC-02 | calc.dart:309-318 | calc_test TC-003 | SOUND |
| Work date is the date entered, night shift keeps it | D-024, D-103 | attendance.dart:252 (batch workDate), calc.dart:73 | calc_test TC-018 | SOUND |
| Hourly amount `divRoundHalfUp(min * rate, 60)` per line | SPEC line 28 | calc.dart:116 | money_test PRD fixtures, calc_test | SOUND. 660 min x 10 AED = 110.00; x 8 = 88.00 |
| Shift or day: fee, half, never hours x rate | CALC-03 | calc.dart:117-123 | calc_test TC-017, "half shift" | SOUND |
| Monthly salary once per period; full period exact; part period by contract method; no method stops | CALC-04, D-102 | calc.dart:141 `monthlySalary`, domain payroll.dart:92 `periodSalary` | payroll_test TC-019 group | SOUND for a single contract. Split months with a fixed divisor: see F02-6 |
| Mid-month contract change splits by days, each day one contract | SPEC line 62 | domain payroll.dart:99-121 | payroll_test "a raise mid-month" | SOUND (calendar days). 1-10: 3,100 x 21/31 = 2,100; 6,200 x 10/31 = 2,000 |
| Rate priority: override, assignment, general; latest start wins a tie | CALC-06, D-020 | calc.dart:60 `pickRate`, :243 `_withOverride` | calc_test TC-021 | SOUND |
| No rate: stop for review, never zero; absent row needs no rate | CALC-06, D-041 | calc.dart:104-105, attendance.dart:212 (`draft`), domain payroll.dart:191 | calc_test, mobile payroll_test "a row with no worker rate" | SOUND |
| Missing company rate holds only the bill, fills in later even on a frozen row | D-041(2) | attendance.dart:395, :417-427, triggers.drift:192-202 | calc_test, mobile payroll_test :275 | SOUND |
| Rate snapshot frozen once posted; a later rate reaches open rows only; closed month takes nothing | CALC-06, D-044(3) | attendance.dart:388-431, triggers.drift:127-137, :192 | mobile payroll_test :236, :307 | SOUND |
| Overtime: separate minutes, paid only if approved, at contract's own rate, no multiplier; missing rate stops | CALC-07 | calc.dart:107-136 | calc_test TC-022, payroll_test CALC-07 | SOUND |
| Group pay order: typed, member rate, own contract, group wage; half is half of wage used | D-042(1), SPEC line 70 | calc.dart:266 `groupPayTerms`, attendance.dart:111-131 | domain group_pay_test | SOUND |
| gross = attendance in month + monthly salary; net = gross + allowances - deductions - recovery - visa | PAY-02, SPEC line 51-52 | domain payroll.dart:80-81, :168-187 | payroll_test TC-032 | SOUND. Fixture: 500 + 1,000 - 200 - 100 = 1,200; paid 600 leaves 600 |
| Adjustment = unposted work dated before the month, less what the corrected row was paid | PAY-02, ATT-08, D-034(2) | domain payroll.dart:168-175, data payroll.dart:86-94 `_alreadyPaid` | payroll_test "work from an earlier period", mobile :331 | SOUND. Paid row 70, corrected to 90: adjustment 20; chain of two corrections pays only the latest paid version |
| opening = opening balance + earlier posted net and adjustment - all salary paid | PAY-02, D-033 | data payroll.dart:231-237, domain payroll.dart:222 | payroll_test TC-001 | SOUND. Sept 1,000, paid 500, Oct 1,000: total 1,500 |
| Net below zero or net + adjustment below zero blocks posting | D-104, PAY-07 | domain payroll.dart:204 | payroll_test TC-033 | SOUND |
| Optional company deduction limit counts deductions, room, recovery and visa against gross + allowances | SPEC line 64, D-034(6), D-039 | domain payroll.dart:195 | payroll_test, visa_test | SOUND |
| Recovery above advance outstanding rejected | PAY-05 | data payroll.dart:416-422, domain payroll.dart:193 | payroll_test TC-035, mobile :179 | SOUND |
| Advance instalments automatic, capped at each advance's balance and at what the month carries; no instalment asks | D-057(2) | domain cash.dart:176, data payroll.dart:210-229 | domain cash_test D-057 | SOUND |
| Visa instalment capped at what is left, kept apart from deductions and recovery | D-039 | data payroll.dart:449-484, domain payroll.dart:194 | domain visa_test | SOUND |
| Absence cut: no row and not absent-marked counts as absent; weekly off and excused days not cut; half not cut; only up to yesterday; contract's own rule | D-057(1),(4) | domain payroll.dart:108-138, data payroll.dart:127-130, :200-205 | payroll_test D-057 group | SOUND per day. A whole month absent hides the worker: F02-2. Rounding done twice: F02-7 |
| Months before the latest posted one pay no salary; a skipped month blocks a monthly worker | D-033, REP-04 | domain payroll.dart:177-180, :199-202 | payroll_test "month order", "closed month" | DEFECT: F02-1, F02-3 |
| One live payroll line per worker and month; posted figures never change | PAY-01, REP-08 | triggers.drift:45-67, :188 | mobile payroll_test TC-036 | SOUND |
| Posting all-or-nothing, idempotent by operation id; rows freeze with it | MODEL-07, TEAM-04, D-041(1) | data payroll.dart:272-369, tenant_database.dart:334-382 | mobile payroll_test TC-036 crash and retry | SOUND |
| Undo a posted line: latest month only, work and items unpaid again, paid money stays | D-033 | data payroll.dart:373-399 | mobile payroll_test :374, :403 | SOUND |
| Payment shares oldest first, owner can change, share above a month's owing refused, extra is its own advance after a yes | PAY-06, D-043(1),(3) | data statement.dart:353-418, cash_entry_form_screen.dart:160-260 | domain statement_test | SOUND (see F02-8 for a load race) |
| Old payment with no shares goes oldest first up to its date | D-043(4) | domain statement.dart:68-86 | statement_test | SOUND |
| Month below zero is a credit off the oldest months | SPEC line 120 | domain statement.dart:39 | statement_test "a month below zero" | SOUND |
| Worker balance = owed now + work not posted - advance not yet cut | SPEC line 84, D-042(2) | data statement.dart:107-348 | statement_test "however payments fall" | SOUND except where an item is stranded (F02-3) |
| Wages due: finished months only, due on last day + wage_due_days | PAY-08 | domain statement.dart:131 | statement_test PAY-08 group | SOUND |
| Cash rows immutable, reversal unique, reversal of a closed month's line dated today | D-030, D-044(3) | triggers.drift:12-19, tables.dart:122, data cash.dart:93-132 | domain cash_test | SOUND. Note: deleteCash opens the closed month first (D-056), so the "dated today" path is rarely reached |
| Return above advance refused; undo of an advance above what is left refused | D-030 | data cash.dart:60, :105 | not traced to a test | UNTESTED (code is correct) |
| Close only an ended month with nothing left; earlier open months close with it; writes in a closed month refused by triggers | REP-04, D-044, D-045 | data closing.dart, triggers.drift:91-185 | closing_test (not opened) | SOUND except the gaps in F02-2 and F02-3 |
| Monthly workers are not asked about missing attendance | D-045(2) | data closing.dart:197-209 | not checked | DEFECT against D-057: F02-2 |
| VAT exclusive and inclusive, total is sum of lines | INV-03..05, D-101 | domain invoice.dart:167-178 | invoice_test | SOUND. 105 inclusive at 500 bps: net 100, VAT 5 |
| Headcount information only | ATT-09 | calc.dart:170 | calc_test TC-028 | SOUND |

## Findings

### F02-1: Posting a later month first silently drops a monthly worker's unposted earlier salary

- Severity: High
- Status: CONFIRMED (by trace; no test exercises it)
- Where: packages/domain/lib/payroll.dart:199-202 (`earlierMonthMissing` loop) and :177-180 (`later` sets salary to 0); apps/mobile/lib/data/payroll.dart:197 (`lastPostedMonth`), :230 (empty months skipped).
- Expected: a monthly salary is paid once per period (CALC-04), a month cannot be skipped for a monthly worker (the `earlierMonthMissing` rule, D-033), and unpaid wages carry forward (PAY-03, D-045(5)).
- Actual: the "earlier month missing" check only runs from the month after `lastPostedMonth`. When the worker has never been posted, `lastPostedMonth` is null and the loop never runs, so any later month can be posted first. Once it is, every earlier month is behind the latest posted one, so its salary becomes 0 (`later`), its figures are empty, and `payrollFor` drops the worker from that month's list (`figures.isEmpty && unpriced == 0`). The statement drops it too, because statement.dart:298 only counts salary for months after `lastPosted`. Nothing on any screen says a month was skipped.
- Reproduction: worker on a monthly contract of AED 3,000 from 2026-09-01, calendar-day method, absence cut off, nothing posted. On 2026-11-02 the owner opens Tankhwah for October and posts. October's line holds 3,000. September's preview now has `laterMonthPosted` and salary 0, and the worker no longer appears in September's list. The slip for September shows no salary and the account balance shows 3,000 less than before the posting. The worker has lost a month's pay without a message. A regression test belongs in apps/mobile/test/payroll_test.dart, next to "money already paid stays on the account, and a later month must go first".
- Proposed minimal fix: in `payrollFor`, when the worker has no posted line, pass a start month into `workerPayroll` and run the same `earlierMonthMissing` loop from there. Use the start the statement already uses for "the account's first activity" (statement.dart:294-296), so a contract dated from a hiring date years ago does not block the first posting. Regression risk: a first posting that owners do today for a month after earlier attendance would now be held until the earlier month is posted or closed. Tests that post a month with earlier monthly coverage and no earlier line would need that month posted first.

### F02-2: A monthly worker who has no attendance all month disappears from payroll, and closing never asks for their attendance

- Severity: Medium
- Status: CONFIRMED (by trace)
- Where: packages/domain/lib/payroll.dart:85 (`isEmpty` ignores `absenceFils`); apps/mobile/lib/data/payroll.dart:230; apps/mobile/lib/data/closing.dart:208 (`salaried` workers skipped in `_findGaps`).
- Expected: under D-057 a missing attendance row cuts a monthly salary, and "the payroll must show each day cut before posting". D-045(2) skips monthly workers in the missing-attendance check "because their pay does not depend on the register", which stopped being true for contracts with the cut on. The contract form turns the cut on for every new monthly contract (contract_form_screen.dart:85).
- Actual: with the cut on, no weekly off days and no rows in the month, `periodSalary` cuts the whole salary, `grossFils` is 0, `isEmpty` is true, and the worker is left out of the month's payroll list entirely, so the day-by-day cut is never shown. Closing does not ask about their missing days either, so nothing flags it. If the worker was posted in an earlier month, the next month then shows `earlierMonthMissing` for a month that has nothing to post. It stays blocked until the empty month is closed, and closing waits on everything else, including overdue invoices.
- Reproduction: monthly contract AED 3,000 from 2026-01-01, calendar days, cut on, no off days; August posted; no attendance rows in September. September's Tankhwah list does not show the worker, and the September closing finds no missing attendance for them. October's preview shows `earlierMonthMissing`, and the only way out is closing September. Regression tests belong in apps/mobile/test/payroll_test.dart and closing_test.dart.
- Proposed minimal fix: count `absenceFils` in `PayrollFigures.isEmpty`, so the worker stays listed and can post a zero month with the cut shown. Then in `_findGaps`, ask about a salaried worker's days when the covering contract has `cutAbsence` on. This second part touches D-045, so it is the owner's call. Regression risk: a posted zero-salary line now appears for a fully absent month, which is the intended visible state. The closing list grows for monthly workers whose attendance is not kept.

### F02-3: A pay item in a month behind a later posted month can never post, but the slip counts it and closing is blocked

- Severity: Medium
- Status: CONFIRMED (by trace)
- Where: apps/mobile/lib/data/payroll.dart:403 `savePayItem`, :489 `applyRoomCharges`, :104-107 (items read for one month only); apps/mobile/lib/features/payroll/payroll_worker_screen.dart:317 (add buttons shown whenever the month is not posted); apps/mobile/lib/data/statement.dart:158-161 (items counted for every month up to the one shown); apps/mobile/lib/data/closing.dart:111-113.
- Expected: an allowance or deduction is earned or cut in the month it is for (PAY-02). The worker register always equals what Tankhwah owes plus work not posted (SPEC line 84, D-043(2)).
- Actual: nothing stops a later month being posted while an earlier month has unposted items. A daily worker is never held by `earlierMonthMissing`, and the add buttons stay on a month that shows `laterMonthPosted`. Such an item is never linked to a line: its own month cannot post, and later months read only their own `periodFrom`. The statement still counts it, so the slip, the register and Wages due disagree with Tankhwah. Closing reports `payrollNotPosted` for it on every later month. The "post ready" fix on the closing screen posts nothing for that month. The only ways out are deleting the item or undoing the later posting.
- Reproduction: daily worker; September allowance of AED 100 added, September not posted; October posted (September's rows correctly come in as an adjustment). The allowance stays unlinked. The September slip shows +100 and the account balance includes it, but Tankhwah's "owed now" does not. Closing September or October lists the worker under pay not posted. A room charge of 200 in the same position makes the slip show 200 more taken than payroll ever cut. Regression test in apps/mobile/test/payroll_test.dart.
- Proposed minimal fix: in `payrollFor`, raise `earlierMonthMissing` for a worker who has any item with `lineId` null and `periodFrom` before this month and after the closed month. This is one query, grouped by worker. Also hide the add buttons when the month has `laterMonthPosted`. Regression risk: low. It only holds workers who already have a stranded item.

### F02-4: A late attendance row on a posted monthly-salary month never gives back that day's absence cut

- Severity: Low
- Status: SUSPECTED (the spec is silent on it, so this may be intended)
- Where: packages/domain/lib/payroll.dart:168-175 (a late monthly row is a `WorkLine` of amount 0); apps/mobile/lib/data/payroll.dart:200-203.
- Expected: ATT-08 and D-034(2) say work approved late goes into the next payroll as the difference. D-057 says the cut "can be changed until posting" but does not say what happens after.
- Actual: for a monthly worker the late row's amount is 0, so the adjustment is 0, and the posted line keeps the cut for a day the register now shows as worked. The owner must notice and add an allowance by hand.
- Reproduction: monthly AED 3,100 in a 31-day month with the cut on, 5 October missing; October posted with a 100 cut. On 3 November the owner adds the 5 October row. November's adjustment is 0, the October line still says "1 din chhutti kaat kar (5)", and the 100 is not returned.
- Proposed minimal fix: an owner decision is needed first. If wanted, `payrollFor` can count, for each posted month, absent days in `absentDays` that now have a row, and add `divRoundHalfUp(rate, perDay)` for each as an adjustment. Regression risk: medium, because it touches posted-month arithmetic.

### F02-5: A late correction that lowers pay with no current work holds the worker, and every later month's closing, with no tool to clear it

- Severity: Low
- Status: CONFIRMED (the behaviour follows D-104; the workflow gap is the finding)
- Where: packages/domain/lib/payroll.dart:204; apps/mobile/lib/data/closing.dart:108-110.
- Expected: D-104 blocks posting and sends the worker to review, and never auto-carries a debt.
- Actual: the review has no resolving action. The row stays unpaid with a negative difference. Each later month's `payrollFor` includes it, so `payrollNotPosted` stops closing for every later month. The only ways to post are inventing an allowance or deleting the correction.
- Reproduction: daily worker paid AED 100 in October for one row; in November the row is deleted (absent correction); the worker has no November work. November shows net 0, adjustment -100, `negativeNet`. December and later months show the same and none can close.
- Proposed minimal fix: an owner decision is needed (for example, record the overpaid difference as an advance after a yes, as D-043(3) does for overpayments). Regression risk: n/a until decided.

### F02-6: With a fixed divisor, a mid-month contract change pays more or less than a full month

- Severity: Low
- Status: CONFIRMED (arithmetic follows the spec's formula literally; flag for the accountant)
- Where: packages/domain/lib/payroll.dart:124-126 and calc.dart:148-151.
- Expected: "Full period = the monthly amount exactly" (CALC-04), and the split never pays twice.
- Actual: each contract is prorated as `monthly x covered / divisor`, so the parts of a fully covered month do not add up to a month. With divisor 30 in October (31 days) and the same AED 3,000 on both sides of a change on the 16th, the result is 1,500 + 1,600 = 3,100. In February (28 days), a raise from 3,000 to 3,300 on the 15th gives 1,400 + 1,540 = 2,940, less than either salary for a full month worked.
- Reproduction: domain payroll_test, with two `monthly(..., method: fixedDivisor, divisor: 30)` contracts split mid-month.
- Proposed minimal fix: for the accountant to decide. One option is to prorate the last contract segment as the month's salary less the earlier segments when the whole month is covered. Regression risk: low; it only touches split fixed-divisor months.

### F02-7: The absence cut is rounded separately from the part-month pay, so one fil can be lost

- Severity: Low
- Status: CONFIRMED
- Where: packages/domain/lib/payroll.dart:125 and :135.
- Expected: one rounding per amount (D-101).
- Actual: `pay` and `less` are each rounded, then subtracted.
- Reproduction: AED 1,000 (100,000 fils), calendar days, contract from the 29th of a 31-day month (3 covered days), 1 absent day. pay = round(9,677.42) = 9,677; less = round(3,225.81) = 3,226; total 6,451 fils. One rounding of 100,000 x 2 / 31 gives 6,452. The test would sit in packages/domain/test/payroll_test.dart.
- Proposed minimal fix: compute `divRoundHalfUp(rate * (covered - off), units)` for the paid figure, and the cut as the full-period pay minus that. Regression risk: low; the existing D-057 fixtures still pass because their figures divide exactly.

### F02-8: A salary payment saved before its months load is written entirely as an advance

- Severity: Low
- Status: SUSPECTED (timing-dependent, not reproduced)
- Where: apps/mobile/lib/features/cash/cash_entry_form_screen.dart:88 (`_loadUnpaid` is async), :187 (`_extraFils`), :253-259.
- Expected: a payment shares out oldest first, and only the true extra becomes an advance (D-043(3)).
- Actual: until `statementsFor` returns, `_unpaid` is empty, so `_extraFils` is the whole amount. A quick Save on a form opened from "Pay now" shows the extra dialog for the full amount, and a yes writes it all as an advance. The balance is unchanged, but the month stays unpaid on Wages due and the advance is then recovered from future pay.
- Reproduction: open Pay now on a posted worker with a long history on a slow phone, then tap Save at once.
- Proposed minimal fix: disable Save for a salary payment until the first `_loadUnpaid` has finished. Regression risk: none.

### F02-9: A shift whose end equals its start is stored as 24 hours

- Severity: Low
- Status: CONFIRMED
- Where: packages/domain/lib/calc.dart:76; no guard in row_editor_screen.dart:83 or attendance_entry_screen.dart:181.
- Expected: "the end may fall on the next day" (ATT-06). A same-time entry is more likely a typo than a 24-hour shift.
- Actual: 08:00 to 08:00 is 1,440 minutes. At AED 8 an hour that pays AED 192 with no warning.
- Proposed minimal fix: refuse equal start and end in both screens, or ask to confirm a 24-hour shift. Regression risk: none in the domain.

### F02-10: The row editor crashes on Apply when Absent is chosen after the break field was cleared

- Severity: Low
- Status: CONFIRMED
- Where: apps/mobile/lib/features/today/row_editor_screen.dart:100 (`int.parse(_break.text.trim())`). The break field and its validator are only built when the status is not absent (:136).
- Reproduction: open a saved row, clear the break field, choose Absent, then tap Apply. `int.parse('')` throws inside `onPressed`, so the button does nothing and an error is logged.
- Proposed minimal fix: `int.tryParse(...) ?? 0`, or use 0 when the status is absent. Regression risk: none.

## Missing versus spec

- PAY-06's "Payment allocation defaults to oldest unpaid first, with owner confirmation" is built. There is no link between a salary line and the advance line written for its extra, so undoing the salary leaves the advance (stated ponytail in statement.dart:352).
- D-045(5) says unpaid wages do not stop closing, as built.
- D-057's rule that an archived worker stops earning relies on the owner posting before archiving (ponytail in data payroll.dart:188); there is no end-date check.

## Known-deferred noticed

- Whole-history reads on daily screens: `statementsFor` for every worker on each table change (Wages due banner), and `payrollFor` reading all cash and lines. Both are marked ponytail with the scale test as evidence (statement.dart:470), so they are not reported.
- `_alreadyPaid` runs one query per corrected row inside the per-worker loop (data payroll.dart:181). It is cheap while corrections are few. Noted only.
- The `plainAmount` negative printing and the `parseAed` length cap are already known and fixed. Not re-reported.
