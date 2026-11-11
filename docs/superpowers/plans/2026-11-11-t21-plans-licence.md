# T21 Plans, Trial, Payment Slips and Signed Licence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this project subagents run only on the owner's word, so the owner's sessions run it natively.

**Goal:** Sell the trial and three monthly plans by bank transfer, with a server-signed licence the app trusts for at most 7 days offline, and limits no screen can miss.

**Architecture:** The cloud keeps versioned plans, the trial, slips and subscriptions in Postgres, where every rule is a server function tested by pgTAP. A thin Edge Function `licence` asks Postgres for the caller's facts, as the caller, and signs their exact bytes with an Ed25519 key it made itself and keeps in Vault. The app (T21b, T21c) checks the signature with the public half from `.env` and enforces the plan at `TenantDatabase.applyOperation`.

**Tech Stack:** Postgres 17 with pgTAP, Supabase Storage and Vault; Deno Edge Function using WebCrypto Ed25519 and `supabase-js` 2; Flutter with a pure-Dart Ed25519 package (T21b).

**Spec:** `docs/superpowers/specs/2026-11-11-t21-plans-licence-design.md`

## Global Constraints

- Money in integer fils, never `double` (CALC-01): Small 19900, Mid 29900, Large 49900; add-on 2000, 2000, 4000.
- Limits: Small 15 active workers, 5 client companies, 1 manager; Mid 35, 9, 2; Large unlimited (null). The trial: every feature, unlimited, 15 days.
- A month runs to the same day next month, clamped to that month's last day, counted from the first paid day (BILL-04, D-105), in Dubai's wall clock.
- Bank details and prices live in the cloud only. The bank name, account number, IBAN and holder never go in git (AI-05); they are typed into the live SQL editor.
- No secret typed by Claude. The signing key is made by the function and kept in Vault; only its public half leaves the cloud.
- Server-only writes for trials, slips, subscriptions and licences (MODEL-05). Tenant identity from the verified session, never the request (AUTH-02).
- The owner's yes before the migration or the function goes to the live project.
- Data is never deleted, hidden or held for money when a plan ends (PLAN-03, PLAN-06).

## Review Focus

1. **A paid customer offline across a renewal.** A prepaid next month must not drop them to safe mode: the licence's end is the end of the unbroken run of paid periods (test in Task 2).
2. **The same person taking a second trial** with `name+1@gmail.com`, `n.a.m.e@gmail.com`, a new company, or the same phone after deleting the account: all refused (tests in Task 2).
3. **A slip upload aimed at another company's folder or an invented path**, or a fourth waiting slip: refused by the storage policy and `submit_slip` (tests in Task 3).
4. **Two phones of one person both asking for a licence**, as during a move to a new phone: only the first phone still on gets one, deterministically, until the old one is turned off (test in Task 2).
5. **A renewal on the 31st** (Jan 31 + 1 month = Feb 28, + 2 months = Mar 31, leap Feb 29): the anchor holds across renewals (tests in Task 3).

---

## File Structure

| File | Responsibility |
| --- | --- |
| `supabase/migrations/20261111130000_plans_licence.sql` | Plans, settings, subscriptions, slips, claims, usage, the licence facts, slip functions, the owner's functions, the signing key keep, `delete_account` updated |
| `supabase/tests/database/plans.test.sql` | Plans and settings readable, not writable; month arithmetic |
| `supabase/tests/database/licence.test.sql` | Licence facts: membership, phones, trial once, usage, paid run, signing key keep |
| `supabase/tests/database/slips.test.sql` | Slips, storage, accept, refuse, revoke, renewal dates, deletion |
| `supabase/functions/licence/sign.ts` | Key pair, signing and verifying, no I/O |
| `supabase/functions/licence/sign_test.ts` | `node:test` tests of `sign.ts`, run by Deno on CI and Node locally |
| `supabase/functions/licence/index.ts` | The HTTP handler: GET public key, POST licence |
| `supabase/config.toml` | `[functions.licence] verify_jwt = false` (the function checks the session itself, so new publishable keys work) |
| `.github/workflows/ci.yml` | Storage started for the slip tests; a `functions` job with Deno |

---

## T21a: the cloud

### Task 1: Plans, settings and month arithmetic

