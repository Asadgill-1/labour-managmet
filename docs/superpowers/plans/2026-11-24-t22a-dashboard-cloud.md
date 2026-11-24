# T22a: the dashboard's cloud side Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything part 1 of the owner's dashboard needs from Postgres: the admin check with MFA, the audit log, the owner's actions on accounts and money, holds and limit overrides reaching the licence, and the read functions the pages draw from.

**Architecture:** One migration adds private tables and `public.admin_*` functions, each `security definer`, each calling `private.require_admin()` first and writing `private.admin_actions` in the same transaction. Reads return `jsonb` for the browser to filter, sort and page. `licence_facts` learns holds, overrides, given periods and the app's version; the `licence` function passes the version through.

**Tech Stack:** Postgres 17 on Supabase, PL/pgSQL, pgTAP (`supabase test db`, run in CI since Docker cannot start here), Deno for the `licence` function.

**Spec:** `docs/superpowers/specs/2026-11-22-t22-owner-dashboard-design.md` (D-081).

## Global Constraints

- Amounts are integer fils (`bigint`); no `numeric` money, no floats (CALC-01).
- Every row of a tenant's data has `tenant_id`; the new tenant tables reference `public.tenants (tenant_id) on delete cascade`, so `delete_account` removes them (D-066). `private.admin_actions` keeps no foreign key and outlives the account: it is the platform's own record of money and account actions.
- Every write function takes a reason of 3 characters or more, except `admin_note` (the note is its own reason) and `admin_accept_slip` (the bank reference is).
- Money rows are never updated: `subscriptions` gains only `revoked_at_utc` through `private.revoke_subscription`, as today; corrections and refunds are new rows.
- The admin check: a row in `private.platform_admins` for `auth.uid()` and `auth.jwt() ->> 'aal' = 'aal2'`. Holds and money entries also need a TOTP check in the last 300 seconds (`amr` method `totp`).
- Replacing an existing function keeps its grants (`create or replace` with the same signature); a changed signature drops the old one and grants the new one to `authenticated` only.
- Refusal messages are plain English sentences raised with `errcode = '42501'` for permission and `'22023'` for bad input, as the existing functions do.

## Review Focus

- A customer signed in at `aal1` or `aal2` who is not in `platform_admins` calls an `admin_` function: refused, and nothing written. (Task 1 tests.)
- The owner at `aal1` (password only, no TOTP): refused for every `admin_` function. (Task 1 tests.)
- An old app (no `p_app_version`) calls `licence_facts` with four arguments after the migration: still served. (Task 3 test.)
- A held account's licence says `state = 'none'`, so an old app that ignores `hold` still locks entries. (Task 3 test.)
- A suspension with an end date in the past no longer holds. (Task 3 test.)

---

### Task 1: Admins, the MFA check and the audit log

**Files:**
- Create: `supabase/migrations/20261124120000_owner_dashboard.sql`
- Create: `supabase/tests/database/admin.test.sql`

**Interfaces:**
- Produces: `private.platform_admins (user_id uuid primary key references auth.users on delete cascade, role text not null default 'owner' check (role = 'owner'), added_at_utc timestamptz not null default now())`; `private.is_platform_admin() returns boolean`; `private.require_admin() returns void` (raises `'admins only'`, 42501); `private.require_recent_mfa() returns void` (raises `'type the code again'`, 42501); `private.log_action(p_action text, p_tenant uuid, p_target uuid, p_reason text, p_before jsonb, p_after jsonb) returns void` (raises `'say why'`, 22023, under 3 characters); `private.admin_actions (id uuid pk, at_utc, actor_id uuid, action text, tenant_id uuid, target_id uuid, reason text, before jsonb, after jsonb)`, update and delete refused by a trigger; `private.tenant_notes (id, tenant_id references tenants on delete cascade, body text 1..2000, at_utc, actor_id)`, also append-only.
- Also: `public.tenants.is_test boolean not null default false`; `public.devices.app_version text check (char_length(app_version) <= 40)`; `public.payment_slips.payer_bank text check (1..100)`, `payer_last4 text check (payer_last4 ~ '^[0-9]{4}$')`; `subscriptions` accepts `source = 'grant'` (amount 0, no slip) for the plan and the add-on; a storage policy `payment_slips_for_admins` lets admins read the `payment-slips` bucket.

