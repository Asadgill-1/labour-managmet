# Verification

What was actually run, with its result. Anything not listed as run was not run.

Environment: Windows 10, Flutter 3.47.7, Dart 3.13.5, Python 3.12.10. Branch `audit/t01-t21` from `9ebcd9b`. Tools set by `source /c/dev/env.sh`.

## Baseline, before any change (2026-11-15)

| Command | Where | Result |
| --- | --- | --- |
| `python tools/check_trace.py` | repo root | Pass. 166 PRD requirements traced |
| `dart analyze --fatal-infos` | `packages/domain` | Pass. No issues |
| `dart test` | `packages/domain` | Pass. 150 tests |
| `flutter analyze` | `apps/mobile` | Pass. No issues |
| `flutter test` | `apps/mobile` | 486 passed, 1 skipped, 13 failed. See below |

The 13 failures of the baseline `flutter test`:

- 2 in `test/cloud_copy_test.dart`, both a 30-second timeout. The computer was running four reviews and other test runs at the time. Run alone on 2026-11-16 the file passed, 8 of 8, at 7 to 10 seconds a test. Taken as load, not a defect. The margin is thin: each test makes real backups with a stretched password, so a slow CI runner could time out the same way.
- 11 in `test/zz_t20b_test.dart`, `zz_t20c_test.dart`, `zz_t20d_test.dart`, `zz_t20dc_test.dart`, `zz_t21b_test.dart` and `zz_t21c_test.dart`. These are screen-capture scripts kept on this computer only: `.gitignore` leaves out `apps/mobile/test/zz_*`, so they are in no commit and no CI run. They were written for earlier tasks and no longer match the code. Not part of the product's test suite.

The 1 skip is `cloud_restore_test.dart`'s Play Store case, which runs only with `--dart-define=PLAY_STORE=true`, as CI does in its own step.

## Runs during the audit

| Date | Command | Result |
| --- | --- | --- |
| 2026-11-15 | `dart test test/money_test.dart` in `packages/domain`, with the new test and before the fix | Fail, as meant: `parseAed('10000000000000')` gave 1000000000000000, not null (BUG-002) |
| 2026-11-15 | `dart test` in `packages/domain`, after the fix | Pass. 151 tests |
| 2026-11-16 | `flutter test test/cloud_copy_test.dart test/android_manifest_test.dart` | Pass. 8 and 1 |
| 2026-11-16 | `git show HEAD:apps/mobile/android/app/src/main/AndroidManifest.xml \| grep -c INTERNET` | 0: the manifest test's one check fails on the code as it was (BUG-001) |
| 2026-11-16 | `flutter build apk --release`, then its merged manifest read (`build/app/intermediates/merged_manifests/release/...`) | Built, 85 MB, signed with the debug key as the template leaves it (OBS-003). The merged manifest lists `android.permission.INTERNET` (BUG-001). Built before the later fixes; never installed on a phone |
| 2026-11-16 | `flutter test test/audit_journey_test.dart` | Pass. The first run failed on the test's own setup (no test binding for the paper's fonts); with that fixed every figure matched |
| 2026-11-17 | Payroll fixes (A): `dart test` in `packages/domain`; 10 app test files around payroll | Pass. 151 domain; 148 app |
| 2026-11-17 | Cloud and account fixes (D): `flutter analyze`; `cloud_copy`, `cloud_screens`, `cloud_restore`, `account`, `account_flow`, `licence`, `plan_guard`, `backup`, `restore` tests | Pass. No issues; 107 passed, 1 skipped (the Play Store case) |
| 2026-11-17 | Billing fixes (B): domain analyze and `dart test`; `flutter analyze`; 13 app test files (`write_path`, `invoices`, `timesheets`, `groups`, `documents`, `reports`, `statement`, `changes`, `records`, `masters`, `attendance`, `rates`, `invoice_edit`) | Pass. 152 domain; no issues; 210 app |
| 2026-11-17 | BUG-013's widget test changed to want 120 days kept and 366 refused, run before the auditor's change | Fail, as meant: "0 se 365 tak poora number likhein." not found |
| 2026-11-17 | `flutter test test/masters_test.dart` after it | Pass. 7 |
| 2026-11-19 | `cloud_restore_test.dart` alone, three times, after the full re-run's failure | Pass. 3 passed, 1 skipped, each time |
| 2026-11-19 | Review 05's findings, each test run before its fix: `payroll_test` (R05-1), `auto_cuts_test` (R05-2), `registers_test` (R05-3), `changes_test` (R05-6), `reports_test` (R05-9) | Fail, as meant: a room charge written (`Expected: <0> Actual: <1>`); October still listed the worker; no date chips while loading; no `entryChanged` text; 366 due days taken |
| 2026-11-19 | After the fixes: `payroll`, `closing`, `auto_cuts`, `salary_payment`, `statement`, `documents`, `changes`, `audit_journey`; then `registers`, `reports`, `app_shell`; then `reports`, `changes`, `attendance`, `timesheets`, `masters`; `flutter analyze` | Pass. 143; 41; 86; no issues |
| 2026-11-19 | A `dart format` run by the auditor rewrote unrelated lines of `lib/data/payroll.dart` | Undone: the file rebuilt from the commit's layout wherever its code was unchanged, then the tests above run again. Its diff is the intended 69 lines added and 5 removed |