**Files:** Create the migration's first part and `supabase/tests/database/plans.test.sql`.

**Interfaces:**
- Produces: `public.plans (code, version, name, price_fils, addon_price_fils, max_workers, max_clients, max_managers, on_sale, sort_order)`, primary key `(code, version)`, one version on sale per code. Seeded `trial` (not on sale), `small`, `mid`, `large`, each version 1.
- Produces: `public.platform_settings` one row (`id = true`): `bank_name`, `account_number`, `iban`, `account_holder` (all null in git), `trial_days` 15.
- Produces: `private.months_after(p_anchor timestamptz, p_months integer) returns timestamptz`, the anchor plus months on Dubai's wall clock.

- [ ] **Step 1: Write `plans.test.sql`**: a signed-in user reads 4 plans, the 3 on sale cost 19900, 29900, 49900 with limits as above; insert, update and delete on `plans` and `platform_settings` throw `42501`; `anon` reads nothing; `trial_days` is 15; `months_after('2027-01-31 10:00+04', 1) = '2027-02-28 10:00+04'`, `(…, 2) = '2027-03-31 10:00+04'`, `months_after('2028-01-31 10:00+04', 1) = '2028-02-29 10:00+04'`, `months_after('2026-11-11 23:30+04', 1) = '2026-12-11 23:30+04'` (a Dubai evening is not shifted by UTC).
- [ ] **Step 2: Write the tables, seed, grants and `months_after`.** `revoke all … from anon, authenticated; grant select … to authenticated`; RLS on with `using (true)` select policies.
- [ ] **Step 3: Push; CI's `supabase` job runs `supabase test db`.** Expected: all plans tests pass.

### Task 2: The licence facts and the trial

**Interfaces:**
- Produces: `public.subscriptions (id, tenant_id, plan_code, plan_version, source 'trial'|'slip', slip_id, starts_at_utc, ends_at_utc, anchor_at_utc, anchor_months, amount_fils, bank_reference, received_on, note, revoked_at_utc, revoke_reason, created_at_utc)`; one trial per company. Members read their company's rows.
- Produces: `private.trial_claims (hash, kind 'email'|'phone', tenant_id, claimed_at_utc)`, kept after an account is deleted; `private.email_hash(text)`, `private.phone_hash(uuid)`.
- Produces: `private.usage_reports (tenant_id primary key, device_id, active_workers, active_clients, reported_at_utc)`.
- Produces: `public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer) returns jsonb`, callable by `authenticated`:
  `{v: 1, iss: "labour-app", jti, iat, tenant_id, device_id, state: "trial"|"paid"|"none", plan, plan_version, plan_name, starts_at, ends_at, lease_until, limits: {workers, clients, managers, devices}}`. Null limit = unlimited; state `none` has limits 0.
- Produces: `public.licence_signing_key() returns jsonb` and `public.licence_signing_key_keep(p_key jsonb) returns jsonb`, `service_role` only, the key in Vault under `licence_signing_key`; keep stores only the first key and returns the kept one.
- Refusals, as exception messages the function maps: `not a member of this company`, `this phone is not registered`, `this device was revoked`, `another phone is on`, `counts out of range`.

Rules the tests pin:
- One phone per person: the caller's first phone still on (`created_at_utc`, then `id`) gets the licence; `devices` = the company's live members.
- The trial starts at the owner's first request when the company has no subscription and neither the owner's email hash nor the phone hash is claimed; then both are claimed. Email normalised: lower case, trimmed, `+tag` dropped, and for Gmail the dots too, `googlemail.com` as `gmail.com`.
- Companies made before the migration get a trial from the migration's day, and their owners' emails and phones are claimed.
- Current = the non-revoked row covering now, a paid row before the trial; `ends_at` = the end of the unbroken run of paid rows (each starting where the last ended); `lease_until = least(now + 7 days, ends_at)`.

- [ ] **Step 1: Write `licence.test.sql`**: trial state with 15 days and null limits; a second call makes no second trial; usage stored and replaced; outsider `42501`; unknown phone; second phone of the owner `another phone is on`, then turning the first off lets it in; turned-off phone refused; counts `-1` refused; a manager's first request starts no trial; a second company by the same owner gets `none`; after the owner deletes the account, a new account on that phone gets `none`; `a.b+x@gmail.com` and `ab@googlemail.com` hash alike; a paid row then a prepaid row give `ends_at` at the second's end and `lease_until` 7 days; `authenticated` cannot call the key functions; `service_role` keeps the first key only.
- [ ] **Step 2: Write the tables, hash functions, `licence_facts`, the key functions, and the backfill for existing companies.**
- [ ] **Step 3: Push; CI passes.**

