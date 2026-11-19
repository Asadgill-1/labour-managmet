# Review 03: billing data layer

## Files read in full

- `docs/DATA_MODEL.md` (the tables and the "Constraints in the database" table), `docs/CALCULATION_SPEC.md` (units, VAT and receivables, fixtures), `DECISIONS.md` rows D-011, D-021, D-047 to D-059.
- `apps/mobile/lib/data/tenant_database.dart` (479 lines).
- `apps/mobile/lib/data/triggers.drift` (334 lines).
- `apps/mobile/lib/data/tables.dart` (701 lines).
- `apps/mobile/lib/data/timesheets.dart` (847 lines).
- `apps/mobile/lib/data/invoices.dart` (957 lines).
- `apps/mobile/lib/data/receipts.dart` (317 lines).
- `apps/mobile/lib/data/documents.dart` (278 lines).
- `apps/mobile/lib/data/changes.dart` (493 lines).
- `apps/mobile/lib/data/import.dart` (409 lines).
- `packages/domain/lib/invoice.dart`, `packages/domain/lib/timesheet.dart`, `packages/domain/lib/csv.dart`, `packages/domain/lib/statement.dart`, and `packages/domain/lib/money.dart` (the working-tree copy, which limits `parseAed` to 13 digits).
- Read for context, in part: `apps/mobile/lib/data/attendance.dart` (`correctEntry`, lines 305-342), `apps/mobile/lib/data/closing.dart` (lines 120-159), `apps/mobile/lib/data/restore.dart` (`lastNumbers`, `recordRestore`), `apps/mobile/lib/features/registers/register_defs.dart` (`_statement`, lines 1099-1195), `apps/mobile/lib/features/rates/contract_form_screen.dart`, `apps/mobile/lib/features/rates/opening_balance_form_screen.dart`, `apps/mobile/lib/features/today/row_editor_screen.dart`, `apps/mobile/test/drift/tenant/migration_test.dart` (lines 1-120 and the test list), `apps/mobile/test/invoices_test.dart` (the test list and lines 316-339).

## Files not fully read

- `apps/mobile/lib/data/tenant_database.steps.dart`: generated. I did not read it line by line. Instead I relied on `migration_test.dart`, which runs `migrateAndValidate` from every old version and compares the result with the v19 snapshot, tables, indexes and triggers included.
- `apps/mobile/test/` files `timesheets_test`, `invoice_edit_test`, `documents_test`, `changes_test`, `records_test`, `reports_test` and `write_path_test`: I searched them for the cases behind each finding but did not read them in full. Where I say a case is untested, I mean that a search for its inputs found nothing.

## Rules checked

