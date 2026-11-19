# Review 05: the audit's final diff (read-only)

Reviewer: independent, read-only. No tests or builds run (a suite was running on the machine). Scope: `git diff -- apps/mobile/lib packages/domain/lib` (generated localizations left out) and `supabase/migrations/20261117120000_audit_fixes.sql` against the newest earlier definitions. Resumed on 2026-11-19 after a usage-limit pause; the auditor's later widening of `checkDays` (terms 0 to 365 with `termsDaysError`, wage days 0 to 90) is included.

## Read in full

- `supabase/migrations/20261117120000_audit_fixes.sql`; `20261111120000_phone_off.sql` (the newest `turn_phone_off` and `register_device`); `20261114120000_cloud_backup.sql` lines 40-60, 110-170, 280-525 (`backup_removals`, the start and finish locks, `submit_slip`, the newest `accept_slip`, `licence_facts`, `delete_account` with its `amr` check); grep of every migration for `for update`, tenant foreign keys and slip updates.
- `apps/mobile/lib/data/account.dart` (whole file: `resetPassword`, `_enrol`, `turnPhoneOff`, `deleteAccount`, `_userGone`, `problemOf`).
- `apps/mobile/lib/features/account/account_screens.dart` lines 1-330 and 700-859 (`accountProblemText`, `CloudStep.attempt`, login, code screen, `PhonesScreen`).
- `apps/mobile/lib/app/root.dart` lines 100-225 (`_startLicence`, `_deleteAccount`, `_leave`).
- `apps/mobile/lib/data/cloud_copy.dart` (whole file), `deleteTenant` keys in `tenant_database.dart`.
- `apps/mobile/lib/data/licence.dart` (whole file).
- `apps/mobile/lib/data/tenant_database.dart` lines 280-394 (`applyOperation`, `_applyOnce`); every caller of `applyOperation` (grep, 45 sites).
- `apps/mobile/lib/data/receipts.dart` (whole file), `masters.dart` lines 1-100, `changes.dart` lines 290-450.
- `apps/mobile/lib/data/payroll.dart` lines 1-570 (`payrollFor`, `postPayroll`, `reversePayrollLine`, `savePayItem`, `applyVisaInstalments`, `applyRoomCharges`); `packages/domain/lib/payroll.dart` (whole file); `apps/mobile/lib/data/statement.dart` lines 95-330; `apps/mobile/lib/data/closing.dart` lines 60-150.
- `apps/mobile/lib/features/payroll/payroll_worker_screen.dart` lines 1-160, `room_charge_screen.dart` lines 40-125.
- `apps/mobile/lib/features/cash/cash_entry_form_screen.dart` lines 60-200; `row_editor_screen.dart` hunk and `openAttendanceRow`; `timesheets.dart` `carryAgreedToAttendance`.
- `apps/mobile/lib/features/registers/ledger_screen.dart` lines 40-190; `register_defs.dart` `_Masters`, `companyLabels`, `_companies`, `_statement`, `_aging`, `_work`; `salary_sheet.dart` hunk; `register_xlsx.dart` escaping (grep of every XML write).
- `packages/domain/lib/csv.dart` (whole parser), `money.dart` hunk; `apps/mobile/lib/data/import.dart` lines 160-300 and `number()`.
- `apps/mobile/lib/app/form_bits.dart` hunks (`checkDays`, `askReason`, `askDailyWage`), `profile_form_screen.dart`, `client_form_screen.dart`, `theme.dart` `saveErrorText` and `saveOrExplain`, `change_notes.dart` `deleteOrArchive`, `opening_balance_form_screen.dart`.
- Fix reports `docs/audit/fixes/A-payroll.md`; `docs/audit/BUG_REGISTER.md`.
- New strings: `accountPasswordAgain`, `openingSettled`, `importUnclosedQuote`, `termsDaysError` are in both ARB files and the generated class.

## Findings

### R05-1: a room charge can still be stranded behind a later posted month (BUG-004 left open on one path)

