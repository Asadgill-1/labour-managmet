# Screen Flow

UI strings are Roman Urdu or English (D-004, locale `en_PK`). Dates DD-MM-YYYY, amounts with AED. Each screen has one main action. Touch targets at least 48 logical pixels, and status never relies on colour alone (UX-03, UX-04).

## Left side panel (D-027, supersedes UX-01's bottom tabs)

Hidden until the Menu button at the top left of a main screen opens it. The arrow in its header, a tap outside it, or Android back hides it. Setup and daily work share the same data, with no duplicate registers. Sites, Rates and Pichla baqaya list what the company and worker screens hold, using the same forms.

| Group | Section | State |
| --- | --- | --- |
| Rozana | Aaj: attendance for any date, bulk entry, copy last team, missing entries | Built |
| Register | Companies, Sites, Labour, Rates, Pichla baqaya | Built |
| Tankhwah aur paisa | Tankhwah, Advance, Adaigi, Kharche | Jald (P2) |
| Billing | Timesheet, Invoice, Paisay mile | Jald (P3) |
| Aur | Reports, Documents (P3), Backup, Plan (P4), Help (P5), Team (P6) | Jald |
| Fixed at the bottom | Apni company, Settings | Built |

## Onboarding (UX-02)

Language > email and password > verify email > company name > optional logo and TRN > first client and site > first worker > first attendance. Optional steps can be skipped. Tax profile is only required before a tax invoice. Before P4 the account steps do not exist, and the app opens on a local dev tenant.

## Main flows

**Daily attendance (ATT-01):** Date > client > site > select workers > review shift, times and rates > exceptions > preview > Save. Copying yesterday's team creates a draft that the owner still reviews (UX-05). Save is all or nothing, with row errors shown beside the row (ATT-04).

**Payroll (PAY-01):** Period > review work and contracts > allowances > approved deductions > preview > owner approves > post > record payment.

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

Use "Company se lena hai", "Mazdoor ko dena hai", "Is mahine ki kamai", "Pichla baqaya", "Ab ada kiya". Not debit or credit alone.

## Usability target (UX-06)

5 non-technical users, after setup: 10 same-rate workers entered in under 60 seconds, with at least 4 of 5 finishing without a trainer. This is a target until measured in the pilot.
