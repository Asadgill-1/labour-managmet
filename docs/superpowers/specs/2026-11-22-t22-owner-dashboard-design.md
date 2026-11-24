# T22: the owner's dashboard

Status: for the owner's approval, 2026-11-22; his answer on consent added 2026-11-24. Requirements: ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-08, ARCH-03, BILL-01, BILL-04, with parts of ADMIN-04, ADMIN-05, MET-01 to MET-03 and MET-07. Changes D-072 and the PRD's OPS-01, OPS-02 and ADMIN-02 on the owner's word (D-081). Builds on D-074 (plans, slips, the signed licence), D-076 (the add-on's periods) and D-073 (phones turned off).

The look is settled by the mockup the owner approved on 2026-11-22: `docs/superpowers/specs/2026-11-22-t22-dashboard-mockup.html` (every name and number in it is sample data).

## Why

Today the owner runs the business from the Supabase SQL editor: the commands in `docs/RUNBOOK.md` accept or refuse a slip, take a period back, list companies over their plan and free a trial claim. Nothing shows him how many accounts signed up, which are paying, what came into the bank, or how big his customers' business is. He wants one place, his own, that shows everything from A to Z, so he can run the platform day to day and pitch investors with real numbers. In his words: data is the most precious thing today.

## What the owner decided

On 2026-11-22, in this order:

1. The dashboard is for him, the platform's owner, never for customers.
2. It shows everything: downloads, accounts, companies, trials, payments, plans, phones, last online, versions, and every customer's business: invoices and their amounts, labour, labour salary, managers, client companies, profit and loss.
3. **All of every company's data goes to the cloud** when the phone is online, and he can read it. This changes D-072, under which the cloud held only an encrypted copy that he could open only with his offline recovery key. Claude said it would build this only with a plain consent page, never with the permission buried in long terms; the owner said: "my app i want all data so make change in design D-072".
4. The work is three parts, in this order: (1) the dashboard on the data the cloud already has, (2) the books in the cloud, (3) a record of crashes and errors from customers' phones. Part 3 waits until the app is complete.
5. The books go up by sending the outbox the app already writes (approach A below).
6. Suspend, temporary suspend and block an account; change an account's settings; fix a customer's books when the customer made a mistake.
7. The subscriptions record shows who sent each slip, the bank and account it came from, how much was due and how much came, the slip's picture, which subscription it bought, and everything else about it.
8. Every registered account gets its own page that opens on a summary of its business: plan, active or not, workers, client companies, managers, amounts billed, labour salary, profit or loss.
9. Language: the menu in English, everything else in Roman Urdu.
10. The mockup's look: the app's bound account book (dark cover band, cream ruled pages, a double rule under a total), built with Hallmark.

## Goals

- The owner does every money and account task from a phone or a laptop browser, never from the SQL editor.
- Every number says where it comes from, for what dates and when it was last updated (ADMIN-01), and an account offline for five days reads "aakhri baar 5 din pehle", never "active" (ADMIN-05).
- Nothing the dashboard does to money or an account overwrites what was there: every change is a new row with who, when and why (ADMIN-03, BILL-04).
- The dashboard holds no secret. A stolen laptop with the site open is a stolen session, never a stolen key.
- A customer's profit on the dashboard is the same number the customer's own app shows on "Malik ki sheet".

## Non-goals

- A dashboard for customers, managers or support staff. One role now: the owner. Finance and support roles come later (ADMIN-08, `docs/LATER.md`).
- Crash and error records (part 3), Play installs (only after Play), the investor pack PDF and cohort tables (MET-06, T23), support tickets (ADMIN-07, T23), budget alerts (ARCH-06, T23).
- Changing a customer's books from the dashboard without the customer's yes.
- Charging money: the platform still takes bank transfers outside the app (BILL-01, BILL-07).

## Anti-goals

- A consent the customer cannot see. If the customer is not told plainly, in Roman Urdu, before the first row leaves the phone, the feature is a failure however well it works.
- A suspended customer who cannot read or export their own books. Their records may be needed for VAT and labour law; the platform must never hold them hostage.
- Editing a posted salary, an issued invoice or a ledger line in place, from anywhere.
- A secret key (service role, signing key, recovery key) in the dashboard's code, its build or its hosting settings.

## Constraints