### Task 3: Slips, storage and the owner's functions

**Interfaces:**
- Produces: `public.payment_slips (id, tenant_id, plan_code, plan_version, months 1..12, expected_fils, file_path unique, state 'waiting'|'accepted'|'refused', refuse_reason, submitted_by, submitted_at_utc, decided_at_utc, source_operation_id unique)`. The company's owner reads its rows.
- Produces: bucket `payment-slips`, private, 5 MiB, `image/jpeg`, `image/png`, `application/pdf`. Upload only to a waiting slip's own path, by its company's owner; the owner may read and remove their slips' files (the app removes them before an account deletion, T21b).
- Produces: `public.submit_slip(p_tenant_id uuid, p_plan_code text, p_months integer, p_file_type text, p_operation_id uuid) returns text` (the path `<tenant>/<slip>.<type>`), owner only, at most 3 waiting, a retry with the same operation id returns the same path.
- Produces, `postgres` only: `private.accept_slip(p_slip_id uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date, p_note text default null) returns uuid` (the subscription); `private.refuse_slip(p_slip_id uuid, p_reason text)`; `private.revoke_subscription(p_subscription_id uuid, p_reason text)`.
- Accept continues the latest unexpired paid row (start at its end, same anchor, months added), else starts now with a new anchor; end = `months_after(anchor, anchor_months)`.
- Changes `public.delete_account()`: usage, subscriptions and slips of the owned companies go too; the trial claims stay.

- [ ] **Step 1: Write `slips.test.sql`**: path under the company folder; manager and outsider refused; bad type, 0 or 13 months, the trial or an unknown plan refused; a fourth waiting slip refused; retry same path; upload at the path works, at another path or folder fails; another company sees no slip; `authenticated` cannot run `accept_slip`; accept makes a row from now for a month with the amount and reference; a second accept refused; accept without a reference refused; refuse needs a reason and sets it; continuation from a prepaid row keeps the anchor (Jan 31 + 2 months = Mar 31); a revoked row is not current; `delete_account` removes slips and subscriptions and keeps the claims.
- [ ] **Step 2: Write the table, bucket, policies and functions; replace `delete_account`.**
- [ ] **Step 3: Remove `storage` from the CI `supabase start -x` list. Push; CI passes.**

### Task 4: The Edge Function and its CI job

