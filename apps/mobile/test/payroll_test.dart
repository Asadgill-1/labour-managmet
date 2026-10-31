import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

// Months well in the past, so a test never meets the "month has not started" rule.
const sep = '2020-09';
const oct = '2020-10';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 20 * 60, breakMinutes: 60);

Future<String> addWorker(TenantDatabase db, String name, {String? room, int? roomCharge, String? roomNote}) {
  return db.saveRow(
    db.workers,
    id: null,
    operationId: newUuid(),
    fields: WorkersCompanion(
      code: Value(name),
      name: Value(name),
      roomId: Value(room),
      roomChargeFils: Value(roomCharge),
      roomChargeNote: Value(roomNote),
    ),
  );
}

Future<void> addContract(TenantDatabase db, String worker, RateBasis basis, int fils) {
  return db.saveRow(
    db.payContracts,
    id: null,
    operationId: newUuid(),
    fields: PayContractsCompanion(workerId: Value(worker), basis: Value(basis.name), rateFils: Value(fils), effectiveFrom: const Value('2020-01-01')),
  );
}

Future<({String client, String site})> addSite(TenantDatabase db) async {
  final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(client), name: const Value('Marina')));
  await db.saveRow(
    db.billingContracts,
    id: null,
    operationId: newUuid(),
    fields: BillingContractsCompanion(clientId: Value(client), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')),
  );
  return (client: client, site: site);
}

/// Marks one worker for one date.
Future<void> addWork(TenantDatabase db, ({String client, String site}) place, String worker, String date) async {
  await db.saveAttendanceBatch(
    workDate: date,
    clientId: place.client,
    siteId: place.site,
    inputs: [EntryInput(workerId: worker, shift: shift)],
    operationId: newUuid(),
  );
}

Future<void> pay(TenantDatabase db, String worker, int fils) {
  return db.addCashEntry(operationId: newUuid(), date: '2020-10-05', kind: CashKind.salaryPaid, amountFils: fils, workerId: worker);
}

Future<WorkerPayroll> row(TenantDatabase db, String month, String worker) async {
  return (await db.payrollFor(month)).singleWhere((p) => p.worker.id == worker);
}

Future<void> addItem(TenantDatabase db, String worker, String month, PayItemKind kind, int fils, {String? authorizedBy, String? room}) {
  return db.savePayItem(
    id: null,
    workerId: worker,
    month: month,
    kind: kind,
    amountFils: fils,
    reason: kind.name,
    authorizedBy: authorizedBy,
    note: null,
    roomId: room,
    operationId: newUuid(),
  );
}