| Rule | Source | Enforced where | Test | Verdict |
| --- | --- | --- | --- | --- |
| Worker code unique in tenant | DATA_MODEL constraints | `tables.dart:87` `UNIQUE (tenant_id, code)`. The import also refuses a code that is already in the app, or twice in the file, ignoring case and spacing (`import.dart:211-212`) | reports_test (import) | SOUND |
| Invoice number unique, null while a draft | DATA_MODEL, INV-08 | `tables.dart:370` `UNIQUE (tenant_id, kind, year, seq)`. `_nextSeq` runs inside the issuing transaction (`invoices.dart:631`, `662`) | invoices_test "numbers run by year with no gap" | SOUND |
| Several credit notes per invoice, capped by its total | D-051, INV-06 | `creditInvoice` refuses `taken > left` (`invoices.dart:758`). v14 dropped `one_credit_note` | invoices_test lines 316-339 | DEFECT, see F03-2 (once credits reach the total, a whole credit is impossible) |
| Duplicate operation rejected | D-021 | Outbox primary key, checked first in `_applyOnce` (`tenant_database.dart:346`) | write_path_test | SOUND for stored data. See F03-5 for the ids that are returned |
| Plan refusal leaves nothing behind | D-074 | `guard` is called inside the transaction, after the retry check (`tenant_database.dart:349`) | plan_guard_test | SOUND |
| Break within shift | DATA_MODEL | `CHECK (break_minutes <= clock_minutes)` plus `>= 0` checks on both columns (`tables.dart:539-540`, `582`) | not checked | SOUND |
| Same work on one live timesheet | TS-05, D-049 | `one_live_timesheet_line` (`triggers.drift:270`). `work_key` is the root of the correction chain (`timesheets.dart:171-177`). The chain cannot leave the date, company or site range, because `correctEntry` copies all three (`attendance.dart:330-333`) | timesheets_test | SOUND |
| Same work not billed twice | TS-05 | `one_live_billing` (`triggers.drift:288`), plus the clash check in `allocateBilling` | timesheets_test, invoices_test | SOUND for hourly, daily and shift work. DEFECT for fixed monthly fees, see F03-1 and F03-3 |
| Allocation within outstanding | INV-05 | `addClientReceipt` (`receipts.dart:181`), `useClientCredit` (capped at what is left), `_lost` | invoices_test lines 521-531 | SOUND at write time. DEFECT when the opening balance changes later, see F03-4 |
| Posted rows immutable: invoices, invoice lines, timesheet lines, billed and invoice allocations | DATA_MODEL, INV-06 | `invoice_keeps_issue`, `invoice_status_forward`, `invoice_no_delete`, `invoice_line_no_edit/no_delete`, `timesheet_line_no_edit/stays_off/no_delete`, `billing_no_edit/stays_released/no_delete`, `invoice_allocation_no_update/no_delete` | invoices_test "an issued invoice never changes, by any path" | SOUND. `invoice_keeps_issue` does not name `id`, `tenant_id`, `actor_id` or `source_operation_id`, but no code path writes those on an issued row |
| A closed month stays as it was | REP-04 | `closed_*` triggers on cash, attendance, payroll items and lines, opening balances and day offs. `closed_entry_no_edit` names only NOT NULL columns with `<>` and nullable ones with `IS NOT`, so NULL does not open a hole | closing_test, migration_test | SOUND |
| Issued paper never changes | DOC-05, D-047 | `issued_no_edit`, `issued_no_delete`, `asset_no_edit`, `asset_no_delete`. `UNIQUE (tenant_id, kind, year, seq, revision)` | migration_test v10 | SOUND |
| Number floors after a restore | DATA-06, D-070 | `nextNumber` takes the higher of the series top and the floor. Series names agree between `lastNumbers` (`restore.dart:65-68`) and the callers ('invoice', 'credit', 'timesheet', `DocKind.name`) | migration_test v18, restore_test | SOUND |
| VAT exclusive: `vat = divRoundHalfUp(net * bps, 10000)` | CALCULATION_SPEC | `lineTax` (`invoice.dart:33`). Worked example: 1,100.00 at 500 bps gives 110000 × 500 / 10000 = 5500 fils, so VAT 55 and total 1,155 | invoices_test line 121 | SOUND |
| VAT inclusive: `net = divRoundHalfUp(gross * 10000, 10000 + bps)` | CALCULATION_SPEC | `lineTax` (`invoice.dart:34-35`). Worked example: 105.00 gives 10500 × 10000 / 10500 = 10000, so net 100 and VAT 5 | invoices_test line 156 | SOUND |
| Zero-rated, exempt and out of scope charge nothing, and only standard and zero-rated print "Tax Invoice" | INV-03, D-050 (4) | `vatBpsOf`, `isTaxInvoice` | invoices_test line 144 | SOUND |
| A discount comes off before VAT, and one above its line is refused | D-050 (3) | `lineTax(amount, discountFils: …)`. `issueInvoice` refuses `discount > amount` (`invoices.dart:653`). Worked example: 1,000 with discount 100 at 5% gives net 900 and VAT 45 | invoices_test line 166 | SOUND |
| Document total is the sum of the lines | D-101 | `invoiceTotals` | invoices_test | SOUND |
| VAT from the supplier's registration, never the customer's TRN | INV-03 | `vatRegisteredOn` in `_partiesToday` | invoices_test lines 111 and 137 | SOUND |
| A fixed monthly fee is charged once a month; a month billed in parts charges what is left | D-054 (1), D-059, CALC-05 | `feeCover`, `feeDone`, `feesCharged`, `fixedFeeCharges`, `_draftLines` | invoices_test lines 390-463 | DEFECT, see F03-1 and F03-3 |
| Work changed after invoicing stops the month until a whole credit and a new invoice | D-051 (3) | `billedWorkChanged`, `billingChanges`, used by closing (`closing.dart:145-157`) | invoices_test lines 592 and 650 | SOUND, apart from the dead end in F03-2 |
| A credit note on a paid invoice gives the money back as credit | D-052 (6) | `releaseOverpaid` (`receipts.dart:270`), lost amounts first and then the newest receipt | invoices_test line 549 | SOUND |
| A receipt undone in the cash book takes its shares with it | D-052 (3) | `receivables` counts only receipts still standing (`receipts.dart:81-86`) | invoices_test line 540 | SOUND |
| Closed as lost, and opened again | D-048 (2) | `_lost` writes `+left` or `-lost` | invoices_test line 621 | SOUND |
| The company statement reconciles with what is owed less unused credit | D-052 (7) | `_statement` in `register_defs.dart`. The algebra holds: opening + invoiced − credited − received − lost equals the sum of `leftFils` + opening left − credit | invoices_test line 742 | SOUND, except after F03-4 |
| No wage reaches what a client company receives | TS-02, D-049 (8) | `TimesheetLines`, `TsLine`, `InvoiceLines` and the revision adjustments have no wage column. Approval's outbox payload holds only the revision and its lines | timesheets_test | SOUND |
| A revision keeps the original | TS-06 | `approveTimesheet` sets the old lines' `live` to false and inserts new ones. Triggers keep the old ones | timesheets_test | SOUND |
| Import is all or nothing | MASTER-08, D-053 (4) | `applyImport` runs one transaction. `ready` requires every line to be right | reports_test | SOUND. See F03-6 for the parser |
| Delete only when nothing names the record | D-056 (6) | `_inUse` through `PRAGMA foreign_key_list` (`changes.dart:297`) | changes_test | SOUND for masters. DEFECT for opening balances, which no foreign key names, see F03-4 |
| A closed month opens on an edit | D-056 (4) | `openMonthsFrom` inside the edit's own transaction (`changes.dart:340`, `355`, `385`, `410`, `429`) | changes_test | SOUND |