- [ ] **Step 1: Write the failing tests** in `admin.test.sql`, users: owner admin `aaaa…1`, customer `1111…1` with a company, stranger `3333…3`:
  - `select ok(not has_function_privilege('anon', 'public.admin_overview(timestamptz, timestamptz, boolean)', 'execute'), 'a visitor cannot read the dashboard')`
  - as the customer at `aal2`: `throws_ok('select public.admin_overview(now() - interval ''30 days'', now(), false)', '42501', 'admins only')`
  - as the owner at `aal1`: the same refusal.
  - as the owner at `aal2`: `lives_ok` on `admin_overview`.
  - `throws_ok($$ update private.admin_actions set reason = 'x' $$, 'P0001', 'the audit log is never changed')` and the same for `delete`.
  - `throws_ok` a grant period with `amount_fils = 100`; `lives_ok` a grant add-on period with amount 0.
  - `throws_ok` `payer_last4 = '12a4'`.
- [ ] **Step 2:** Push the branch; CI's `supabase test db` fails on the missing functions.
- [ ] **Step 3: Implement** the tables, columns, constraints, the four `private` functions, the triggers and the storage policy in the migration. The old unnamed checks on `subscriptions` (`source in ('trial', 'slip')` and the trial-or-slip-with-payment check) and `addon_is_paid` are dropped by a `do` block that finds them through `pg_get_constraintdef`, then re-added by name: `subscriptions_source_known`, `slip_periods_carry_payment`, `given_periods_are_free (source <> 'grant' or amount_fils = 0)`, `addon_is_paid_or_given (kind = 'plan' or source in ('slip', 'grant'))`.
- [ ] **Step 4:** CI passes this task's tests.

### Task 2: The owner's actions

**Files:**
- Modify: `supabase/migrations/20261124120000_owner_dashboard.sql`
- Modify: `supabase/tests/database/admin.test.sql`

**Interfaces:**
- Consumes: Task 1's `private.require_admin`, `private.require_recent_mfa`, `private.log_action`; the existing `private.accept_slip(uuid, bigint, text, date, text)`, `private.refuse_slip(uuid, text)`, `private.revoke_subscription(uuid, text)`, `private.email_hash(text)`.
- Produces, all `public`, `security definer`, granted to `authenticated` only, each logging one `admin_actions` row named after itself without the `admin_` prefix:
  - `admin_accept_slip(p_slip uuid, p_amount_fils bigint, p_bank_reference text, p_received_on date, p_payer_bank text, p_payer_last4 text, p_note text default null) returns uuid`
  - `admin_refuse_slip(p_slip uuid, p_reason text) returns void`
  - `admin_revoke_period(p_period uuid, p_reason text) returns void`
  - `admin_give_days(p_tenant uuid, p_kind text, p_plan_code text, p_days integer, p_reason text) returns uuid`: a `grant` period of 1 to 366 days, starting at the end of the tenant's unbroken run of that kind or now; `p_plan_code` null takes the current plan's code and its version; `'trial'` gives the trial again.
  - `admin_limit_override(p_tenant uuid, p_what text, p_cap integer, p_until timestamptz, p_reason text) returns uuid` and `admin_end_override(p_override uuid, p_reason text) returns void`, over `private.limit_overrides (id, tenant_id, what in ('workers', 'clients', 'managers'), cap integer >= 0, until_utc, reason, created_at_utc, created_by, ended_at_utc)`.
  - `admin_money_entry(p_tenant uuid, p_kind text, p_period uuid, p_amount_fils bigint, p_field text, p_value text, p_reference text, p_on_date date, p_reason text) returns uuid` over `private.money_entries (id, tenant_id, kind in ('refund', 'correction'), subscription_id references subscriptions on delete cascade, amount_fils >= 0, field, value, reference, on_date, reason, created_at_utc, created_by)`; a refund needs an amount above 0 and at most the period's amount less earlier refunds; a correction needs `p_field` in `('received_on', 'bank_reference', 'amount_fils', 'payer_bank', 'payer_last4')` and a value. Needs recent MFA.
  - `admin_hold(p_tenant uuid, p_kind text, p_until timestamptz, p_told text, p_note text, p_reason text) returns uuid` and `admin_lift_hold(p_hold uuid, p_reason text) returns void`, over `private.tenant_holds (id, tenant_id, kind in ('suspend', 'block'), until_utc, told text 1..300, note, created_at_utc, created_by, lifted_at_utc, lifted_by, lift_reason)`; one live hold per tenant; `p_until` in the past refused. Both need recent MFA.
  - `admin_free_trial_claim(p_email text, p_reason text) returns integer` (claims removed)
  - `admin_set_test(p_tenant uuid, p_is_test boolean, p_reason text)`, `admin_rename(p_tenant uuid, p_name text, p_reason text)`, `admin_note(p_tenant uuid, p_body text)`, `admin_phone(p_device_row uuid, p_off boolean, p_reason text)`, all `returns void`.
  - `admin_add_cost(p_month date, p_item text, p_amount_fils bigint, p_note text) returns uuid` over `private.platform_costs (id, month date (first of month), item 1..100, amount_fils >= 0, note, created_at_utc, created_by)`, and `admin_save_settings(p_bank_name text, p_account_number text, p_iban text, p_account_holder text, p_support_contact text, p_reason text) returns void`.

