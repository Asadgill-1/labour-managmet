# Audit status

Independent audit of the built application, started 2026-11-15. Branch `audit/t01-t21`, cut from `p4/t20d-c-restore` at `9ebcd9b` with a clean working tree. Nothing is pushed, deployed or run on the live Supabase project.

## Scope

The request names stages "D1 to D21". The repo has no documents by that name. It tracks work as tasks T01 to T26 in `TASKS.md` (phases P0 to P7) and decisions D-001 to D-078 and D-101 to D-105 in `DECISIONS.md`. This audit takes the stages to be **tasks T01 to T21**, which are the ones built. T22 to T26 (owner dashboard, telemetry, manager sync, release readiness) are NOT_STARTED and are recorded as not built, not as defects.

Sources of intended behaviour, in order: `PRD_Roman_Urdu.md` (166 requirement IDs), `DECISIONS.md` (later decisions override the PRD where they say so), `docs/CALCULATION_SPEC.md`, `docs/DATA_MODEL.md`, `docs/SCREEN_FLOW.md`, `docs/superpowers/specs/*.md`, `docs/LATER.md` (work deferred on purpose).

## Environment

Windows 10, Flutter 3.47.7, Dart 3.13.5, Python 3.12.10, Node present, Supabase CLI present. Docker cannot start (virtualisation off in the BIOS), so `supabase test db` cannot run here. Deno is not installed. No Android device or emulator.

## Baseline before any change

| Check | Result |
| --- | --- |
| `python tools/check_trace.py` | Pass: 166 PRD requirements traced |
| `dart analyze --fatal-infos` in `packages/domain` | Pass: no issues |
| `dart test` in `packages/domain` | Pass: 150 tests |
| `flutter analyze` in `apps/mobile` | Pass: no issues |
| `flutter test` in `apps/mobile` | See `VERIFICATION.md` |
| `supabase test db` | Not run here: needs Docker. Last CI run recorded in `PROGRESS.md` passed (43664625445) |
| `deno check`, `deno test` | Not run here: no Deno. Same CI run passed |

## First-party modules

Excluded as generated or vendored: `apps/mobile/lib/data/tenant_database.g.dart`, `tenant_database.steps.dart`, `lib/l10n/app_localizations*.dart`, `test/drift/tenant/generated/`, `drift_schemas/`, `build/`, `.dart_tool/`, `android/` Gradle wrappers, `graphify-out/`. Also outside the repo's tracked files: `apps/mobile/windows/` (local test runner), `test/zz*` (screen captures).

| Area | Files | Lines | Reviewed |
| --- | --- | --- | --- |
| Domain package | `packages/domain/lib/*.dart` (10) | 1,200 | See below |
| Write path, schema | `lib/data/tenant_database.dart`, `tables.dart`, `triggers.drift` | 1,200 | See below |
| Masters, attendance, payroll, cash, closing | `lib/data/{masters,attendance,payroll,statement,cash,visa,closing}.dart` | 2,240 | See below |
| Timesheets, invoices, receipts, papers, changes, import | `lib/data/{timesheets,invoices,receipts,documents,changes,import}.dart` | 3,300 | See below |
| Account, lock, licence, plans, backup, restore, cloud copy | `lib/data/{account,app_lock,licence,plans,plan_guard,backup,restore,cloud_copy,recovery}.dart` | 1,760 | See below |
| App shell | `lib/main.dart`, `lib/app/*.dart` | 2,400 | See below |
| Screens | `lib/features/**` (70 files) | 14,300 | See below |
| Papers | `lib/documents/document_frame.dart` | 500 | See below |
| Cloud | `supabase/migrations/*.sql` (6), `supabase/functions/**` (6), `supabase/tests/database/*.sql` (8), `config.toml` | 2,900 | See below |
| Tools and CI | `tools/check_trace.py`, `apps/mobile/tool/recovery_key.dart`, `.github/workflows/ci.yml` | 400 | See below |

Review state per area is kept in the "Reviewed modules" section, filled as each review is verified.

## Reviewed modules