void main() {
  group('payroll', () {
    late TenantDatabase db;
    setUp(() async {
      db = memoryDb();
      await seedProfile(db);
    });
    tearDown(() => db.close());

    test('TC-001 carry-forward: 1,000 earned, 500 paid, next month 1,500 due and 1,500 if nothing is paid (PAY-02, PAY-03)', () async {
      final ali = await addWorker(db, 'Ali');
      await addContract(db, ali, RateBasis.month, 100000);

      expect(await db.postPayroll(sep, operationId: newUuid()), 1);
      final september = await row(db, sep, ali);
      expect(september.openingFils, 0);
      expect(september.payableFils, 100000);

      await pay(db, ali, 50000);
      expect((await row(db, sep, ali)).paidFils, 50000);
      expect((await row(db, sep, ali)).closingFils, 50000);

      final preview = await row(db, oct, ali);
      expect(preview.openingFils, 50000);
      expect(preview.figures.grossFils, 100000, reason: 'old debt is never new earnings');
      expect(preview.payableFils, 150000);

      await db.postPayroll(oct, operationId: newUuid());
      final october = await row(db, oct, ali);
      expect(october.line!.netFils, 100000);
      expect(october.line!.payableFils, 150000);
      expect(october.closingFils, 150000);

      // A later payment lands on the latest month, and September's own figures stay as they were.
      await pay(db, ali, 20000);
      expect((await row(db, oct, ali)).closingFils, 130000);
      expect((await row(db, sep, ali)).closingFils, 50000);
    });

    test('TC-032 the deductions example: opening 500, gross 1,000, room 200, recovery 100, paid 600 (PAY-04, D-031)', () async {
      final room = await db.saveRow(db.rooms, id: null, operationId: newUuid(), fields: const RoomsCompanion(name: Value('Sonapur 12')));
      final ali = await addWorker(db, 'Ali', room: room);
      await addContract(db, ali, RateBasis.month, 100000);
      await db.saveRow(
        db.openingBalances,
        id: null,
        operationId: newUuid(),
        fields: OpeningBalancesCompanion(
          kind: const Value('worker_salary_owed'),
          workerId: Value(ali),
          amountFils: const Value(50000),
          asOfDate: const Value('2020-09-30'),
          sourceNote: const Value('Old register'),
        ),
      );
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-01', kind: CashKind.advanceGiven, amountFils: 10000, workerId: ali);
      await addItem(db, ali, oct, PayItemKind.roomCharge, 20000, authorizedBy: 'Signed paper', room: room);
      await addItem(db, ali, oct, PayItemKind.advanceRecovery, 10000);

      await db.postPayroll(oct, operationId: newUuid());
      final line = (await row(db, oct, ali)).line!;
      expect(line.earnedFils + line.salaryFils, 100000);
      expect(line.deductionsFils, 20000);
      expect(line.recoveryFils, 10000);
      expect(line.netFils, 70000);
      expect(line.payableFils, 120000);

      await pay(db, ali, 60000);
      expect((await row(db, oct, ali)).closingFils, 60000);
      expect(await db.advanceLeft(ali), 0, reason: 'the recovery came off the advance');
      final charged = await (db.select(db.payrollItems)..where((i) => i.roomId.equals(room) & i.lineId.isNotNull())).getSingle();
      expect(charged.amountFils, 20000);
    });

    test('TC-033 a deduction needs an authorization, and one above earnings stops only that worker (PAY-07, D-104)', () async {
      final ali = await addWorker(db, 'Ali');
      final sara = await addWorker(db, 'Sara');
      await addContract(db, ali, RateBasis.month, 10000);
      await addContract(db, sara, RateBasis.month, 10000);

      await expectLater(addItem(db, ali, oct, PayItemKind.deduction, 100), throwsA(anything));
      await addItem(db, ali, oct, PayItemKind.deduction, 10001, authorizedBy: 'Signed paper');
      expect((await row(db, oct, ali)).figures.issues, {PayrollIssue.negativeNet});

      expect(await db.postPayroll(oct, operationId: newUuid()), 1);
      expect((await row(db, oct, ali)).posted, isFalse);
      expect((await row(db, oct, sara)).posted, isTrue);
    });

    test("TC-035 recovery above the advance is refused, counting the month's other recoveries (PAY-05)", () async {
      final ali = await addWorker(db, 'Ali');
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-01', kind: CashKind.advanceGiven, amountFils: 10000, workerId: ali);
      await addItem(db, ali, oct, PayItemKind.advanceRecovery, 6000);
      await expectLater(addItem(db, ali, oct, PayItemKind.advanceRecovery, 4001), throwsA(isA<AdvanceTooHigh>()));
      await addItem(db, ali, oct, PayItemKind.advanceRecovery, 4000);
    });

    test('TC-036 posted payroll cannot be changed, even directly, and one month cannot post twice (PAY-01, REP-08)', () async {
      final ali = await addWorker(db, 'Ali');
      await addContract(db, ali, RateBasis.month, 100000);
      await addItem(db, ali, oct, PayItemKind.allowance, 5000);
      await db.postPayroll(oct, operationId: newUuid());

      await expectLater(db.customStatement('UPDATE payroll_lines SET net_fils = 1'), throwsA(anything));
      await expectLater(db.customStatement('DELETE FROM payroll_lines'), throwsA(anything));
      await expectLater(db.customStatement('UPDATE payroll_runs SET period_from = 1'), throwsA(anything));
      await expectLater(db.customStatement('DELETE FROM payroll_runs'), throwsA(anything));
      await expectLater(db.customStatement('UPDATE payroll_items SET amount_fils = 1'), throwsA(anything));
      await expectLater(db.customStatement('DELETE FROM payroll_items'), throwsA(anything));
      await expectLater(
        db.customStatement(
          "INSERT INTO payroll_lines SELECT 'x', tenant_id, created_at_utc, updated_at_utc, actor_id, version, source_operation_id, run_id, worker_id, period_from, "
          'opening_fils, earned_fils, salary_fils, adjustment_fils, allowances_fils, deductions_fils, recovery_fils, net_fils, payable_fils, paid_before_fils, reversed FROM payroll_lines',
        ),
        throwsA(anything),
      );

      expect(await db.postPayroll(oct, operationId: newUuid()), 0);
      expect(await db.select(db.payrollLines).get(), hasLength(1));
    });

    test('TC-036 a crash during posting leaves nothing, and a retry posts once (MODEL-07, TEAM-04)', () async {
      final ali = await addWorker(db, 'Ali');
      final sara = await addWorker(db, 'Sara');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addContract(db, sara, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-10-01');
      await addWork(db, place, sara, '2020-10-01');
      await db.customStatement("CREATE TRIGGER boom BEFORE INSERT ON payroll_lines WHEN NEW.worker_id = '$sara' BEGIN SELECT RAISE(ABORT, 'boom'); END");
      final auditBefore = (await db.select(db.auditEvents).get()).length;

      await expectLater(db.postPayroll(oct, operationId: newUuid()), throwsA(anything));
      expect(await db.select(db.payrollRuns).get(), isEmpty);
      expect(await db.select(db.payrollLines).get(), isEmpty);
      expect((await db.select(db.attendanceEntries).get()).every((e) => e.payrollLineId == null), isTrue);
      expect(await db.select(db.auditEvents).get(), hasLength(auditBefore));

      await db.customStatement('DROP TRIGGER boom');
      final op = newUuid();
      expect(await db.postPayroll(oct, operationId: op), 2);
      await db.postPayroll(oct, operationId: op);
      expect(await db.select(db.payrollRuns).get(), hasLength(1));
      expect(await db.select(db.payrollLines).get(), hasLength(2));
    });

    test('saved attendance counts in payroll at once, and posting freezes it (ATT-07, D-041)', () async {
      final ali = await addWorker(db, 'Ali');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-10-01');

      final open = await row(db, oct, ali);
      expect(open.figures.earnedFils, 7000);
      expect(open.canPost, isTrue);
      expect((await db.select(db.attendanceEntries).getSingle()).state, 'submitted');

      expect(await db.postPayroll(oct, operationId: newUuid()), 1);
      final paid = await db.select(db.attendanceEntries).getSingle();
      expect(paid.workerAmountFils, 7000);
      expect(paid.payrollLineId, isNotNull);
      expect(paid.state, 'approved');
    });

    test('a row with no worker rate holds only that worker, until a rate reaches it (CALC-06, D-041)', () async {
      final ali = await addWorker(db, 'Ali');
      final sara = await addWorker(db, 'Sara');
      final place = await addSite(db);
      await addContract(db, sara, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-10-01');
      await addWork(db, place, sara, '2020-10-01');

      final held = await row(db, oct, ali);
      expect(held.figures.issues, {PayrollIssue.missingRate});
      expect(held.unpricedRows, 1);
      expect(await db.postPayroll(oct, operationId: newUuid()), 1);
      expect((await row(db, oct, ali)).posted, isFalse);
      expect((await row(db, oct, sara)).posted, isTrue);

      await db.savingRate(() => addContract(db, ali, RateBasis.day, 8000));
      final fixed = await row(db, oct, ali);
      expect(fixed.figures.issues, isEmpty);
      expect(fixed.figures.earnedFils, 8000);
    });

    test("a missing company rate never holds the wage, and the bill fills in later without moving the pay (ATT-07, D-041)", () async {
      final ali = await addWorker(db, 'Ali');
      final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('ATE')));
      final site = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(client), name: const Value('Melboard')));
      await addContract(db, ali, RateBasis.day, 7000);
      await addWork(db, (client: client, site: site), ali, '2020-10-01');

      var stored = await db.select(db.attendanceEntries).getSingle();
      expect(stored.state, 'submitted');
      expect(stored.clientAmountFils, isNull);
      expect((await row(db, oct, ali)).figures.earnedFils, 7000);
      expect(await db.postPayroll(oct, operationId: newUuid()), 1);

      await db.savingRate(
        () => db.saveRow(
          db.billingContracts,
          id: null,
          operationId: newUuid(),
          fields: BillingContractsCompanion(clientId: Value(client), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')),
        ),
      );
      stored = await db.select(db.attendanceEntries).getSingle();
      expect(stored.state, 'approved');
      expect(stored.clientRateFils, 1000);
      expect(stored.clientAmountFils, 11000, reason: '12 hours less a 1 hour break');
      expect(stored.workerAmountFils, 7000);

      // Frozen again now that it has a rate, and the pay was frozen all along.
      await expectLater(db.customStatement('UPDATE attendance_entries SET client_amount_fils = 1'), throwsA(anything));
      await expectLater(db.customStatement('UPDATE attendance_entries SET worker_amount_fils = 1'), throwsA(anything));
    });

    test('a rate that changes nothing records nothing', () async {
      final ali = await addWorker(db, 'Ali');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-10-01');
      final before = (await db.select(db.auditEvents).get()).length;
      expect(await db.repriceRows(operationId: newUuid()), 0);
      expect(await db.select(db.auditEvents).get(), hasLength(before));
    });

    test('a daily worker earns per row, and a monthly worker once whatever the rows (CALC-03, CALC-04)', () async {
      final ali = await addWorker(db, 'Ali');
      final sara = await addWorker(db, 'Sara');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addContract(db, sara, RateBasis.month, 200000);
      for (final date in ['2020-10-01', '2020-10-02', '2020-10-03']) {
        await addWork(db, place, ali, date);
        await addWork(db, place, sara, date);
      }
      expect((await row(db, oct, ali)).figures.earnedFils, 21000);
      expect((await row(db, oct, sara)).figures.grossFils, 200000);
    });

    test('a correction after posting pays only the difference next month, kept out of that month\'s earnings (ATT-08, PAY-02)', () async {
      final ali = await addWorker(db, 'Ali');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-09-15');
      await db.postPayroll(sep, operationId: newUuid());

      final paid = await db.select(db.attendanceEntries).getSingle();
      Future<String> correct(AttendanceEntry old, int wage) => db.correctEntry(
        old,
        EntryInput(workerId: ali, overrideReason: 'Rate agreed', shift: ShiftInput(startMinute: 8 * 60, endMinute: 20 * 60, breakMinutes: 60, workerOverrideFils: wage)),
        reason: 'Wrong rate',
        operationId: newUuid(),
      );
      final firstId = await correct(paid, 8000);
      final first = await (db.select(db.attendanceEntries)..where((e) => e.id.equals(firstId))).getSingle();
      await correct(first, 9000);
      await addWork(db, place, ali, '2020-10-01');

      final october = await row(db, oct, ali);
      expect(october.figures.earnedFils, 7000);
      expect(october.figures.adjustmentFils, 2000, reason: 'walks past the unpaid correction to what was really paid');
      expect(october.figures.netFils, 7000);
      expect(october.payableFils, 7000 + 7000 + 2000);
      await db.postPayroll(oct, operationId: newUuid());
      expect((await row(db, oct, ali)).line!.adjustmentFils, 2000);
    });

    test('work approved after its month was posted is not lost (ATT-07)', () async {
      final ali = await addWorker(db, 'Ali');
      final place = await addSite(db);
      await addContract(db, ali, RateBasis.day, 7000);
      await addWork(db, place, ali, '2020-09-15');
      await db.postPayroll(sep, operationId: newUuid());
      await addWork(db, place, ali, '2020-09-16');

      final october = await row(db, oct, ali);
      expect(october.figures.adjustmentFils, 7000);
      expect(october.figures.earnedFils, 0);
      expect(october.openingFils, 7000);
    });

    group('undo', () {
      test('keeps the line on record, frees its work and items, and the month can post again (REP-08)', () async {
        final ali = await addWorker(db, 'Ali');
        final place = await addSite(db);
        await addContract(db, ali, RateBasis.day, 7000);
        await addWork(db, place, ali, '2020-10-01');
        await db.addCashEntry(operationId: newUuid(), date: '2020-10-01', kind: CashKind.advanceGiven, amountFils: 3000, workerId: ali);
        await addItem(db, ali, oct, PayItemKind.advanceRecovery, 3000);
        await db.postPayroll(oct, operationId: newUuid());
        expect(await db.advanceLeft(ali), 0);

        final line = (await row(db, oct, ali)).line!;
        final op = newUuid();
        await db.reversePayrollLine(line, reason: 'Wrong amount', operationId: op);
        await db.reversePayrollLine(line, reason: 'Wrong amount', operationId: op);

        final open = await row(db, oct, ali);
        expect(open.posted, isFalse);
        expect(open.figures.earnedFils, 7000);
        expect(open.items.single.lineId, isNull);
        expect(await db.advanceLeft(ali), 3000, reason: 'the recovery no longer stands');
        final audit = await (db.select(db.auditEvents)..where((a) => a.action.equals('reverse'))).getSingle();
        expect(audit.reason, 'Wrong amount');
        await expectLater(db.customStatement('UPDATE payroll_lines SET reversed = 0'), throwsA(anything));

        expect(await db.postPayroll(oct, operationId: newUuid()), 1);
        expect(await db.select(db.payrollLines).get(), hasLength(2));
        expect((await row(db, oct, ali)).line!.id, isNot(line.id));
      });

      test('money already paid stays on the account, and a later month must go first (PAY-03)', () async {
        final ali = await addWorker(db, 'Ali');
        await addContract(db, ali, RateBasis.month, 100000);
        await db.postPayroll(sep, operationId: newUuid());
        await pay(db, ali, 40000);
        await db.postPayroll(oct, operationId: newUuid());

        final september = (await row(db, sep, ali)).line!;
        final october = (await row(db, oct, ali)).line!;
        await expectLater(db.reversePayrollLine(september, reason: 'x', operationId: newUuid()), throwsA(isA<LaterMonthPosted>()));
        await db.reversePayrollLine(october, reason: 'x', operationId: newUuid());
        expect((await row(db, oct, ali)).openingFils, 60000);
        expect((await row(db, sep, ali)).paidFils, 40000);

        await db.reversePayrollLine(september, reason: 'x', operationId: newUuid());
        final paidAhead = await row(db, sep, ali);
        expect(paidAhead.openingFils, -40000, reason: 'a credit, shown as paid ahead and never as negative pay');
        expect(paidAhead.payableFils, 60000);
      });
    });

    test('room charge goes on the workers the owner ticks, at their amounts, and shows in payroll (PAY-07, D-041)', () async {
      final room = await db.saveRow(db.rooms, id: null, operationId: newUuid(), fields: const RoomsCompanion(name: Value('Sonapur 12')));
      final noted = await addWorker(db, 'Ali', room: room, roomCharge: 20000, roomNote: 'Signed paper');
      final noNote = await addWorker(db, 'Sara');
      final notTicked = await addWorker(db, 'Omar', roomCharge: 20000);
      final idle = await addWorker(db, 'Bilal');
      for (final worker in [noted, noNote, notTicked]) {
        await addContract(db, worker, RateBasis.month, 100000);
      }

      Future<int> charge(String op) => db.applyRoomCharges(oct, charges: {noted: 20000, noNote: 15000, idle: 5000}, reason: 'Room', ownerApproved: 'Owner', operationId: op);
      final op = newUuid();
      expect(await charge(op), 3);
      await charge(op);

      final first = await row(db, oct, noted);
      expect(first.figures.deductionsFils, 20000);
      expect(first.canAddRoomCharge, isFalse);
      expect(first.items.single.authorizedBy, 'Signed paper');
      expect(first.items.single.roomId, room);

      final second = await row(db, oct, noNote);
      expect(second.figures.deductionsFils, 15000);
      expect(second.items.single.authorizedBy, 'Owner', reason: 'ticking the worker is the authorization');

      expect((await row(db, oct, notTicked)).figures.deductionsFils, 0);

      // Someone with no work this month still shows, and stops for review rather than carrying a debt (D-104).
      expect((await row(db, oct, idle)).figures.issues, {PayrollIssue.negativeNet});

      // A second go never doubles a charge.
      expect(await db.applyRoomCharges(oct, charges: {noted: 99}, reason: 'Room', ownerApproved: 'Owner', operationId: newUuid()), 0);
      expect((await row(db, oct, noted)).figures.deductionsFils, 20000);
      await db.postPayroll(oct, operationId: newUuid());
      expect(await db.applyRoomCharges(oct, charges: {noNote: 99}, reason: 'Room', ownerApproved: 'Owner', operationId: newUuid()), 0);
    });

    test("the company's own limit holds a worker for review, and there is none by default (PAY-07)", () async {
      final ali = await addWorker(db, 'Ali');
      await addContract(db, ali, RateBasis.month, 100000);
      await addItem(db, ali, oct, PayItemKind.deduction, 60000, authorizedBy: 'Signed paper');
      expect((await row(db, oct, ali)).figures.issues, isEmpty);

      final profile = await db.select(db.tenantProfiles).getSingle();
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(deductionLimitBps: Value(5000)));
      expect((await row(db, oct, ali)).figures.issues, {PayrollIssue.deductionAboveLimit});
    });
  });

  testWidgets('the owner reviews a month, adds a deduction, posts it, records the payment and undoes it', (tester) async {
    final db = memoryDb();
    await real(tester, () async {
      await seedProfile(db);
      final ali = await addWorker(db, 'Ali Khan', roomCharge: 20000, roomNote: 'Signed paper');
      await addContract(db, ali, RateBasis.month, 100000);
    });
    await pumpApp(tester, db);

    await goTo(tester, 'Tankhwah');
    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('Post ke liye tayyar'), findsOneWidget);

    // Nothing is charged until the owner ticks someone, and their usual amount starts filled in.
    await tester.tap(find.text('Room charge lagayein'));
    await settle(tester);
    expect(find.text('0 mazdoor par lagayein'), findsOneWidget);
    expect(find.text('200.00'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tester.tap(find.text('1 mazdoor par lagayein'));
    await settle(tester);
    expect(find.textContaining('1 mazdoor par room charge'), findsOneWidget);
    expect(find.text('Kamai AED 1,000.00, katoti AED 200.00'), findsOneWidget);

    // A deduction without a reason and an agreement does not save.
    await tester.tap(find.text('Ali Khan'));
    await settle(tester);
    await tester.tap(find.text('Katoti').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '50');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsNWidgets(2));
    await tester.enterText(find.widgetWithText(TextFormField, 'Wajah'), 'Tools lost');
    await tester.enterText(find.widgetWithText(TextFormField, 'Agreement ya ijazat'), 'Signed paper');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('Tools lost'), findsOneWidget);
    expect(find.text('AED 750.00'), findsWidgets);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Tankhwah post karein (1)'));
    await settle(tester);
    expect(find.textContaining('1 mazdoor, AED 750.00'), findsOneWidget);
    await tester.tap(find.text('Post karein'));
    await settle(tester);
    expect(find.text('Post ho gayi'), findsOneWidget);
    expect(find.text('Tankhwah post karein (0)'), findsOneWidget);

    // Paying starts on what is owed, and goes through the cash book like all money.
    await tester.tap(find.text('Ali Khan'));
    await settle(tester);
    await tester.tap(find.text('Adaigi likhein'));
    await settle(tester);
    expect(find.text('750.00'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)'), '300');
    await tester.tap(find.text('Save karein'));
    await settle(tester);
    expect(find.text('AED 450.00'), findsNWidgets(2), reason: 'the band, and the account');
    expect(find.text('AED 300.00'), findsOneWidget);

    await tester.tap(find.text('Post wapas karein'));
    await settle(tester);
    await tester.tap(find.text('Wapas karein'));
    await settle(tester);
    expect(find.text('Yeh zaroori hai'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Wrong month');
    await tester.tap(find.text('Wapas karein'));
    await settle(tester);
    expect(find.text('Abhi post nahin'), findsOneWidget);
    await shutDown(tester, db);
  });
}