- Amounts are integer fils in the database, the API and the TypeScript; one function turns fils into text. No floating point near money (CALC-01).
- Every table has `tenant_id` where it holds a tenant's data; the dashboard never takes tenant identity from a request without the database checking the caller (BUILD-01, AUTH-02).
- Each live migration, Edge Function deploy and the dashboard's first deploy to Vercel needs the owner's yes, each time.
- The repo is public: the Supabase project's URL and keys go in `apps/admin/.env.local`, which git ignores.
- Supabase free tier: 500 MB database, 1 GB storage. Part 2 will outgrow it (see Cost).

## Approaches

### Getting the books to the cloud (part 2)

- **A. Send the outbox (chosen by the owner).** Every save in the app already writes an outbox row holding the whole changed record, with its id, version, device and an idempotency key (TEAM-04, since P1). Today the rows are never sent. The app sends the unsent ones in batches when online; the cloud keeps the newest version of each record. Least new code, works offline, retries are harmless, and T25's two-phone sync can start from the same pipe.
- B. Upload the whole database file daily, unlocked, and read it in the cloud. A day behind, heavy, and the cloud would have to open SQLite files.
- C. Mirror each of the app's 31 tables as a Postgres table. The nicest to query, but every schema change in the app would need a matching migration in the cloud.

### Who may use the dashboard (part 1)

One sensible way: the owner signs in with Supabase Auth and a TOTP code from an authenticator app (MFA), and every dashboard function in Postgres checks that the caller is in `private.platform_admins` **and** that the session's assurance level is `aal2`. The site itself holds only the public URL and anon key. The other ways were dropped: a Next.js server holding the service-role key puts the most powerful secret on a web host; Vercel's own password protection protects the page, not the data.

### Crashes and errors (part 3, later)

Our own record in the same cloud, shown on this dashboard, was preferred to Sentry, which would add an account, a second dashboard and a third party holding customer data. Android's native crashes come from Play Console once the app is on Play. Built when the app is complete (`docs/LATER.md`).

## Part 1: the dashboard on today's cloud data

### Access

