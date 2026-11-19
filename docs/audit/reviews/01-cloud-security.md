# Review 01: cloud and security

## Files read in full
- PRD_Roman_Urdu.md chapters 03, 12, 13, 16, 20; DECISIONS.md D-060 to D-078; both design docs; docs/LATER.md; PROGRESS.md "Open".
- supabase/config.toml
- supabase/migrations/20261108120000_cloud_tenants.sql
- supabase/migrations/20261109120000_one_account_per_phone.sql
- supabase/migrations/20261109130000_delete_account.sql
- supabase/migrations/20261111120000_phone_off.sql
- supabase/migrations/20261111130000_plans_licence.sql
- supabase/migrations/20261114120000_cloud_backup.sql
- supabase/functions/licence/index.ts, sign.ts, sign_test.ts
- supabase/functions/backup/index.ts, request.ts, request_test.ts
- supabase/tests/database/: tenants, phones, delete_account, phone_off, plans, licence, slips, cloud_backup (.test.sql)
- apps/mobile/lib/data/account.dart, licence.dart, plan_guard.dart, plans.dart, app_lock.dart
- apps/mobile/lib/main.dart, lib/app/root.dart, lib/app/providers.dart, lib/app/settings.dart
- apps/mobile/lib/features/account/account_screens.dart (lines 1-860 of 945; the rest is layout widgets)
- apps/mobile/lib/data/backup.dart, recovery.dart, cloud_copy.dart, restore.dart
- apps/mobile/lib/features/backup/backup_screen.dart, restore_screen.dart, cloud_copies_screen.dart
- apps/mobile/lib/features/more/settings_screen.dart, db_check_screen.dart; apps/mobile/lib/spike_checks.dart
- apps/mobile/tool/recovery_key.dart, apps/mobile/.env.example, apps/mobile/pubspec.yaml, .github/workflows/ci.yml, .gitignore
- Also read for context: `deleteTenant` and `thisDeviceId` in apps/mobile/lib/data/tenant_database.dart; gotrue 2.27.3 `recoverSession`/`setSession` in the local pub cache (to confirm a resumed session emits `tokenRefreshed`, not `signedIn`, so `Account.signedIn` stays false after a resume).

