# Screen Flow

UI strings are Roman Urdu or English (D-004, locale `en_PK`). Dates DD-MM-YYYY, amounts with AED. Each screen has one main action. Touch targets at least 48 logical pixels, and status never relies on colour alone (UX-03, UX-04).

## Left side panel (D-027, supersedes UX-01's bottom tabs)

Hidden until the Menu button at the top left of a main screen opens it. The arrow in its header, a tap outside it, or Android back hides it. Setup and daily work share the same data, with no duplicate registers. Sites, Rates and Pichla baqaya list what the company and worker screens hold, using the same forms.

| Group | Section | State |
| --- | --- | --- |
| Rozana | Aaj: attendance for any date, by group or by worker, copy last team, missing entries. Rozana hisaab: money in and out for any date | Built |
| Register | Companies, Sites, Labour, Mazdoor group, Rooms, Rates, Pichla baqaya | Built |
| Tankhwah aur billing | Tankhwah | Built |
| Tankhwah aur billing | Timesheet, Invoice, Paisay mile (P3) | Jald |
| Aur | Reports, Documents (P3), Backup, Plan (P4), Help (P5), Team (P6) | Jald |
| Fixed at the bottom | Apni company, Settings | Built |

## Onboarding (UX-02)

Language > email and password > verify email > company name > optional logo and TRN > first client and site > first worker > first attendance. Optional steps can be skipped. Tax profile is only required before a tax invoice. Before P4 the account steps do not exist, and the app opens on a local dev tenant.

## Main flows

**Daily attendance (ATT-01):** Date > group or single workers > client > site > review shift, times and rates > exceptions > preview > Save. A group ticks its members and fills in its company, site and times. Group and worker have separate searches. Unticking a member, or adding someone new (who is asked for a daily wage, starting from the group's), lasts for that attendance only (D-029). Copying yesterday's team creates a draft that the owner still reviews (UX-05). Save is all or nothing, with row errors shown beside the row (ATT-04).

**Daily money (D-030):** Money given or received > what it was for > worker, room, company or expense type > amount > Save. The line shows on that worker or room by itself. Tapping a line offers to undo it with a reason. The original stays on record.

**Room result (D-031):** Rooms > month > rent received, rent paid, and the difference in words as profit, loss or even.

**Payroll (PAY-01, D-033):** Month > everyone with pay or a problem, with what stops them in words > approve waiting attendance or add room charges in one tap > a worker's screen for allowances, deductions and advance recovery > post everyone who is ready, after one confirmation > record the payment, which goes through the cash book. Undo with a reason reopens that worker's month.

**Timesheet (TS-01):** Client > date range > site > daily summary or worker detail > commercial or non-commercial version > approve > share.

**Invoice (INV-01):** Client > period > site or timesheet items > PO reference > quantities > tax review > preview > issue. The final number is assigned only at issue.

**Share (DOC-06, DOC-07):** Preview > recipient and document summary > save, print, share sheet or WhatsApp. The user picks the recipient and sends. "Share opened" is never shown as "delivered".

## Status words (UX-07)

| Status | Meaning |
| --- | --- |
| Mobile par save | Committed to the local database |
| Sync baqi | Waiting to reach the server (Team only) |
| Server par save | Server acknowledged it |

Offline never shows a blocking spinner. A financial error is never retried silently.

## Labels (UX-03)

Use "Company se lena hai", "Mazdoor ko dena hai", "Is mahine ki kamai", "Pichla baqaya", "Ab ada kiya". Not debit or credit alone. A credit reads "Pehle se ada kiya" or "Zyada ada kiya", never a negative salary.

## Usability target (UX-06)

5 non-technical users, after setup: 10 same-rate workers entered in under 60 seconds, with at least 4 of 5 finishing without a trainer. This is a target until measured in the pilot.
