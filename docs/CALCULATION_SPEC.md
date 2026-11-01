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

No rate found: stop and review, never a silent zero. An approved row keeps its rate snapshot, so later rate changes do not touch history. No worker rate holds that worker's payroll. No company rate holds only the bill, which fills in when the rate is added, even on a frozen row. Rows freeze when their payroll is posted, and an absent row needs no rate (D-041).

## Overtime (CALC-07)

Regular and overtime minutes are stored separately. Commercial client charge and employee entitlement are separate. A multiplier applies only if the contract states one. Extra clock hours never get an automatic multiplier.

## Payroll (PAY-02)

```text
gross           = saved attendance dated in the month + monthly salary
current net     = gross + allowances - approved deductions - advance recovery
adjustment      = unposted work dated before the month, less what a corrected row was already paid
opening         = opening balance + every earlier posted net and adjustment - all salary paid before posting
total payable   = opening + current net + adjustment
closing         = total payable - salary paid since posting
owed now        = opening balance + every posted net and adjustment - all salary paid
```

- Opening unpaid is old debt: never new earnings, never a second wage expense.
- Current net below zero, or net plus adjustment below zero: block posting and send to review, never auto-carry as debt (D-104, PAY-07).
- Monthly salary splits by days when a contract changes mid-month. Each day goes to one contract, so overlapping contracts never pay twice.
- Approved overtime on a monthly contract is earned per attendance line at the contract's own overtime rate. With no such rate, the row stops for review (CALC-07).
- A company's optional deduction limit: `(deductions + recovery) * 10000 <= (gross + allowances) * limit_bps`. Above it, posting stops for review. None is built in (D-034).
- Overpayment: classified as a worker advance or credit, never a negative salary (PAY-06).
- Payment allocation defaults to oldest unpaid first, with owner confirmation (PAY-06).

## Pay on a group row (D-042)

Wage typed for the row, then a rate set for this worker in the group (per day or per hour), then their own contract, then the group's daily wage. The group's wage only reaches someone with no pay of their own. Half pay is half of the daily wage actually used, if the group says so.

## Worker account (D-041, D-042)

The worker register reads every stored row and keeps no balance of its own (REP-08).

```text
balance = opening salary owed + work + posted monthly salary + allowances
          - opening advance - advance given + advance returned
          - deductions, room charge and visa instalments - salary paid
```

- An advance counts when it is given, so taking it back through pay does not move the balance. The row is still shown.
- Visa money counts as it is cut from pay. Money the company spends on a visa moves nothing until then, and what is left shows beside the balance.
- The balance always equals: owed now + work not yet posted - advance not yet cut.
- A monthly salary shows once its month is posted. Allowances, deductions and salary are dated on the last day of their month.
- A date range starts from the balance brought forward, and each worker's total is where they ended, not a sum.

## A worker's month on a slip (D-042)

```text
closing = opening + work + monthly salary + allowances - advance - room - visa - other deductions - paid
```

- Each closing is the next opening, and the last closing is the balance above, apart from a monthly salary not yet posted, which the slip counts and the register does not.
- A salary payment stays whole. It goes on the month before its date while that month still has something owing, otherwise on its own month. T12 replaces this with the owner's own choice.
- A monthly salary counts before posting at what posting would pay, from the account's first activity.
- Money from before the app is opening balance, never this month's earnings or advance (MASTER-05).

## Owner's sheet (D-042, REP-03)

```text
profit on a line = company bill - wage for that work
estimate         = bills - wages - monthly salaries - allowances + other deductions
                   + room money in (from pay and cash) - room rent paid - other expenses
```

- Work rows only, by work date, so it does not wait for an invoice. A company with no rate or a monthly rate shows no bill, and the sheet says its profit looks low.
- Monthly salaries are not split across companies. Advance and visa money are not expenses (REP-02).
- It is labelled an estimate, never audited net profit.

## Advance sub-ledger (PAY-05)

```text
outstanding = opening + issued - recovered through posted payroll - returned
```

Recovery above outstanding is rejected. Neither issue nor recovery is a wage expense.

## Visa money (D-039)

left = paid - returned - recovered through standing payroll lines. A month's net takes off the instalment, kept apart from deductions and advance recovery. It counts toward the company's own deduction limit, and it stops at what is left. Spending it is cash flow, not a wage expense (REP-02).

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

Rounding level (D-101). Partial-period methods offered (D-102). Work-date attribution (D-103). Deduction limits and authorization evidence (PAY-07). The payroll rules in D-034, above all no automatic absence cut on a monthly salary. Overtime configuration (CALC-07). VAT categories and rounding on Tax Invoices (INV-02..04).
