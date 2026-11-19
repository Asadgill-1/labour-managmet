# Fixes F: the owner's billing answers (D-080 (1) to (3))

Branch `audit/t01-t21`, nothing committed. Each answer: a test seen failing for the right reason first, then the fix, then the test files around it. `DECISIONS.md` shows as changed in the working tree, but not by this work; no record file was touched here.

## D-080 (1), F03-1: a company has one fixed monthly amount at a time

- Outcome: REPRODUCED (a second fixed amount saved with no warning), fixed.
- Test: `apps/mobile/test/invoices_test.dart`, group `a monthly contract (TS-08)`, `F03-1 a company has one fixed monthly amount at a time, at any site, so none goes unbilled (D-080 (1))`. The group's company already has AED 5,000 fixed for every site from 2020-01-01. The test saves a fixed AED 3,000 for site Yard (open, and for 16 to 20 October only), a second AED 3,000 for every site from the same day, and an hourly Yard rate turned into a fixed one: all refused, nothing written. Then it ends the first amount on 2020-10-31, adds 6,000 from 2020-11-01 to 2020-12-31 and 6,500 from 2020-12-01 to 2020-12-31 (same scope, later start, over the 6,000's dates: a new rate, allowed), refuses Yard from 2020-12-15, and allows Yard from 2021-01-01. It also checks `saveErrorText` gives `contractSecondFixed` in English and Roman Urdu.
- Failing output before the fix:

  ```
  F03-1 a company has one fixed monthly amount at a time, ... [E]
    Expected: throws <Instance of 'SecondFixedAmount'>
      Actual: <Instance of 'Future<String>'>
       Which: emitted '21d6b71b-b38f-4f13-9f7a-fb692b662b10'
  ```

