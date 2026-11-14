# T20d: the cloud backup, the paid add-on

Status: for the owner's approval, 2026-11-14. Requirements: DATA-02, DATA-06, DATA-07, DATA-08, PLAN-03, PLAN-05, PLAN-06, BILL-02, AUTH-07. Builds on D-069 and D-070 (the backup file and its restore), D-072 (the owner's choices for the cloud copy) and D-074 (plans and the signed licence).

## Why

Today a company's data lives only on its phone and in the backup files it remembers to save. A phone lost without a file loses everything. The owner chose on 2026-11-11 that every company's encrypted backup goes to the cloud by itself, that bringing it back from the cloud is the paid add-on, and that the platform can open a copy for a company that forgot its backup password (D-072).

## What the owner decided

From D-072, 2026-11-11:

1. Every company's backup goes to the cloud, add-on or not. The platform pays for the storage.
2. Bringing a cloud copy back needs the add-on, at its own price (AED 20 a month for Small and Mid, AED 40 for Large), with no extra fee.
3. It is never hidden: signup and the Backup page say the encrypted backup is kept in the cloud, that bringing it back needs the add-on, and that the platform can open it to give it back.
4. Each copy's key is kept twice: locked by the company's backup password, and locked by the platform's recovery key. The app holds only that key's public half. The private half stays offline with the owner, with a second copy kept apart, never on the server, in git or in `.env`.
5. The backup password is asked once at signup, to be written down.
6. Without the add-on the cloud keeps the latest copy; with it, daily copies too.
7. After an account is deleted, the latest copy stays 60 days, then goes. It keeps only the company's id and the account's email.

On 2026-11-14:

8. The trial does not include bringing a cloud copy back. A trial company's copy still goes to the cloud; getting it back needs the add-on.
9. A daily copy is kept 30 days.
10. The app sends the copy by itself when it opens, at most once a day, only when the data changed and there is internet. The Backup page also has a button to send one now.

## Goals

- A company that signs up has a cloud copy from its first day, with nothing to press.
- A company that lost its phone logs in on a new one, sees that a copy exists and from when, buys the add-on if it has none, and gets its data back through the restore it already knows.
- A new phone's empty data never replaces the old phone's cloud copy without the owner saying so.
- The platform's owner can open a copy for a company that forgot its password, on a computer that is offline, and no one else can.
- The cloud decides who may bring a copy back. A changed app can't get one without the add-on.

## Non-goals

Sending while the app is closed; a Wi-Fi-only switch; copies larger than the storage's single-file limit (50 MB on Supabase's free tier; the live project's own limit is read when the bucket is made), which need a resumable upload; the dashboard's view of copies and add-ons (T22); the terms and the privacy policy's wording (T26); an email to support (T19d). Each goes to `docs/LATER.md`.

## Anti-goals

- Calling the copy end-to-end encrypted (DATA-08). The platform can open it, and the app says so.
- The platform's private key anywhere but offline with the owner.
- A backup file the user saves or sends being openable by the platform. Only the cloud copy carries the platform's lock, so D-069's promise for the file ("hum bhi nahin") stays true.
- A second backup format. The cloud copy must come back through the restore that exists.
- Deleting the last good copy before a newer one is safely stored.

## Approaches

**A. The same backup file with one more entry, behind a small cloud function (chosen).** The cloud copy is the backup zip of D-069, locked with the backup password, plus `recovery.json`: the copy's own key, sealed to the platform's public key. Storage is private with no rules for the app at all; a `backup` function hands out a one-time upload link or a 60-second download link after Postgres, asked as the user, says yes. Restore reads the copy exactly as it reads a file. Costs: one more cloud function, and working out the copy's key on the phone takes a few seconds in the background.

**B. The app talks to storage directly under row-level rules.** No function. But the rule that bringing back needs the add-on, and the removal of copies after 30 and 60 days, would then lean on the app, which a changed app ignores, and stored files can't be removed from SQL. Turned down.

**C. A new file format: a random key per copy, wrapped once by the password and once by the recovery key.** The textbook shape, but it is a second format, the restore screens need a second path, and every restore stretches the password in Dart. Turned down.

Also turned down: sealing the backup password itself to the platform. It is the least code, but the platform's key would then open every backup file the company ever saved with that password, not only the cloud copies.

## How it works

### The copy

