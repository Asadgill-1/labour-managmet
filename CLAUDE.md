# Labour Supply Management App

Android app for UAE labour-supply companies, Supabase control backend, Next.js owner dashboard. Spec: `PRD_Roman_Urdu.md`.

## Start of every session

1. Read `PROGRESS.md`, then the current task in `TASKS.md`, then run `git status`. Trust the repo, not chat memory (AI-04).
2. Load the Ponytail skill. For questions about the PRD or code, query the graph first: `graphify query "<question>"`.

## Commands

Tools are not on PATH by default. Run this first in Git Bash:

```bash
source /c/dev/env.sh
```

| Check | Command |
| --- | --- |
| Traceability | `python tools/check_trace.py` |
| Domain tests | `cd packages/domain && dart test` |
| App | `cd apps/mobile && flutter analyze && flutter test` |
| APK | `cd apps/mobile && flutter build apk` |

## Working rules

- One small task at a time: requirement ID, issue, branch `pN/tNN-name`, test, evidence, PR (AI-02).
- Task states: NOT_STARTED, IN_PROGRESS, BLOCKED, IMPLEMENTED_UNVERIFIED, VERIFIED, OWNER_ACCEPTED. Never VERIFIED without an actual test run (AI-03).
- Update `PROGRESS.md`, `TASKS.md` and `REQUIREMENTS_TRACEABILITY.md` in the same PR. Rebuild the graph with `/graphify . --update` when a task changes the docs or code.
- Log scope, price, payroll formula, permission, retention and billing changes in `DECISIONS.md` (AI-07). Missing feature: hide it or show it as unavailable, never fake it.
- Missing integration credentials: mark BLOCKED. A skip is not a pass (AI-06).

## Never

- `double` near money. Amounts are integer fils, durations integer minutes, one central rounding function (CALC-01).
- Editable balances. Balances derive from postings, payments, allocations and reversals (REP-08).
- A table without `tenant_id`, or tenant identity taken from an unverified request (BUILD-01, AUTH-02).
- "UAE law" defaults hard-coded for proration, overtime or deduction limits (CALC-04, CALC-07).
- Secrets, keystores, real customer records or production backups in git (AI-05). Secrets go in `.env` through masked prompts.
- Calling a PDF a UAE e-invoice (INV-09).
- Play uploads, production deploys, customer messages or repo visibility changes without the owner's explicit yes.