## Files not fully read
- apps/mobile/lib/features/plans/plan_screen.dart: lines 40-140 read in full (loading, slip pick and send); the rest (layout of plan cards, add-on choice, slip list, trial note) read by targeted search only.
- apps/mobile/lib/features/plans/plan_lock.dart: read by targeted search only (the guard wrapper, banner, keep-active chooser calling `archiveAllBut`). The write-path rules themselves are in plan_guard.dart, read in full.
- apps/mobile/lib/features/account/account_screens.dart lines 860-945 (StepScaffold, language button, PasswordField, MarginNote): layout only, skimmed.
- Existing Dart tests (apps/mobile/test/*.dart) were not read in full; cloud_copy_test.dart was checked by test name only for F01-2.

## Rules checked
| Rule | Source | Enforced where | Verdict |
| --- | --- | --- | --- |
| Tenant id from verified membership, never from the request | AUTH-02, D-060 | `private.member_role` (auth.uid()) in every function and policy | SOUND |
| RLS on every cloud table; reads limited to members, owner sees company-wide rows | AUTH-05 | all six migrations: RLS on, select-only grants, no write grants | SOUND |
| No table writable from the API; writes only through SECURITY DEFINER functions with `search_path = ''` | MODEL-05 | all public functions | SOUND |
| EXECUTE revoked from anon/public where needed (Supabase grants public functions to anon directly) | AUTH-05, AUTH-06 | every function revokes `from public, anon` or `from public, anon, authenticated` | SOUND |
| Signing key only server-side, made in Vault, readable by service_role only | BILL-03, D-074 (5) | `licence_signing_key*`, licence function | SOUND |
| Licence signed (Ed25519) and bound to tenant and phone, 7-day lease, replay ignored | BILL-03, BILL-05 | sign.ts; licence.dart `verifyLicence`, `refresh` | SOUND |
| Clock moved back forces an online check | BILL-06 | licence.dart `licenceStatus` | DEFECT (F01-8, Low) |
| Client cannot give itself a plan, trial or add-on | MODEL-05, D-074 | subscriptions written only by `accept_slip` (postgres) and the one trial insert | SOUND |
| One trial per company, email and phone | D-074 (2) | `licence_facts`, `private.trial_claims` | SOUND for the stock app; a changed app can send any phone id, as BILL-06 accepts |
| Month = same day next month, clamped, from the anchor; early renewal continues | BILL-04, D-074 (3) | `private.months_after`, `accept_slip` | SOUND; DEFECT under concurrency (F01-6, Low); test time bomb (F01-5) |
| Slip files only in the company's own folder, by its owner | AUTH-05, D-074 (3) | storage policies via `slip_file_of_owner` | SOUND |
| Cloud copies: no app access to the bucket; links only after Postgres says yes; 60 s download link | D-072, design doc | `backups` bucket with no policies; backup function | SOUND |
| A copy comes back only with an active add-on, owner, phone that is on | D-072 (2), D-075 (1) | `backup_download` | SOUND |
| A phone's empty data never replaces the cloud copy unasked | design goal, D-076 (5) | `backup_start` other-phone check | DEFECT (F01-2, High) |
| A changed app cannot fill the storage | D-076 (4) | `backup_starts` cap | DEFECT (F01-3, Medium) |
| Deleted account: newest copy 60 days, rest at once; only id and email kept | D-072 (5) | `delete_account`, `backup_removals_due/done` | SOUND |
| Turning a phone off needs the password | D-073 (2), D-074 T21b call | app UI only | DEFECT (F01-1, High) |
| Turning a phone back on needs the owner's password | D-073 (4) | `register_device` | DEFECT (F01-4, Medium) |
| A network error never wipes a phone | D-073 (3), D-067 (4) | account.dart `phoneIsOff` returns false on any error | SOUND |
| Account deletion needs a password typed in the last 10 minutes | D-066 | `delete_account` `amr` check; app signs in first | SOUND |
| Deletion: cloud first, then the phone, key before file | D-066 | root.dart `_deleteAccount`, tenant_database.dart `deleteTenant` | SOUND; partial failure DEFECT (F01-7, Low) |
| Logout closes the database, clears memory, images, share files, session | AUTH-04, D-062 | root.dart `_leave`, account.dart `logOut` | SOUND |
| PIN salted and hashed, 8 tries counted across restarts | D-064, D-065 | app_lock.dart | SOUND (the hash of a 4-6 digit PIN is brute-forceable by anyone who can read the secure store, as its comment says) |
| Expiry never hides or deletes data; read, export, backup and restore stay | PLAN-03, D-074 (4) | plan_guard.dart (`_alwaysAllowed`, archives always allowed); reads are never guarded | SOUND |
| No licence, unreadable licence or clock trouble fails closed for writes only | D-074, T21c | plan_guard.dart, licence.dart | SOUND |
| Backup: standard crypto (SQLCipher 4, PBKDF2-HMAC-SHA512 256k, HMAC per page); password never in the file | DATA-02, D-069 | backup.dart | SOUND |
| Recovery seal: X25519 + HKDF-SHA256 + ChaCha20-Poly1305, fresh ephemeral key and random nonce, bound to tenant and checksum; key file PBKDF2 600k | D-072 (4), D-077 (2), (3) | recovery.dart, tool/recovery_key.dart | SOUND |
| Restore: label, tenant, schema, checksum, password, integrity check before any change; atomic rename; data here backed up first | DATA-05, D-070, D-071 | backup.dart `readBackupLabel`/`checkBackup`, restore.dart `swapIn`, restore_screen.dart | SOUND |
| App and server contracts agree (parameter names, response shapes, error words) | MODEL-06 | account.dart vs migrations, request.ts, index.ts | SOUND (checked: licence `{payload,sig}`, backup `{path,token}`, `{finished_at}`, `{url}`, every refusal word the app maps) |
| Edge functions: missing/forged token refused, no error detail leaked | AUTH-05 | `verify_jwt = false`, but the user's JWT is checked by PostgREST on the `asUser` call; unknown errors return `server` | SOUND |
| Secrets not in git | AI-05 | .gitignore (`.env*`, keystores); `.env.example` holds only public halves | SOUND |

## Findings

### F01-1: A session token alone turns the owner's working phone off, and that phone then wipes its own books
- Severity: High
- Status: CONFIRMED (code path); the attacker needs a valid session of the owner, for example the refresh token kept in secure storage on a lost or stolen phone (D-074 keeps it there)
- Where: supabase/migrations/20261111120000_phone_off.sql:7-23, `public.turn_phone_off`; apps/mobile/lib/app/root.dart:119-122 `_closeIfOff` and :206 `deleteTenant`; apps/mobile/lib/data/account.dart:72-85 (session persisted)
- Expected: D-073 (2) says "the cloud must trust the step, so the page asks for the login password", and the T21b builder call in D-074 says turning a phone off "still needs the password typed in that run". `delete_account` enforces this on the server through the JWT `amr` password timestamp (10 minutes).
- Actual: `turn_phone_off` checks only that the caller is the owner (or the phone's own user). It does not check a recent password, and it does not check that the caller's own phone is on. The password is asked only by the app's PhonesScreen (account_screens.dart:742), which a direct call to `/rest/v1/rpc/turn_phone_off` skips. Turning a phone off also does not end that phone's sessions, so the old phone's refresh token keeps working after it is turned off.
- Reproduction: owner has phone A (lost, session still in storage, perhaps already turned off by the owner) and phone B (in use). With A's refresh token, call `rpc/turn_phone_off` with B's `devices.id` (readable by the owner through `devices` RLS). Next time B opens online, `phone_is_off(tenant, B)` returns true, `_closeIfOff` calls `_leave(LoginNote.phoneOff)`, and `deleteTenant` removes B's key and file. B's data is gone unless a backup file exists or the add-on is bought to bring the cloud copy back. Regression test: supabase/tests/database/phone_off.test.sql (a call with `amr` older than 10 minutes, or with no `amr`, must raise).
- Proposed minimal fix: in `turn_phone_off`, require the same `amr` password check that `delete_account` uses. The app's PhonesScreen must then ask for the password again when the server says "type the password again" (a sign-in earlier in the same run can be older than 10 minutes). Regression risk: low on the server; the app must map the new refusal to the password prompt, or the step fails with a generic error.

### F01-2: After a reinstall (or "clear data") on the same phone, the empty company's copy replaces the real cloud copy with nothing asked
- Severity: High
- Status: CONFIRMED by tracing the code; no test covers it
- Where: supabase/migrations/20261114120000_cloud_backup.sql:121-126 (`backup_start`, the other-phone check compares only `device_id`) and :189-196 (`backup_finish` removes every older non-daily copy); apps/mobile/lib/data/cloud_copy.dart:97-107 (`sendIfDue`) and :131-153; apps/mobile/lib/features/backup/backup_screen.dart:77-89 (`_keepPassword` calls `sendIfDue`); :309-311 (Today's "password due" notice)
- Expected: design doc goal "A new phone's empty data never replaces the old phone's cloud copy without the owner saying so", and its anti-goal "Deleting the last good copy before a newer one is safely stored"; D-076 (5), D-077 (5).
- Actual: the guard is "the latest copy came from another phone". D-063 says the phone's id survives a reinstall, so a reinstalled phone, or one whose app data was cleared, counts as the same phone. On that phone the secure store is empty, so `_mark` and `_lastAt` are null and no backup password is kept. After login the company opens with an empty file, Today shows "backup password due", and once the owner types it, `_keepPassword` calls `sendIfDue`. The outbox mark `0/null` differs from the null kept mark, so the empty company is sent with `replace: false`; `backup_start` does not refuse because `v_last` equals this phone's id; `backup_finish` then queues every older copy without a live daily keep for removal at `now()`, and the same `finish` call removes them from storage (`removeDue`). Without the add-on, which is the normal state (the add-on is bought after a loss), the only copy of the company's data is destroyed.
- Reproduction: company with a finished cloud copy from phone P and no add-on. Uninstall and reinstall the app on P (or clear its data), log in, open the Backup page from Today's notice, keep the backup password. Result: `cloud_backups` holds only the new near-empty copy; `private.backup_removals` named the old file, and the function removed it. Regression tests: apps/mobile/test/cloud_copy_test.dart (a sender with no kept record whose cloud already holds a copy must not send by itself), and supabase/tests/database/cloud_backup.test.sql if the guard is put in SQL.
- Proposed minimal fix: in `CloudSender`, when this install has never sent a copy (`_lastAt == null` and no kept record) and `cloudCopies()` is not empty, do not send automatically; set `_problem = AccountProblem.otherPhoneCopy`, so the existing Backup page question ("bring that data back first, or keep this phone's data") appears. A cleaner server-side variant is a `p_first` flag on `backup_start` that refuses like the other-phone case. Regression risk: low; the signup's first copy is unaffected because the cloud then holds none. The question appears once after a reinstall, which is the intended behaviour.

### F01-3: The 20-copies-a-day cap does not stop one account from filling the storage
- Severity: Medium
- Status: CONFIRMED by reading; not measured against the live quota
- Where: supabase/migrations/20261114120000_cloud_backup.sql:127-139 (`backup_start`), :43-58; supabase/functions/backup/index.ts:52-57 and :19-28 (`removeDue` runs only after a finished upload); supabase/migrations/20261108120000_cloud_tenants.sql:94-119 (`create_tenant` has no limit per user)
- Expected: D-076 (4): "a company starts at most 20 a day, so a changed app cannot fill the storage."
- Actual: every `start` hands out a fresh two-hour upload link, and the unfinished upload it replaces is queued for removal 3 hours later. Removal happens only when some company later finishes an upload. So one company can hold 20 x 50 MB = 1 GB of unfinished uploads for at least 3 hours per day by never calling `finish`. The cap is per company, and one verified account can make any number of companies with `create_tenant`, register its one phone in each (`phone_account` ignores the caller's own devices), and repeat. The live project is on Supabase's free plan (D-061), whose file storage quota is, to my knowledge, 1 GB (not checked against the live project).
- Reproduction: with one owner session, loop 20 times: `backup` function `start` with a new `operation_id` and `size_bytes` 52428800, then upload 50 MB to the returned token; never `finish`. Repeat for a second company made with `create_tenant`. Storage use grows by about 1 GB per company per day. Regression test: supabase/tests/database/cloud_backup.test.sql (a second `start` while an unfinished upload younger than its link exists is refused, or the day's bytes are capped).
- Proposed minimal fix: refuse a new `start` while the company has an unfinished upload younger than the link's two hours (return that upload's path again instead), and lower the daily cap to a handful. Optionally cap companies per user in `create_tenant`. Regression risk: low; a retry after a crash then reuses the earlier path, which `backup_start` already supports through `arrived`.

### F01-4: An owner's turned-off phone turns itself back on with any session, no password
- Severity: Medium
- Status: CONFIRMED (code path); exploitation needs a session token of the owner, as in F01-1
- Where: supabase/migrations/20261111120000_phone_off.sql:40-68, `public.register_device` (lines 60-66 clear `revoked_at_utc` for an owner)
- Expected: D-073 (4): "The owner logging in on that phone again with the password turns it back on: the password is the owner's authorization."
- Actual: `register_device` revives a revoked owner device for any authenticated owner session; nothing checks that a password was typed. The stock app calls it only right after `signInWithPassword` (account.dart `_enrol`), but a direct RPC with a kept refresh token does the same. Because "the first phone on" is chosen by `created_at_utc` (`licence_facts` line 402-407, `require_owner_phone` line 83-87), the revived old phone outranks the new one: the new phone's licence check then fails with `other_phone`, its writes go to safe mode, and the old phone may `backup_start(p_replace => true)` and `backup_finish`, which removes the company's earlier non-daily cloud copies (cloud_backup.sql:189-196).
- Reproduction: owner turns phone A off from phone B. With A's refresh token, call `rpc/register_device(tenant, A's device_id, ...)`; A is on again; `licence_facts` for B now raises "another phone is on". Regression test: supabase/tests/database/phone_off.test.sql (reviving with no recent `amr` password must raise; the existing test at line 81-84 revives with no `amr` and would need a password `amr` claim).
- Proposed minimal fix: when the row is revoked, require the `amr` password timestamp within 10 minutes before clearing `revoked_at_utc`. Regression risk: a login made by a password-reset code (`amr` method `otp`/`recovery`) could not revive an old phone; that path is not live yet (T19d).

### F01-5: slips.test.sql stops passing on 2027-02-28
- Severity: Low
- Status: CONFIRMED by reading (date arithmetic), not run
- Where: supabase/tests/database/slips.test.sql:179-196
- Expected: CI tests that pass on any day (AI-03, the `supabase` CI job runs on every push).
- Actual: the test inserts a paid period ending `2027-02-28 10:00+04` and expects `accept_slip` to continue it to `2027-04-30`. `accept_slip` continues only a period whose `ends_at_utc > now()`. From 2027-02-28 06:00 UTC the earlier period has ended, the new one starts at `now()`, and the assertion "which run from Feb 28 to Apr 30" fails, turning the whole `supabase test db` job red.
- Reproduction: run `supabase test db` with the database clock after 2027-02-28 06:00 UTC. Regression test: the same file.
- Proposed minimal fix: build the fixture relative to now, for example anchor `date_trunc('month', now() + interval '3 months') - interval '1 day'` at a month's last day, or insert the period with `starts`/`ends` computed by `private.months_after` from a future 31st. Regression risk: none outside the test.

### F01-6: `accept_slip` does not lock the company, so two accepts at once overlap their periods
- Severity: Low
- Status: CONFIRMED by reading; reachable only from the SQL editor today (T22 adds a dashboard button)
- Where: supabase/migrations/20261114120000_cloud_backup.sql:311-366, `private.accept_slip`
- Expected: BILL-04, every renewal its own entry continuing the current expiry; the prompt's "two concurrent calls" check.
- Actual: the function locks only the slip row. Two different slips of one company accepted in two sessions at the same time both read the same `v_prev` and both start at its end, so two paid months yield one month of cover. `submit_slip` and `backup_start` lock the tenant row; this function does not.
- Reproduction: two SQL sessions, `begin; select private.accept_slip(slip1, ...)` and `begin; select private.accept_slip(slip2, ...)` for the same tenant, then commit both: two subscriptions with the same `starts_at_utc`. Regression test: supabase/tests/database/slips.test.sql cannot show concurrency; a check that the function takes `for update` on `public.tenants` (or a serial second accept continuing from the first) is the practical guard.
- Proposed minimal fix: `perform 1 from public.tenants t where t.tenant_id = v_slip.tenant_id for update;` right after the slip is read. Regression risk: none.

### F01-7: Deleting the account when the answer is lost leaves the books on the phone and no way to finish
- Severity: Low
- Status: CONFIRMED by reading
- Where: apps/mobile/lib/app/root.dart:146-149 (`_deleteAccount`), apps/mobile/lib/data/account.dart:427-433
- Expected: D-066: the account and its books go "from the cloud and from this phone, for good"; the cloud first, then the phone.
- Actual: if `delete_account` commits but the response is lost (network drop), `deleteAccount` throws `offline`, `_leave(LoginNote.accountDeleted)` never runs, and the company stays open on the phone. A retry fails at `signInWithPassword` with "wrong login" because the user no longer exists. Nothing tells the owner the account is gone, and the data stays on the phone (readable by whoever holds it when no PIN is set).
- Reproduction: drop the connection after the RPC is sent (a fake client in apps/mobile/test/account_test.dart that commits and then throws `SocketException`); the screen shows "offline", and a second try shows "wrong login".
- Proposed minimal fix: on a retry whose sign-in fails with invalid credentials after a previous delete attempt, or on any error after the RPC was sent, ask `phone_account`/`memberships` (or sign in) to learn whether the account still exists, and run `_leave(accountDeleted)` when it is certainly gone. Regression risk: low, but "certainly gone" must never be inferred from a network error (D-067 (4)).

### F01-8: The licence's "latest time seen" moves only at start and at a check, so a frozen clock keeps an offline licence alive
- Severity: Low
- Status: CONFIRMED by reading; BILL-06 already says an offline device cannot be made piracy-proof
- Where: apps/mobile/lib/data/licence.dart:165-177 (`load`), :207-210 (`_see`), :116-122 (`licenceStatus`)
- Expected: T21 design "the app keeps the latest time it has seen. A phone clock moved back before that ... needs an online check" (BILL-05, BILL-06).
- Actual: `_latestSeen` is written only in `load()` and after a successful `refresh()`. An offline user who sets the phone's clock to a fixed time T before `lease_until` each time before opening the app can use it for hours, close it, set the clock back to T, and open again: `now` is never more than 10 minutes behind the stored latest time, so the 7-day lease never ends. Going online would end the trick (a fresh `iat` is ahead of T).
- Reproduction: apps/mobile/test/licence_test.dart with a clock that reads T at each `load()`, advances 5 hours between loads, and is reset to T: the status stays `active` indefinitely.
- Proposed minimal fix: also call `_see` from the write guard (or on a periodic timer while open), so time spent in the app raises the latest time seen. Regression risk: low; a phone whose clock jumps forward and back while open would be asked to go online, which `clockSlack` already tunes.

## Missing versus spec
- DATA-01 asks for "PIN se protected key access and rate limiting". The tenant database key sits in secure storage and is not unlocked by the PIN; the PIN is a screen gate with an attempt count (D-064, D-065 chose an optional PIN). Not a defect against the decisions, but the PRD wording is not met.
- BILL-03 asks for redemption to be "rate-limited and replay-protected". No activation codes exist (out of scope by the T21 design), and `submit_slip` has no per-time rate limit beyond 3 waiting slips.
- AUTH-06 MFA for the admin, and the admin dashboard (T22), are not built; acceptance is by SQL editor.
- Turning a phone off does not end that phone's Supabase sessions (refresh tokens). Supabase offers no per-device session revocation, so this is a design gap rather than a code slip; it is what makes F01-1 and F01-4 reachable from a lost phone.

## Known-deferred noticed
- Slip files are removed before `delete_account` can refuse a company with other members (docs/LATER.md, T24).
- Abandoned uploads and removed copies wait for the next finished upload or the RUNBOOK command (D-076 (6), LATER T22).
- The add-on alone shows the on-sale price, while the cloud charges the company's own version (LATER T22).
- Payment records go with a deleted account; owner decision open (LATER).
- A web way to ask for deletion (D-067 (4), T26); another phone of the account keeps its copy until T25.
- Managers, invites and the manager phone's way back (T24); sync and server-side counts (T25).
- `db_check_screen.dart` and `spike_checks.dart` are T03 proof to delete after the phone test (PROGRESS.md Open). They only open test tenants with fixed ids `...000a`/`...000b` in the app's own folder; no security issue found.
- Copies over 50 MB need a resumable upload (LATER T20d).
