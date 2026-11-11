# Runbook

For the owner, an independent reviewer or a future buyer (AI-08). Extended as each phase adds parts.

## Reproduce the build

Requires Flutter 3.47.7 stable, Android SDK platform 36, JDK 17, Python 3.

```bash
git clone https://github.com/Asadgill-1/labour-managmet.git
cd labour-managmet
python tools/check_trace.py
(cd packages/domain && dart pub get --enforce-lockfile && dart test)
(cd apps/mobile && flutter pub get --enforce-lockfile && flutter analyze && flutter test)
(cd apps/mobile && flutter build apk --release --target-platform android-arm64)
```

On the original machine, `source /c/dev/env.sh` puts these tools on PATH. Backend steps are added when that part exists.

## Ownership

Everything stays under the owner's accounts and control. Nothing here holds a credential.

| Asset | Owner | Status |
| --- | --- | --- |
| Source code | `Asadgill-1` on GitHub, private | Active |
| Android signing keystore | Owner, backed up off the dev machine | Not created (before the first pilot APK) |
| Play Console | Owner | Not created (P7) |
| Supabase project | Owner | Created 2026-11-08, free plan, Singapore (D-061) |
| Email provider and domain | Owner | Not created (P4) |
| Admin hosting | Owner | Not created (P5) |

Environment: `apps/mobile/.env.example` names what `apps/mobile/.env` holds, the project URL and its publishable key, from Project Settings > API Keys. `.env` is git-ignored. The secret key never goes in it. Build or run with `--dart-define-from-file=.env` (for example `flutter build apk --dart-define-from-file=.env`) to get the account screens; without it the app works on the phone alone (D-062). Set `EMAIL_CODES=true` only once the project's email templates carry `{{ .Token }}`, which needs custom SMTP (T19d).

Cloud database: migrations and pgTAP tests live in `supabase/`. This computer has virtualisation off, so Docker and `supabase start` can't run here; the `supabase` CI job starts it in Docker and runs `supabase test db` on every push (D-060). The CLI here also fails to read `~/.supabase/profile`, so new migration files are named by hand, `YYYYMMDDHHMMSS_name.sql`. The live project got its first migration through the dashboard's SQL editor, with a row in `supabase_migrations.schema_migrations` like the one `supabase db push` writes (D-061). Later migrations go the same way, or by `supabase db push` once the CLI is linked, which needs the owner's sign-in and database password. `20261109120000_one_account_per_phone` went there through the SQL editor on 2026-11-09 (D-063).

One account per phone (D-063): to free a phone for another account, turn its device row off in the SQL editor, `update public.devices set revoked_at_utc = now() where device_id = '<id>';`. That account is then refused on the phone too. On Android the id is the phone's Android ID for this app, made into a UUID, so a debug and a release build of the app count as two phones.

Opening a backup without the app (D-069): unzip the backup file; `data.db` is a SQLCipher 4 database. In DB Browser for SQLCipher, open it, choose SQLCipher 4 defaults and type the backup password. `manifest.json` names the company's id, the schema version and the time it was made.

Deleting an account (D-066): `20261109130000_delete_account` adds `delete_account`, which removes the caller's own companies, members, devices and `auth.users` row, and only for a session signed in with the password in the last ten minutes. It went to the live project through the SQL editor on 2026-11-09, on the owner's yes (TC-157). The dashboard warns that the query is destructive, because the function's body deletes; running it deletes nothing.

Turning a phone off (D-073): `20261111120000_phone_off` adds `turn_phone_off` and `phone_is_off` and replaces `register_device`, so the owner's sign-in turns a phone back on. It went to the live project through the SQL editor on 2026-11-11, on the owner's yes (TC-174). The SQL can be put in the editor by opening `/dashboard/project/<ref>/sql/new?content=<the SQL, URL-encoded>`, then pressing Run. To turn a phone off by hand, set its device row's `revoked_at_utc` as for one account per phone above; it removes the company from itself as it next opens online.

Plans and the licence (D-074): `20261111130000_plans_licence` adds the plans, the trial, the payment slips and `licence_facts`, and the `licence` Edge Function signs what it says. Going live, each step on the owner's yes: run the migration in the SQL editor and record it; deploy the function; call `<project URL>/functions/v1/licence` once with GET, which makes the signing key in Vault and shows its public half, and put that half in `apps/mobile/.env` as `LICENCE_KEY`. Check first that the deployed function has `SUPABASE_SERVICE_ROLE_KEY`. The bank details go only there: `update public.platform_settings set bank_name = '...', account_number = '...', iban = '...', account_holder = '...', updated_at_utc = now();`. Waiting slips: `select s.id, t.name, s.plan_code, s.months, s.expected_fils, s.file_path, s.submitted_at_utc from public.payment_slips s join public.tenants t using (tenant_id) where s.state = 'waiting' order by s.submitted_at_utc;`, the file in Storage's `payment-slips` bucket. After finding the money in the bank: `select private.accept_slip('<slip id>', <amount in fils>, '<bank reference>', '<date received>', '<note>');`, or `select private.refuse_slip('<slip id>', '<the reason the customer sees>');`. Taking a period back: `select private.revoke_subscription('<period id>', '<reason>');`. Companies over their plan: `select t.name, u.active_workers, u.active_clients, u.reported_at_utc from private.usage_reports u join public.tenants t using (tenant_id);`, against their plan's limits. Freeing a trial on request: `delete from private.trial_claims where hash = private.email_hash('<email>');`. It went live on 2026-11-11 on the owner's yes: the migration in four parts through the SQL editor, since its editor link holds about 10 KB at most (the dashboard asks about row level security, answered Run without RLS, since the SQL turns it on itself, and about destructive statements in `delete_account`, answered Run query); then `supabase functions deploy licence --project-ref <ref> --use-api --no-verify-jwt` after the owner's `supabase login`. This computer's `SUPABASE_ACCESS_TOKEN` belongs to another account, so Supabase CLI commands here run with it unset (`env -u SUPABASE_ACCESS_TOKEN supabase ...`). Slip files a deletion left behind: `select o.name from storage.objects o where o.bucket_id = 'payment-slips' and not exists (select 1 from public.payment_slips s where s.file_path = o.name);`, removed in the Storage page.

## Direct dependency licences

| Package | Licence |
| --- | --- |
| `drift`, `sqlite3` | MIT |
| SQLite3MultipleCiphers (bundled through `sqlite3`) | MIT |
| `flutter_secure_storage`, `path_provider`, `http`, `local_auth`, `crypto` | BSD-3-Clause |
| `supabase` | MIT |