## Writes outside applyOperation

I searched all of `apps/mobile/lib` for `into(`, `update(`, `delete(`, `customStatement`, `batch(`, `insertReturning`, `customUpdate` and `customInsert`, excluding generated files. Every table write in `data/attendance.dart`, `cash.dart`, `closing.dart`, `masters.dart`, `payroll.dart`, `statement.dart`, `restore.dart`, `timesheets.dart`, `invoices.dart`, `receipts.dart`, `documents.dart` and `changes.dart` sits inside a `change:` closure. `_storeLines` (`invoices.dart:688`) and `_allocate` (`receipts.dart:138`) are helpers, and they are only called from inside a `change:` closure. The remaining hits are listed below.

| Path:line | What it writes | Verdict |
| --- | --- | --- |
| `data/tenant_database.dart:269` | `PRAGMA foreign_keys = ON` in `beforeOpen` | Configuration, not data. Fine |
| `data/tenant_database.dart:354`, `369` | The audit event and the outbox row | These are the write path itself. Fine |
| `data/tenant_database.dart:107-266` | The migration steps | Schema only. Fine |
| `data/backup.dart:79-86` | `VACUUM INTO`, `ATTACH`, and a rekey of the copy | They write only to the outgoing copy, never to the company's tables. Fine |
| `spike_checks.dart:25`, `30` | A `spike` table in a test database | A spike tool, not app data. Fine |
| `storage.delete` and `File.delete` calls in `account.dart`, `app_lock.dart`, `restore.dart`, `recovery.dart`, `tenant_database.dart`, `features/...` | Secure storage and files | Not database writes. Fine |

Retry after a partial failure: `_applyOnce` runs the retry check, the guard, the change, the audit event and the outbox row in one drift transaction. A failure anywhere rolls all of it back, so a retry with the same operation id runs again from the start, and a retry after success returns at line 347. Nested calls (`approveEntries` in `approveTimesheet`, `allocateBilling` in `issueInvoice`, `creditInvoice` in `editInvoice`, `releaseBilling` in `creditInvoice`) use fresh ids, but they run inside the outer transaction, so the outer id guards them. The data is never written twice. What a retry returns to its caller is not always right, see F03-5.

## Findings

