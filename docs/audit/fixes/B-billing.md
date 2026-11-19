# Fixes B: billing and data

Branch `audit/t01-t21`, nothing committed. Each item: failing test first, then the fix, then the test files around it.
Line numbers are those of the final working tree.

## BUG-010 (F03-5): a retry with the same operation id returned an id that was never stored

- Outcome: REPRODUCED, fixed at the root.
- Root cause: `TenantDatabase.applyOperation` (`apps/mobile/lib/data/tenant_database.dart`) returned nothing. On a retry `_applyOnce` found the outbox row and returned early, and each caller then returned the fresh `newUuid()` it had made before the call, which was never written.
- Fix: `applyOperation` and `_applyOnce` now return `Future<String>`, the stored record id: `seen.recordId` from the outbox row on a retry, otherwise the `recordId` just written. Every caller that minted an id and returned it now returns what `applyOperation` gives (`return applyOperation(...)`):
  - `invoices.dart` `createInvoice`, `creditInvoice`, `editInvoice`
  - `timesheets.dart` `createTimesheet`
  - `receipts.dart` `addClientReceipt`
  - `documents.dart` `_keepImage` (so `saveDocumentImage` points the template at the real asset), and `issueDocument`, which read its row back by the fresh id (now by the stored one)
  - `attendance.dart` `saveAttendanceBatch`, `correctEntry` (not in the review; same pattern)
  - `masters.dart` `saveRow` (create path), `saveWorkerGroup` (not in the review; same pattern, and `saveRow` is what every form uses)