- `private.platform_admins (user_id uuid primary key references auth.users, role text check (role = 'owner'), added_at_utc)`. The owner adds himself once, in the SQL editor (RUNBOOK). The dashboard cannot add admins.
- `private.is_platform_admin()`: true only for a row's user whose JWT has `aal = 'aal2'`.
- Supabase MFA (TOTP) is turned on for the project. First sign-in shows a QR code to enrol; every sign-in after asks for the 6-digit code. Signing up from the dashboard is impossible: there is no signup page, and the RPCs refuse anyone not in the table.
- Holds, refunds, plan changes and blocks ask for the code again if the last TOTP check is older than 5 minutes (read from the JWT's `amr`).
- The dashboard's session ends after 12 hours idle.

### The audit log

- `private.admin_actions (id, at_utc, actor_id, action, tenant_id, target_id, reason, before jsonb, after jsonb)`. Written inside the same transaction as the change it records. A trigger refuses `update` and `delete` on it for everyone (ADMIN-03). `reason` is required, 3 characters or more, for every write.
- `private.tenant_notes (id, tenant_id, body, at_utc, actor_id)`: the owner's notes on an account, append-only too.

### Pages

Menu in English, content in Roman Urdu. Every list's filters, sort, page and date range live in the URL, so a view can be bookmarked or sent. Every region has four states: loading (a skeleton in the shape of the content), empty (what belongs there and the one action that fills it), error (what broke, the last good data and when it was fetched) and full.

1. **Overview** (mockup 1): the date range (today, 7 days, 30 days, 3 months, 12 months, custom), comparison with the previous period, a switch that hides test accounts, and the time the data was fetched. Figures: MRR, cash collected, paying accounts, trial accounts, trial-to-paid, and from part 2 what customers billed. "Aaj ke kaam": waiting slips, slips whose file never arrived, accounts over their limits (from `private.usage_reports`), trials ending in 5 days, accounts offline 7 days or more. Cash collected by month, with a table view. The MRR bridge for the month (opening + new + expansion + reactivation - contraction - churn = closing, MET-03). Plan mix. Recent activity across accounts. "Aap ka apna nafa": cash collected minus the platform's costs the owner has written in Settings; a cost not written shows as "likha nahin", never as zero (MET-04).
2. **Accounts** (mockup 2): one row per tenant. Saved views (trial ending, offline 7 days, over limit, slip waiting, plan ended, in loss). Filters: plan, state, signup date, version, last online, labour (from the counts each licence check reports), phones, add-on, backup, refused slip, test; and from part 2 emirate, bill and profit or loss. Columns to choose, sorting, selecting rows, CSV export, pages of 25, 50 or 100. Columns: account (name, owner's email, signup date), state, plan end, emirate, phones, last online, version, labour, and from part 2 bill, salary and profit or loss.
3. **One account** (mockups 2a, 3, 3a to 3c), tabs:
   - *Business khulasa* (part 2, mockup 2a): the account's state (running, trial, held, plan ended, offline since), plan, limits, people, when its data last arrived; a range switch; figures; profit and loss in the lines of "Malik ki sheet"; profit or loss by month; money owed by clients, owed to workers, advances out; client companies; labour. Before part 2 this tab shows the account's state, plan and limits only, and says the rest comes when the books reach the cloud.
   - *Khulasa*: the account's facts (owner, email confirmed, signup, tenant id, members, cloud backup, the owner's note), health (licence check, backup, limits) and the account's story newest first: account made, email confirmed, company made, trial, slips, periods, phones turned off, holds, the owner's actions, and from part 2 the first worker, attendance and invoice.
   - *Plan aur paise* (3a): the plan, its period and limits, and the actions below; the account's money ledger.
   - *Phone*: each device with label, platform, version, last seen, on or off, and turning one off or back on.
   - *Kitab* (part 2): workers, clients, invoices, attendance, payroll and expenses as filtered tables, with CSV.
   - *Backup*: the account's cloud copies and add-on periods (from T20d).
   - *Timeline*: the same story as Khulasa, full length.
   - *Account* (3c): login email, company name, members, phones, trial, test flag, export, deletion on request.
   - *Notes*.
4. **Subscriptions** (mockups 4 and 4a), tabs:
   - *Intezar*: the queue on the left, the chosen slip on the right with its picture, what it bought, who sent it and when, and checks the dashboard makes itself: the file arrived, the amount matches, the bank reference was not used before. Accepting asks the amount that reached the bank, the bank reference, the date, the payer's bank and the last 4 digits of the payer's account, when the plan starts (after the current period, or now), and a private note. Refusing asks the reason the customer sees. "Chhorein, agli" skips. After a decision the next slip opens.
   - *Sab subscriptions*: every slip and period, one line each: picture, account, who sent it (name, role, email), plan and cover, months, price version, period, due, received (red when different), payer's bank and last 4 digits, reference, date in the bank, state, who decided and when. Filters and a total line. Opening one shows all of it with the large picture, its download, a receipt PDF, refund and correction.
   - *Paison ka khata*: every accepted slip, refund and correction across accounts, for the accountant, with CSV and Excel.
   - *Refund* and *Tajdeed is hafte* (renewals due this week).
5. **Business** (part 2, mockup 5): totals over every account's books: labour, billed, invoices, attendance days, payroll, profit and loss in the lines of "Malik ki sheet", billed by month, by emirate, accounts in profit and in loss, the biggest accounts. Always labelled as the customers' business, apart from the platform's own income (MET-01). Customer profit is always "andazan, audit shuda nahin", as in the app.
6. **Audit log** (mockup 6): every row of `private.admin_actions`, filtered by who, action, account and date, with CSV. It says it cannot be changed or deleted.
7. **Settings** (mockup 7): the admins and their MFA, the bank details customers see, the support contact, the plans and price versions (read only), test accounts, the platform's costs by month (for "Aap ka apna nafa"), and the licence key's date.

Investors in the mockup's menu waits for T23's investor pack; until then the menu does not show it.

### What the owner can do to an account

Each is a Postgres function that checks `private.is_platform_admin()`, writes the change and its `admin_actions` row in one transaction, and never updates a money row in place:

- Accept or refuse a slip. Wraps today's `private.accept_slip` and `private.refuse_slip`, adds `payment_slips.payer_bank` and `payment_slips.payer_last4` (four digits, checked), and the choice to start now rather than after the current period. Starting now with the rest of the old period credited or not is the owner's choice at the time (`docs/LATER.md`, T22).
- Take a period back (today's `private.revoke_subscription`).
- Give free days or extend: a new period with `source = 'grant'`, amount 0.
- Change the plan: from now or from the period's end. A period is never edited; ending one early is a new row that says from when, and `licence_facts` reads both.
- Give or take back the add-on.
- Raise a limit until a date: `private.limit_overrides (tenant_id, what in ('workers', 'clients', 'managers'), cap, until_utc, reason, ...)`, read by `licence_facts`.
- Record a refund or a correction: `private.money_entries (tenant_id, kind in ('refund', 'correction'), subscription_id, amount_fils, field, value, reference, on_date, reason, actor, at)`. A correction records the right value; the original stays.
- Hold an account: `private.tenant_holds (tenant_id, kind in ('suspend', 'block'), until_utc null, told, note, created_at_utc, created_by, lifted_at_utc, lifted_by, lift_reason)`. *Arzi suspend* has an end date and lifts itself; *suspend* lasts until lifted; *block* also refuses new phones for the account (`register_device`) and bans the account's users in Supabase Auth through the `admin` Edge Function until lifted. `licence_facts` returns the hold, with the text the customer sees and the end date, and the `licence` function signs them into the licence (a redeploy, on the owner's yes). Lifting is its own action, with a reason.
- Free a trial claim; give the trial again; mark or unmark a test account; rename the company; turn a phone off or back on; add a note.
- Change the login email: through the `admin` Edge Function, which holds the service-role key on the server, checks the caller's `aal2` and admin row itself, and sends a code to both the old and the new address.

### What the customer's app does

- A held account opens in the same read-only mode as an ended plan (T21c): the books, papers, Excel, the backup and restore stay open; every entry button is locked. Today and the lock say "Account ruka hua hai" with the end date if there is one, and the text the owner wrote, and lead to the support contact.
- An offline phone stops within 7 days anyway, as with an ended plan (D-074).
- The licence request carries the app's version; the cloud keeps it on the device's row (`devices.app_version`), so the dashboard can show it.

### Data the dashboard reads in part 1

`tenants`, `memberships`, `devices` (with `last_seen_at_utc` and the new `app_version`), `auth.users` (email, confirmed, created), `subscriptions`, `payment_slips` and their files in Storage (an admin-only storage policy lets the dashboard make a 60-second link), `cloud_backups`, `private.usage_reports`, `private.trial_claims`, `platform_settings`, and the new tables above. The dashboard reads only through `admin_` functions; it never queries a table.

New flag: `tenants.is_test`, so test accounts can be left out of every figure (MET-07).

Metrics follow the PRD's table under MET: paying customers are accounts with a paid, unrevoked period on the date; MRR normalises each paying account's current period to a month (price plus add-on); cash collected is accepted slips by the date the money reached the bank, minus refunds; trial-to-paid takes the trials that started in the window. The MRR bridge's sum is checked by a test on sample data (MET-03).

## Part 2: the books in the cloud

### Consent, in the app

- Signup, after the company's name and before the backup password, shows one page in Roman Urdu: what goes to the cloud (all of the company's records: workers, clients, attendance, payroll, invoices, cash, papers, pictures), who can see it (the platform's owner), why (running and improving the service, help with mistakes, business totals shown to investors without the company's name), how long (until the account is deleted), and that passwords, the PIN and the backup password never leave the phone. One button to agree.
- The answer is kept on the tenant: `tenants.data_consent_at_utc` and `tenants.data_consent_version`. Nothing is sent before it. A change to the wording raises the version and asks again. An account made before part 2 sees the page once, on its next open, before anything is sent.
- Settings shows the same text, and the privacy policy and Play's data safety form say the same (T26).
- The company is told it is responsible for telling its own workers that their data is kept by the platform.