### F03-1: Two fixed monthly contracts of one company share one fee, so the second site's fee is never billed and closing counts it as settled
- Severity: High
- Status: CONFIRMED (traced through the code; not run)
- Where: `apps/mobile/lib/data/timesheets.dart:66-67` `feeCover`; `apps/mobile/lib/data/invoices.dart:323` (the draft line key) and `:338-343` (`earlier` and `rest`); `timesheets.dart:699-702` `feesCharged`; `invoices.dart:931` `workCharges`.
- Expected: CALC-05 says a fixed fee is "one fee for the contract". A billing contract can be scoped to a site (`BillingContracts.siteId`, and the contract form offers a site for every basis, including `monthFixed`). Each contract's fee should therefore be charged for its own month. D-054 (1) says "a fixed fee once" per company, but it was written with one contract per company in mind, so this needs the owner's word.
- Actual: The fee's cover is `clientId|monthFixed|YYYY-MM`. It carries no contract, no site and no rate. The draft line key is `fee|basis|rate|month`, which also has no site. Both feed the "already charged" sum.
- Reproduction with numbers:
  - Case A, one invoice. Company C has site A and site B, each with a `monthFixed` contract at AED 5,000. October work is approved on one timesheet, and an invoice is drafted for 1-31 October across all sites. Both sites' rows fall under the key `fee|monthFixed|500000|2026-10`, so the invoice has one line of AED 5,000 instead of AED 10,000. After issuing, every row of both sites is allocated and counts as billed.
  - Case B, separate invoices. Site A is AED 5,000 and site B is AED 3,000. An invoice for site A alone charges 5,000, with `fee_month` 2026-10. Then `feesCharged()['C|monthFixed|2026-10']` is 500000. For site B's rows, `feeDone(fees, cover, 300000)` is true, so `billableLines` marks them `BillHold.billed`. An invoice for site B is refused with `nothingToBill`, `workCharges` marks the rows settled, and `uninvoicedWork` does not stop the month. AED 3,000 is lost with no warning anywhere.
  - Regression test: `apps/mobile/test/invoices_test.dart`, in the monthly contract group. The existing tests use one fixed contract per company (`invoices_test.dart:381`), so they would still pass with this rule broken.
- Proposed minimal fix: Add the site to the fee's identity in three places: `feeCover` (pass `line.siteId`), the draft key, and `fixedFeeCharges` (read the site from the invoice line's timesheet line, or store `site_id` beside `fee_month`). Note that a contract with no site that covers every site would then be charged once per site, which is also wrong. The robust key is the billing contract id, which attendance rows do not store today. Regression risk: medium. It changes how months already invoiced count, so old lines with no site need a rule such as "a line issued before counts for every site of that month", tested like the v17 migration test.

### F03-2: Once credit notes for amounts reach the invoice's total, the invoice can never be credited whole, so its work stays charged and a changed-work hold can never clear
- Severity: Medium
- Status: CONFIRMED (traced; not run)
- Where: `apps/mobile/lib/data/invoices.dart:750-758` `creditInvoice`; `editInvoice` (`:822`) goes through the same path.
- Expected: D-051 (2) says "a whole credit note after them takes back only what they left, as one line, and then frees the work". D-051 (3) says the only fix for changed work is a whole credit note and a new invoice.
- Actual: An amount credit equal to everything left is allowed (`taken > left.totalFils` is false when the two are equal). Afterwards `left` is 0 net and 0 VAT, so a whole credit builds `single(left)` with `taken == 0`, which `taken <= 0` refuses as `creditTooBig`. The invoice stays `issued`, `releaseBilling` never runs, and the billed allocations stay live.
- Reproduction with numbers: Take the invoice from `invoices_test.dart:316`: net 10,500 fils + VAT 525 = 11,025 fils. Issue `creditInvoice(id, amountFils: 10500)`; VAT 525 makes `taken` 11,025, which equals `left`, so it is accepted. Now `creditInvoice(id, reason: 'Cancelled')` and `editInvoice(id, …)` both throw `InvoiceRefused(creditTooBig)`. `unbilledLines(sheet)` stays empty forever. If that work's attendance is then corrected, `billingChanges` reports `invoiceOutOfDate` (`closing.dart:153-157`), and there is no step that clears it, so the month cannot close until the attendance is put back. Regression test: `invoices_test.dart`, next to the test at line 316.
- Proposed minimal fix: Either refuse an amount credit that takes everything left (tell the owner to use a whole credit), or let a whole credit with nothing left proceed with no line (zero value), setting the status to `credited` and releasing the billing. The first option is one condition (`taken >= left.totalFils` when `amountFils != null`) and has low regression risk. The second writes a zero-value tax document, which a tax adviser would need to accept.

