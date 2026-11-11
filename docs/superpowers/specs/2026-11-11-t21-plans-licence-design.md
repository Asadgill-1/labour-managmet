# T21: plans, trial, payment slips and the signed licence

Status: for the owner's approval, 2026-11-11. Requirements: BILL-02, BILL-03, BILL-05, BILL-06, PLAN-03, PLAN-04, PLAN-06. Builds on D-002 (Ed25519 licences), D-062, D-063, D-072.

## Why

The app has no plans yet: every company gets everything, for good. The owner wants to sell three monthly plans, paid by bank transfer outside the app, after a free trial. Nobody should be able to use more than they paid for by a trick, and nobody's data should ever be held hostage.

## What the owner decided (2026-11-11)

1. **Trial period:** 15 days from signup, every feature, no card.
2. **Plans**, per month, prices in AED:

   | Plan | Price | Add-on | Active workers | Client companies | Managers |
   | --- | --- | --- | --- | --- | --- |
   | Small Company | 199 | 20 | 15 | 5 | 1 |
   | Mid Size Company | 299 | 20 | 35 | 9 | 2 |
   | Large Size Company | 499 | 40 | unlimited | unlimited | unlimited |

   The add-on is the cloud backup (D-072). "Companies" means client companies.
3. **Paying:** a "Plan lein" page shows the plans, then the bank details (RAK Bank, the account number with a copy button, the account holder Asad Aslam), then a place to upload the transfer slip. The slip reaches the platform; the owner checks the bank, and opens the plan for that company.
4. **After the trial, unpaid:** what was entered stays visible and PDFs can be made, but no new entry until a paid plan is taken.
5. **Approach A:** a signed licence, chosen over reading the plan unsigned.
6. **No key typed anywhere:** the owner did not want to sign in to Supabase to place the signing key.
7. **Limits must hold** against tricks, checked in the cloud where it can be.
8. Agreed: prices and bank details live in the cloud's plan config, not in the app or the public repo; managers show as "jald aa raha" until T24; the slip arrives by email only once Resend is set up (T19d), and until then the owner sees it in the Supabase dashboard; the payment page is in the pilot APK only, and off in a Play Store build until the policy review (BILL-07, T26).

## Goals

- A company gets the trial at signup, once per phone and per email.
- The plan page, the bank details, the slip upload, and the slip's state (waiting, accepted, refused with a reason).
- The owner accepts or refuses a slip with one prepared SQL command until T22's dashboard.
- The cloud signs a licence; the app trusts only a valid signature, for at most 7 days offline (BILL-05).
- Limits and the unpaid mode are enforced at the app's single write path, so no screen can miss them.

## Non-goals

T22's admin dashboard and renewal ledger (BILL-04); email on a new slip (T19d); Play Billing; managers (T24); the cloud backup add-on itself (T20d), shown as "jald aa raha" until then; activation codes (BILL-02 asks for them only "zaroorat par", and the app picks up an accepted plan by itself).

## Anti-goals

- Deleting, hiding or locking a company's data when a plan ends, or charging to get it out: viewing, PDFs, Excel export, the backup file and restore always work (PLAN-03, PLAN-06, D-072).
- Selling what isn't built.
- A secret in git, in chat, or typed by Claude.

## Approaches

- **A. Signed licence (chosen).** The cloud signs the company's plan with Ed25519; the app holds only the public key, and believes a plan only with a valid signature. A tampered phone can't grant itself a plan. Costs an Edge Function and a key.
- **B. Unsigned plan.** The app reads its plan from the cloud and keeps it. No function or key, but a rooted phone with the database key could give itself any plan offline; fails BILL-03.
- **C. Sign inside Postgres.** Needs pgsodium, which Supabase has deprecated. Dropped.

## Design

### Cloud (T21a)

