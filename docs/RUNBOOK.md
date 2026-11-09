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

Cloud database: migrations and pgTAP tests live in `supabase/`. This computer has virtualisation off, so Docker and `supabase start` can't run here; the `supabase` CI job starts it in Docker and runs `supabase test db` on every push (D-060). The CLI here also fails to read `~/.supabase/profile`, so new migration files are named by hand, `YYYYMMDDHHMMSS_name.sql`. The live project got its first migration through the dashboard's SQL editor, with a row in `supabase_migrations.schema_migrations` like the one `supabase db push` writes (D-061). Later migrations go the same way, or by `supabase db push` once the CLI is linked, which needs the owner's sign-in and database password.

## Direct dependency licences

| Package | Licence |
| --- | --- |
| `drift`, `sqlite3` | MIT |
| SQLite3MultipleCiphers (bundled through `sqlite3`) | MIT |
| `flutter_secure_storage`, `path_provider`, `http` | BSD-3-Clause |
| `supabase` | MIT |