### F03-3: A fixed monthly contract whose rate changes inside a month is charged in full at both rates on one invoice
- Severity: Medium
- Status: CONFIRMED (traced; not run). Related to D-059's stated limitation for a contract that ends mid-month, but this case is not the same.
- Where: `apps/mobile/lib/data/invoices.dart:323` (the key includes `rateFils`), `:338-344`.
- Expected: CALC-05 says one fee for the contract, never multiplied. D-059 says each new invoice starts at the month's amount less what live invoices already charged for that month.
- Actual: Rows of the same month at two fixed rates make two keys. `earlier` only counts invoices that are already issued, so each line's `rest` is its own whole rate.
- Reproduction with numbers: A `monthFixed` contract at AED 5,000 effective 2026-01-01, replaced by AED 6,000 effective 2026-10-16. October rows on 10-05 (rate 500000) and 10-20 (rate 600000) are approved. A draft for 1-31 October has two fee lines, 5,000 and 6,000, both with `fee_month` 2026-10, so it charges AED 11,000 for one month. The owner can type a lower figure, but the default is wrong and gives no warning. Regression test: `invoices_test.dart`, in the monthly group.
- Proposed minimal fix: For `monthFixed`, key the draft line by month alone and take the rate from the latest row, or show one line per rate but subtract the earlier lines of the same draft and month when working out `rest`. Regression risk: low, limited to `_draftLines`.

### F03-4: A company's balance from before the app can be lowered or deleted after receipts settled it, and the money received disappears from the company's credit
- Severity: Medium
- Status: CONFIRMED (traced; not run)
- Where: `apps/mobile/lib/data/changes.dart:297-310` `_inUse` (nothing has a foreign key to `opening_balances`, so it is never "in use"); `features/rates/opening_balance_form_screen.dart:49-70` (`saveRow` and `deleteRecord` with no check); `apps/mobile/lib/data/receipts.dart:124-125`.
- Expected: INV-05 and D-052 (1) and (3) say what a receipt settled never changes, and whatever is left over waits as the company's credit. REP-08 says the statement reconciles with what is owed less unused credit.
- Actual: The allocation rows on the opening balance (`invoice_id` NULL) stay, while the amount they settled shrinks or goes. `openingLeftFils` turns negative or disappears, `openOf` hides it, and the receipt's `unusedFils` stays at 0.
- Reproduction with numbers: Opening `client_receivable` AED 1,000. A receipt of AED 1,000 is entered with parts `{null: 100000}`. The owner then edits the opening balance to AED 600, or deletes it. Now `openingLeftFils` is −400 (or the company has no entry), and `creditOf` is 0. The statement balance is 600 − 1,000 = −400, which prints "company credit AED 400", while the invoice screen offers no credit to use, and a new invoice for that company shows AED 400 too much owed. Regression test: `invoices_test.dart`, next to "the company's balance from before the app is owed first" (line 566).
- Proposed minimal fix: In `saveRow` and `deleteRecord` for a `client_receivable` opening balance, refuse an amount below what standing receipts and closings set against it (the sum of `parts` with `invoiceId == null` for that client from `receivables`). A trigger is harder, because "standing" depends on reversals. Regression risk: low.

### F03-5: A retry with the same operation id returns an id that was never stored
- Severity: Low
- Status: CONFIRMED (traced; not run)
- Where: `invoices.dart:575` `createInvoice`, `:722` `creditInvoice`, `:812` `editInvoice`; `timesheets.dart:280` `createTimesheet`, `:490` `startTimesheetRevision`; `receipts.dart:171` `addClientReceipt`; `documents.dart:83` `_keepImage`, which `saveDocumentImage` (`:70-74`) uses.
- Expected: TEAM-04 and UX-07 say a retry after a crash or double tap changes nothing and acts like the first call.
- Actual: Each method makes `newUuid()` before `applyOperation`. On a retry, `_applyOnce` returns early without writing, and the method returns the new id, which does not exist. `saveDocumentImage` then points the template at that missing asset, which fails on the foreign key, so the retry shows an error even though the first call succeeded.
- Reproduction: Call `createInvoice(…, operationId: X)` twice. The second call returns an id for which `invoiceView` throws "no element". `invoices_screen.dart:123` and `timesheets_screen.dart:105` keep one operation id per form, so a second tap on that form is exactly this case. Regression test: `write_path_test.dart`.
- Proposed minimal fix: On a retry, read the record id from the outbox row (`seen.recordId`), for example by having `applyOperation` return it, and return that. Regression risk: low.