- What changed:
  - `apps/mobile/lib/data/masters.dart`: new `SecondFixedAmount` exception (top of file). `saveRow` calls `_oneFixedAmount(rowId)` inside its `change:` closure for `billing_contracts`, after the write, as it already does for `keepOpeningSettled`, so a throw rolls the write back with the audit event and outbox row. `_oneFixedAmount` reads the saved row; if it is `monthFixed`, it refuses when another `monthFixed` contract of the same company has dates that meet it (`datesOverlap`, the helper the form's overlap check already uses), unless that other contract has the same `siteId` and `workerId` and a different `effectiveFrom`. That pair is one amount's rate change: `pickRate` gives the later start every date from then on (CALC-06), so there is never more than one amount on a day.
  - `apps/mobile/lib/app/theme.dart`: `saveErrorText` maps `SecondFixedAmount()` to `contractSecondFixed`. The contract form saves through `saveOrExplain`, so the message shows there.
  - Strings: `contractSecondFixed`, "This company already has a fixed monthly amount for these dates. Change that amount, or end it first." / "In tareekhon ke liye is company ki fixed mahana raqam pehle se hai. Usi raqam ko badlein, ya pehle use khatam karein."
  - `feeCover` and the schema are unchanged.
- Callers checked: billing contracts are written only through `saveRow` (the contract form, `contract_form_screen.dart:160`, and tests) and removed through `deleteRecord`. No import, restore step or sync writes them row by row (company rates import is not built, D-053 (7)). The form's own check (`billingContractOverlaps`) still runs first and still refuses the same site and worker over the same dates with `contractOverlap`; the new rule adds the cross-site case.

## D-080 (2), F03-2: a credit note for an amount cannot take all that is left

- Outcome: REPRODUCED, fixed.
- Test: `apps/mobile/test/invoices_test.dart`, group `a credit note (INV-06)`, `F03-2 for an amount can never take all that is left, so the whole invoice can still be taken back (D-080 (2))`. The audit's case: a registered invoice of 135.00 + 6.75 VAT, an amount credit of 30.00 (+1.50), leaving 105.00 + 5.25 = 110.25. An amount credit of 105.00 (110.25 with VAT) is refused with `creditTakesAll` and nothing is written. `editInvoice` then goes through: the whole credit note takes the rest, the invoice is `credited`, its work is free (`unbilledLines` has the row again) and the new draft charges 135.00. It also checks `saveErrorText` gives `invCreditTakesAll` in both languages.
- Failing output before the fix:

  ```
  F03-2 for an amount can never take all that is left, ... [E]
    Expected: throws <Instance of 'InvoiceRefused'> with `problem`: InvoiceProblem:<InvoiceProblem.creditTakesAll>
      Actual: <Instance of 'Future<String>'>
       Which: emitted '97746e29-c32d-425f-abe6-44e8b67a807f'
  ```

- What changed:
  - `apps/mobile/lib/data/invoices.dart`: `InvoiceProblem.creditTakesAll`. In `creditInvoice`, after the existing `creditTooBig` check: `if (!whole && taken == left.totalFils) throw const InvoiceRefused(InvoiceProblem.creditTakesAll);`. With `>` still refused as `creditTooBig`, an amount credit is now accepted only below what is left, so a whole credit note always has something left to take and can free the work.
  - `apps/mobile/lib/app/theme.dart`: `saveErrorText` maps it to `invCreditTakesAll`.
  - `apps/mobile/lib/features/invoices/invoice_screen.dart`, `_CreditSheet`: the amount field says the same at the field, before the sheet closes (above what is left still says `invCreditTooBig`).
  - Strings: `invCreditTakesAll`, "That is all that is left of this invoice. Choose Whole invoice instead, so its work can go on a new invoice." / "Yeh is invoice ki saari baqi raqam hai. Is ke bajaye Poora invoice chunein, taake is ka kaam naye invoice par ja sake." The amount's help, `invCreditPartHelp`, said "up to {amount}", which now would be wrong, so it says "less than {amount}" / "{amount} se kam".
- Callers checked: `creditInvoice` is called by the invoice screen's credit sheet (`invoice_screen.dart:124`) and by `editInvoice` (`invoices.dart`, always whole, `amountFils` null, so never refused by the new rule). Existing tests that credit an amount all take less than what is left; none needed changing.

## D-080 (3), F03-3: a fixed monthly fee is charged once a month, at the newest rate in it

- Outcome: REPRODUCED, fixed. The same double charge was found for a fee per worker and fixed by the same rule (see below).
- Tests, `apps/mobile/test/invoices_test.dart`, group `a monthly contract (TS-08)`, using a helper `rateChanged` (a new company whose contract goes from one rate to another on 2020-10-16, with Asif on the 6th and 21st and Bilal on the 6th, on one approved timesheet):
  - `F03-3 a fixed amount whose rate changes inside a month is charged once, at the newest rate (D-080 (3))`: AED 5,000 then 6,000. The draft has one line, 1 x 6,000, from the 6th to the 21st with all three rows. A draft fee saved under the old key (`fee|monthFixed|500000|2020-10`) is ignored without error and the line stays at 6,000. The owner's figure under the line's key (5,500) is used. Issued at 6,000, the month has nothing more to bill and is not "not invoiced".
  - `a fee per worker whose rate changes inside a month charges each worker once, at their newest rate`: AED 2,000 then 2,500 per worker. Lines are 1 x 2,000 (Bilal) and 1 x 2,500 (Asif).
- Failing output before the fix:

  ```
  F03-3 a fixed amount whose rate changes inside a month is charged once, ... [E]
    Expected: [(int, int, int):(1, 600000, 600000)]
      Actual: [(int, int, int):(1, 500000, 500000), (int, int, int):(1, 600000, 600000)]
    one month, not 5,000 and 6,000

  a fee per worker whose rate changes inside a month charges each worker once, ... [E]
    Expected: Set:[(int, int, int):(1, 200000, 200000), (int, int, int):(1, 250000, 250000)]
      Actual: Set:[(int, int, int):(2, 200000, 400000), (int, int, int):(1, 250000, 250000)]
    Bilal at the old rate, Asif once at the new
  ```

  Asif was charged 2,000 and 2,500 for one month.
- What changed, `apps/mobile/lib/data/invoices.dart`, `_draftLines`:
  - The rows that would go on are collected first. For each monthly row, its fee's cover (`feeCover`, reused: the month for a fixed fee, the worker and month for a fee per worker) maps to the row with the latest work date; `rateOf(row)` is that row's rate.
  - A fixed fee's line key is `fee|monthFixed|YYYY-MM`, no rate. A fee per worker keeps `fee|<basis>|<rate>|YYYY-MM`, with the rate now the worker's newest in the month, so each worker sits in one line and the key reads as before when the rate did not change. Hour, day and shift lines are unchanged.
  - The line's `rest` (`clientMonthlyCharge`) and printed unit price use `rateOf(first)` instead of the first row's rate. `rest` still subtracts what live invoices already charged for the month (D-059), and `draft.fees[key]` still wins, so the owner can change the line.
- Old saved drafts: `draft.fees` and `draft.discounts` are maps looked up with `[key] ?? default`, so a key no line has any more is read as nothing: no crash. A fixed fee typed or a discount set on an open draft before this change is not applied; the line shows the month's amount less earlier invoices, and the owner types it again. The old entry stays in the draft's JSON unused. A fee per worker's key changes only for a worker whose rate changed inside the month. No migration was written: drafts are short-lived and the app has no customers yet.
- Callers checked: `_draftLines` is used by `createInvoice` (refuses nothing to bill), `invoiceView` for a draft, and so `issueInvoice` and the paper. `issueInvoice` allocates every source row, both rates' rows, at 0, and `_storeLines` keeps `fee_month` from the line's first date, which is the same month. `billableLines`, `feesCharged`, `feeDone` and `workCharges` were not changed: with the month charged at the newest rate, `feeDone` counts rows at either rate as charged, since the amount reached is at least each row's own rate.

## Test runs after the fixes

Run one file at a time from `apps/mobile`, after `flutter gen-l10n`:

| File | Result |
| --- | --- |
| `test/invoices_test.dart` | 50 of 50 passed (46 before, plus the 4 new tests), twice |
| `test/timesheets_test.dart` | 39 passed |
| `test/closing_test.dart` | 30 passed |
| `test/masters_test.dart` | 7 passed |
| `test/reports_test.dart` | 12 passed |
| `test/audit_journey_test.dart` | 1 passed |
| `test/rates_test.dart` (contract form and overlap check) | 5 passed |
| `test/invoice_edit_test.dart` | 6 passed |
| `test/invoice_paper_test.dart` | 9 passed |
| `test/timesheet_paper_test.dart` (two fixed contracts on two companies) | 20 passed |
| `test/drift/tenant/migration_test.dart` (credits for an amount on old data) | 16 passed |
| `test/payroll_test.dart` | 23 passed |
| `test/attendance_test.dart` | 16 passed |
| `test/groups_test.dart` | 9 passed |
| `test/registers_test.dart` | 23 passed |

`flutter analyze`: No issues found. No existing test or assertion was changed or deleted.

## Open points for the owner and the orchestrator

- The fee per worker fix (one line per worker a month, at that worker's newest rate) goes beyond D-080 (3)'s wording, which names only a fixed contract. It applies the existing rule "a fee per worker once for each worker a month" (D-054 (1), D-059) inside one invoice. Log it with D-080 (3) or ask the owner.
- Two other places still list a monthly contract once per rate, so a rate changed inside a month shows both: the salary sheet's contract lines and its company bill (`apps/mobile/lib/features/registers/salary_sheet.dart:37-79`, keyed by company, basis and rate), which would read AED 11,000 where the invoice now charges 6,000; and the timesheet's monthly contract rows (`packages/domain/lib/timesheet.dart` `monthlyContracts`, keyed by basis and rate), which show two rows with no amount. Not changed: outside this brief.
- F03-1 checks a contract's own dates. An older amount left open after a same-scope new rate (only possible outside the form, which makes the owner end the first) still counts as overlapping a later site amount. Through the form this cannot happen.
- A company that already holds two overlapping fixed amounts from before this change keeps them. Any save of either is refused until that save removes the overlap: end one before the other starts, change its basis, or delete it (contracts can be deleted, nothing names them).
- Not checked on a phone or in the running app; the field message and the save message are covered by `saveErrorText` and the validator code only.