### Sending

- When the app opens or comes to the front, is online and has consent, it sends the unsent outbox rows oldest first, 200 at a time, through `public.push_book_changes(p_tenant, p_device, p_changes)`. The function checks that the caller belongs to the tenant, the device is not turned off, and consent is given; it keeps each record's newest version (`private.book_rows (tenant_id, entity, record_id, record_version, data jsonb, operation_id, device_id, changed_at_utc, received_at_utc)`, primary key `(tenant_id, entity, record_id)`), remembers each operation id (`private.book_ops`) so a resend changes nothing, and returns the ids it took. The app marks those sent. A failure waits and tries again later; nothing on screen waits for it.
- Only the app's own record types are taken; anything else is refused.
- After a restore, or when the cloud holds nothing for the tenant, the app sends every current row once, so the cloud never misses what an earlier phone did not send.
- Pictures: `document_assets` rows go up without their bytes; the bytes go to a private Storage bucket, `book-files/<tenant>/<asset id>`, through a signed upload. The company's signature and stamp pictures stay on the phone (see Calls).
- Deleting an account deletes its book rows and files at once (D-066); only the 60-day backup copy stays (D-072 (5)).

### What the dashboard reads in part 2

- Lists (workers, clients, invoices, attendance, payroll, cash) from `private.book_rows`.
- Profit and loss: the app works out each month's "Malik ki sheet" figures with the code that draws that sheet today and sends them as a record of their own (`entity = 'month_summary'`, `record_id = 'YYYY-MM'`), whenever a month's data changes. The dashboard adds these up; it never works out profit itself, so the two can never disagree.
- The funnel (account made, company made, first worker, first attendance, first invoice, paid) from the first record of each kind. Play installs and first opens are added after the app is on Play (MET-05).

