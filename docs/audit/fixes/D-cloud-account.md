# Fixes D: cloud copy, account and licence, app side (BUG-020 to BUG-024)

All tests below ran on this computer with `flutter test <file>`, one file at a time. No commit. Nothing under
`supabase/` was edited; the app side of BUG-023/BUG-024 follows `supabase/migrations/20261117120000_audit_fixes.sql`
as written.

Each "before" was taken on the code without the lib change (the change removed, the test run, the change put back).

## BUG-020 (F01-2, High): after a reinstall the empty company replaces this phone's own cloud copy

**REPRODUCED.**

Test: `after a reinstall the phone's empty company never replaces this same phone's earlier copy by itself (BUG-020)`,
`apps/mobile/test/cloud_copy_test.dart:130`. The cloud holds a finished copy from this phone's own id; a sender with
no kept record (fresh secure storage) runs `sendIfDue`, then `sendNow()`, then `sendNow(replace: true)`.

Before:

```
after a reinstall ... (BUG-020) [E]
  Expected: <0>
    Actual: <1>
  the cloud would take it, as the copy is from this phone, and then remove the real one
```

The fake first had to behave as the real SQL does for a same-phone copy. `backup_start` already let the same phone
through (it compares only the device id, as `20261114120000_cloud_backup.sql:121-126`); `backup_finish` did not remove
anything. Now it does, as `backup_finish` does (`cloud_backup.sql:189-196`): with the add-on active the new copy is a
kept daily copy; every other earlier finished copy without a keep goes, with its file.