- The zip of D-069 (`manifest.json`, `data.db` in SQLCipher 4's format) plus `recovery.json`.
- The copy's key is what SQLCipher itself derives: PBKDF2-HMAC-SHA512, 256,000 rounds, over the password and the file's own salt. The app works it out in the background and seals it with X25519, HKDF-SHA256 and ChaCha20-Poly1305 from the `cryptography` package the app already uses. The seal is bound to the company's id and the data's checksum, so it fits no other copy.
- A file saved or sent from the Backup page has no `recovery.json`.
- A build without the recovery key's public half (`RECOVERY_KEY` in `.env`) makes no cloud copy and says the cloud backup is unavailable.

### The platform's recovery key

- A tool in the repo, run by the owner on his own computer: `make` creates the pair, asks for a passphrase twice without showing it, writes the private half locked with that passphrase to a folder the owner names, and prints only the public half. It refuses a folder inside a git checkout.
- `open` takes the key file, its passphrase and a copy downloaded from the dashboard, and writes an ordinary backup file locked with a new password, which the owner gives to the company.
- `docs/RUNBOOK.md` gets the steps: making the key, keeping two copies apart, opening a copy only after checking the company's login email and its payment, and replacing the key.

### The cloud

- A private bucket `backups`, one folder per company, zips only, no access for the app.
- `cloud_backups`: one row per copy with its company, phone, size, time and whether it is a daily copy. The company's owner can read the rows, so the app can say a copy exists and from when, add-on or not.
- `backup_start`: the owner's first phone that is on asks to send a copy and gets its path. Refused when the latest copy came from another phone, unless the owner chose to replace it.
- `backup_finish`: once the file is seen in storage, the copy counts. It is a daily copy when the add-on is active then. Older copies go: every copy that is not the newest and is not a daily copy under 30 days old.
- `backup_download`: gives the path only to the owner, on the phone that is on, while an add-on period is active.
- The add-on is its own period, apart from the plan's, so a company in the middle of a paid month can buy it the day its phone is lost. A slip covers the plan, the plan with the add-on, or the add-on alone. `accept_slip` makes the periods; the licence carries the add-on's end.
- `plans` gets the days a daily copy is kept (30). `platform_settings` gets a support contact, typed by the owner in the live SQL editor like the bank details.
- Deleting an account moves the newest copy to a kept list with the company's id, the email and a date 60 days on; the others are marked to go at once. Each finished upload from any company also removes whatever is due, and the RUNBOOK has the command to run it by hand.

### The app

- **Signup:** after the company's name, a step for the backup password, typed twice, with the words to write it down and D-072's plain statement. It can't be skipped. A company that already exists and keeps no password yet sees a notice on Today.
- **Sending:** when the company opens, and when the app comes back to the front, a copy is sent if the last one is over a day old and the data changed since. It works with the plan ended too. A failure changes nothing and shows on the Backup page.
- **Backup page:** a cloud section with the last cloud copy's time or why none went, "Abhi cloud mein bhejein", the plain words, and the question when the cloud's copy came from another phone: bring that data back first, or keep this phone's data.
- **Plan lein:** each plan offers the add-on with its price and the new total. A company with a plan and no add-on can buy the add-on alone. Settings shows the add-on's end.
- **Restore:** "Cloud se" beside the file picker lists the copies with date and size. Without the add-on it says what is there and leads to Plan lein (in a Play Store build it says the add-on is unavailable there). With it, a copy downloads and goes through the same steps as a file: the label, the kept password or a typed one, the numbers check, the data here kept aside. "Password yaad nahin?" shows the support contact.
- **New phone:** the offer a company with no data here gets (D-070) says when the cloud's copy is from.
- **Deleting the account:** the screen says the latest cloud copy stays 60 days and then goes.

## Slices

1. **T20d-a, the cloud:** one migration, the `backup` function, pgTAP and Deno tests. It runs on the live project only on the owner's yes.
2. **T20d-b, sending:** the sealed key, the tool, the signup step, sending by itself, the Backup page, the deletion screen's words.
3. **T20d-c, getting it back:** the add-on on Plan lein and in the licence, and "Cloud se" in the restore.

## Builder's calls, for the owner to check

- The add-on bought alone costs the add-on price of the plan the company is on; a company with no paid plan names the plan, and the owner sees it on the slip.
- When the add-on ends, daily copies already made stay until each is 30 days old; no new daily copies are made.
- A copy over the storage's single-file limit is not sent, and the Backup page says so.
- The private key file is locked with a passphrase. If the passphrase or both copies are lost, a forgotten backup password can't be helped any more, as D-072 accepted.
- The 60-day removal rides on other companies' uploads rather than a timer. With no upload on a day, it waits for the next one or the RUNBOOK command.

## Tests

- pgTAP: who may start, finish and download; the other-phone refusal; which copies go; the add-on's periods alone and with a plan; the licence's add-on; the 60 days after a deletion; another company's owner gets nothing.
- Dart: the derived key opens the real SQLCipher file; the seal opens only with the private half and only for its own copy; a cloud copy restores through the existing check; a saved file carries no `recovery.json`; when a copy is sent and when not; the tool's `make` and `open` with a throwaway key.
- Screens drawn and read by eye: the signup step, the Backup page's cloud section, Plan lein with the add-on, "Cloud se" with and without the add-on, the deletion screen.
- On a phone, by the owner: a copy sent, the phone "lost", the add-on bought with a slip, the copy brought back on a second phone.