### Cost

A company with 15 workers adds about 3 to 5 MB of rows a year; pictures add more. A hundred companies outgrow the free tier's 500 MB database within a year, so the project moves to Supabase Pro (about USD 25 a month) before then. The Overview's "Aap ka apna nafa" shows that cost once the owner writes it in Settings.

## The dashboard's code

- `apps/admin`: Next.js with TypeScript (ARCH-03, D-002), built as a static site, so it can be hosted anywhere and holds nothing but the public URL and anon key. Pages that need an id take it in the query string (`/account?id=`), since a static build has no server routes.
- Supabase JS for sign-in, MFA and the `admin_` functions. No other state library; no i18n library: the strings sit in one file.
- The look: the tokens of `apps/mobile/lib/app/theme.dart` as CSS custom properties, Roboto, Hallmark's app-screen rules, the mockup as the reference. Works from 375 px wide (ARCH-03).
- Hosting: on the owner's computer (`pnpm dev`) until the owner says yes to Vercel (D-002). The site's address is not linked from anywhere.

## Tests

- pgTAP for every `admin_` function: refused without an admin row, refused at `aal1`, refused for a customer; the change and its audit row land together; the audit table refuses update and delete; a hold reaches `licence_facts` and lifts itself at its date; a limit override reaches `licence_facts`; money rows are never updated; the MRR bridge adds up on sample data.
- pgTAP for `push_book_changes`: refused without consent, for another tenant, for a turned-off phone; a resend changes nothing; an older version never replaces a newer one; deleting the account removes the rows.
- Deno tests for the `admin` function.
- Flutter tests: the consent page before any send; a held licence locks entries and shows the owner's text; the sender marks only the ids the cloud took; a restore sends everything once; the month summary equals "Malik ki sheet" for the same month.
- `apps/admin`: TypeScript's check, Vitest for the fils formatter and the URL filters, the build, in CI. The pages drawn as images and read by eye before the owner sees them; Hallmark's lint with `--scope app` on each page.

## What the owner does

1. Say yes to each live migration and function deploy, as before.
2. Turn on MFA (TOTP) in the Supabase dashboard's Auth settings, make his admin login, and add its id to `private.platform_admins` in the SQL editor (RUNBOOK).
3. Enrol the authenticator app on first sign-in, and keep its recovery codes offline.
4. Say yes to Vercel when he wants the dashboard online.
5. Have the consent text and the privacy policy read by a UAE lawyer before Play (T26).

## Left to the builder

Table and function names beyond those above; the exact SQL for the metrics; how the app batches and backs off; the dashboard's component structure; the skeletons' shapes; the CSV columns.

## Calls Claude made, for the owner to check

1. **Block keeps the books readable.** Suspend and block lock new entries only; the customer can always read, print, export and back up their own books.
2. **Fixing a customer's books needs the customer's yes** and goes in as a correction, never an edit (OPS-05). It needs the cloud to send a request to the phone, so it is built with T25's sync, as part 4 (`docs/LATER.md`).
3. **The payer's account: the bank and the last 4 digits only.** Enough to match a payment; the full number is on the slip's picture anyway, and a leak of the table then exposes less.
4. **The signature and stamp pictures stay on the phone.** With them anyone could forge the company's papers; they are in the encrypted backup already.
5. **Profit comes from the app's own sheet**, sent as a monthly summary, so the dashboard and the app never disagree.
6. **"Accounts", not "Companies"**, for the platform's customers, because the customers' own clients are called companies in the app.
7. **One admin role, the owner.** Finance and support roles wait until someone else needs a login.
8. **Part 1 first, part 2 after**: part 1 needs only today's data, part 2 needs app changes and consent.

## The owner's answer, 2026-11-24

- A company that does not agree to send its data cannot use the app: "Nahin, ijazat zaroori". Signup stops at the consent page, with a way back and a way to log out; an account made before part 2 that does not agree is held at that page on its next open, its books still readable, exportable and backed up, as with a held account. UAE law asks consent to be freely given, so the lawyer in "What the owner does", step 5, reads this choice first, before Play.
