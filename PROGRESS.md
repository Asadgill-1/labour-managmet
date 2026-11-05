# Progress

Read this first each session (AI-04). Replace it, do not append; git holds the history.

**Phase:** P3 started on the owner's word on 2026-11-02, with P2's sign-off and the P1 gate's phone checks (D-035) still open. T14 to T18 are built
**Branch:** `p3/t18-reports` (stacked: ... > p2/t13b > p3/t14 > p3/t15 > p3/t16 > p3/t17 > p3/t18, none merged)
**Next task:** the P3 gate: PDF review, duplicate-billing and numbering tests, and the owner's phone test of T14 to T18. T19 then needs the owner's Supabase project and SMTP. The owner's phone test is still open

## Done

| Task | State | Evidence |
| --- | --- | --- |
| T01, T02, T03 | IMPLEMENTED_UNVERIFIED | CI read for the first time on 2026-10-31, once the repo was public: trace, gitleaks, domain and mobile are green on every branch. The Android job has never run, because it runs only on PRs. The database has never been checked on a phone |
| T04 | OWNER_ACCEPTED | Policy defaults D-101 to D-105 approved 2026-10-31 |
| T05 to T10b, T12a | IMPLEMENTED_UNVERIFIED | CI green. The owner said "Theek hain" on 2026-10-31 to worker groups and the cash book on the phone. The checklist results are not reported yet |
| T11 | IMPLEMENTED_UNVERIFIED | `dart test`: 82 passing. `flutter test`: 73 passing, including PRD examples, a crash during posting, and one full flow through the screens. `flutter analyze` clean. Owner has not seen it, and D-033 and D-034 are waiting for an answer |
| T18 | IMPLEMENTED_UNVERIFIED | `dart test`: 146 passing, with CSV reading and typed dates. `flutter test`: 327 passing, including the Reports tab and each report it opens, company money by how late, work invoiced and still to bill read from the same rows as closing, the owner's sheet keeping VAT, receipts and advances out, and CSV import of workers with rates, companies and sites: preview first, every mistake by row and column, nothing saved while a line is wrong, and a failure part way taking back what was written. On 2026-11-05 the panel, Reports, both new reports, the import screen with mistakes and ready, and the papers were drawn and read by eye. That review moved the import button beside the search, since in the header it covered the menu on a narrow phone, made the preview show each line's trade, dates and rate as they will be saved, stopped work with no company rate reading as invoiced, and counted its days. Backup before an import waits for T20. Not on a phone |
| T17 | IMPLEMENTED_UNVERIFIED | `dart test`: 141 passing, with the PRD's receipt figures. `flutter test`: 318 passing, including an upgrade from schema v14, a receipt for part with credit left over and a retry that changes nothing, every refusal writing nothing, credit received before an invoice and used on it, a receipt undone in the cash book, a credit note on a paid invoice giving the money back as credit, a balance from before the app owed first, an overdue invoice stopping the month until paid or closed as lost and opened again, the company statement reconciling with what is owed less credit, and a receipt recorded from the invoice through the screens. On 2026-11-05 the list, closing, receipt form, a part-paid, overdue and closed invoice, the closing dialog, the company statement, the company screen and the cash book were drawn and read by eye, with the receipt paper and the statement PDF. That review fixed the closing dialog's wrong label, its cut help text and its wrapped button, added the credit to the cash book line, coloured an overdue amount, and stopped a fixed monthly line naming its unit twice. The invoice register no longer fails on a line typed by hand or a credit for an amount, which T16 missed. Not on a phone |
| T16 | IMPLEMENTED_UNVERIFIED | `dart test`: 138 passing, with the PRD's VAT figures. `flutter test`: 307 passing, including upgrades from schema v12 and v13, lines typed by hand, credit notes for an amount then the rest, a month stopped by work changed after it was invoiced (D-051), a draft that reads its timesheets and bills nothing twice, VAT only from the company's own registration, a discount and prices with VAT in, numbers with no gap and a retry that changes nothing, every path to change an issued invoice refused, a credit note that frees the work, a monthly fee charged once, the month stopped by work with no invoice, the invoice register, the whole path from an approved timesheet to an issued invoice and a credit note through the screens, and invoicing at the 1,000-worker size. Screens, the tax invoice, the credit note and a draft drawn and read by eye, and on 2026-11-05 the added line, the credit note sheets, a part credit, the changed-work note and both new papers. That review moved the part-credit totals up the screen and made "1 rows" singular. Not on a phone: "Send with timesheet" uses an Android share of several files that has only been compiled |
| T15 | IMPLEMENTED_UNVERIFIED | `dart test`: 129 passing. `flutter test`: 269 passing, including an upgrade from schema v11, the whole path from a company and dates to an accepted timesheet and a new revision through the screens, no wage or hidden rate in what a company gets, the same work refused twice by the app and the database, a retry of every step, and 5,200 rows at the 1,000-worker size. Screens and papers drawn and read by eye. On 2026-11-04 a Windows build was driven with agent-desktop from an empty app to an accepted R2, a refused second timesheet, a correction after approval, R3, and closing October, with every figure right. It found four faults, now fixed with tests: a picker failure called the file the wrong type, a revision asked for an undo's reason, the corrected-rows note was plural for one row, and a draft went without asking. Not on a phone. The billing calls have no screen until T16 |
| T14 | IMPLEMENTED_UNVERIFIED | `dart test`: 114 passing. `flutter test`: 210 passing, including an upgrade from schema v10, images refused by their bytes, a tall image shrinking whole, issued papers unchanged by a later logo, revisions under one number, a copy from what was stored, triggers refusing any change, and no blank last page. Slip, letterhead, COPY, receipt, pre-printed and register PDFs drawn with the Windows PDF engine and read by eye. Excel read back with openpyxl. Not on a phone, so the Android image picker, preview and print have only been compiled |
| T13c | IMPLEMENTED_UNVERIFIED | The whole app redesigned with Hallmark (D-046). No route or action changed. 20 screens drawn and read by eye. Hallmark's linter reads CSS, so it could not run on Flutter, and the waiver is stamped in `lib/app/theme.dart`. Not on a phone |
| T13b | IMPLEMENTED_UNVERIFIED | `flutter test`: every finding stops a month, each on its date, each clearing, an old payment settled with no figure moving, an upgrade from schema v9, and 1,000 workers. Not on a phone (D-045) |
| T13 | IMPLEMENTED_UNVERIFIED | `dart test`: 114 passing. `flutter test`: 179 passing, including month-close reconciliation, every refused write, a dated reversal, the screen from closing to opening again, an upgrade from schema v8, and closing at 1,000 workers. Closing screen, confirmation and closed state drawn and read by eye. Not yet on a phone |
| T12 | IMPLEMENTED_UNVERIFIED | `dart test`: 112 passing. `flutter test`: 154 passing, including an upgrade from schema v7, the whole path from reminder to payment through the screens, and the reminder at 1,000 workers. Reminder, list, payment form, dialog, cash book and Tankhwah drawn and read by eye. Not yet on a phone |
| T11f | IMPLEMENTED_UNVERIFIED | `dart test`: 102 passing. `flutter test`: 128 passing, including an upgrade from schema v6 and a 1,000-worker month of 26,000 rows. Slip and owner's sheet drawn with the Windows PDF engine and read by eye, Excel read back with openpyxl. Not yet on a phone or in real Excel |
| T11e | IMPLEMENTED_UNVERIFIED | `dart test`: 90 passing. `flutter test`: 107 passing, including an upgrade from schema v5. PDFs drawn with the Windows PDF engine and read by eye, Excel read back with openpyxl. Not yet on the owner's phone |
| T11b, T11c, T11d, T18a | IMPLEMENTED_UNVERIFIED | `flutter test` and `dart test` pass, including PRD-style sums for each register. The owner used these on a phone on 2026-11-01: PDF export works, and the feedback became T11e. PDFs were drawn with the Windows PDF engine and read by eye: 18 pages, no blank last page. Excel was read back with openpyxl. Never opened in real Excel. The Android send, open and save channel has only been compiled, never run |