- [ ] **Step 1: Write the failing tests**: an accepted slip makes its period and keeps `payer_bank` and `payer_last4`; a refused slip keeps its reason; each action leaves exactly one `admin_actions` row with the actor and reason; `admin_give_days(…, 'plan', null, 10, …)` after a paid period starts at its end; a hold without a TOTP in the last 300 seconds is refused with `'type the code again'`; a second live hold is refused; a refund above what was paid is refused; `admin_free_trial_claim` returns 2 for an email and phone pair claimed together; renaming keeps the old name in `before`.
- [ ] **Step 2:** CI fails on them.
- [ ] **Step 3: Implement** the tables and functions. `admin_accept_slip` sets the payer columns, then calls `private.accept_slip`; the reason it logs is `'bank reference ' || p_bank_reference`.
- [ ] **Step 4:** CI passes.

### Task 3: The licence knows holds, overrides, given periods and the version

**Files:**
- Modify: `supabase/migrations/20261124120000_owner_dashboard.sql`
- Modify: `supabase/functions/licence/index.ts`
- Modify: `supabase/tests/database/admin.test.sql`

**Interfaces:**
- Consumes: Tasks 1 and 2's tables.
- Produces: `public.licence_facts(p_tenant_id uuid, p_device_id uuid, p_active_workers integer, p_active_clients integer, p_app_version text default null) returns jsonb`, the four-argument one dropped; each call sets the device's `last_seen_at_utc` to now and its `app_version` when given, so the dashboard's "last online" is the last licence check (ADMIN-05); the licence gains `"hold": {"kind", "until", "told"}` or `null`; while a hold is live the state is `'none'` and the limits are 0, as with no period; `limits` take the higher of the plan's and a live override's cap; a `grant` period counts as paid for the run of paid periods, and the state is `'trial'` only when the period's plan is `trial`. `private.accept_slip` continues after a running `grant` period as after a paid one. `register_device` refuses a new phone while a `block` hold is live: `'this account is blocked'`, 42501. The `licence` function sends `p_app_version` when the body's `app_version` is a string of 1 to 40 characters.

- [ ] **Step 1: Write the failing tests**: the version lands on the device row; a four-argument call still lives; a live suspension gives `state = 'none'` and the `told` text; a suspension whose `until` passed does not hold; a block refuses `register_device` for a new phone; an override of 40 workers on Small gives `limits.workers = 40`; ten given days after a paid period keep `state = 'paid'` and move `ends_at` 10 days on; a given trial gives `state = 'trial'`.
- [ ] **Step 2:** CI fails.
- [ ] **Step 3: Implement**, replacing `licence_facts`, `private.accept_slip` and `public.register_device` from their latest versions (`20261114120000_cloud_backup.sql`, `20261117120000_audit_fixes.sql`) with only these changes.
- [ ] **Step 4:** CI passes, `deno check` included.

### Task 4: What the pages read