### F03-6: An unclosed quote in a CSV file silently swallows the rest of the file into one cell
- Severity: Low
- Status: CONFIRMED (traced; not run)
- Where: `packages/domain/lib/csv.dart:27-50` `parseCsv`.
- Expected: MASTER-08 and D-053 (4) say every line shows with its row number and what is wrong with it.
- Actual: A quote that opens and never closes keeps `quoted` true to the end of the file, and the parser reports nothing about it.
- Reproduction with numbers: A workers file reads `Code,Name` / `W1,"Ali` / `W2,Bilal` / `W3,Omar`. The parser gives one data row with name `Ali\nW2,Bilal\nW3,Omar`. The plan is `ready` with one line, and saving it creates one worker with a three-line name while W2 and W3 are dropped. The preview shows the title, so a careful owner may notice. Regression test: `reports_test.dart`, next to the `parseCsv` tests.
- Proposed minimal fix: Return a flag from `parseCsv` when the file ends inside quotes, and have `planImport` refuse the file with a problem on that row. Regression risk: low.

### F03-7: A correction does not check that the row it corrects is still current, so a stale row can fork its correction chain
- Severity: Low
- Status: SUSPECTED
- Where: `apps/mobile/lib/data/changes.dart:353-379` `editAttendance` and `:383-405` `deleteAttendance` use the caller's `old` object; `apps/mobile/lib/data/attendance.dart:324-337` `correctEntry` neither re-reads `old` nor checks `superseded`.
- Expected: ATT-08 and TS-05 say a correction makes one new row and the original is only flagged, so one piece of work has one row standing.
- Actual: If `old` has already been superseded, a second correction of it is written as well. That leaves two rows standing for one `work_key`. `workCharges` counts both, and a timesheet draft that holds both fails at approval on `one_live_timesheet_line`, with a database error instead of a message.
- What I could not establish: `row_editor_screen.dart` writes once after the editor closes and gets the row from a stream, so I found no path in the UI today that passes a stale row. `carryAgreedToAttendance` re-reads its row, and its outer transaction rolls a fork back through `getSingle()`. The defence therefore rests on the callers.
- Proposed minimal fix: Inside `correctEntry`'s `change`, re-read `old` and throw if `superseded` is true. Regression risk: low. Regression test: `changes_test.dart`.

## Missing versus spec

- A credit note or invoice for only the difference is not built, by decision (D-051 (3)).
- A refund of a company's credit, a receipt in another currency, and reminders before a due date are not built, by decision (D-052 (9)).
- Importing opening balances, company rates or attendance, and undoing an import, are not built (D-053 (7)).
- Numbers are counted on one phone. T25 must give each device its own series (D-047 (8), and the `ponytail` notes at `invoices.dart:281` and `documents.dart:44`).
- `issueDocument` works out its sequence number and renders the PDF before its transaction (`documents.dart:202-214`). Two papers of the same kind issued at the same moment would collide on the unique key, so one would fail rather than be duplicated. MODEL-07 puts rendering after the record, so this ordering is a choice, not a defect. I noted it only because the failure would show as a database error.

## Known-deferred noticed

- T25 server-issued numbers for Team, and T25 carrying images and files apart from the outbox (D-047 (4) and (8)).
- E-invoicing provider integration (D-011). The PDFs say they are not UAE e-invoices.
- `receivables()` adds up a company's whole history each time (the `ponytail` note at `receipts.dart:75`).
- A contract that ends mid-month still starts the second invoice at the whole rest, which the owner lowers by hand (D-059, told to the owner). F03-3 is a different case: it doubles the fee within one invoice.
