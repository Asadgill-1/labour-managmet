# Fixes E: cloud SQL (BUG-023 to BUG-027)

None of this has been run. `supabase test db` on CI is the first real check.

Docker and Deno cannot run on this computer, so everything below was checked by reading only. Files changed, all
under `supabase/`:

- `supabase/migrations/20261117120000_audit_fixes.sql` (new): replaces `public.turn_phone_off`,
  `public.register_device` and `private.accept_slip`.
- `supabase/tests/database/phone_off.test.sql`, `slips.test.sql`, `licence.test.sql`, `cloud_backup.test.sql`.

No applied migration was edited. Each function is replaced with `create or replace` and the same signature, the same
`language plpgsql`, the same `security definer set search_path = ''` (or, for `accept_slip`, the same plain
`set search_path = ''` with no `security definer`). `create or replace` keeps a function's privileges, so the grants
stay as the earlier migrations set them: `turn_phone_off` and `register_device` revoked from `public, anon` and
granted to `authenticated`; `accept_slip` revoked from `public`. No `revoke`/`grant` is stated again, the same way
the earlier replacements in `20261109120000`, `20261111120000` and `20261114120000` left them out ("Replacing it
keeps its grants").

I checked each body by diffing it against the newest earlier definition. The only differences are the lines named
below.

## BUG-023 (F01-1, High): `turn_phone_off` takes any owner session

**Change.** `20261117120000_audit_fixes.sql` lines 8-31. The starting point is `20261111120000_phone_off.sql`
lines 7-23, the only definition. After the "not a phone of yours" check (lines 14-17) comes the check from
`delete_account`, copied character for character (lines 18-25):

```sql
if not exists (
  select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
  where a ->> 'method' = 'password' and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 600
) then
  raise exception 'type the password again' using errcode = '42501';
end if;
```

**Why it is correct.**
- `auth.jwt()` reads the verified claims PostgREST put in `request.jwt.claims`. Supabase Auth writes `amr` as an
  array of `{method, timestamp}`, and a token refresh keeps the original sign-in timestamp. So a refresh token kept
  on a lost phone yields `amr` entries whose password `timestamp` is the old sign-in time. They fail the
  600-second window, and the call raises before the `update`.
- A missing `amr` becomes `'[]'`, which gives no rows, so `not exists` is true and the call raises. An `otp` entry
  (an email code) has the wrong `method` and also raises.
- The check comes after "not a phone of yours". A stranger or a manager reaching for the owner's phone still gets
  that same message, and the existing tests for those two cases pass unchanged. The check covers every caller who
  gets past that point: the owner, and a member turning off their own phone. D-073 (2) asks for the password for
  the step as a whole.
- The message text and errcode `42501` are identical to `delete_account`'s, so the app can treat both the same way.
- A retry on a phone already off now also needs a fresh password. Without one, the retry is refused and nothing
  changes, since nothing would have changed anyway. With one, the call is a no-op as before (MODEL-06 holds).

**App side (another engineer, not done here).** `Account.turnPhoneOff` (apps/mobile/lib/data/account.dart:322) must
map the refusal `type the password again` to the password prompt, call `signInAgain`, and retry.

D-073 (2) lets the page skip the password "if the user signed in during this run of the app". The cloud now accepts
that sign-in only for 10 minutes after the password was typed. So a session signed in earlier in the run will be
asked again. This narrows a permission rule. It probably needs a line in DECISIONS.md (AI-07), which is outside
`supabase/` and is not written here.

## BUG-024 (F01-4, Medium): `register_device` turns an owner's switched-off phone back on for any session

**Change.** `20261117120000_audit_fixes.sql` lines 35-70. The starting point is `20261111120000_phone_off.sql`
lines 40-68, the newest definition. After the manager check (lines 55-57) there is one new block (lines 58-64):
`if v_row.revoked_at_utc is not null and not exists (<the same amr check>) then raise 'type the password again'`.

**Why it is correct, path by path.**
- Not a member, or the phone held by another account: these are refused as before, ahead of the new block.
- First registration (`not found`): the function inserts and returns at lines 49-53, before the new block, so it
  needs no password. This matters because the signup path (`confirmSignup`, whose `amr` is `otp`) reaches
  `createCompany` and then `_enrol` and `register_device` with a new row.
- A phone that is on (`revoked_at_utc is null`): both conditions on the new block are false (`null is not null` is
  false and `and` short-circuits), so it updates as before with no password. The new test "a phone that is on signs
  in again with no password typed" pins this down.
- A manager's revoked phone: it is refused at line 55 with `this device was revoked`, as before, ahead of the new
  block. The existing test passes unchanged.
- An owner's revoked phone: it needs a password `amr` entry no older than 600 seconds, else
  `type the password again`. With one, it updates as before: `revoked_at_utc = null` and the new label.
- The block is reached only when `v_role = 'owner'`, because any other role with a revoked row raised at line 55.

**How the app calls it.** `_enrol` (account.dart:185-199) is called only from `openCompany` (after a sign-in, from
`_afterSignIn`) and from `createCompany`. Neither runs on a resumed session at app start (`resume()` does not call
it). After the normal `signIn` (`signInWithPassword`), `amr` holds a fresh password entry, so reviving the old phone
right after typing the password works as D-073 (4) says.

**Regression to know about.** `_afterSignIn` also runs after a password reset (`resetPassword`, which is
`verifyOTP(recovery)` then `updateUser`, account_screens.dart:286-294). That session's `amr` is a recovery or OTP
entry, not `password`. I did not check whether GoTrue adds a password entry on `updateUser`, and I believe it does
not. So an owner who resets the password on a turned-off phone would get `type the password again` from
`openCompany`. The app should then ask for the new password, sign in, and call `openCompany` again. F01-4 noted the
same limit. The app engineer should map this refusal in `openCompany` too, not only in `turnPhoneOff`.

## BUG-026 (F01-6, Low): `accept_slip` locks only the slip

**Change.** `20261117120000_audit_fixes.sql` lines 74-130. The starting point is `20261114120000_cloud_backup.sql`
lines 311-366, the newest definition (it replaced the one in `20261111130000_plans_licence.sql`). One line was added
at line 93, right after the slip is read and found:
`perform 1 from public.tenants t where t.tenant_id = v_slip.tenant_id for update;`

**Why it is correct.**
- Two sessions accepting slip 1 and slip 2 of one company: each locks its own slip, then both ask for the company's
  row. The second waits until the first commits. The second's later `select ... from public.subscriptions` is a new
  statement, so under READ COMMITTED it takes a new snapshot and sees the period the first one made. It then
  continues from that period's end instead of starting from the same `v_prev`.
- It sits after `if not found`, so `v_slip.tenant_id` is set. It sits before the state check, which is harmless,
  since the slip row is already locked by this transaction.
- Lock order is slip, then company. No other function locks a company row first and then an existing slip row:
  - `submit_slip` locks the company and inserts a new slip.
  - `refuse_slip` takes only the slip.
  - `delete_account` deletes slips before it deletes the tenant, which is the same order as here.
  So this adds no deadlock. The subscription insert's foreign-key share lock on the tenant row is already covered by
  this transaction's own `for update`.
- `perform 1 ... for update` is the exact form `submit_slip`, `backup_start` and `backup_finish` already use.

## BUG-027 (F01-5, Low): slips.test.sql stops passing on 2027-02-28

**Change.** `supabase/tests/database/slips.test.sql` lines 177-206 (test only).
- A `do` block stores `test.year` as next year in Dubai.
- The fixture period is built with `make_timestamptz(y, 1, 31, 10, 0, 0, 'Asia/Dubai')` (start and anchor) and
  `make_timestamptz(y, 3, 1, 10, 0, 0, 'Asia/Dubai') - interval '24 hours'` (end, Feb's last day 10:00 Dubai, whether
  Feb 28 or 29).
- The expected result is that same end as the start, and `make_timestamptz(y, 4, 30, 10, 0, 0, 'Asia/Dubai')` as
  the end.

**Why it is correct.**
- The period lies in next year, so its `ends_at_utc > now()` on any day the test runs. `accept_slip` therefore
  always picks it as `v_prev`. Tenant `...0002` has no other subscription: no trial is ever made in this file,
  because `licence_facts` is not called.
- `accept_slip` computes `v_months = 1 + 2 = 3` and `months_after(Jan 31 10:00 Dubai, 3)`. The anchor
  `at time zone 'Asia/Dubai'` is the wall time `y-01-31 10:00`. Adding 3 months gives `y-04-30 10:00` (Postgres
  clamps to the month's end). Turning that back `at time zone 'Asia/Dubai'` gives exactly
  `make_timestamptz(y, 4, 30, 10, 0, 0, 'Asia/Dubai')`. The start is `v_prev.ends_at_utc`, the fixture's end.
- What the test proves is kept: the end is Apr 30, not Apr 28 or 29. Feb's last day plus two months would give that,
  so the anchor day holds. The expected values are written out with `make_timestamptz`, not computed with
  `months_after`, so the test does not grade the function with itself.
- `interval '24 hours'` rather than `'1 day'`, so the session's TimeZone setting cannot shift it. Dubai has no DST.
- In a leap year (a run in 2027 builds 2028), the fixture ends Feb 29 and the result is still Apr 30.

## BUG-025 (F01-3, Medium): many unfinished 50 MB uploads per company. Not written.

The suggested change is: while an unfinished upload younger than the link's life exists, hand back its path instead
of making another. It is not safe by reading alone, for these reasons:

1. **The operation id does not match.** The app makes a new `operation_id` for every send
   (account.dart:250) and calls `finish` with it. `backup_finish` finds the row by `source_operation_id =
   p_operation_id`. A reused earlier row carries the old id, so `finish` raises `no such copy` and every send after
   an interrupted one fails until the earlier upload is two hours old. The retry path that `backup_start` supports
   today works only because the app repeats the same operation id.
2. **Rebinding the row would be wrong too.** If `backup_start` instead moved the earlier row to the new operation id:
   - when the earlier upload had arrived but was never finished, `arrived` would be true. The app would skip the
     upload and finish the older file as if it were the current data, and the cloud would quietly hold stale books;
   - when the earlier file had not arrived, the backup function would call `createSignedUploadUrl` again on a path
     whose first upload may still be under way. Two uploads would race on one object, or the second would fail
     because the object exists.
3. **Refusing instead needs app work.** A "wait, an upload is under way" refusal needs a new word in
   `supabase/functions/backup/request.ts` and the app's mapping. It would also block a real retry after a crash for
   up to two hours, which goes against D-076 (6), "an upload left unfinished gives way".

**Options, for the owner to choose.**
- **A, recommended.** Cap the unfinished uploads a company may hold, not the starts. In `backup_start`, before making
  a new row, count the company's `private.backup_removals` rows with `remove_after_utc > now()`. Those are exactly
  the abandoned uploads still inside their three hours: copies that left the list are queued at `now()`, and a
  deleted company cannot start at all. Refuse when the count is 2 or 3 or more, reusing the existing words
  `too many copies today` (already mapped to `too_many`/429 in the app) or a new word. This bounds one company to
  about (N+1) x 50 MB of unfinished files at once. A crash retry still works, and the daily cap of 20 stays. It
  needs a test in `cloud_backup.test.sql`, and an owner decision on N and on the words (AI-07, retention and limits).
- **B.** Remove abandoned files sooner. Have the backup function run `removeDue` on `start` as well as on `finish`,
  or on a schedule. This does not shorten the three hours, since the link lives two, but it stops files waiting
  past them for the next finished upload.
- **C.** The same as A, plus a cap on companies per verified user in `create_tenant` (F01-3's second half). Left
  out on instruction.
- **D.** Bind the upload's size. The size the phone declares is not enforced by the upload link, so a cap in bytes
  per day is not effective without it.

## Existing tests changed, and why

| File | Line | Change | Why |
| --- | --- | --- | --- |
| phone_off.test.sql | 77 | fresh password `amr` claim before "the owner turns the old phone off" and the two calls after it | those calls must still pass, and now need the password |
| phone_off.test.sql | 113-117 | fresh password `amr` claim before "the owner signs in on the old phone again" (the label now says "with the password") | reviving the owner's phone now needs the password |
| licence.test.sql | 90-91 | fresh password `amr` claim before "the owner turns the first phone off" | `turn_phone_off` needs the password |
| cloud_backup.test.sql | 232-233 | fresh password `amr` claim before "the owner turns the old phone off" | the same |
| slips.test.sql | 177-206 | fixture and expected values moved from fixed 2027 dates to next year's | BUG-027 |

The claims are built the way the existing `delete_account` tests build them: `set_config('request.jwt.claims',
jsonb_build_object(... 'amr', jsonb_build_array(jsonb_build_object('method', 'password', 'timestamp',
extract(epoch from now())::bigint)))::text, true)`. That claim stays in force for the calls that follow until the
next claims change. Those calls (`backup_start`, `backup_download`, `submit_slip`, `licence_facts`) ignore `amr`.

Checked and left as they are:
- phones.test.sql:46, which runs `register_device` after a revoke by hand. It is Beta's first registration in Beta's
  own company, so no row is revoked.
- licence.test.sql:146, a new account's first registration, after the earlier row was deleted.
- phone_off.test.sql:49 and :54, the stranger and the manager calling `turn_phone_off`, still refused with
  `not a phone of yours`.
- phone_off.test.sql:93, the manager reviving, still refused with `this device was revoked`.

No assertion was deleted or loosened.

## New tests and plan counts

**phone_off.test.sql: plan 17, plus 7, gives 24.**
1. `turn_phone_off` with no `amr` raises `type the password again`.
2. The same with a password `amr` 601 seconds old.
3. The same with a fresh `otp` `amr`.
4. `register_device` refreshing a phone that is on, with no `amr`, lives.
5. `register_device` reviving the owner's off phone with no `amr` raises `type the password again`.
6. The same with a password `amr` 601 seconds old.
7. `phone_is_off` is still true after those refusals.

The allowed cases are the existing tests, now with a fresh password `amr`. The existing "the second time changed
nothing" (version 2) also shows the three refused calls changed nothing.

**slips.test.sql: plan 40, plus 1, gives 41.** The new test checks that `pg_get_functiondef` of `accept_slip`
contains the company lock line. One session cannot race another in pgTAP, so this is the practical guard F01-6
proposes. The serial case, where a second accept continues from the first, is already covered by "an early renewal
continues from the end of the paid month".

**licence.test.sql: plan 47, unchanged. cloud_backup.test.sql: plan 91, unchanged.** These only gained a claims line,
which is not a test.

I counted each plan twice: once by hand while editing, and once by counting lines that start with a pgTAP assertion
(`lives_ok|throws_ok|is|isnt|ok|results_eq|is_empty`) in each file. The counts are 24, 41, 47 and 91, matching
`plan(n)`.

## For the owner: what must happen before these fixes protect the live project

1. Push the branch and get the `supabase` CI job green (`supabase test db`). That job is the first time any of this
   runs.
2. `20261117120000_audit_fixes.sql` replaces `accept_slip` with its add-on form, which reads `payment_slips.covers`
   and `subscriptions.kind`. Those columns come from `20261114120000_cloud_backup.sql`, which the RUNBOOK says is not
   live yet. So on the live project, `20261114120000_cloud_backup` must be applied first, as its own RUNBOOK step,
   then this migration. Applying this one alone would create a function that fails when a slip is accepted.
3. On the owner's yes, apply `20261117120000_audit_fixes.sql` to the live project the way `docs/RUNBOOK.md`
   describes: through the dashboard's SQL editor (it is under 10 KB, so one part), with its row recorded in
   `supabase_migrations.schema_migrations`, or by `supabase db push` once the CLI is linked.
4. Ship the app change that maps `type the password again` to the password prompt for turning a phone off and for
   opening the company on a turned-off phone. Until then, an owner whose sign-in is older than 10 minutes sees a
   generic error on those two steps. The server side is still safe without it.
5. Decide BUG-025 (options above). The storage gap stays open until then.