**Files:**
- Modify: `supabase/migrations/20261124120000_owner_dashboard.sql`
- Modify: `supabase/tests/database/admin.test.sql`

**Interfaces:**
- Consumes: everything above, `public.tenants`, `memberships`, `devices`, `subscriptions`, `payment_slips`, `plans`, `cloud_backups`, `private.usage_reports`, `auth.users`.
- Produces, `public`, `security definer`, admin only, no log row:
  - `admin_overview(p_from timestamptz, p_to timestamptz, p_include_test boolean) returns jsonb` with `fetched_at`, `accounts {total, trial, paying, ended, held}`, `mrr_fils` at `p_to`, `cash_fils` (accepted slips whose `received_on` falls in the range, less refunds by `on_date`), `trial_to_paid {started, paid}` (trials started in the range and those with a slip accepted since), `slips_waiting`, `today` (lists: waiting slips, slips older than a day whose file is missing from storage, accounts over a limit, trials ending in 5 days, accounts with no device seen in 7 days), `cash_by_month` (12 months to `p_to`), `mrr_bridge` for the month holding `p_to` (`opening, new, expansion, reactivation, contraction, churn, closing`), `plan_mix`, `costs_fils` for that month.
  - `admin_accounts(p_include_test boolean) returns jsonb`: one object per tenant with id, name, owner email and its confirmation, created, state, plan, plan end, add-on end, phones on, last seen, newest app version, workers and clients from the last usage report, the live hold, waiting slips, paid total, `is_test`.
  - `admin_account(p_tenant uuid) returns jsonb`: the above for one, plus members, devices, periods, slips, money entries, holds, overrides, notes, cloud copies, and `story`: dated events from those tables and `admin_actions`, newest first.
  - `admin_slips(p_from timestamptz, p_to timestamptz) returns jsonb`: every slip submitted in the range with its tenant, sender's email and role, periods made, and the money entries against them.
  - `admin_audit(p_from timestamptz, p_to timestamptz) returns jsonb`: actions in the range with the actor's email, newest first, at most 5,000.
  - `admin_settings() returns jsonb`: admins with whether they have a verified TOTP factor, `platform_settings`, plans, costs by month, test accounts.
- MRR at an instant: for each non-test tenant, the plan price of its paid or given period covering the instant (0 for given and trial periods) plus the add-on price of its add-on period covering it, from the period's own price version. The bridge per tenant from `o` (opening) to `c` (closing): new when `o = 0` and `c > 0` and no paid period before the month; reactivation when `o = 0`, `c > 0` and one before; expansion `c - o` when `c > o > 0`; contraction `o - c` when `0 < c < o`; churn `o` when `c = 0 < o`.

- [ ] **Step 1: Write the failing tests**: with four sample tenants (one new Small, one Small to Mid with the add-on, one churned Small, one trial) the bridge reads opening 39800, new 19900, expansion 12000, churn 19900, closing 51800 and `opening + new + expansion + reactivation - contraction - churn = closing`; a test tenant is left out unless asked; `cash_fils` subtracts a refund; `admin_accounts` has one row per tenant; `admin_account` of an unknown id raises `'no such account'`; `admin_audit` returns the actions written by Task 2's tests.
- [ ] **Step 2:** CI fails.
- [ ] **Step 3: Implement.** `-- ponytail:` on `admin_accounts`: every account at once, the browser filters; page in Postgres past about 2,000 accounts.
- [ ] **Step 4:** CI passes.

### Task 5: Records

**Files:**
- Modify: `DECISIONS.md` (D-081 to ACCEPTED, approved 2026-11-24), `TASKS.md`, `PROGRESS.md`, `REQUIREMENTS_TRACEABILITY.md`, `TEST_CASES.md` (TC-217 onward), `docs/LATER.md`, `docs/RUNBOOK.md` (adding the owner's admin row, turning on TOTP, going live).

- [ ] **Step 1:** Write them, naming the CI run that passed.
- [ ] **Step 2:** `python tools/check_trace.py` prints `OK: 166`.
- [ ] **Step 3:** Commit by name and push.

Not in T22a, and where it goes: the `admin` Edge Function (a login email change, banning a blocked account's users in Auth) and changing a plan from now, with the web slice T22c; the app's side of holds and of sending the version, T22b.