Test evidence is host only. Encryption on Android, UX-06 timing and BUILD-04 on a real device are all still open.

## Needed from the owner

Details in `docs/owner/P2_CHECKLIST.md`.

1. Encryption check result, and seconds for the 10-worker entry (D-035).
2. An answer on D-033, D-034, D-043, D-044, D-047, D-049, D-050, D-051, D-052 and D-053 after trying Tankhwah, Mahina band, Kaghazat, Timesheet, Invoice, receipts, Reports and CSV import on the phone. A tax adviser should see D-050 and D-051, and an accountant D-052.
3. Run `gh auth login`. The public repo made CI readable, but PRs and merges still need it.
4. Plug the phone in by USB with USB debugging on, so the share of several files can be checked from here. This computer has virtualisation off, so it can't run an emulator.

## Open

- After login: open the stacked PRs in order, confirm the Android job passes on the first PR, merge. Turn on branch protection for `main`, which is off now and is available on public repos (AI-05, D-032).
- `db_check_screen.dart` and `spike_checks.dart` are the T03 proof. Delete both once the phone test passes.
- When a "Jald" section in `lib/app/side_panel.dart` gets built, give it a `Section` value, a screen in `app.dart`, and move it out of the "Jald" row in `docs/SCREEN_FLOW.md`.
- The owner's phone holds real test data, so D-025 no longer applies: schema is now v15, and every change needs a version bump and a migration. `migration_test.dart` upgrades v1 data.
- T21 must gate letterhead uploads, which DOC-02 makes a paid feature, and keep logo and basic identity free. T25 must give each device its own paper numbers, and carry images and stored files itself, since the audit log and outbox leave the bytes out on purpose (D-047). T20's backup holds them, because they sit in the database.
- Issued papers sit in the database for good. A slip is about 60 KB, so a thousand workers' slips for a year would be about 700 MB if every one were issued. Measure on a phone before pilots.
- A register's date line can sit alone at the foot of a page, with its rows on the next. A table row can't be told to stay with the next one. Split tables by date if owners mind.
- An invoice or receipt paper is English whatever the app's language (D-050, D-052). A timesheet sent with it still follows the app's language.
- What companies owe is read from all their history each time, which is a few thousand rows over years. Keep running totals if a phone shows lag. Not measured at scale yet.
- A refund of a company's credit, a receipt in another currency, and a reminder before an invoice falls due are not built (D-052). Add when owners ask.
- CSV import brings in workers, companies and sites only. Opening balances, company rates and attendance by file, and undoing an import, are not built (D-053). A backup prompt before an import waits for T20.
- The owner's sheet bills from attendance at company rates, not from invoices. Whether to read invoices instead is in D-053 for the owner and an accountant.
- Statement rows written within one second sort in the order they were read, since times are stored to the second. Only the balance at the end is certain then.
- "Send with timesheet" uses an Android share of several files, which has only been compiled. Check it on the phone first.
- `billed_allocations.invoice_id` still has no foreign key, since adding one rebuilds the table and its triggers. Issuing is the only writer.
- T25 must give Team tenants invoice numbers from the server (INV-08), as it must for papers and timesheets.
- Work changed after it was invoiced is put right by a whole credit note and a new invoice (D-051). A credit note or invoice for the difference alone is not built. Add it if owners or the tax adviser ask.
- T25 must give each device its own timesheet numbers, as it must for papers. An approved timesheet's lines go in one outbox row, which reaches megabytes at thousands of rows.
- A timesheet paper over 5,000 rows warns it will be slow, and over 30,000 is refused, as registers are. Measure the detail paper on a phone. A timesheet has no Excel, since TS-07 asks for a PDF. Add it if owners ask.
- A paper keeps the letterhead it was first issued with, for that revision. If owners want a new look on an accepted timesheet without a revision, that needs a rule (D-049).
- T24 must hold rows a manager enters until the owner sees them. D-041 made posting the only approval, which is right for one owner only. T15 must approve rows it links, since rows can now reach billing before payroll.
- Tankhwah's "To pay" still ignores an advance until a recovery is added, by choice (D-043), and the slip counts it when given. The worker's screen shows both, and one button adds the recoveries.
- Undoing a salary line that overpaid leaves its advance line, which is undone by hand. Link the two if owners trip on it.
- A monthly worker with no attendance, payment or posted month shows on the unpaid list only once a month is posted, because a contract's start date must not run up pay nobody recorded (D-042). Tankhwah still lists them each month.
- The unpaid list adds up every worker on each change. It is fast on this laptop at 1,000 workers and has not been measured on a phone. Debounce it if a phone shows lag.
- A 26,000-row PDF took 1.2 GB and 90 seconds on this laptop, so a phone may run out of memory below the 30,000-row limit. Measure on a phone. Excel is fine at that size.
- Slips go one worker at a time, as DOC-07 asks. WhatsApp still asks for the contact each time. Opening a worker's chat from their stored number needs an unofficial WhatsApp extra, so it waits until asked.
- A closed month's attendance has no correction of its own: the difference goes in an open month as an allowance or deduction, or the month is opened again. A credit note and a new invoice cover a bill that changes. Company receipts with no invoice are not checked at closing until T17. T24 must keep closing and opening with the owner.
- Unpaid wages do not stop a month closing, because they carry forward (D-045). The owner confirmed this on 2026-11-02 and added the invoice rule in D-048.
- T17 must allocate `clientReceipt` rows to invoices (INV-05). T18 takes wage expense from posted lines, never from payments (REP-02).
- A client company that pays for a visa and cuts it from an invoice is not covered. Visa money runs against the worker only (D-039). Add to invoices if the owner says that happens.
- PDFs use Roboto, which has Latin letters only, so a name typed in Urdu or Arabic script prints as boxes. Margin reports and CSV import are still T18.
- Rozana hisaab has no running cash-in-hand figure, because no opening cash exists yet. Group wages have no overtime. Payroll periods are calendar months only, though the tables store from and to. Add when asked.
- UX-02 is local only until T19 adds accounts. UX-07's sync statuses arrive with T25.
- Worker lists sort by plain text, so "Worker 10" comes before "Worker 2". Real names are fine; revisit if codes are shown as the sort key.

