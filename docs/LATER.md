# Later

Everything promised for a later task, in one place, so nothing is lost between sessions. Each line names where it was decided. When a task starts, read its part here with its row in `TASKS.md`; when a line is built, delete it here in the same PR.

## After T21 went live (2026-11-11)

- The owner types the bank name, account number, IBAN and holder into `platform_settings` in the live SQL editor, never in git, before Plan lein ships (T21b).
- The app's first live licence on a phone: the owner's company fetches a signed trial licence that `LICENCE_KEY` checks, then Plan lein with the real bank details and a test slip (TC-184).
- T21c on a phone with a throwaway company: the locks after its trial is taken back, then Small's 16th worker and the chooser (TC-189).

## T22: the owner's dashboard

- Slips: a list of waiting slips with the file, accept with amount, bank reference, received date and a note, or refuse with a reason. Until then the prepared SQL in `docs/RUNBOOK.md` (BILL-01, ADMIN-03).
- Every accept, refuse, revoke, refund and correction with actor, time and reason in an audit log; a finance change never overwrites the first entry (ADMIN-03, BILL-04).
- Upgrading mid-period: today an accepted Mid slip starts after the current Small period ends. The dashboard should offer starting it at once, with the rest of the old period credited or not, as the owner decides then.
- Grace extension and suspend, plan migration, refund (ADMIN-03).
- Companies over their limit, from the counts each licence check reports (`private.usage_reports`).
- Ending or giving back a trial or a period from the dashboard, so safe mode can be shown to a customer or tried without the SQL editor (T21c's phone test uses `private.revoke_subscription`).
- Slips whose file never arrived (a dropped upload the customer did not retry): shown as such, refused in one tap. The app could also send the file again to the same slip; today it says "File nahin pohanchi" and the customer sends a new slip (T21b).
- Replacing the licence signing key: a button that makes a new pair, keeps the old public half valid until every phone has the new one, and shows the new public half for the next app build.
- Freeing a trial claim on request, as the RUNBOOK's SQL does now.
- The cloud backup (T20d): what a slip covers shown with it; each company's copies and add-on periods; taking an add-on period back; a button that removes the files due from storage, which today happens on the next finished upload or by hand; a deleted account's kept copy found by its email; downloading a copy to open for a company that forgot its backup password, with the check of its login email and payment recorded.
- The account deletion web way by request (D-067), with T26.
- The customer register (ADMIN-02): tenant id, contact, signup date, email verified, plan, trial or expiry, seats and phones, last online, app version, payments.
- MFA for the admin (ADMIN-01), Vercel hosting (D-002).

## T19d: real email through Resend (BLOCKED until the owner has a domain and a Resend account, D-068)

- Signup and reset emails from the app's own domain; reset by code ("Password bhool gaye?" is unavailable until then).
- An email to the platform's address when a slip arrives, with the company, plan, months and amount expected.
- The account deletion web request's code (D-067).
- A way to write to support from the app about a forgotten backup password; until then the app shows the support contact (T20d).

## T20d: the cloud backup, the paid add-on (D-072, D-075, D-076)

The design is `docs/superpowers/specs/2026-11-14-t20d-cloud-backup-design.md`; what the app calls is in `docs/superpowers/plans/2026-11-14-t20d-a-cloud.md`.

T20d-a, the cloud, is built and not live:

- On the owner's yes: the migration and the `backup` function on the live project, the upload limit checked, the support contact typed into the live settings (TC-194, RUNBOOK under The cloud backup).

T20d-b, sending, is built (D-077):

- The owner makes the recovery key on his computer with `tool/recovery_key.dart make`, keeps a second copy apart, and puts the printed `RECOVERY_KEY` in `apps/mobile/.env` (RUNBOOK under The cloud backup). Until then a build sends no copy.
- On a phone, after the live run and the key: a throwaway company's first copy in the cloud, downloaded and opened with the tool (TC-199).

T20d-c, getting it back:

- Plan lein offers each plan with the add-on, its price and the new total (2000 fils for Small and Mid, 4000 for Large), and the add-on alone for the plan the company is on (`submit_slip`'s `p_covers`). Settings shows the add-on's end from the licence's `addon_until`.
- "Cloud se" beside the file picker in the restore: the copies with date and size; without the add-on it says what is there and leads to Plan lein, and in a Play Store build it says the add-on is unavailable there; with it the copy downloads and goes through the same steps as a file. "Password yaad nahin?" shows the support contact.
- The offer a new phone's empty company gets (D-070) says when the cloud's copy is from.
- After a cloud copy is brought back onto this phone, the next copy goes with `replace`, so the brought-back data takes the old phone's place without the question. Until then the Backup page asks (D-077), and "Pehle wo data wapas laayein" opens the restore from a file.
- Never called end-to-end encrypted (DATA-08).
- On a phone, by the owner: a copy sent, the phone "lost", the add-on bought with a slip, the copy brought back on a second phone.

After T20d:

- Sending while the app is closed, and a Wi-Fi-only switch.
- Copies over 50 MB, which need a resumable upload.

## T23: telemetry, health, support

- Sentry with session replay off (D-002); minimal events; support tickets kept 30 days after they close.
- Investor metrics from real sources only: 1 tenant with 2 users and 2 devices counts as 1 customer.
- Alerts and budget limits.

## T24: managers

- Invites, permission presets, a manager's own phone (one phone per person also for managers, D-074).
- The manager limit from the plan: Small 1, Mid 2, Large unlimited.
- A manager's phone turned off gets a way back (D-073).
- Removing a member; handing a company over before the owner deletes the account (D-066).
- Deleting the account removes the slip files before the cloud's refusal for other members can come (T21b), since only the signed-in owner can remove them. Once members exist, ask the cloud first, then remove the files.
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