## Full re-run after every fix (2026-11-17)

| Command | Where | Result |
| --- | --- | --- |
| `python tools/check_trace.py` | repo root | Pass. 166 PRD requirements traced (and again after TC-205 to TC-212 were added) |
| `dart analyze --fatal-infos` | `packages/domain` | Pass. No issues |
| `dart test` | `packages/domain` | Pass. 152 tests (150 at the baseline) |
| `flutter analyze` | `apps/mobile` | Pass. No issues |
| `flutter test` over the 38 committed test files and the audit's two new ones (`test/zz_*` left out) | `apps/mobile` | 514 passed, 1 skipped, 1 failed, in 9 minutes 22 seconds. The failure: `cloud_restore_test.dart`'s first test passed its checks, then its tearDown could not delete its temp folder, `PathAccessException ... being used by another process, errno = 32`. See below |
| `flutter test --dart-define=PLAY_STORE=true test/cloud_restore_test.dart` | `apps/mobile` | Pass. 1 passed, 3 skipped, as meant |

The one failure, `cloud_restore_test.dart`'s first test: every check in it passed; then its tearDown, `work.delete(recursive: true)`, was refused by Windows because a file in the test's temp folder was still held open (errno 32). Run alone afterwards the file passed three times out of three (3 passed, 1 skipped each), and the screens fixer's run of every file one process at a time passed it too. Neither the test nor its setup was changed by the audit. The audit's changes add no file work in that path (a copy after a restore skips the new check). Taken as a lock held a moment too long under a full parallel run, likely the system's virus scan of the new backup file. Not proven, and not reproduced (OBS-008). So the full re-run is not wholly green, and this is said rather than counted as a pass.

## Second full re-run, after review 05's fixes (2026-11-19)

| Command | Where | Result |
| --- | --- | --- |
| `python tools/check_trace.py` | repo root | Pass. 166 PRD requirements traced (after TC-213 was added) |
| `dart analyze --fatal-infos` | `packages/domain` | Pass. No issues |
| `dart test` | `packages/domain` | Pass. 152 tests |
| `flutter analyze` | `apps/mobile` | Pass. No issues |
| `flutter test` over the same 40 files as the first re-run (`test/zz_*` left out) | `apps/mobile` | Pass. 517 passed, 1 skipped, none failed, in 10 minutes 14 seconds. Two more than the first re-run: review 05's tests in `payroll_test.dart` and `auto_cuts_test.dart`; the others it added extend existing tests |
| `flutter test --dart-define=PLAY_STORE=true test/cloud_restore_test.dart` | `apps/mobile` | Pass. 1 passed, 3 skipped, as meant |

`cloud_restore_test.dart`, which failed in the first re-run's tearDown (OBS-008), passed this time. That does not prove the flake gone: it was not changed, and it may come back under load.

## Journeys exercised

| Journey | How | Result |
| --- | --- | --- |
| QA-01: company, two client companies and sites, workers paid by the hour, day and month, bulk attendance with a second tap, payroll, a part payment, timesheets, two VAT invoices, the same work refused a second invoice, a part receipt, a receipt above what is owed refused, the invoice's paper, a backup, a wrong password refused, a restore on another phone under its own key, then the next invoice's number | `apps/mobile/test/audit_journey_test.dart`, on an encrypted database file through the app's own write paths. Expected figures worked out by hand from `docs/CALCULATION_SPEC.md` | Pass. Pay 180.00, 160.00 and 3,000.00; closing 80.00 after 100.00 paid; invoices 405.00 + 20.25 VAT and 240.00 + 12.00 VAT, numbered 0001 and 0002; 225.25 left after 200.00 received; the restored file gives the same figures and the same paper byte for byte; the next invoice is 0003 |

That test drives the data layer, not the screens. Signup and login are covered only by the existing tests against stand-ins for Supabase.

## Not run, and why

| Check | Why |
| --- | --- |
| `supabase test db` (the cloud's 8 SQL test files) | Docker cannot start: virtualisation is off in the BIOS. `PROGRESS.md` records CI run 43664625445 passing them on 2026-11-15; not re-checked by this audit |
| `deno check`, `deno test` for the two functions | Deno is not installed here. Same CI run |
| Anything on Android | No phone or emulator. Keystore-backed keys, the share sheet, WhatsApp, the image and file pickers, the fingerprint prompt and printing have only been compiled |
| The live Supabase project | Out of bounds without the owner's yes. No signup, licence or backup call was made |
