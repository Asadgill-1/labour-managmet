# T22b: the app's side of holds and its version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A held account's phone says why it is locked and who to call; every licence check tells the cloud the app's version.

**Architecture:** The licence already says `state = 'none'` while a hold is live (T22a), so the existing read-only mode applies; the app only reads the licence's new `hold` and words the lock with it. The version is a constant next to `pubspec.yaml`'s, checked by a test, sent in the licence request.

**Tech Stack:** Flutter, the existing `Licence`, `planRefusal` and `plan_lock.dart`.

**Spec:** `docs/superpowers/specs/2026-11-22-t22-owner-dashboard-design.md` ("What the customer's app does"), D-081 (7).

## Global Constraints

- The books stay readable, printable, exportable and backed up while held: no new block on reads, exports, backup or restore (D-081 (7)).
- The owner's words are shown as he wrote them, in quotes, never translated.
- Strings in both arb files, then `flutter gen-l10n`.

## Review Focus

- A held licence that also carries an end date in the past (the phone offline since): the lock still reads as held until the next check, since the licence the phone holds says so.
- A hold with no end date: the text leaves the date out rather than printing "null".

---

### Task 1: The licence's hold, the lock's words, the version

**Files:**
- Modify: `apps/mobile/lib/data/licence.dart` (`Licence.hold`, parsed from `hold`)
- Modify: `apps/mobile/lib/data/plan_guard.dart` (`PlanBlock.held`)
- Modify: `apps/mobile/lib/features/plans/plan_lock.dart` (the held note and its support action)
- Modify: `apps/mobile/lib/features/plans/plan_screen.dart` (`PlanStatusSection` shows the hold)
- Modify: `apps/mobile/lib/features/backup/restore_screen.dart` (its support dialog moves to a shared `showSupportContact`)
- Create: `apps/mobile/lib/app/version.dart` (`const appVersion = '0.1.0';`)
- Modify: `apps/mobile/lib/data/account.dart` (`'app_version': appVersion` in the licence body)
- Modify: `apps/mobile/lib/l10n/app_en_PK.arb`, `app_en.arb`
- Test: `apps/mobile/test/licence_test.dart`, `apps/mobile/test/plan_lock_test.dart` or the file that tests the lock today, `apps/mobile/test/version_test.dart`

**Interfaces:**
- Produces: `typedef LicenceHold = ({String kind, DateTime? until, String told});` and `final LicenceHold? hold;` on `Licence`; `PlanBlock.held`, chosen by `planRefusal` when the status is `ended` and the licence has a hold; `Future<void> showSupportContact(BuildContext context, Account account, {required String title, String? body})`.
- Strings: `planHeldNote(told)` "Platform ne aap ka account rok diya hai: “{told}”. Jo likha hai wo dekh, chhap aur export kar sakte hain."; `planHeldUntilNote(date, told)` "Platform ne aap ka account {date} tak rok diya hai: “{told}”. Jo likha hai wo dekh, chhap aur export kar sakte hain."; `planSupport` "Support se rabta"; English: "The platform has paused your account: …" and "… until {date}: …", "Contact support".

- [ ] **Step 1: Write the failing tests**: a signed licence with `"hold": {"kind": "suspend", "until": "2026-12-01T00:00:00Z", "told": "Support se rabta karein"}` reads into `hold` with those values, and one with `"hold": null` into null; `planRefusal` on that held licence gives `PlanBlock.held`; the lock's text holds the told words and the date, and with no `until` no date; reading `pubspec.yaml`'s `version:` before the `+` equals `appVersion`; the licence request's body carries `app_version`.
- [ ] **Step 2:** `flutter test` on those files fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** The files pass, then the full `flutter test` and `flutter analyze`.
- [ ] **Step 5:** Draw the held lock and Settings as images (`test/zz`) and read them.
- [ ] **Step 6: Commit** by name.
