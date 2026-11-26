# T22d: the books in the cloud, with the customer's consent — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** T22's part 2: the app asks the company's consent in plain Roman Urdu, then sends every record of its books to the cloud, with a month summary from "Malik ki sheet"; the owner's dashboard reads them on a Business page, a business summary and a Kitab tab per account.

**Architecture:** A change list the app's database fills itself (a trigger on each book table) names every record touched; the app sends those records as they stand now, 200 at a time, through `public.push_book_changes`, which checks member, phone, consent and record types and keeps the newest version of each record in `private.book_rows`. The month's figures come from the code that draws "Malik ki sheet" and go up as `month_summary` records. The dashboard reads only through new `admin_` functions and only adds up what the app worked out.

**Tech Stack:** Postgres (Supabase) with pgTAP; Flutter with drift (SQLite triggers, schema 19 to 20), Riverpod, supabase_flutter; Next.js static export with Supabase JS, Vitest.

**Spec:** `docs/superpowers/specs/2026-11-22-t22-owner-dashboard-design.md`, "Part 2: the books in the cloud" and "The owner's answer, 2026-11-24" (D-081). The look: `docs/superpowers/specs/2026-11-22-t22-dashboard-mockup.html`, mockups 2a and 5.

## Global Constraints

- Amounts are integer fils everywhere: in `book_rows.data`, the RPCs' answers and the TypeScript. No `double` near money (CALC-01).
- Every cloud table has `tenant_id`; tenant identity comes only from Postgres checking the caller (BUILD-01, AUTH-02). `book_rows` and the app's `book_changes` both carry it.
- Nothing leaves the phone before consent: the app checks its kept answer, and the cloud refuses a push without `tenants.data_consent_at_utc` (anti-goal: "a consent the customer cannot see").
- Passwords, the PIN and the backup password are not in the book tables and never go; the signature and stamp pictures stay on the phone (spec, Calls 4).
- A held or unconsented company still reads, exports and backs up its books (anti-goal).
- The dashboard never works out profit: it adds up the app's `month_summary` records, and every customer profit says "andazan, audit shuda nahin" (spec, Calls 5; REP-03).
- Menu in English, everything else in Roman Urdu; the mockup's look; Hallmark lint 0 FAIL with `--scope app`.
- Each live migration and deploy needs the owner's yes; nothing here runs on the live project.
- Repo is public: no project ref or key in git.

## Review Focus

1. A company that has used the app for months before this update: its first send must take every existing record once, in batches that each stay under the request size, without freezing the screen. Test: `fills every existing record once, then sends it in batches` (Task 3).
2. A restore puts older rows on the phone: the cloud must not lose newer versions it holds, nor bring back a record deleted later. Tests: `an older version never replaces a newer one`, `a delete's mark keeps an older copy out` (Task 1), `a restore sends everything again` (Task 3).
3. A push that fails halfway (network drops after the cloud took it): the next try resends the same records and nothing doubles. Test: `a resend changes nothing` (Task 1) and `a failed push keeps the list` (Task 3).
4. An account made before this update opened offline: the consent page still shows before anything is sent, and "Abhi nahin" leaves the books readable with every entry locked. Test: `an old account sees the page on open and can still read` (Task 4).
5. A record type the app adds later, or a typo: the cloud refuses it rather than storing junk, and the app's list of book tables is the database's own list. Tests: `an unknown record type is refused` (Task 1), `every book table has its three triggers` (Task 2).

---

### Task 1: The cloud: consent, the book rows, the push and the owner's reads

**Files:**
- Create: `supabase/migrations/20261127120000_books_in_cloud.sql`
- Create: `supabase/tests/database/books.test.sql`