| Area | State |
| --- | --- |
| `packages/domain/lib/money.dart`, `dates.dart` | Read in full by the auditor. BUG-002, OBS-002 |
| `lib/data/tenant_database.dart` (write path, migrations list) | Read in full by the auditor; review 03 read the triggers. BUG-010 |
| `android/app/src/main` (manifest, `MainActivity.kt`, `export_paths.xml`), `android/app/build.gradle.kts` | Read in full by the auditor. BUG-001, OBS-003, OBS-004 |
| `tools/check_trace.py`, `.github/workflows/ci.yml` | Read in full. No finding |
| Cloud: `supabase/migrations`, `supabase/functions`, `supabase/tests`, `config.toml`, and the app's account, licence and cloud copy code | Review 01 (`reviews/01-cloud-security.md`, 8 findings). Static only: no Docker or Deno here |
| Domain calculations, attendance, payroll, statement, cash, visa, closing | Review 02 (`reviews/02-payroll-money.md`, 10 findings) |
| Timesheets, invoices, receipts, papers, changes, import, write path triggers | Review 03 (`reviews/03-billing-data.md`, 7 findings) |
| Screens, registers, exports, app shell, strings | Review 04 (`reviews/04-screens-exports.md`, 9 findings) |
| The audit's own fixes | Review 05 (`reviews/05-final-diff.md`, 9 findings), read-only, of the product-code diff and the new migration; and the auditor's own read of every fixer's diff. Five became BUG-029 to BUG-033, fixed by the auditor; four are observations OBS-009 to OBS-012 |

Each review file lists the files its reviewer read in full. The four reviews made 34 findings. The auditor checked each one: 25 became defects (BUG-003 to BUG-027) and 10 are questions for the owner or an accountant (F02-2 gave one of each). BUG-028 was found while fixing BUG-003. Fixes were made by five fixers (Opus 5.5, on the owner's word), one Dart fixer at a time, each test seen failing before its fix. Their reports are in `docs/audit/fixes/`. The auditor read every diff and re-ran the tests after each one.

## Blockers

- Docker and Deno are missing, so the cloud's SQL tests and the functions' tests cannot be run here. The new migration `supabase/migrations/20261117120000_audit_fixes.sql` and its four test files are written, not run. CI's `supabase test db` is their first run.
- No phone or emulator: nothing on Android is verified (Keystore, share sheet, image picker, fingerprint, print, a release build logging in).
- The live Supabase project is out of bounds without the owner's yes. The new migration is not on it.
- T19d (real email) waits on the owner's domain (D-068).

## Uncommitted changes on `audit/t01-t21`

Nothing is committed or pushed. `git status` lists every change. In short:

- App and domain code for BUG-001 to BUG-024 and BUG-028 to BUG-033 (`apps/mobile/lib`, `packages/domain/lib`, the Android manifest), with their tests in `apps/mobile/test` and `packages/domain/test`; two new test files, `test/android_manifest_test.dart` and `test/audit_journey_test.dart`.
- The cloud's side of BUG-023, BUG-024, BUG-026 and BUG-027: `supabase/migrations/20261117120000_audit_fixes.sql` and four changed files in `supabase/tests/database/`.
- Records: `DECISIONS.md` (D-079, PROPOSED), `PROGRESS.md`, `TASKS.md`, `TEST_CASES.md` (TC-205 to TC-213), `REQUIREMENTS_TRACEABILITY.md`, `docs/DATA_MODEL.md` (OBS-005), `docs/SCREEN_FLOW.md` (BUG-015), and `docs/audit/`.
- Not refreshed: the graph in `graphify-out/` (the project's rule is the skill's `/graphify . --update`, never the bare CLI).

## Next actions

1. The owner reads the final report and decides on committing, D-079 and the questions in `BUG_REGISTER.md`.
2. After a commit and a push, on the owner's yes: CI's `supabase test db` and the Android job are the first runs of the cloud's SQL and of a release build.
3. On the owner's yes, the live project gets `20261114120000_cloud_backup.sql` (T20d-a) and then `20261117120000_audit_fixes.sql`, per `docs/RUNBOOK.md`.
4. On a phone: a release APK signs up, logs in, fetches its licence and sends its copy (BUG-001); the T20c and T20d phone tests already listed in `PROGRESS.md`.
