# Calculation Specification

Source of truth for `packages/domain`. Figures are arithmetic fixtures from the PRD, not labour-law or tax advice. An accountant reviews this before production.

## Units

- **Money:** integer fils. 1 AED = 100 fils. No `double` anywhere near money (CALC-01).
- **Time:** integer minutes. Timestamps stored in UTC, displayed in Asia/Dubai.
- **Percentages:** integer basis points. 5% = 500.
- **Rounding:** one function, `divRoundHalfUp` in `packages/domain/lib/money.dart`. Half-up on magnitude, so a reversal is the exact negative of its original (D-101).

## Attendance line

| Value | Rule | Req |
| --- | --- | --- |
| Clock minutes | `end - start`. The end may fall on the next day. 20:00 to 08:00 = 720 | CALC-02, ATT-06 |
| Validity | `0 <= break <= clock`, otherwise the row is rejected | ATT-06 |
| Client billable minutes | `clock - client unpaid break` | CALC-02 |
| Worker payable minutes | `clock - worker unpaid break` | CALC-02 |
| Work date | The date entered by hand. A night shift keeps it even when it ends next day (D-024) | ATT-06 |

The client and worker sides are calculated independently and can differ.

## Amount by contract basis

| Basis | Rule | Req |
| --- | --- | --- |
| Hourly | `divRoundHalfUp(minutes * rate_fils_per_hour, 60)` per attendance line | CALC-02 |
| Shift or day | Agreed fee by eligibility: full, half, or explicit partial amount, plus extra time if contracted. Never `hours * rate` | CALC-03 |
| Worker monthly | Once per payroll period, never per attendance row. Full period = the monthly amount exactly. Partial period uses the method on the contract | CALC-04 |
| Client monthly per worker | Monthly fee times the number of contracted workers | CALC-05 |
| Client fixed monthly | One fee for the contract, never multiplied by worker rows. Attendance is evidence only | CALC-05, TS-08 |

**Partial period:** no default (D-102). The contract must choose calendar days or a fixed divisor, effective-dated. `divRoundHalfUp(monthly * covered_units, total_units)`. A contract without a choice stops for review.

## Which rate applies (CALC-06)

1. Approved override on the entry
2. Date, site or worker assignment contract
3. Effective client billing contract, or effective worker pay contract

No rate found: stop and review, never a silent zero. An approved row keeps its rate snapshot, so later rate changes do not touch history.

## Overtime (CALC-07)

Regular and overtime minutes are stored separately. Commercial client charge and employee entitlement are separate. A multiplier applies only if the contract states one. Extra clock hours never get an automatic multiplier.

## Payroll (PAY-02)

```text
current net     = gross + allowances - approved deductions - advance recovery
total payable   = opening unpaid + current net + approved adjustments
closing unpaid  = total payable - allocated salary payments
```

- Opening unpaid is old debt: never new earnings, never a second wage expense.
- Current net below zero: block posting and send to review, never auto-carry as debt (D-104, PAY-07).
- Overpayment: classified as a worker advance or credit, never a negative salary (PAY-06).
- Payment allocation defaults to oldest unpaid first, with owner confirmation (PAY-06).

## Advance sub-ledger (PAY-05)

```text
outstanding = opening + issued - recovered - refunded or adjusted
```

Recovery above outstanding is rejected. Neither issue nor recovery is a wage expense.

## VAT and receivables (INV-03..05)

VAT applies from the supplier's registration and the supply treatment, never from a customer TRN alone. Standard rate is 500 bps in the example; zero-rated, exempt and out-of-scope are separate categories that a tax reviewer confirms.

```text
exclusive line:  vat = divRoundHalfUp(net * bps, 10000)
inclusive line:  net = divRoundHalfUp(gross * 10000, 10000 + bps);  vat = gross - net
document total:  sum of line net + sum of line vat  (D-101)
outstanding:     total - allocated receipts - credit notes
```

Taking inclusive VAT as `gross - net` means the parts always add back to the gross exactly. A receipt before invoicing stays an unapplied credit (INV-05).

## Reports (REP-02, REP-03)

| Measure | Rule |
| --- | --- |
| Wage expense | Earned wage, on posting. Paid wage is cash flow only |
| Service revenue | Ex-VAT issued invoices. VAT collected and cash receipts are not revenue |
| Labour contribution | Ex-VAT service revenue minus matched worker earnings. Never labelled net profit |
| Headcount | Unique workers, shift count and worker-days shown separately. Information only, never an input to an amount (ATT-09) |

## PRD fixtures

These must pass exactly in `dart test`. Amounts in AED.

| Case | Input | Result |
| --- | --- | --- |
| Billing | 10 workers, 660 billable minutes, 10/hour | 1,100 before VAT |
| Wage | Same, 8/hour | 880 |
| Contribution | 1,100 - 880 | 220 |
| Shift wage | 10 workers, full shift 70 | 700, contribution 400 |
| Carry-forward | September net 1,000, paid 500. October net 1,000 | October total 1,500. Closing 1,500 if nothing is paid |
| Deductions | Opening 500 + gross 1,000 - room 200 - recovery 100, paid 600 | Total 1,200, closing 600 |
| Advance | Issued 300, recovered 100 | Outstanding 200 |
| VAT exclusive | 1,100 at 5% | VAT 55, total 1,155 |
| Receipt | 1,155 invoiced, 500 received | Outstanding 655 |
| VAT inclusive | 105 at 5% | Net 100, VAT 5 |
| Midnight shift | 20:00 to next-day 08:00 | 720 minutes |
| Headcount | One worker, two shifts | Unique 1, shifts 2 |

## For the accountant to confirm

Rounding level (D-101). Partial-period methods offered (D-102). Work-date attribution (D-103). Deduction limits and authorization evidence (PAY-07). Overtime configuration (CALC-07). VAT categories and rounding on Tax Invoices (INV-02..04).
