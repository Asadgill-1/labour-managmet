# T22c: the owner's web dashboard, the `admin` function and changing a plan from now

> For agentic workers: run this plan natively, task by task (the owner's standing choice). Steps use `- [ ]`.

**Goal:** the owner runs slips, periods, holds, limits, refunds, notes, phones and settings from his browser, on the cloud side T22a built, and never from the SQL editor.

**Architecture:** `apps/admin` is a Next.js static export in TypeScript. It holds only the public URL and the anon key, signs in with Supabase Auth and a TOTP code, and reads and writes only through the `admin_` functions, which check the admin row and `aal2` themselves. The `admin` Edge Function mirrors a block into Supabase Auth (bans the account's users while the block lasts); it decides nothing itself. A new migration lets a period end early by a row of its own (`private.period_cuts`), read through one view by every function that asks which period covers a moment.

**Tech stack:** Next.js 16 (`output: 'export'`), React 19, TypeScript 5.9, `@supabase/supabase-js` 2, Vitest, pnpm. Deno for the function, pgTAP for the migration.

**Spec:** `docs/superpowers/specs/2026-11-22-t22-owner-dashboard-design.md` (D-081), the look in `docs/superpowers/specs/2026-11-22-t22-dashboard-mockup.html`, and D-082 for what T22a built.

## Global constraints

- Money is integer fils everywhere in TypeScript: one formatter (`showFils`) and one parser (`readAed`); no `Number` arithmetic on AED with decimals (CALC-01).
- Menu in English (Overview, Accounts, Subscriptions, Audit log, Settings); everything else in Roman Urdu (D-081 (9)).
- Business, Investors, Kitab and crash records are part 2, T23 and part 3: not in the menu, not faked.
- Every list's filters, sort, page and range live in the URL. Every region has loading, empty, error and full states.
- No secret in `apps/admin`, its build or its env: only `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`, in `apps/admin/.env.local`, which git ignores.
- Holds, refunds, corrections and plan changes ask for the TOTP code again when the session's last code is older than 5 minutes.
- Nothing is deployed: the migration, the function and Vercel each wait for the owner's yes.
- Hallmark app-screen rules: tokens from `apps/mobile/lib/app/theme.dart` and the mockup at `:root`, Roboto, ruled rows, no cards in cards, 375 px wide works.

## Review focus

1. A session that is `aal1` (password typed, code not yet) must never see data: the shell sends it to the code step.
2. An amount typed as `189`, `189.5`, `1,455.00` or `12.345` reads as 18900, 18950, 145500 fils or is refused; never a float.
3. A slip whose file never arrived shows so, and still can be refused.
4. A failed write leaves the form filled and says what the cloud said; it never shows success.
5. A block whose Auth ban failed is visible on the account and can be retried.

---

## Task 1: `apps/admin`, its words and its arithmetic

**Files:** create `apps/admin/{package.json,tsconfig.json,next.config.ts,vitest.config.ts,.env.example}`, `apps/admin/lib/{money,dates,url,csv,words,checks}.ts`, `apps/admin/test/*.test.ts`; modify `.github/workflows/ci.yml` (job `admin`: install, `tsc --noEmit`, `vitest run`, `next build`).

**Produces:**
- `showFils(fils: number, aed?: boolean): string` (`145500` → `1,455.00`, with `AED ` when asked; negatives with a minus).
- `readAed(text: string): number | null` (fils, or null for anything not a non-negative amount with at most 2 decimals).
- `showDate(iso)`, `showTime(iso)`, `ago(iso, now)` in Dubai time: `22 Nov 2026`, `22 Nov, 10:42`, `aaj 09:15`, `kal 21:40`, `5 din pehle`; `null` reads `kabhi nahin`.
- `readQuery<T>(params, defaults): T` and `writeQuery(state, defaults): string` (defaults left out of the URL).
- `toCsv(rows: string[][]): string` (quotes cells with comma, quote or newline; a cell starting with `=`, `+`, `-`, `@` gets a leading `'`).
- `slipChecks(slip, typedFils, referencesSeen)`: file, amount, reference checks as `{ok, text}`.
- `creditDays(cut periods, new plan price, now)`: the suggested credit (Task 6).

- [ ] Write `test/money.test.ts`, `dates.test.ts`, `url.test.ts`, `csv.test.ts` with the values above; see them fail.
- [ ] Write the lib; `pnpm vitest run` passes; `pnpm tsc --noEmit` clean.
- [ ] Commit.

## Task 2: a stand-in cloud for runs on this computer

**Files:** create `apps/admin/scripts/fake-cloud.mjs` (dev only, not in the build).

Answers what the site asks Supabase: `/auth/v1/token` (password), `/auth/v1/factors` and `/auth/v1/factors/:id/challenge|verify` (any 6 digits; `000000` is wrong), `/auth/v1/user`, `/rest/v1/rpc/admin_*` with sample data marked as sample, and `/storage/v1/object/sign/...`. Tokens are unsigned JWT-shaped strings carrying `aal` and `amr`. Run: `node scripts/fake-cloud.mjs` and `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399 pnpm dev`.

- [ ] Write it; the login and every page open against it in the browser pane.

## Task 3: sign-in, the code, the shell

**Files:** `app/layout.tsx`, `app/globals.css` (the mockup's tokens and rules), `app/login/page.tsx`, `components/{Shell,Region,Tag,Dialog,ReasonField,CodeField}.tsx`, `lib/{cloud,session,use-rpc}.ts`.

- Login: email and password, then enrol (QR from `mfa.enroll`, verify) or challenge (`mfa.challengeAndVerify`). No sign-up anywhere.
- Shell: the cover bar with the menu, the user's email, sign out; redirects to `/login` unless `aal2`; signs out after 12 hours with no activity.
- `useRpc(name, args)`: `{data, error, loading, fetchedAt, reload}`; an error keeps the last data and its time.
- `freshCode()`: true when the JWT's newest `totp` `amr` is under 4.5 minutes old; `CodeField` shows only when it is not.

## Task 4: Overview, Accounts, the account page

**Files:** `app/page.tsx` (Overview), `app/accounts/page.tsx`, `app/account/page.tsx` (`?id=&tab=`), `components/account/*.tsx`.

- Overview: range (Aaj, 7 din, 30 din, 3 mahine, 12 mahine, Apni tareekh), the previous range for comparison, hide test accounts, fetched time; MRR, cash, paying, trial, trial to paid, slips waiting; Aaj ke kaam (slips, files not arrived, over limit, trials ending, offline 7 days); cash by month with a table; the MRR bridge; plan mix; recent activity; Aap ka apna nafa with "likha nahin" for no cost row.
- Accounts: saved views (Sab, Trial khatam hone wale, 7 din se offline, Had se upar, Slip intezar mein, Ruke hue, Plan khatam), search, plan, state, version, phones, add-on, sort on every column, 25/50/100 a page, CSV.
- Account: status row (state, plan, limits, people, data arrived) on every tab, a line that the books come in part 2; tabs Khulasa, Plan aur paise, Phone, Backup, Timeline, Account, Notes; actions: note, give days (plan, add-on, trial again), limit override and its end, take a period back, refund, correction, hold (arzi suspend, suspend, block) and lift, free the trial claim, test flag, rename, phone off and on. Login email change and deletion by request show as unavailable, with why.

## Task 5: Subscriptions, Audit log, Settings

**Files:** `app/subscriptions/page.tsx` (`?tab=intezar|sab|khata|refund|tajdeed&slip=`), `app/audit/page.tsx`, `app/settings/page.tsx`.

- Intezar: the queue, the slip's picture by a 60-second link, what it bought, who sent it, the checks; accept (amount, reference, received date, payer's bank, last 4, start after the current period or now, credit days, note) or refuse (the reason the customer sees), "Chhorein, agli"; the next slip opens after a decision.
- Sab: every slip in the range, one line each, a total line, one opened in full with its picture and its refund and correction.
- Khata and Refund: every slip period, refund and correction, CSV. Tajdeed: paid plans ending in 7 days with no slip waiting.
- Audit: filters who, action group, account, range; CSV; says it is never changed or deleted.
- Settings: admins and their MFA, bank details and support contact (the owner types them; saved with a reason), plans read only, test accounts, costs by month with an add form.

## Task 6: the `admin` function and a plan from now

**Files:** create `supabase/functions/admin/{index.ts,ban.ts,ban_test.ts}`, `supabase/migrations/20261126120000_plan_from_now.sql`, `supabase/tests/database/plan_from_now.test.sql`; modify the CI `functions` job.

- `banPlan(account, now)`: for a live block, every member's user id and `ban_duration` (hours to the block's end, rounded up, or `876000h`); otherwise `none`. The function checks the caller by calling `admin_account` with the caller's session, then sets each user with the server key. Tests: block with and without an end, suspend, no hold, revoked members left out.
- Migration: `private.period_cuts (subscription_id pk, tenant_id, cut_at_utc, created_at_utc, created_by)`, never updated; `private.periods`, the periods with each cut applied; `licence_facts`, `private.mrr_at`, `private.account_row`, `private.accept_slip`, `admin_give_days` and `submit_slip` read periods through it; `admin_account` adds each period's cut and each member's `banned_until`; `admin_accept_slip` gains `p_start_now` and `p_credit_days`; new `admin_change_plan(p_tenant, p_plan_code, p_days, p_reason)`. Both cut every non-trial plan period still running or to come at now, need the code of the last 5 minutes, and write one audit row.
- pgTAP: a cut period stops covering at the cut and its later periods never come back; the licence and the MRR read the new plan; a slip accepted from now starts now with its credit after it; the next slip continues after the credit; the cut rows refuse update; both refused without a fresh code, for a customer and at `aal1`.
- Dashboard: "Plan abhi se badlein" on the account, "Abhi se" on accept, both with the suggested credit (`creditDays`), which the owner may change.

## Task 7: look, tests, records

- [ ] Every page drawn at 1280 and 375 wide against the stand-in and read by eye; Hallmark's lint with `--scope app`.
- [ ] CI: `admin`, `functions` and `supabase` jobs pass.
- [ ] PROGRESS, TASKS, TRACEABILITY, TEST_CASES, DECISIONS (D-083 for this slice's calls), LATER, RUNBOOK (running the site, the function's deploy); the graph.
