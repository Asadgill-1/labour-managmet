import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:test/test.dart';

void main() {
  test('visa money left = paid - returned - recovered, and a reversal cancels its original', () {
    const lines = [
      CashLine(CashKind.visaPaid, 300000),
      CashLine(CashKind.visaPaid, 50000),
      CashLine(CashKind.visaPaid, 50000, reversal: true),
      CashLine(CashKind.visaReturned, 20000),
      CashLine(CashKind.advanceGiven, 99900),
    ];
    expect(visaPaidTotal(lines), 300000);
    expect(visaReturnedTotal(lines), 20000);
    expect(visaOutstanding(lines, recoveredFils: 30000), 250000);
  });

  test('visa money handed back is money in, visa money spent is money out', () {
    expect(isMoneyIn(CashKind.visaReturned), isTrue);
    expect(isMoneyIn(CashKind.visaPaid), isFalse);
    expect(cashTotals(const [CashLine(CashKind.visaPaid, 300), CashLine(CashKind.visaReturned, 100)]), (inFils: 100, outFils: 300));
  });

  PayrollFigures month({int visa = 0, int left = 0, int? limitBps, int recovery = 0, int advanceLeft = 0}) => workerPayroll(
    month: '2020-09',
    currentMonth: '2020-10',
    work: const [WorkLine('2020-09-05', 100000)],
    contracts: const [],
    items: [
      if (visa > 0) PayItemLine(PayItemKind.visaRecovery, visa),
      if (recovery > 0) PayItemLine(PayItemKind.advanceRecovery, recovery),
    ],
    advanceLeftFils: advanceLeft,
    visaLeftFils: left,
    limitBps: limitBps,
  );

  test('a visa instalment comes off net, apart from deductions and advance recovery', () {
    final f = month(visa: 30000, left: 300000, recovery: 10000, advanceLeft: 10000);
    expect(f.netFils, 60000);
    expect(f.visaFils, 30000);
    expect(f.deductionsFils, 0);
    expect(f.recoveryFils, 10000);
    expect(f.issues, isEmpty);
  });

  test('an instalment above the visa money left stops the worker for review', () {
    expect(month(visa: 30000, left: 20000).issues, contains(PayrollIssue.recoveryAboveVisa));
  });

  test("the company's own deduction limit counts the visa instalment", () {
    expect(month(visa: 30000, left: 300000, limitBps: 2000).issues, contains(PayrollIssue.deductionAboveLimit));
    expect(month(visa: 20000, left: 300000, limitBps: 2000).issues, isEmpty);
  });

  test('a month holding only a visa instalment is not empty', () {
    final f = workerPayroll(
      month: '2020-09',
      currentMonth: '2020-10',
      work: const [],
      contracts: const [],
      items: const [PayItemLine(PayItemKind.visaRecovery, 100)],
      advanceLeftFils: 0,
      visaLeftFils: 100,
    );
    expect(f.isEmpty, isFalse);
    expect(f.issues, contains(PayrollIssue.negativeNet));
  });
}
