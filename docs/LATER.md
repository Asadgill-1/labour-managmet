# Later

Everything promised for a later task, in one place, so nothing is lost between sessions. Each line names where it was decided. When a task starts, read its part here with its row in `TASKS.md`; when a line is built, delete it here in the same PR.

## T21b: the app's licence and the plan page

- Check the signed licence with the public half kept in `.env` as `LICENCE_KEY`; one pure-Dart Ed25519 package, its licence checked (D-002, D-074).
- Fetch the licence at start and after login when online, sending the counts of active workers and client companies; keep it in secure storage with the latest time the phone has seen (BILL-05, BILL-06).
- A clock moved back before the latest time seen, or before the licence's issue time, needs an online check. An older licence than the one kept is ignored (replay).
- Settings shows the plan, its end, the last check and the next check due (BILL-05).
- The Plan lein page: the plans from the cloud in order with AED prices and limits ("Unlimited" when there is none); managers and the cloud backup add-on as "jald aa raha"; the bank details, showing only those filled, with a copy button on the account number and the IBAN; plan and months (1 to 12) with the total; the slip as a photo or PDF up to 5 MB; then the slip's state and the refusal reason. Hidden in a Play Store build (BILL-07).
- The home screen shows the trial's days left from 5 days before the end.
- Account deletion first removes the company's slip files through Storage, then deletes the account, because SQL can't remove a stored file.
- On a refused licence the app says why: "Is account par ek aur phone chal raha hai. Purana phone band karein." opens the T20c page; a phone turned off follows T20c.
- Screens drawn as images and read by eye before any APK.

## T21c: enforcement

- One guard at `TenantDatabase.applyOperation`, the single write path, so no screen can miss it.
- Safe mode (plan ended, lease past 7 days offline, no valid licence) allows only: viewing, archiving, issuing and reprinting papers of what exists (PDFs), Excel export, the backup file and restore, the company profile and settings, turning a phone off. Everything else is refused with a reason that opens Plan lein; buttons for new entries show a lock (PLAN-03, D-072).
- Adding or un-archiving a worker or client company past the plan is refused: "Is plan mein 15 workers hain".
- A company already over its plan sees "Kaun se 15 active rahein?"; the rest are archived with history and balances untouched (PLAN-04); new entries wait until it is done.

## After T21 went live (2026-11-11)

- The owner types the bank name, account number, IBAN and holder into `platform_settings` in the live SQL editor, never in git, before Plan lein ships (T21b).
- The app's first live licence: the owner's company fetches a signed trial licence that `LICENCE_KEY` checks (T21b's test on a phone).

## T22: the owner's dashboard

- Slips: a list of waiting slips with the file, accept with amount, bank reference, received date and a note, or refuse with a reason. Until then the prepared SQL in `docs/RUNBOOK.md` (BILL-01, ADMIN-03).
- Every accept, refuse, revoke, refund and correction with actor, time and reason in an audit log; a finance change never overwrites the first entry (ADMIN-03, BILL-04).
- Upgrading mid-period: today an accepted Mid slip starts after the current Small period ends. The dashboard should offer starting it at once, with the rest of the old period credited or not, as the owner decides then.
- Grace extension and suspend, plan migration, refund (ADMIN-03).
- Companies over their limit, from the counts each licence check reports (`private.usage_reports`).
- Replacing the licence signing key: a button that makes a new pair, keeps the old public half valid until every phone has the new one, and shows the new public half for the next app build.
- Freeing a trial claim on request, as the RUNBOOK's SQL does now.
- The account deletion web way by request (D-067), with T26.
- The customer register (ADMIN-02): tenant id, contact, signup date, email verified, plan, trial or expiry, seats and phones, last online, app version, payments.
- MFA for the admin (ADMIN-01), Vercel hosting (D-002).

## T19d: real email through Resend (BLOCKED until the owner has a domain and a Resend account, D-068)

- Signup and reset emails from the app's own domain; reset by code ("Password bhool gaye?" is unavailable until then).
- An email to the platform's address when a slip arrives, with the company, plan, months and amount expected.
- The account deletion web request's code (D-067).

## T20d: the cloud backup, the paid add-on (D-072)

- The backup password asked once at signup, to be written down.
- Each copy's key locked twice: by the backup password and by the platform's recovery key, whose private half stays offline with the owner, with a second copy kept apart, never on the server, in git or in `.env`.
- The latest copy always kept; with the add-on, daily copies too, the number set with the plans (PLAN-05).
- After an account deletion, the latest cloud copy stays 60 days, keeping only the company id and email to find it, then goes; the deletion screen, the terms and Play's answers say so.
- The add-on in the licence, and its price on Plan lein (2000 fils for Small and Mid, 4000 for Large), once it is built.
- Never called end-to-end encrypted (DATA-08).

## T23: telemetry, health, support

- Sentry with session replay off (D-002); minimal events; support tickets kept 30 days after they close.
- Investor metrics from real sources only: 1 tenant with 2 users and 2 devices counts as 1 customer.
- Alerts and budget limits.

## T24: managers

- Invites, permission presets, a manager's own phone (one phone per person also for managers, D-074).
- The manager limit from the plan: Small 1, Mid 2, Large unlimited.
- A manager's phone turned off gets a way back (D-073).
- Removing a member; handing a company over before the owner deletes the account (D-066).
- Rows a manager enters held until the owner sees them; closing and opening months stay with the owner.

## T25: sync

- Sync ADR (custom outbox or PowerSync); two phones of one company in step; conflicts.
- Each device its own paper, timesheet and invoice numbers, or numbers from the server for Team tenants (INV-08).
- Images and stored files carried on their own, since the outbox holds no bytes.
- A phone whose session or device was revoked locks itself; the cloud can then count workers itself rather than trust the phone's counts.

## T26: release

- The privacy policy discloses the trial claims (a hash of the email and the phone id, kept after deletion to stop repeat trials) and the slip files; a lawyer reads it, and the cloud copy wording (D-072).
- Play's data safety and deletion answers; the deletion web page (D-067).
- The payment page stays off in a Play build until the policy review (BILL-07, BILL-08); the bank account's fitness for these receipts checked with the bank (BILL-09).
- Independent reviews, benchmarks, full regression (QA-01).

## Owner decisions still open

- Whether payment records (amount, date, bank reference) stay for the platform's own books after a customer deletes the account; today they go with it (D-066, D-074). An accountant should say how long the platform must keep them.
- The real account number and the IBAN for the live settings (the number given in chat looked like an example).
- Whether a payment made during the trial should start after the trial's last day instead of at once (D-074 starts it at once).