**Interfaces:**
- Produces, callable by `authenticated`:
  - `public.give_data_consent(p_tenant_id uuid, p_version integer) returns timestamptz`: the owner only; keeps the highest version; returns when it was given.
  - `public.push_book_changes(p_tenant_id uuid, p_device_id uuid, p_changes jsonb) returns integer`: `p_changes` is an array of `{"entity": text, "id": text, "version": int, "data": object | null}` (null data = deleted), at most 500; returns how many it read.
  - `public.admin_account_book(p_tenant uuid) returns jsonb`: `{consent_at, consent_version, last_at, records, counts: {workers, clients, sites, invoices}, firsts: {worker, attendance, invoice}, months: [summary...]}`.
  - `public.admin_book(p_tenant uuid, p_entity text) returns jsonb`: `[{id, version, at, data}]`, live rows of one record type, newest first.
  - `public.admin_business(p_from text, p_to text, p_include_test boolean) returns jsonb` (months as `YYYY-MM`): `{months: [{month, accounts, bill, wages, salaries, allowances, cuts, room_in, room_out, expenses, estimate, days, invoices, invoiced, credited}], accounts: [{tenant_id, name, bill, wages, estimate, invoiced, workers, clients, last_at}], workers, clients, with_books, consented, accounts_total}`.
  - `private.account_row` gains `consent_at`, `book_at` (last record received), `bill_month`, `estimate_month` (this Dubai month's summary), so Accounts and the account head read them.
- A summary's data keys, fixed here and in Task 3: `month, bill, wages, salaries, allowances, cuts, room_in, room_out, expenses, estimate, days, workers, no_rate, invoices, invoiced, credited` (fils except `days`, `workers`, `no_rate`, `invoices`).

- [ ] **Step 1: Write `books.test.sql`** with the harness of `admin.test.sql` (`pg_temp.claims`), two companies (Alpha owned by user 1, Beta by user 3), Alpha's phone registered. Assertions, by name:
  - `push refused without consent` (`42501`), `consent refused for someone not the owner`, `consent kept with its version`, `a lower version does not lower it`.
  - `push refused for another company`, `push refused from a turned-off phone`, `push refused from a phone never registered`.
  - `push keeps each record` (3 records in, `count(*) = 3`), `a resend changes nothing` (same data, count 3), `a newer version replaces`, `an equal version replaces`, `an older version never replaces a newer one`, `a delete's mark keeps an older copy out` (version 3 null data, then version 2 data: still deleted).
  - `an unknown record type is refused`, `a record naming another company is refused` (`data.tenant_id`), `more than 500 changes are refused`.
  - `admin reads refused for a customer`, `admin reads refused at aal1`; `the account's book has its months and counts`; `business adds up two accounts' months` (bill 100000 + 50000 = 150000), `business leaves test accounts out`; `admin_book lists live workers only`; `account_row shows this month's bill`.
  - `deleting the account removes its book rows`.
- [ ] **Step 2: Commit the test alone and push; CI's `supabase test db` fails** with "function public.push_book_changes does not exist". Record the run id.
- [ ] **Step 3: Write the migration.** `tenants.data_consent_at_utc timestamptz`, `tenants.data_consent_version integer`. `private.book_rows (tenant_id uuid references public.tenants on delete cascade, entity text check (entity in <the 30 book tables> or 'month_summary'), record_id text check (length 1..100), record_version integer check (> 0), data jsonb, device_id uuid, changed_at_utc timestamptz default now(), received_at_utc timestamptz default now(), primary key (tenant_id, entity, record_id))`, no grants to API roles. `push_book_changes`: caller's role via `private.member_role`, a live device row for (tenant, caller, device) and not `phone_is_off`, consent set, array of 1 to 500, each data an object or null, under 500 000 characters, with no `tenant_id` but this one; upsert `on conflict do update ... where excluded.record_version >= book_rows.record_version`. The admin reads start with `perform private.require_admin()`. Replace `private.account_row` keeping every key it has.
- [ ] **Step 4: Push; CI passes** `books.test.sql` and every earlier file. Record the run id.
- [ ] **Step 5: Commit** `feat(cloud): the books in the cloud, with consent, the push and the owner's reads (T22d)`.

### Task 2: The app's change list

**Files:**
- Modify: `apps/mobile/lib/data/tables.dart` (add `BookChanges`), `apps/mobile/lib/data/triggers.drift` (three triggers per book table), `apps/mobile/lib/data/tenant_database.dart` (schema 20, step `from19To20`, `bookTables`)
- Generated: `tenant_database.g.dart`, `tenant_database.steps.dart`, `drift_schemas/tenant/drift_schema_v20.json`, `test/drift/tenant/*`
- Test: `apps/mobile/test/books_test.dart`

**Interfaces:**
- Produces: `BookChanges` table `book_changes (seq integer primary key autoincrement, tenant_id text, entity text, record_id text, version integer)`; `const bookTables = <String>{...}`, the 30 tables with `Common` (every table but `audit_events`, `outbox`, `book_changes`); triggers named `book_<table>_ins`, `_upd`, `_del` writing `NEW.version` (insert, update) or `OLD.version + 1` (delete).

- [ ] **Step 1: Test** `every book table has its three triggers` (reads `sqlite_master`; also asserts `bookTables` equals the tables whose columns include `source_operation_id`) and `a save, an edit and a delete each name the record` (a worker saved, edited, deleted: three rows, the last with version 3).
- [ ] **Step 2: Run** `flutter test test/books_test.dart`: fails, `bookChanges` not defined.
- [ ] **Step 3: Add the table and triggers**, bump `schemaVersion` to 20, run `dart run build_runner build --delete-conflicting-outputs` and `dart run drift_dev make-migrations`, and fill `from19To20`: create the table, then every trigger whose name starts with `book_`.
- [ ] **Step 4: Run** `flutter test test/books_test.dart test/drift`: pass.
- [ ] **Step 5: Commit** `feat(app): a change list the database fills for every book table (T22d)`.

### Task 3: Sending, and the month summary from "Malik ki sheet"

**Files:**
- Modify: `apps/mobile/lib/features/registers/salary_sheet.dart` (figures out of the sheet)
- Create: `apps/mobile/lib/data/books.dart`
- Modify: `apps/mobile/lib/data/account.dart` (`giveConsent`, `cloudConsent`, `pushBooks`, `bookSender`)
- Modify: `apps/mobile/lib/app/root.dart` (start, resume, settle before close, after a swap)
- Test: `apps/mobile/test/books_test.dart`

**Interfaces:**
- Produces in `salary_sheet.dart`: `typedef OwnerMonth = ({int bill, int wages, int salaries, int allowances, int cuts, int roomIn, int roomOut, int expenses, int days, int workers, int noRate})`, `int estimateOf(OwnerMonth m)`, `Future<OwnerMonth> ownerMonth(TenantDatabase db, String month)`; `buildSalarySheet` draws its two summary blocks from it.
- Produces in `books.dart`: `const consentVersion = 1`; `typedef BookPush = Future<void> Function(List<Map<String, Object?>> changes)`; `class BookSender { BookSender({required FlutterSecureStorage storage, required String tenantId, required TenantDatabase Function() db, required BookPush push, required Future<int?> Function() cloudConsent, required Future<void> Function(int version) giveConsent}); Future<void> load(); bool get consented; Future<void> agree(); Future<void> send(); Future<void> settled(); Future<void> restored(); Stream<bool> watchConsent(); }`; `Future<Map<String, Object?>> monthSummary(TenantDatabase db, String month)` (keys as in Task 1).
- Consumes: `push_book_changes`, `give_data_consent` (Task 1); `book_changes` (Task 2).

- [ ] **Step 1: Tests:** `the month summary is Malik ki sheet's figures` (the data of `reports_test.dart`'s October sheet: each summary key equals the sheet's row, and `estimate` its total); `nothing goes before consent`; `fills every existing record once, then sends it in batches` (450 workers: three pushes of 200, 200, 50 plus the summaries; no batch over 512 KB); `sends a record as it stands now` (saved then edited before the send: one change, version 2, the edited name, no blob columns); `a delete goes as a mark` (data null, version + 1); `a failed push keeps the list` (push throws: the next send sends the same records); `changes made while sending stay for the next send`; `a restore sends everything again`; `the months from the earliest changed day to now get a summary`.
- [ ] **Step 2: Run**: fails, `ownerMonth` not defined.
- [ ] **Step 3: Implement.** `ownerMonth` is the existing arithmetic moved out, with `buildSalarySheet` calling it; `monthSummary` adds the month's issued invoices (count, net of their lines) and credit notes (net) by issue date. `BookSender.send`: once per run (a second call waits for the first); nothing without consent; with no `book_full_<tenant>` mark in storage, clears the list and fills it from every book table, then marks it; reads up to 200 list rows oldest first, reads those records by table (`SELECT *`, blob columns left out), a missing record goes as a mark with the list's version, adds the summaries of the months from the earliest `YYYY-MM` found in the records' text values (or last month) to this month, pushes in pieces of at most 512 KB, and deletes the list rows it read only after the cloud said yes; repeats until the list is empty. `restored()` drops the mark. `Account.cloudConsent` reads `tenants.data_consent_version`; `giveConsent` calls the RPC and keeps the answer in secure storage under `book_consent_<tenant>`.
- [ ] **Step 4: Run** `flutter test test/books_test.dart test/reports_test.dart test/registers_test.dart`: pass.
- [ ] **Step 5: Commit** `feat(app): send the books as they stand, with the month's figures from Malik ki sheet (T22d)`.

### Task 4: The consent page

**Files:**
- Create: `apps/mobile/lib/features/account/consent_screen.dart`
- Modify: `apps/mobile/lib/features/account/account_screens.dart` (name, then consent, then backup password; `createCompany` gives consent), `apps/mobile/lib/data/account.dart` (`createCompany(..., consent:)`), `apps/mobile/lib/data/plan_guard.dart` (`PlanBlock.noConsent`), `apps/mobile/lib/features/plans/plan_lock.dart` (its words and step), `apps/mobile/lib/app/root.dart` (the page on open for an old account), `apps/mobile/lib/features/more/settings_screen.dart` (the same text, and the answer), `apps/mobile/lib/app/providers.dart` (`bookSenderProvider`), `apps/mobile/lib/l10n/app_en_PK.arb`, `app_en.arb`
- Test: `apps/mobile/test/account_flow_test.dart`, `apps/mobile/test/zz_t22d_test.dart` (images)

**Interfaces:**
- Produces: `ConsentScreen({required String companyName?, required Future<void> Function() onAgree, VoidCallback? onLater, VoidCallback? onBack, Future<void> Function()? onLogOut})`; `planRefusal(..., bool consented = true)`.

- [ ] **Step 1: Tests:** `signup asks consent after the name and before the backup password`; `the company is made with consent given`; `an old account sees the page on open and can still read` (Abhi nahin: Today opens, an entry button shows the lock with "Ijazat dein"); `agreeing from the lock sends`; `Settings shows what goes to the cloud`.
- [ ] **Step 2: Run**: fails, `ConsentScreen` not defined.
- [ ] **Step 3: Implement** the page: what goes (every record: labour, companies, hazri, tankhwah, invoice, cash, papers, pictures), who sees it (the platform's owner), why (running and improving the service, help with mistakes, business totals for investors without the company's name), how long (until the account is deleted), what never goes (passwords, the PIN, the backup password), that the company tells its own labour; one button "Haan, ijazat hai". At signup also back and log out; on open for an old account "Abhi nahin" opens the books read-only for this run.
- [ ] **Step 4: Run** `flutter analyze && flutter test`: pass. Draw the page at signup, on open and in Settings as images under `test/zz` and read them.
- [ ] **Step 5: Commit** `feat(app): the consent page, before anything leaves the phone (T22d)`.

### Task 5: The dashboard reads the books

**Files:**
- Create: `apps/admin/app/business/page.tsx`, `apps/admin/lib/book.ts`, `apps/admin/test/book.test.ts`
- Modify: `apps/admin/lib/types.ts`, `apps/admin/lib/words.ts` (menu: Business), `apps/admin/components/Shell.tsx`, `apps/admin/app/account/page.tsx` (tabs Business khulasa first, Kitab), `apps/admin/components/account/tabs.tsx` (`BookSummary`, `Kitab`, the firsts in the story), `apps/admin/app/page.tsx` (customers' bill), `apps/admin/app/accounts/page.tsx` (this month's bill and profit, the "Nuqsan mein" view), `apps/admin/scripts/fake-cloud.mjs`

**Interfaces:**
- Produces in `book.ts`: `type MonthSummary`, `addMonths(rows: MonthSummary[]): MonthSummary` (sums each key, integers only), `monthsBetween(from: string, to: string): string[]`, `bookColumns: Record<string, {key: string, label: string, kind: "text" | "fils" | "date" | "minutes"}[]>` for the Kitab tables.
- Consumes: the Task 1 RPCs.

- [ ] **Step 1: Vitest** `addMonths sums every key`, `addMonths refuses a fraction`, `monthsBetween spans a year end`.
- [ ] **Step 2: Run** `pnpm test`: fails.
- [ ] **Step 3: Implement** the Business page (range, the sheet's lines added up, bill by month with a table, accounts in profit and in loss, the biggest accounts, consent counts, "andazan, audit shuda nahin"), the account's Business khulasa (consent and last arrival, range, the sheet's lines, by month, counts) and Kitab (labour, companies, invoices, hazri, payroll, cash, with CSV), the firsts in the story, the Overview figure and the Accounts columns; the fake cloud answers all of it with sample books.
- [ ] **Step 4: Run** `pnpm typecheck && pnpm test && pnpm build`; look at every new screen at 1280 and 375 against the fake cloud; Hallmark lint `--scope app` 0 FAIL.
- [ ] **Step 5: Commit** `feat(admin): the customers' books on the dashboard (T22d)`.

### Task 6: Records

- [ ] D-084 in `DECISIONS.md` (the calls), TC-224 to TC-227 in `TEST_CASES.md`, `TASKS.md`, `PROGRESS.md` (next task, Done row, owner item 23), `REQUIREMENTS_TRACEABILITY.md` (TEAM-04, ADMIN-04, MET-01, OPS-01, ADMIN-02), `docs/LATER.md` (delete what was built; add what was left), `docs/RUNBOOK.md` (going live: the migration, then the app build). `python tools/check_trace.py`. Graph refresh. Commit, push, CI.