- Severity: Medium (the same defect BUG-004 names, through the room charge screen).
- Status: CONFIRMED by tracing.
- Where: `apps/mobile/lib/features/payroll/room_charge_screen.dart:67-68`, `apps/mobile/lib/data/payroll.dart:543-546`.
- Expected: no item is added to a month behind a later posted month (`canAddItems`, PAY-02).
- Actual: both guards ask only workers that are on the month's payroll list. A worker with a later posted month and nothing left in this month is not on the list: `payrollFor` gives `later` true, so salary 0, no unpaid rows (the later posting linked them), no items, `isEmpty`, and line 273 `continue`s. The screen's `taken` set then leaves the worker in `candidates`, and `applyRoomCharges` skips only workers found in `current` with `!canAddRoomCharge`, so it inserts the charge.
- Scenario: daily worker Asif, rows in September, October posted (September's rows go into October's line as adjustment). Owner opens September's room charges: Asif is offered; ticking AED 300 writes a September `roomCharge` with no line. September now shows `laterMonthPosted` and can never post; November gets `earlierMonthMissing` from `itemMonths`; the statement counts the AED 300 cut that payroll never takes, until the owner finds and deletes the item.
- Fix: in `applyRoomCharges` (and the screen's `taken`), also skip a worker with a non-reversed line dated after the month, e.g. one query of `payrollLines` where `periodFrom > from and reversed = false` for the ticked workers. A data-layer refusal in `savePayItem` would close every path at once (A-payroll.md lists it as not done).

### R05-2: a back-dated cut-absence contract now lists the worker for months before their account starts, and closing asks to post them

- Severity: Low (no money moves; extra zero lines and a closing finding).
- Status: CONFIRMED by tracing.
- Where: `packages/domain/lib/payroll.dart:86` (`isEmpty` with `absenceFils`), `apps/mobile/lib/data/payroll.dart:273`, `apps/mobile/lib/data/closing.dart:108-109`.
- Expected (D-042 (5), as the statement reads it): a salary counts only from the account's first activity, so a month before it has nothing to post or close.
- Actual: `isEmpty` is now false whenever the cut is non-zero, and nothing in `payrollFor` checks `firstMonth` before listing. A month wholly before the first activity, covered by the contract, cuts every day, so the worker is listed and `canPost`, and closing that month raises `payrollNotPosted` until a zero line is posted. The statement (`statement.dart:302`) does not count that month at all.
- Scenario: owner starts in November 2026; worker Bilal entered with a monthly AED 3,100 contract from his hiring date 2025-01-01, cut on, first row 2026-11-03. Closing October 2026 (for October cash or invoices) now lists Bilal under "pay not posted" with "31 days absent"; every earlier unclosed month back to January 2025 shows him on Tankhwah the same way.
- Fix: in `payrollFor`, when the worker has no posted line, skip (as before) a month whose figures are empty apart from the cut and that is before `activity.firstOrNull` (or has no activity at all). The "forgot to end the contract" case after activity, which BUG-005 was about, keeps its new behaviour.

### R05-3: the register screen loses its date controls while new dates load, and has none when the build fails

- Severity: Low.
- Status: CONFIRMED by reading the build.
- Where: `apps/mobile/lib/features/registers/ledger_screen.dart:115` and `129-135`.
- Expected: new dates never show the old rows (BUG-014), and the owner can still change the dates.
- Actual: the header with the date buttons and chips is item 0 of the `ListView`, which is built only when `data != null`. On every date change the whole body becomes a spinner until the build ends; if the build throws, the body is `EmptyState(databaseError)` with no date controls, so the only way out is to leave the screen. Before, the old figures and the header stayed.
- Scenario: Company statement, all dates, a large book: tap "This month", the band disappears for the seconds the build takes; a build error for one range leaves a page with no way to pick another range.
- Fix: build the header (from `widget`/state, not from `data`) above the spinner or error, or keep `_last.data` for the header's band only and blank the rows and export.

### R05-4: the first cloud copy whose finish answer was lost makes the same phone ask "another phone's copy" and stops automatic copies

- Severity: Low.
- Status: CONFIRMED by tracing (needs the finish step to succeed on the cloud and its answer to be lost).
- Where: `apps/mobile/lib/data/cloud_copy.dart:138`.
- Expected: only a phone that may not hold the cloud's newest data (reinstall, cleared data, phone turned back on) is held for the owner's choice (BUG-020).
- Actual: `_lastAt` is set only when `sendCloudCopy` returns. If `finish` is counted by the cloud but the answer is lost, `_lastAt` stays null, `_problem` becomes `offline`, and the next try (an hour later or the next start) finds the copy this phone just sent in `cloudCopies`, so it refuses with `otherPhoneCopy`. `sendIfDue` then sends nothing until the owner answers on the Backup page, whose words say the copy came from another phone.
- Fix: write a marker (for example `'sent': true` in `_keep`) before the upload starts and skip the early check when it is set; or compare against the cloud's newest copy's device id, which the start step already checks.

### R05-5: a deletion retry is recognised only while the old access token is still in memory

- Severity: Low.
- Status: SUSPECTED (depends on supabase-dart's auto refresh and GoTrue's answer for a deleted user; not run).
- Where: `apps/mobile/lib/data/account.dart:436`, `449-458`.
- Expected (BUG-021): a retry after a deletion whose answer was lost finishes the phone's side.
- Actual: `_userGone` calls `getUser()` with the session in memory. Once the access token nears expiry the client refreshes it; the deleted user's refresh token fails, the client signs out, and `getUser()` throws `AuthSessionMissingException`, which `_userGone` reads as "not gone". The retry then signs in and gets `wrongLogin`, the original symptom. An expired token gives GoTrue's `bad_jwt`, also "not gone". The fixer noted only the app-restart case.
- Scenario: delete sent at 10:00 with a token that expires at 10:20; answer lost; the owner retries at 10:25: "wrong email or password", the books stay on the phone.
- Fix: keep the access token the deletion was sent with (`_deleteSent` becomes that token) and ask `getUser(thatToken)`, so a later sign-out of the client does not matter; that covers a retry within the token's hour. Past it, and after a restart, the case stays open as the fixer recorded.

### R05-6: a correction from a stale row now fails with the general "save failed" message

- Severity: Low (known to the fixer, A-payroll.md BUG-008).
- Status: CONFIRMED by tracing.
- Where: `apps/mobile/lib/data/attendance.dart:330`, `apps/mobile/lib/app/theme.dart:343-358`.
- Expected (UX-04): a refusal says what to do.
- Actual: `EntryChanged` has no case in `saveErrorText`, so the row editor and the timesheet's "carry agreed to attendance" show `saveFailed`. Nothing is written, so no data risk. `carryAgreedToAttendance` on a timesheet line whose row was corrected since now always fails this way.
- Fix: one `EntryChanged() => l10n.entryChanged` case ("This row was changed. Open it again.") in both ARB files.

### R05-7: the reset password flow, if its final sign-in fails, cannot be retried with the same code

- Severity: Low.
- Status: SUSPECTED (GoTrue's recovery code is single-use; not run).
- Where: `apps/mobile/lib/data/account.dart:150-156`.
- Expected: a network failure at the last step leaves a retry that works.
- Actual: `verifyOTP` and `updateUser` succeed, then `signInWithPassword` fails offline: the screen says offline; a retry calls `verifyOTP` with the used code and gets `otp_expired`, shown as a bad code, though the new password is already set. The owner can log in from the login screen with it, but nothing says so.
- Fix: if a session from the code is already present on retry, skip straight to `signInWithPassword`; or catch the sign-in failure after `updateUser` and tell the owner the password is changed and to log in.

### R05-8: turning off a phone that is already off now needs a recent password too

- Severity: Low (no harm; a retry after a lost answer asks for the password instead of succeeding).
- Status: CONFIRMED by reading the SQL.
- Where: `supabase/migrations/20261117120000_audit_fixes.sql:20-25`.
- Expected (MODEL-06, the original's comment): "A phone already off stays as it was, so a retry changes nothing."
- Actual: the `amr` check runs before the `revoked_at_utc is null` test, so a retry more than ten minutes after the sign-in raises `type the password again`. The app now handles that (password field), so this is a wording point, not a break. A member turning off their own phone also needs a recent password now, which is stricter than BUG-023 asked; the app has no member path to it yet.
- Fix: none needed; or move the check inside `if v_row.revoked_at_utc is null`.

### R05-9: imported due days have no upper limit, unlike the form

- Severity: Low.
- Status: CONFIRMED by reading.
- Where: `apps/mobile/lib/data/import.dart:391-397`, `client_form_screen.dart:106`.
- Expected: the same rule in both ways in (0 to 365 after the auditor's change).
- Actual: import takes any whole number of 0 or more. A company imported with 400 cannot be saved from its form until the field is changed. Negative numbers are refused by import, and the invoice clamps a stored negative to 0, so no invoice is due before it issues.
- Fix: refuse `n > 365` in `number()` for `ImportField.dueDays` (a `max` argument).

## Checked and found sound

- SQL: all three functions keep their exact signatures and defaults, so `create or replace` keeps owner, ACL and grants (`turn_phone_off` and `register_device` to `authenticated`, `accept_slip` revoked from public); both public ones keep `security definer set search_path = ''` and `auth.uid()`; `accept_slip` stays invoker. Every other line matches the newest original.
- The `amr` check is the same expression `delete_account` already uses: GoTrue's `amr` is an array of `{method, timestamp}` with an integer Unix time; a refreshed session keeps its original timestamp; a session from `verifyOTP` (signup or recovery) carries `otp`/`recovery`, never `password`, so an OTP or recovery session cannot pass. The app's reset flow now signs in with the password, and `PhonesScreen` falls back to the password field on `passwordAgain`.
- `register_device`: the check applies only to an existing revoked row of an owner; a first sign-in and a phone that is on are unchanged; the non-owner refusal still comes first.
- `accept_slip` lock order: slip row, then tenant row. `submit_slip`, the backup start and finish take the tenant row and never wait on an existing slip; `delete_account` takes no tenant lock before deleting slips; `backup_removals` has no foreign key. No cycle found, and the second of two concurrent accepts reads the first one's period, as each later statement gets a new snapshot under read committed.
- `applyOperation` returning `Future<String>`: every caller checked; ids returned on a retry are the outbox's `recordId`, which each caller set to the record it returns; void callers are unaffected.
- `keepOpeningSettled` runs inside the write's transaction after the change, for both `saveRow` and `deleteRecord`, covers a changed kind or company (it checks the old company), and its refusal reaches `saveErrorText` through `saveOrExplain` and `deleteOrArchive`.
- BUG-003 `firstMonth` sources match the statement's activity (rows, items without recoveries, old balances from the next day, salary and advance cash with same-month mistakes set aside, inactive workers ignored, closed months skipped).
- `parseCsv` throws only at the end and only when a quote is still open; its one caller catches it; `parseAed` 13 digits stays inside 64-bit and JavaScript-safe integers.
- `checkDays` (terms 0 to 365 with `termsDaysError`, wage days 0 to 90 with `wageDueDaysError`) trims, accepts empty as "not set", and matches what the save path stores (`int.tryParse`); the invoice clamp keeps a stored negative from making an invoice overdue on its day.
- `companyLabels` always gives distinct labels, including a TRN shared by two same-named companies and a company literally named "Acme (1)"; other registers use the company name only for display.
- The Excel writer escapes every text it writes, sheet and defined names included.
- `Licensing.view`: `_latestSeen` moves synchronously before the unawaited write and never backwards; it waits for `load()`. An error from that background write would go unhandled, but only if secure storage itself fails.
- Controller disposal one frame late in the two dialogs, the `mounted` guard on export, `_loadingUnpaid` with stale loads, and the row editor's absent fallback are correct.