- Sibling callers checked (all 41 `applyOperation` calls in `lib/data`): the rest either return `Future<void>` (`cash.dart` `addCashEntry`, `reverseCashEntry`; `closing.dart` `markDayOff`, `closeMonth`, `reopenMonth`; `statement.dart` `addSalaryPayment`, `settleOldPayment`; `timesheets.dart` `startTimesheetRevision`, `_stepRevision`, `deleteTimesheetDraft`, billing allocations; `invoices.dart` `issueInvoice`, `deleteInvoiceDraft`; `receipts.dart` `useClientCredit`, `_lost`; `changes.dart` `deleteRecord`, `replaceCash`; `restore.dart`), or use an id they were given (`old.id`, `operationId`, `payment.id`). `startTimesheetRevision` was listed in the review but returns nothing, so no caller can get a wrong id from it. Two return counts, not ids, and give 0 on a retry: `approveEntries` and `postPayroll` (payroll.dart, other fixer's file, left alone). Not an id bug; noted only.
- Tests (failing first):
  - `test/invoices_test.dart` `a retry of a draft, a credit note or an edit gives back the one it made (BUG-010)`. Before the fix:
    ```
    Expected: '361ffdd4-1e04-4bda-bb2d-8de46e0dd23b'
      Actual: '24c329f6-2d67-42e2-81f9-20b74de4e444'
    a second tap on the same form
    test\invoices_test.dart 249:7
    ```
  - `test/invoices_test.dart` `part received leaves the rest owed ... and a retry changes nothing`: the retry line now also expects the first receipt's id (an added assertion, nothing removed). Before: `Expected: '1f4d...' Actual: '26e8...' the retry gives back the receipt it made (BUG-010)`.
  - `test/timesheets_test.dart` `a retry of a draft, a day, a correction or a new record gives back the one it made (BUG-010)` (createTimesheet, saveAttendanceBatch, correctEntry, saveRow). Before: `Expected: '16d0...' Actual: '0700...'`.
  - `test/groups_test.dart` `keeps its members, and a retry of the same operation changes nothing`: the retry now expects the first group's id (added assertion). Before: `Expected: 'f11e...' Actual: 'd53a...'`.
  - `test/documents_test.dart` `a retry of the same upload gives back the image it kept, and the template still points at it (BUG-010)`. Before: `SqliteException(787): ... FOREIGN KEY constraint failed`, exactly the review's symptom.
  - `test/write_path_test.dart` `a retry gives back the id the first call stored, not the one it was handed (BUG-010)`: the root contract. Before the fix this file did not compile (`A value of type 'Future<void>' can't be returned from a function with return type 'Future<String>'`), since `applyOperation` returned nothing; the helper `insertClient` now returns the id.
- After the fix: `write_path_test` 9/9, `invoices_test` 44/44, `timesheets_test` 39/39, `groups_test` 9/9, `documents_test` 25/25, `attendance_test` 16/16, `masters_test` 6/6, all passed. `flutter analyze`: no issues.
- Existing expectations changed: none. Two existing retry tests gained an assertion on the returned id.

## BUG-009 (F03-4): a company's old balance could be lowered or deleted after receipts settled it

- Outcome: REPRODUCED, fixed in the data layer.
- Root cause: opening balances are written through the generic `saveRow` (`masters.dart`) and removed through `deleteRecord` (`changes.dart`). No foreign key names an `opening_balances` row, so `_inUse` never holds it, and neither path asked what receipts had settled of it. The allocation rows with `invoice_id` NULL stay while the amount under them shrinks or goes, so `openingLeftFils` goes negative or disappears and the receipt's money vanishes from `creditOf`.
- Fix (one rule, run inside the same write's transaction, so a refusal writes nothing):
  - `apps/mobile/lib/data/receipts.dart` 15-20: new `OpeningSettled` exception. 144-152: `keepOpeningSettled(old)`: for a `client_receivable` row, sums the parts with `invoiceId == null` that `receivables()` counts for that company (receipts still standing, the same set `openingLeftFils` uses) and throws when that is more than the company's opening balance after the change (0 when it is gone or no longer a `client_receivable`).
  - `apps/mobile/lib/data/masters.dart` 50, 59, 94: `saveRow` keeps the stored row (`existing`, hoisted out of the `if`) and, for `opening_balances` updates, calls `keepOpeningSettled` after the write.
  - `apps/mobile/lib/data/changes.dart` 334-335: `deleteRecord` calls it after the delete of an `opening_balances` row.
  - It runs after the outbox retry check, so a retry of a save that went through is never refused.
  - Screen: `apps/mobile/lib/app/theme.dart` 356, `saveErrorText` maps `OpeningSettled` to the new string, which `saveOrExplain` (the form's save) and `deleteOrArchive` (its delete, through `showSaveError`) show. Strings: `app_en.arb` 2269 and `app_en_PK.arb` 1011 `openingSettled`, then `flutter gen-l10n` (regenerated `app_localizations.dart`, `app_localizations_en.dart`; the other fixer's `accountPasswordAgain` entries stay).
- Paths checked: `opening_balance_form_screen.dart` `_save` (saveRow) and `_delete` (deleteRecord) are the only writers in the app; `import.dart` writes no opening balances; `plan_guard.dart` archives through `saveRow` only tables with `active`, which `opening_balances` has not. A cloud or file restore replaces the whole database and is not a per-row path.
- Test: `apps/mobile/test/invoices_test.dart` 599, `the company's balance from before the app can't drop below what receipts settled of it, or go (BUG-009)`, next to "the company's balance from before the app is owed first". Opening `client_receivable` AED 1,000.00 (100000 fils), receipt AED 1,000.00 with parts `{null: 100000}`; edit to AED 600.00 refused, delete refused, balances unchanged (100000, left 0, credit 0); edit up to AED 1,200.00 allowed (left 20000, credit 0); and `saveErrorText` gives `openingSettled` in `en` and `en_PK`.
- Failing first: the class did not exist yet, so the first run used `throwsA(anything)` in place of `throwsA(isA<OpeningSettled>())`:
  ```
  Expected: throws anything
    Actual: <Instance of 'Future<String>'>
     Which: emitted '3c35721f-5fb3-425a-9d05-02759f612063'
  AED 1,000 received against it would vanish from the credit
  test\invoices_test.dart 603:13
  ```
  With the edit line taken out, the delete line failed the same way (`Actual: <Instance of 'Future<void>'> Which: emitted <null>`), so both paths were open. The typed matcher went back in before the fix.
- After the fix: `invoices_test` 45/45, `records_test` 8/8, `changes_test` 12/12, `rates_test` 5/5, `masters_test` 6/6, `plan_guard_test` 16/16, `invoice_edit_test` 6/6, all passed.
- Left for the owner: no widget test drives the opening balance form itself; the message path is checked through `saveErrorText`, which both the form's save and delete use. The rule only covers `client_receivable`; worker opening balances settled by salary allocations are outside this finding.
- Existing expectations changed: none.

## BUG-011 (F03-6): an unclosed quote in a CSV file swallowed the rest of the file into one cell

- Outcome: REPRODUCED, fixed.
- Root cause: `parseCsv` (`packages/domain/lib/csv.dart`) left `quoted` true to the end of the text and returned what it had, so the one cell held every later line, and nothing said so.
- Fix:
  - `packages/domain/lib/csv.dart` 6-11: new `UnclosedQuote(row)` exception. 27, 49: the row a quote opens on is kept (`row + 1`, the record number the spreadsheet shows, so a quoted line break earlier in the file and blank rows still count right). 60: if the text ends inside quotes, `parseCsv` throws `UnclosedQuote`. Doc 13-16 says so.
  - `apps/mobile/lib/data/import.dart` 132, 138-139: `ImportPlan.unclosedQuoteRow`. 166-171: `planImport` catches `UnclosedQuote` and returns a plan with no lines and that row, so it is not `ready` and `applyImport` refuses it (StateError) as before for a plan that is not ready.
  - `apps/mobile/lib/features/more/import_screen.dart` 154-155: the plan's note says `importUnclosedQuote(row)` before the other notes.
  - Strings: `app_en.arb` 2094-2101 and `app_en_PK.arb` 954 `importUnclosedQuote` (`{row}` int; Roman Urdu says "Line {row}", as `importRow` does there), then `flutter gen-l10n`.
- Callers of `parseCsv`: only `planImport` in the app; the domain tests and `reports_test` call it on good files.
- Tests (failing first, the domain one with `throwsA(anything)` until the class existed):
  - `packages/domain/test/csv_test.dart` 20, `a quote that never closes is refused, naming the row it opened on, instead of swallowing the rest (BUG-011)`: the review's `Code,Name` / `W1,"Ali` / `W2,Bilal` / `W3,Omar` gives `UnclosedQuote` row 2; a CRLF file with a closed quoted line break, a blank row, then `W2,"open` gives row 4. Before the fix:
    ```
    Expected: throws anything
      Actual: <Closure: () => List<({List<String> fields, int row})>>
       Which: returned [(fields: [Code, Name], row: 1), (fields: [W1, Ali
                       W2,Bilal
                       W3,Omar], row: 2)]
    test\csv_test.dart 21:5
    ```
  - `apps/mobile/test/reports_test.dart` 107, `a quote that never closes refuses the file at the row it opened on, so no line takes in the rest (BUG-011)`: the same file through `planImport`; no lines, `unclosedQuoteRow` 2, not ready, `applyImport` throws, workers unchanged. Before the fix:
    ```
    Expected: empty
      Actual: ['W1  Ali\nW2,Bilal\nW3,Omar']
    no worker named Ali and the rest of the file
    ```
    (Only the first assertion and `ready` were there for that run; the `unclosedQuoteRow` check was added with the field.)
  - `apps/mobile/test/reports_test.dart` 251-254, in the existing widget test of the import screen: the bad file chosen again shows `importUnclosedQuote(2)` (an added step; the rest of the test is unchanged).
- After the fix: domain `csv_test` 6/6, `reports_test` 12/12, passed.
- Existing expectations changed: none.

## BUG-028: the statement counted the as-of month's salary on top of an old balance dated that month's last day

- Outcome: REPRODUCED, fixed.
- Root cause: in `statementsFor` (`apps/mobile/lib/data/statement.dart`), the month a monthly salary starts counting from was the earliest of the account's activity, and an old balance gave its as-of month (`brought.keys`). Payroll (`payroll.dart` 218-220, other fixer's BUG-003 change) starts the account the day after the as-of date. So a balance dated 2020-09-30 made the statement add September's salary on top of a balance that already held it, until a month was posted, and the statement and Tankhwah disagreed.
- Fix: `apps/mobile/lib/data/statement.dart` 295-301: the salary-start list takes each worker opening balance as the month of `addDays(asOfDate, 1)`, as payroll does. `brought` itself is untouched, so the balance amount is still placed in its as-of month and shows as the next month's opening; no test needed that to move. A balance dated any day but a month's last keeps its own month, so the existing test with a balance on 2020-09-01 (September still counts its salary) is unchanged and passes. Only worker balances are read there (`openingsOf` holds rows with a worker id, which are `worker_salary_owed` or `worker_advance`, the two kinds `brought` took).
- Test: `apps/mobile/test/statement_test.dart` 174, `a balance dated a month's last day already holds that month's salary, so the next month counts only its own, as payroll does (BUG-028)`. Seed's monthly worker Imran (AED 2,000 from 2020-09-01, one row on 2020-10-05), plus an old salary owed AED 500 dated 2020-09-30. October: opening 50000, salary 200000, closing 250000, and the closing equals `payrollFor('2020-10')`'s `closingFils` for him. Before the fix:
  ```
  Expected: <50000>
    Actual: <250000>
  the old balance alone, with no September salary on top of it
  test\statement_test.dart 177:7
  ```
- After the fix: `statement_test` 18/18. Around it: `payroll_test` 22/22, `salary_payment_test` 27/27, `closing_test` 30/30, `registers_test` 20/20, `auto_cuts_test` 6/6, `visa_test` 9/9, `cash_test` 8/8, `audit_journey_test` 1/1, all passed.
- Existing expectations changed: none.

## Final checks (all four bugs in)

- `apps/mobile`: `flutter analyze`: No issues found.
- `packages/domain`: `dart analyze --fatal-infos`: No issues found. `dart test`: 152 passed.
- Every committed app test file, one process at a time (test/zz_* not run): the files named above, and also `account_flow_test` 27, `account_test` 21, `android_manifest_test` 1, `app_lock_test` 2, `app_shell_test` 6, `backup_test` 5, `cloud_copy_test` 9, `cloud_restore_test` 3 (+1 skipped, as before), `cloud_screens_test` 4, `invoice_paper_test` 9, `licence_test` 17, `plans_test` 8, `recovery_test` 6, `restore_test` 5, `spike_checks_test` 1, `timesheet_paper_test` 19, all passed.
- Not run: `scale_test` (load test, untouched by these changes), `python tools/check_trace.py`, the graph refresh. `PROGRESS.md`, `TASKS.md`, `REQUIREMENTS_TRACEABILITY.md` and `DECISIONS.md` were not edited; none of the four fixes changes scope, price, a payroll formula, a permission, retention or billing rules. They only make the code match rules already written (TEAM-04, INV-05, MASTER-08, D-042).
- Nothing committed or pushed.

## Left for the owner or the auditor

- BUG-009: the guard is in the app's write path (`saveRow`, `deleteRecord`), not a database trigger, so raw SQL or a future writer that skips both could still lower a settled balance. A trigger would need a schema bump and migration (MODEL-08); the review judged it harder for the same reason ("standing" depends on reversals).
- BUG-010: `saveDocumentImage` on a retry points the template at the stored image again under a fresh operation id, so a retry adds one harmless template audit row. `approveEntries` and `postPayroll` return a count that is 0 on a retry. Neither returns a wrong id; left as they are.
- No widget test drives the opening balance form's refusal; the message is checked through `saveErrorText`, which the form's save and delete both use.