**Interfaces:**
- `sign.ts`: `type StoredKey = { private_pkcs8: string; public_raw: string }` (base64); `makeKeyPair(): Promise<StoredKey>`; `signLicence(facts: unknown, key: StoredKey): Promise<{ payload: string; sig: string }>` (base64url, no padding, the signature over the payload's exact bytes, the UTF-8 of `JSON.stringify(facts)`); `verifyLicence(licence, publicRaw: string): Promise<boolean>`.
- `index.ts`: `GET` → `{public_key}`, making and keeping the key on first run; `POST {tenant_id, device_id, active_workers, active_clients}` with the user's `Authorization` → `{payload, sig}`, or `{error}` with 400 `bad_request`, 401 `sign_in`, 403 `not_member` | `not_registered` | `phone_off` | `other_phone`, 500 `server`.

- [ ] **Step 1: Write `sign_test.ts`**: a signed licence verifies with its public half; one changed payload byte fails; another key fails; the payload decodes to the facts; the public half is 32 bytes.
- [ ] **Step 2: Run `node --test supabase/functions/licence/sign_test.ts`.** Expected: fails, no `sign.ts`.
- [ ] **Step 3: Write `sign.ts`, then `index.ts`; add the config entry and a CI job `functions`: `denoland/setup-deno@v2` (`deno-version: v2.x`), `deno check supabase/functions/licence/index.ts`, `deno test supabase/functions/licence/`.**
- [ ] **Step 4: Run the Node test.** Expected: 5 pass. Push; CI's `functions` job passes.

### Task 5: Records

- [ ] DECISIONS D-074 (the plans, prices, trial, one phone per person, months 1 to 12, 3 waiting slips, 5 MB, trial claims kept, payment rows deleted with the account, a paid slip starting at once even during the trial, the licence's fields); TEST_CASES TC-175 to TC-179; REQUIREMENTS_TRACEABILITY for BILL-02, BILL-03, BILL-05, BILL-06, PLAN-03, PLAN-04, PLAN-06; TASKS T21 IN_PROGRESS with slices; PROGRESS row T21a; RUNBOOK: going live, filling the bank details, accepting and refusing slips, seeing companies over their limit, freeing a trial claim; DATA_MODEL rows. `python tools/check_trace.py` passes. Refresh the graph.

---

## T21b: the app's licence and the plan page

### Task 6: Licence check in the app

**Files:** `apps/mobile/lib/data/licence.dart`, `apps/mobile/test/licence_test.dart`; `pubspec.yaml` gains one pure-Dart Ed25519 package (licence checked: MIT, BSD or Apache).

**Interfaces:**
- `class Licence { tenantId, deviceId, state (trial|paid|none), plan, planName, startsAt, endsAt, leaseUntil, issuedAt, limits {workers, clients, managers, devices} }` (null = unlimited).
- `Licence? verifyLicence(String payload, String sig, List<int> publicKey)`: null on a bad signature, wrong schema `v`, another tenant or another device.
- `LicenceStatus licenceStatus(Licence? l, DateTime now, DateTime latestSeen)`: `active`, `safeMode(reason)`; safe when null, state `none`, `now > leaseUntil`, or `now < latestSeen` or `now < issuedAt` (clock moved back, BILL-06).
- Fetched at start and after login when online, by `functions.invoke('licence')` with the counts from the tenant database; kept in secure storage with the latest time seen; an older `iat` than the kept one is ignored (replay).
- `LICENCE_KEY` (the base64 public half) in `.env` and `.env.example`; a build without cloud settings has no plans (development only).

- [ ] Tests: good, tampered, wrong key, wrong tenant, wrong device; lease end; clock back before latest seen and before issue; replayed older licence; `none`. Then the code. `flutter analyze && flutter test`.

### Task 7: Plan lein page, slip upload, Settings status, trial note

- Plan lein: the on-sale plans from `plans` in `sort_order` with price in AED from fils and limits ("Unlimited" for null); managers and the add-on shown as "jald aa raha"; the bank details from `platform_settings` showing only filled fields, with a copy button on the account number and the IBAN; choose plan and months (1 to 12, total shown); pick a photo or PDF up to 5 MB through the backup file channel; `submit_slip`, then upload to the returned path; the slip list with its state and the refusal reason. Hidden in a Play Store build (BILL-07).
- Settings: the plan, its end, the last check and the next check due (BILL-05).
- Home: the trial's days left from 5 days before the end.
- Account deletion first removes the company's slip files through Storage, then calls `delete_account`.
- Screens drawn as images and read by eye before an APK (the owner judges by look).

## T21c: enforcement

### Task 8: The write-path guard

- `TenantDatabase.applyOperation` asks one `PlanGuard.allows(entity, action, change)` before the transaction; refused writes raise a `PlanRefused(reason)` the screens show with a button to Plan lein.
- Safe mode allows: archiving; issuing and reprinting papers of what exists (PDFs); Excel export; backup and restore; the company profile and settings; turning a phone off. Everything else refused.
- Limits: adding or un-archiving a worker or a client company past the plan's number is refused with "Is plan mein 15 workers hain" (the number from the licence).
- Buttons for new entries show a lock in safe mode.
- Tests: each state against each kind of write; the 16th worker on Small; un-archive past the limit.

### Task 9: Over the limit

- A company over its plan (40 workers after the trial, then Small) sees "Kaun se 15 active rahein?": a list to tick; the rest are archived with history and balances untouched (PLAN-04); new entries wait until done; no data hidden.
- Tests: the chooser archives exactly the rest; balances unchanged; entries allowed after.

---

## Done for T21

All of TC-175 to TC-179, TC-012 and TC-047 run; the owner's two-phone run on the live project after the owner's yes; PROGRESS, TASKS and REQUIREMENTS_TRACEABILITY updated in the same PR.
