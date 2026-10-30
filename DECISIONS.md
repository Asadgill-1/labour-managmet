# Decisions

Status: ACCEPTED (owner approved the plan on 2026-10-31), or PROPOSED (waiting for sign-off). New decisions go at the bottom. Never rewrite an old one; supersede it.

| ID | Status | Decision | Why |
| --- | --- | --- | --- |
| D-001 | ACCEPTED | Stack: Flutter, SQLite via `drift` on SQLCipher, key in `flutter_secure_storage`, Supabase, Next.js + TypeScript | PRD's proposal (ARCH-01..03). Encrypted DB binding must pass the T03 spike |
| D-002 | ACCEPTED | Riverpod and `go_router`; `pdf`, `printing`, `share_plus`; Ed25519 licences; Vercel for admin; Sentry confirmed at T23 with replay off | Disposing a Riverpod scope clears tenant state on logout (AUTH-04) |
| D-003 | ACCEPTED | Monorepo: `apps/mobile`, `apps/admin`, `packages/domain`, `supabase/`, the 8 AI-01 docs at root | One repo for one product. Move to `C:\dev\labour-managmet` if the space in the folder path breaks the Android build |
| D-004 | ACCEPTED | English for code and repo docs. Roman Urdu for app strings and owner checklists | BUILD-03 needs Roman Urdu for the owner, code readers need English |
| D-005 | ACCEPTED | One encrypted SQLite file per tenant, each with its own key | Strongest local isolation with the least code (AUTH-04) |
| D-006 | ACCEPTED | Integer fils and minutes, one central rounding function | CALC-01 forbids binary floating point for final totals |
| D-007 | ACCEPTED | Append-only ledger, balances derived | REP-08. Only opening-balance migration is editable |
| D-008 | ACCEPTED | Write every mutation to an outbox from P1 | TEAM-04. Avoids retrofitting sync in P6 |
| D-009 | ACCEPTED | Sync engine chosen by ADR at T25 (custom outbox vs PowerSync) | Depends on real data shapes that do not exist yet |
| D-010 | ACCEPTED | Roman Urdu uses locale `en_PK`, not `ur` | `ur` flips the app to RTL and loads Urdu-script Material strings |
| D-011 | ACCEPTED | P3 stores invoices as structured data, adds a structured export and labels PDFs as not e-invoices. Provider integration is a separate go/no-go before public sale | FTA notice of 25-10-2026: below AED 50m must appoint a provider by 31-03-2027 and implement by 01-07-2027, penalty AED 5,000 per month or part month. A tax adviser must confirm who is in scope |
| D-012 | ACCEPTED | Pilot through a signed APK. Final billing flow after Play policy review | BILL-07, BILL-08 |
| D-013 | ACCEPTED | Plan approval allows commits and pushes to feature branches, PRs merged after CI. Play uploads, production deploys, customer messages and visibility changes each need a separate yes | Owner approval gate |
| D-014 | ACCEPTED | One `.gitignore`-only commit went directly to `main` on 2026-10-31 | The remote was empty and PRs need a base branch. This exceeded D-013's wording and was reported to the owner |
| D-015 | ACCEPTED | Use the Graphify and Ponytail skills throughout. `graphify-out/` is gitignored and rebuilt on demand | Owner instruction on 2026-10-31 |

## Policy defaults (PROPOSED, sign-off at the P0 gate)

An accountant must review these before production. None of them is a legal opinion.

| ID | Topic | Default | Req |
| --- | --- | --- | --- |
| D-101 | Rounding | Half-up to fils per attendance line. VAT per invoice line; document total is the sum of lines | CALC-01, INV-04 |
| D-102 | Monthly proration | No default. Each contract must choose calendar days or a fixed divisor | CALC-04 |
| D-103 | Midnight shift | Work date is the shift start date; contract can override | ATT-06 |
| D-104 | Negative current wage | Block posting and send to review, never auto-carry as debt | PAY-07 |
| D-105 | Renewal on month end | Anchor on the original day, clamp to the last day of the month | BILL-04 |