- **`plans`**: versioned config, one row per plan version: code, version, name, monthly price and add-on price in integer fils (CALC-01), limits (workers, clients, managers, devices; null = unlimited), features, and whether it is on sale. Seeded with the three plans and the trial. A price change is a new version; a company keeps the version it paid for until renewal.
- **`platform_settings`**: the bank name, account number and holder. Readable by signed-in users, written only by `postgres`. Filled on the live project through the SQL editor, never in git.
- **`subscriptions`**: per company: plan code and version, start, end, source (trial or payment slip), and revoked with a reason. Server-only writes (MODEL-05). `create_tenant` starts the 15-day trial. Companies made before this migration get their 15 days from the day it runs, so nobody already testing is locked out at once.
- **`trial_claims`**: a hash of the phone's id and of the email, kept even after an account is deleted, so a new signup on the same phone or with the same email gets no second trial. Disclosed in the privacy policy (T26).
- **`payment_slips`** and a private storage bucket: the owner of a company uploads an image or PDF up to 5 MB into the company's own folder, with the plan and months chosen. At most 3 waiting slips per company. `private.accept_slip(id, months)` makes the subscription, starting at the end of the current paid period if it hasn't ended, else today; a month runs to the same day next month, clamped to that month's last day (BILL-04, the P0 rule). `private.refuse_slip(id, reason)`. Both callable only by `postgres`, that is, from the SQL editor or later T22.
- **`usage_reports`**: each licence request carries the phone's counts of active workers and client companies; the cloud keeps the latest, so the owner can see a company over its limit (T22, T23).
- **Licence function** (Edge Function `licence`): takes the caller's session, the company id, the phone's id and the counts. It refuses a phone the company turned off (D-073) and anyone not a member. A plan allows 1 phone plus one per manager; a phone past that gets no licence and is told to turn an old phone off (T20c). It returns the licence: company id, plan, plan version, limits, features, plan start and end, `lease_until` (now + 7 days, never past the plan's end), the phone's id, issuer, token id, issued at, and schema version (BILL-03), with an Ed25519 signature over its exact bytes.
- **The key is made in the cloud.** On its first run, the function makes the key pair itself and keeps the private half in Supabase Vault, readable only by the function. Nobody types or sees it. The public half is shown by a public call, and goes into the app's build settings (`.env`) once. This answers the owner's wish not to place a key by hand. Replacing the key later becomes a T22 button.

### App (T21b, T21c)

- **Licence:** fetched at start and after login when online, kept in secure storage, checked against the public key on every read. Settings shows the plan, its end, the last check and the next check due (BILL-05).
- **Clock:** the app keeps the latest time it has seen. A phone clock moved back before that, or before the licence's issue time, needs an online check (BILL-06).
- **States:** trial or paid and within limits: everything. Unpaid, ended, lease past 7 days offline, or no valid licence: the safe mode the owner chose. A build with no cloud settings has no plans, for development only.
- **Enforcement:** at `applyOperation`, the single write path, so no screen can miss it. Safe mode allows only archiving, issuing and reprinting papers of what already exists, Excel export, the backup file and restore, the company profile and settings. Everything else is refused with a reason that opens the plan page. Buttons for new entries show the lock too.
- **Limits:** adding or un-archiving a worker or client company past the plan's number is refused with "Is plan mein 15 workers hain". If a company is already over (40 workers after the trial, then Small), the app shows "Kaun se 15 active rahein?"; the rest are archived with their history and balances untouched (PLAN-04), and new entries wait until it's done.
- **Plan lein page:** the plans and prices from the cloud config, managers and the add-on as "jald aa raha", the bank details with a copy button for the account number, then the slip upload and the slip's state. Hidden in a Play Store build (BILL-07).
- **Trial note:** the days left, on the home screen from 5 days before the end.

### Against tricks (the owner's question 2)

Workers stay on the phone; the cloud doesn't hold them until sync (T25), so the cloud can't count them itself. The limit is in the signed licence, which a phone can't change, and the app enforces it at its single write path. Each licence request reports the counts, so the owner sees a company over its limit. A second trial on the same phone or email is refused. A phone turned off gets no licence. A clock moved back forces an online check. What no offline app can stop is someone who rebuilds the app itself (BILL-06); for that, the counts reported to the cloud are the alarm.

## Tests

- pgTAP: trial at signup and once per phone and email; plans readable, not writable; slips only in the company's own folder and rows, the limit of 3; accepting and refusing only by `postgres`; renewal dates; usage reports.
- Deno (new CI job): the licence payload, signing, and refusal of a turned-off phone or a non-member.
- Dart: signature check (good, tampered, wrong key), lease and clock rules, the write-path guard in each state, the limits and the chooser, the plan page and the slip.
- Screens drawn as images and read by eye; the owner's two-phone run.

## Left to the builder

The exact table columns, the allow-list of actions in safe mode, the Dart Ed25519 package (pure Dart, licence checked), and how the slip picker reuses the backup file channel.

## Needs the owner later

A yes before the migration and the Edge Function go live; the bank details to put in the live config; a lawyer's look at the trial-claims retention.