Changes:
- `apps/mobile/lib/data/cloud_copy.dart:136-140`, in `_attempt` (the one place `sendIfDue` and `sendNow` both go
  through): when this install never sent a copy (`_lastAt == null`), the owner did not choose replace, the copy is not
  the one right after a copy was brought back (`_replaceNext`, D-078), and `account.cloudCopies` is not empty, it
  stops with `AccountRefused(AccountProblem.otherPhoneCopy)`. That sets the problem and the Backup page shows its
  existing question (bring that data back, or keep this phone's data). A failure to list the copies is kept as that
  failure (offline etc.), so nothing is sent.
- `apps/mobile/test/cloud_fake.dart:332-338`: `backup_finish` removes earlier unkept copies (above).

After: the test passes.

When the guard does not fire (checked by tests that stay green):
- a brand-new company's first copy: the cloud holds none (`cloud_screens_test` "a new company keeps its backup password
  and sends its first cloud copy with nothing pressed", `cloud_copy_test` first test);
- after a cloud copy is brought back (D-078): `_replaceNext` is set by `broughtBack()` (`cloud_copy_test` "once the
  cloud's newest copy is brought back", `cloud_restore_test` first test);
- the owner's "Keep this phone's data": `replace: true`;
- a phone that already sent once: `_lastAt` is set (`cloud_copy_test` first and second tests).

Existing expectation changed: `cloud_copy_test.dart:114`, in "another phone's copy is never replaced by itself":
`expect(starts(), 1)` is now `expect(starts(), 0)`. Before, the new phone asked the cloud to start and the cloud
refused (other_phone_copy). Now this phone has never sent a copy, so it asks the owner before calling the cloud at all.
The test's point (the question waits for the owner; nothing is sent) is the same and stricter. So that the cloud's own
refusal is still covered, the same test now goes on (lines 121-127): after this phone has sent, another phone's newer
copy arrives, and the next copy is refused by the cloud with `otherPhoneCopy`.

Words on the Backup page: `cloudOtherPhoneAsk` ("The copy in the cloud is from another phone. Bring that data back here
first, or send this phone's data in its place?") and `accountOtherPhoneCopy` say "another phone". After a reinstall the
copy is this phone's own earlier one, so "from another phone" is wrong for that case, though the choice it offers is
the right one. I did not change it: the Roman Urdu wording is the owner's. A wording that fits both cases would be, in
English, "The copy in the cloud may hold data this phone does not have. Bring that data back here first, or send this
phone's data in its place?", with the matching Roman Urdu in `app_en_PK.arb`. Owner to decide.

Not done: the server-side variant (a `p_first` flag on `backup_start`). A changed app can still send unasked; the
review rates the app-side guard as enough for the stock app.

Side effects to know: (1) a local-file restore (not the cloud's newest copy) on a phone that never sent leaves
`_replaceNext` unset, so the question is asked once; that is right, as the file may be older than the cloud's copy.
(2) If a first copy finished in the cloud but its answer was lost, the next try asks the question once.

## BUG-023 and BUG-024, app side (F01-1, F01-4): the cloud now asks for the password again

**REPRODUCED** (on the fake modelled on the new migration).

How `delete_account`'s "type the password again" was handled: it was never mapped. `Account.deleteAccount` always signs
in with the password first, so the refusal cannot happen, and `problemOf` turned the words into `failed`. I added the
mapping, used by both new refusals.

Fake: `FakeCloud.passwordOld` (`cloud_fake.dart:105-107`): the session's password sign-in is over ten minutes old, or it
has none. A password sign-in clears it (`:233`); an emailed code (`/auth/v1/verify`) sets it (`:221`), as a session from
a code carries no password `amr`. `turn_phone_off` refuses with `type the password again` (42501) while it is set
(`:277`); `register_device` refuses the same way for a phone in `offPhones` (`:262`), as the migration does for a
revoked owner row.

Tests:
- `turning a phone off with a password typed over ten minutes ago asks for it again, then works (BUG-023)`,
  `account_test.dart:254`.
- `an owner's phone turned off opens again only with the password typed; after an emailed code it is asked (BUG-024)`,
  `account_test.dart:272`.
- `a login in this run older than ten minutes: the cloud refuses to turn a phone off, and the password is asked
  (BUG-023)`, `account_flow_test.dart:506`.

Before (no mapping):

```
turning a phone off ... (BUG-023) [E]
  Expected: AccountProblem:<AccountProblem.passwordAgain>
    Actual: AccountProblem:<AccountProblem.failed>
an owner's phone turned off ... (BUG-024) [E]
  Expected: AccountProblem:<AccountProblem.passwordAgain>
    Actual: AccountProblem:<AccountProblem.failed>
```

Before (mapping in, `resetPassword` unchanged): the BUG-024 test failed at `openCompany` after the password reset with
`AccountRefused(AccountProblem.passwordAgain)`: a dead end, since the reset screen has no way to type the password.

Before (mapping in, PhonesScreen unchanged), widget test:

```
Expected: exactly one matching candidate
  Actual: _AncestorWidgetFinder:<Found 0 widgets with type "TextFormField" that are ancestors of widgets with text "Password": []>
the password is asked, not a dead end
```

Changes:
- `apps/mobile/lib/data/account.dart:34-36`: `AccountProblem.passwordAgain`.
- `account.dart:502`: `PostgrestException` whose message contains `type the password again` maps to `passwordAgain`.
- `account.dart:153-155`, `resetPassword`: after setting the new password, signs in with it, so the session carries a
  password typed just now and `openCompany` can turn the owner's switched-off phone back on.
- `apps/mobile/lib/features/account/account_screens.dart:36`: the text for `passwordAgain`.
- `account_screens.dart:791-802`, `PhonesScreen._turnOff`: on `passwordAgain` the page goes back to its password step
  (the list is hidden, the password field shows) and the refusal's words show; after the password the list comes back
  and the owner taps Turn off again.
- `apps/mobile/lib/l10n/app_en.arb:2406`, `app_en_PK.arb:1074`: `accountPasswordAgain`, "For this step, type your
  login password again." / "Is kaam ke liye apna login password dobara likhein." `flutter gen-l10n` run.

Sibling callers of `register_device` (only `_enrol`):
- `openCompany`, called only from `_afterSignIn` (LoginScreen after a password login; CodeScreen after a signup code,
  a password reset, or a password login for the link-only email). After a password login the password is seconds old.
  After a signup code the user has no company, so `createCompany` runs instead. After a reset, fixed above. If the
  refusal still reaches the login screen it now says to type the password again, and the login screen has the field.
- `createCompany`: always a new device row for the new company, never a revoked one, so never refused.
- Restore and account switch do not call `register_device` (grep of `lib/`).
- `turn_phone_off` is called only from `PhonesScreen`.

Not done: the app's `signedIn` still means "a password typed in this run", not "in the last ten minutes". The cloud is
what decides, and its refusal now leads to the password, so a local timer would only save one round trip.

## BUG-021 (F01-7, Low): deleting the account when the answer is lost

**REPRODUCED.**

Test: `a deletion whose answer was lost finishes on the retry once the cloud says the login is gone; no answer never
does (BUG-021)`, `account_test.dart:177`. Fake: `deleteAnswerLost` (`cloud_fake.dart:40-41`, `:402`) commits the
delete and then drops the connection; `GET /auth/v1/user` (`:235-239`) answers 403 `user_not_found` for a user who no
longer exists, as GoTrue does.

Before:

```
a deletion whose answer was lost ... (BUG-021) [E]
  AccountRefused(AccountProblem.wrongLogin)
```

Change, `apps/mobile/lib/data/account.dart:433-458`, `deleteAccount`:
- `_deleteSent` is set just before `delete_account` is sent.
- On a retry with `_deleteSent`, it first asks GoTrue for the signed-in user (`_userGone`). Only an `AuthException`
  with code `user_not_found` counts as gone; a network error, a server error or any other answer is "not gone" and the
  normal path runs (so offline still says offline). When gone, `deleteAccount` returns normally and the caller
  (`root.dart` `_deleteAccount`) runs `_leave(LoginNote.accountDeleted)`, the same path as a normal delete.

After: passes; the test also checks that with no network the retry says offline, and that `delete_account` is sent
once only.

Left open (marked `ponytail:` in the code): `_deleteSent` is kept in memory, so a retry after the app restarts still
says "wrong login". Keeping it in secure storage would cover that. Also, if the session's access token expired (one
hour) before the retry, GoTrue answers `bad_jwt`, not `user_not_found`, and the retry says "wrong login" as before.
A retry that is recognised as gone does not check the typed password; the account is already gone in the cloud, so
the password has nothing left to protect except this phone's copy, which D-066 says goes too.

## BUG-022 (F01-8, Low): the latest time seen moves only at load and after a check

**REPRODUCED.**

Tests, `apps/mobile/test/licence_test.dart`:
- `time spent in the app moves the latest time seen, so a clock set back to the same time each start needs a check
  (BUG-022)` (line 253): eight offline days, the clock set to the same time before each start, five hours of use with
  the plan read (as the write guard reads it on each entry).
- `reading the plan before the kept time is read never moves it back (BUG-022)` (line 271): guards the fix itself.

Before:

```
time spent in the app ... (BUG-022) [E]
  Expected: LicenceStatus:<LicenceStatus.clockBack>
    Actual: LicenceStatus:<LicenceStatus.active>
  day 1
```

Change, `apps/mobile/lib/data/licence.dart:156-163`: the `view` getter, which the write guard (`root.dart:101`,
`planGuard`) reads on every write, also moves the latest time seen forward to now (in memory at once, kept in storage
without waiting), never back, only once the kept time has been read in `load()`, and at most once a minute so each
entry does not write the secure store. `clockSlack` and `licenceStatus` are unchanged.

The second test failed when the "only once loaded" condition was taken out (`Expected: clockBack, Actual: active`): a
read before `load()` would have written a time earlier than the kept one.

## Test runs after all fixes

Each file run by itself, after every fix was in:

| File | Result |
| --- | --- |
| cloud_copy_test | +9, all passed |
| cloud_screens_test | +4, all passed |
| cloud_restore_test | +3, 1 skipped (`playStoreBuild`, as before), all passed |
| account_test | +21, all passed |
| account_flow_test | +27, all passed |
| licence_test | +17, all passed |
| plan_guard_test | +16, all passed |
| backup_test | +5, all passed |
| restore_test | +5, all passed |

## flutter analyze

`cd apps/mobile && flutter analyze`: No issues found! (ran in 108.5s)
