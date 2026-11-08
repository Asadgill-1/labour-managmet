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
| Supabase project | Owner | Not created (P4) |
| Email provider and domain | Owner | Not created (P4) |
| Admin hosting | Owner | Not created (P5) |

Environment sample (`.env.example`) arrives with the first secret in P4.

## Direct dependency licences

| Package | Licence |
| --- | --- |
| `drift`, `sqlite3` | MIT |
| SQLite3MultipleCiphers (bundled through `sqlite3`) | MIT |
| `flutter_secure_storage`, `path_provider` | BSD-3-Clause |