## Known risks

- E-invoicing, see `DECISIONS.md` D-011.
- The repo is public (D-032). A secret pushed here is exposed at once, so from P4 on, Supabase keys, the keystore and SMTP passwords stay in `.env` and out of git. Gitleaks runs on every push, but only after the push.
- Disk is about 95% full with 14 GB free, after VS Build Tools went on for the Windows test build. Docker for P4 needs more, so free space before then.
- Release APK builds take 3 to 11 minutes here, depending on the Gradle cache. Use debug builds while developing.
- The P1 release build warned that `CupertinoIcons` has no bundled font. No screen reviewed so far shows one. Check on the phone test.

## Lessons

- In a widget test, database work must run on the real clock (`real()` in `test/support.dart`), or the test hangs.
- Never chain a commit after a test run in one command unless it is gated on the result. It happened once in T06.
- Forms must not sit in a lazy list. Off-screen fields skip validation. Use `FormBody`.
- A `ListTile` with `selected: true` paints `selectedTileColor`, not `tileColor`. Golden PNGs caught the panel's active item being invisible, which every widget test missed. Review new screens as images (load real fonts with `FontLoader`, or text shows as blocks).
- A tile's white background is painted on the Material behind the list. A row that grows after first paint keeps the old background height until something scrolls. Wrap such rows in `GrowingRow`.
- Render a PDF on this machine with the Windows PDF engine: `Windows.Data.Pdf.PdfDocument` from PowerShell 5.1, through `AsTask`. Edge headless and the browser pane both failed. Python's `/tmp` is not Git Bash's `/tmp`: use `cygpath -w`.
- A failed widget test that leaves its database open makes `flutter test` hang for minutes, and `flutter_tester` keeps `sqlite3mc.dll` locked. Stop it before the next run.
- A closure reading a text field at build time missed what was just typed. Read a field when the button is pressed. The flow test found it.
- A lazy list only builds what is on screen, so actions under thousands of rows are out of reach. The next step goes above the rows. Drawing the screens found it.
- Never `git add -A` while review images sit in `test/zz`. It happened once on an unpushed commit, and they are ignored now.
- A square image at full width left no room for rows and the PDF engine gave up at 5,000 pages. Anything an owner uploads into a header needs a height limit. A test found it.
- Colours are read from `brand`, `action` and friends while widgets build, so they can't sit in a `const`. `usePalette` marks every element for a rebuild after a change, which reaches `const` screens too. A test covers it.
- A `pw.Table` clips each cell, so text can't run across columns even with an overflowing `Stack`. It also breaks a heading word when a column is narrow, so draw a PDF and look at it after changing column widths.
- `partial_method` holds a `PartialMethod` name such as `calendarDays`. The old comment on the column said `calendar_days`, and a test had copied it.
- A Windows build can be driven with agent-desktop, but Flutter on Windows exposes MSAA only, so agent-desktop sees an empty view. `apps/mobile/windows/` (local, in `.git/info/exclude`) holds the runner and a headed driver that finds widgets through MSAA. It can't type punctuation, and Flutter ignores a synthesized ctrl+a or ctrl+v. `analysis_options.yaml` excludes `windows/**`, since the Flutter tool adds it back whenever that folder exists. It found four faults the widget tests missed.
- A shared dialog took its field label for granted: `askReason` said "undo" on a new revision and on reopening a month. A helper used for more than one job takes its words from the caller.
- A test that walks the side panel can find the sub-tab it wants below the fold once more main tabs are open. `goTo` scrolls to it and pumps a frame before tapping, or the tap lands on the old spot.
- A capture test froze for five minutes when it wrote to the database a screen was watching. Draw papers from a database of their own.
- A rule that stops a month reaches every test that closes one. D-048 (3) needed `invoiceUpTo` in `test/support.dart`.
- Never run the bare `graphify update` CLI on this repo. See `CLAUDE.md`. Refresh the graph after every task, as the owner asked on 2026-10-31. Current graph: 3,771 nodes, 5,883 edges, 130 communities, including all 278 PRD nodes and 166 requirements. Repo docs other than the PRD have no semantic extraction yet.
