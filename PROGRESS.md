# Progress

Read this first each session (AI-04). Replace it, do not append; git holds the history.

**Phase:** P2. The owner's requests of 2026-10-31 and 2026-11-01 (D-036 to D-041) are built. D-041 came from the owner's first phone test. The P1 gate's phone checks are still open (D-035)
**Branch:** `p2/t11e-phone-feedback` (stacked: ... > p2/t11 > p2/t11b > p2/t11c > p2/t18a > p2/t11d > p2/t11e, none merged)
**Next task:** Owner's phone test of T11e and what is left of T11b, T11c, T11d and T18a, then T12

## Done

| Task | State | Evidence |
| --- | --- | --- |
| T01, T02, T03 | IMPLEMENTED_UNVERIFIED | CI read for the first time on 2026-10-31, once the repo was public: trace, gitleaks, domain and mobile are green on every branch. The Android job has never run, because it runs only on PRs. The database has never been checked on a phone |
| T04 | OWNER_ACCEPTED | Policy defaults D-101 to D-105 approved 2026-10-31 |
| T05 to T10b, T12a | IMPLEMENTED_UNVERIFIED | CI green. The owner said "Theek hain" on 2026-10-31 to worker groups and the cash book on the phone. The checklist results are not reported yet |
| T11 | IMPLEMENTED_UNVERIFIED | `dart test`: 82 passing. `flutter test`: 73 passing, including PRD examples, a crash during posting, and one full flow through the screens. `flutter analyze` clean. Owner has not seen it, and D-033 and D-034 are waiting for an answer |
| T11e | IMPLEMENTED_UNVERIFIED | `dart test`: 90 passing. `flutter test`: 107 passing, including an upgrade from schema v5. PDFs drawn with the Windows PDF engine and read by eye, Excel read back with openpyxl. Not yet on the owner's phone |
| T11b, T11c, T11d, T18a | IMPLEMENTED_UNVERIFIED | `flutter test` and `dart test` pass, including PRD-style sums for each register. The owner used these on a phone on 2026-11-01: PDF export works, and the feedback became T11e. PDFs were drawn with the Windows PDF engine and read by eye: 18 pages, no blank last page. Excel was read back with openpyxl. Never opened in real Excel. The Android send, open and save channel has only been compiled, never run |

Test evidence is host only. Encryption on Android, UX-06 timing and BUILD-04 on a real device are all still open.

## Needed from the owner

Details in `docs/owner/P2_CHECKLIST.md`.

1. Encryption check result, and seconds for the 10-worker entry (D-035).
2. An answer on D-033 and D-034 after trying Tankhwah on the phone.
3. Run `gh auth login`. The public repo made CI readable, but PRs and merges still need it.

## Open

- After login: open the stacked PRs in order, confirm the Android job passes on the first PR, merge. Turn on branch protection for `main`, which is off now and is available on public repos (AI-05, D-032).
- `db_check_screen.dart` and `spike_checks.dart` are the T03 proof. Delete both once the phone test passes.
- When a "Jald" section in `lib/app/side_panel.dart` gets built, give it a `Section` value, a screen in `app.dart`, and move it out of the "Jald" row in `docs/SCREEN_FLOW.md`.
- The owner's phone holds real test data, so D-025 no longer applies: schema is now v6, and every change needs a version bump and a migration. `migration_test.dart` upgrades v1 data.
- T24 must hold rows a manager enters until the owner sees them. D-041 made posting the only approval, which is right for one owner only. T15 must approve rows it links, since rows can now reach billing before payroll.
- T12 must let the owner choose which month a payment settles, defaulting oldest first (PAY-06), turn an overpayment into an advance, since a credit only shows as "Zyada ada kiya" for now, and add overdue alerts (PAY-08). Oldest-first needs no new figures on posted lines.
- T13 must turn `reverseCashEntry` and `reversePayrollLine` into dated adjustments once periods lock (REP-04). T14 builds the payslip from `payroll_lines` and its linked rows (PAY-09). T17 must allocate `clientReceipt` rows to invoices (INV-05). T18 takes wage expense from posted lines, never from payments (REP-02).
- A client company that pays for a visa and cuts it from an invoice is not covered. Visa money runs against the worker only (D-039). Add when invoices exist (T16) if the owner says that happens.
- Register PDFs use Roboto, which has Latin letters only, so a name typed in Urdu script prints as boxes. Letterhead uploads, snapshots and payslips are still T14. Margin reports and CSV import are still T18.
- Rozana hisaab has no running cash-in-hand figure, because no opening cash exists yet. Group wages have no overtime. Payroll periods are calendar months only, though the tables store from and to. Add when asked.
- UX-02 is local only until T19 adds accounts. UX-07's sync statuses arrive with T25.
- Worker lists sort by plain text, so "Worker 10" comes before "Worker 2". Real names are fine; revisit if codes are shown as the sort key.

## Known risks

- E-invoicing, see `DECISIONS.md` D-011.
- The repo is public (D-032). A secret pushed here is exposed at once, so from P4 on, Supabase keys, the keystore and SMTP passwords stay in `.env` and out of git. Gitleaks runs on every push, but only after the push.
- Disk is about 89% full with 25 GB free. Docker for P4 needs more, so free space before then.
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
- Colours are read from `brand`, `action` and friends while widgets build, so they can't sit in a `const`. `usePalette` marks every element for a rebuild after a change, which reaches `const` screens too. A test covers it.
- A `pw.Table` clips each cell, so text can't run across columns even with an overflowing `Stack`. It also breaks a heading word when a column is narrow, so draw a PDF and look at it after changing column widths.
- `partial_method` holds a `PartialMethod` name such as `calendarDays`. The old comment on the column said `calendar_days`, and a test had copied it.
- Never run the bare `graphify update` CLI on this repo. See `CLAUDE.md`. Refresh the graph after every task, as the owner asked on 2026-10-31. Current graph: 2,229 nodes, 3,530 edges, 97 communities, including all 278 PRD nodes and 166 requirements. Repo docs other than the PRD have no semantic extraction yet.
