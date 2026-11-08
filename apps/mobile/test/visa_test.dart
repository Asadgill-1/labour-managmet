import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/visa.dart';

import 'support.dart';

// A month well in the past, so a test never meets the "month has not started" rule.
const sep = '2020-09';

/// A worker on AED 1,000 a month, with the visa money and instalment given.
Future<String> addWorker(TenantDatabase db, {int spent = 300000, int? instalment}) async {
  final id = await db.saveRow(
    db.workers,
    id: null,
    operationId: newUuid(),
    fields: WorkersCompanion(code: const Value('W1'), name: const Value('Asif'), visaInstalmentFils: Value(instalment)),
  );
  await db.saveRow(
    db.payContracts,
    id: null,
    operationId: newUuid(),
    fields: PayContractsCompanion(workerId: Value(id), basis: Value(RateBasis.month.name), rateFils: const Value(100000), effectiveFrom: const Value('2020-01-01')),
  );
  if (spent > 0) await db.addCashEntry(operationId: newUuid(), date: '2020-09-01', kind: CashKind.visaPaid, amountFils: spent, workerId: id);
  return id;
}

Future<WorkerPayroll> row(TenantDatabase db, String worker) async => (await db.payrollFor(sep)).singleWhere((p) => p.worker.id == worker);

void main() {
  late TenantDatabase db;

  setUp(() async {
    db = memoryDb();
    await seedProfile(db);
  });

  tearDown(() => db.close());

  test('spending and handing back move what is left, and a return above it is refused', () async {
    final w = await addWorker(db);
    await db.addCashEntry(operationId: newUuid(), date: '2020-09-02', kind: CashKind.visaReturned, amountFils: 20000, workerId: w);
    expect(await db.visaLeft(w), 280000);
    await expectLater(
      db.addCashEntry(operationId: newUuid(), date: '2020-09-03', kind: CashKind.visaReturned, amountFils: 280001, workerId: w),
      throwsA(isA<VisaTooHigh>()),
    );
    expect(await db.visaLeft(w), 280000);
  });

  test('a visa line with no worker is refused by the database', () async {
    await expectLater(db.addCashEntry(operationId: newUuid(), date: '2020-09-01', kind: CashKind.visaPaid, amountFils: 100), throwsA(anything));
  });

  test('no instalment is taken until the owner sets one and presses the button', () async {
    final w = await addWorker(db);
    final before = await row(db, w);
    expect(before.needsVisaInstalment, isFalse);
    expect(before.figures.visaFils, 0);
    expect(before.figures.netFils, 100000);
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid());
    expect((await row(db, w)).items, isEmpty);
  });

  test('instalment, post and undo: 3,000 spent, 300 a month', () async {
    final w = await addWorker(db, instalment: 30000);
    expect((await row(db, w)).needsVisaInstalment, isTrue);
    expect(await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid()), 1);

    final ready = await row(db, w);
    expect(ready.needsVisaInstalment, isFalse);
    expect(ready.figures.visaFils, 30000);
    expect(ready.figures.netFils, 70000);
    expect(ready.figures.deductionsFils, 0);
    expect(await db.visaLeft(w), 300000, reason: 'nothing comes back until posted');

    expect(await db.postPayroll(sep, operationId: newUuid()), 1);
    final line = (await row(db, w)).line!;
    expect(line.visaRecoveryFils, 30000);
    expect(line.netFils, 70000);
    expect(await db.visaLeft(w), 270000);
    expect(await db.advanceLeft(w), 0, reason: 'visa money and advances stay apart');
    final account = (await db.visaAccounts()).single;
    expect((account.paidFils, account.backFils, account.leftFils), (300000, 30000, 270000));

    await db.reversePayrollLine(line, reason: 'Wrong month', operationId: newUuid());
    expect(await db.visaLeft(w), 300000);
  });

  test('the instalment stops at what is left', () async {
    final w = await addWorker(db, spent: 20000, instalment: 30000);
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid());
    expect((await row(db, w)).figures.visaFils, 20000);
  });

  test('pressing the button again adds nothing, and a retry applies once', () async {
    final w = await addWorker(db, instalment: 30000);
    final operation = newUuid();
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: operation);
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: operation);
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid());
    expect((await row(db, w)).items, hasLength(1));
  });

  test('a typed instalment above what is left is refused', () async {
    final w = await addWorker(db, spent: 30000);
    Future<void> save(int fils, {String? id}) => db.savePayItem(
      id: id,
      workerId: w,
      month: sep,
      kind: PayItemKind.visaRecovery,
      amountFils: fils,
      reason: 'Visa',
      authorizedBy: null,
      note: null,
      roomId: null,
      operationId: newUuid(),
    );
    await expectLater(save(30001), throwsA(isA<VisaTooHigh>()));
    await save(30000);
    expect((await row(db, w)).figures.visaFils, 30000);
  });

  test('undoing visa money that has already come back is refused', () async {
    final w = await addWorker(db, spent: 30000, instalment: 30000);
    await db.applyVisaInstalments(sep, reason: 'Visa', operationId: newUuid());
    await db.postPayroll(sep, operationId: newUuid());
    final paid = await (db.select(db.cashEntries)..where((c) => c.workerId.equals(w))).getSingle();
    await expectLater(db.reverseCashEntry(paid, reason: 'Mistake', operationId: newUuid()), throwsA(isA<VisaTooHigh>()));
  });

  testWidgets('the Visa sub-tab shows the account and sets an instalment', (tester) async {
    await real(tester, () => addWorker(db));
    await pumpApp(tester, db);
    await goTo(tester, 'Visa ka paisa');
    expect(find.text('Asif'), findsOneWidget);
    expect(find.text('AED 3,000.00'), findsWidgets);

    await tester.tap(find.text('Asif'));
    await settle(tester);
    expect(find.text('Band hai'), findsOneWidget);
    await tester.tap(find.text('Har mahine ki qist'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), '300');
    await tester.tap(find.text('Theek hai'));
    await settle(tester);
    expect(find.text('AED 300.00'), findsOneWidget);
    await shutDown(tester, db);
  });
}
