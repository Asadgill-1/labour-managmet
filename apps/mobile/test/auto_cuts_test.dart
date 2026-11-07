import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/payroll/payroll_worker_screen.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';
import 'timesheets_test.dart' as ts;

const oct = '2020-10';

/// AED 3,100 a month, AED 100 a day by calendar days, with Fridays off.
Future<String> monthlyWorker(TenantDatabase db, {bool cut = true}) async {
  final id = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W9'), name: Value('Karim')));
  await db.saveRow(
    db.payContracts,
    id: null,
    operationId: newUuid(),
    fields: PayContractsCompanion(
      workerId: Value(id),
      basis: Value(RateBasis.month.name),
      rateFils: const Value(310000),
      effectiveFrom: const Value('2020-01-01'),
      partialMethod: Value(PartialMethod.calendarDays.name),
      cutAbsence: Value(cut),
      offWeekdays: const Value('5'),
    ),
  );
  return id;
}

/// October 2020 for Karim: worked every day but Fridays, the 5th and the 12th, which have nothing, the 26th, marked absent,
/// and the 20th, which the owner marked as a day with no work.
Future<void> october(TenantDatabase db, String karim) async {
  for (var d = monthFirstDay(oct); d.compareTo(monthLastDay(oct)) <= 0; d = addDays(d, 1)) {
    if (weekdayOf(d) == DateTime.friday || const {'2020-10-05', '2020-10-12', '2020-10-20'}.contains(d)) continue;
    await ts.work(db, d, worker: karim, input: d == '2020-10-26' ? const ShiftInput(status: AttendanceStatus.absent) : ts.shift);
  }
  await db.markDayOff('2020-10-20', [karim], operationId: newUuid());
}

void main() {
  group('a monthly salary cut for days with no attendance (D-057)', () {
    late TenantDatabase db;

    setUp(() async {
      db = memoryDb();
      await ts.seed(db);
    });

    tearDown(() => db.close());

    test("cuts each day off at the contract's own rule, but no Friday and no day the owner excused, and posting keeps it", () async {
      final karim = await monthlyWorker(db);
      await october(db, karim);
      const absent = ['2020-10-05', '2020-10-12', '2020-10-26'];

      final preview = (await db.payrollFor(oct)).singleWhere((p) => p.worker.id == karim).figures;
      expect((preview.salaryFils, preview.absenceFils, preview.absentDays.join(' '), preview.issues.length), (280000, 30000, absent.join(' '), 0));
      final slip = (await db.statementsFor(oct, workerId: karim)).single;
      expect((slip.salaryFils, slip.absenceFils, slip.absentDays.join(' ')), (280000, 30000, absent.join(' ')));

      await db.postPayroll(oct, operationId: newUuid());
      final line = await (db.select(db.payrollLines)..where((l) => l.workerId.equals(karim))).getSingle();
      expect((line.salaryFils, line.absenceFils, line.absentDays), (280000, 30000, absent.join(',')));
      final posted = (await db.payrollFor(oct)).singleWhere((p) => p.worker.id == karim).figures;
      expect((posted.absenceFils, posted.absentDays.length), (30000, 3));
      expect(db.customStatement("UPDATE payroll_lines SET absence_fils = 0 WHERE id = '${line.id}'"), throwsA(anything), reason: 'posted payroll is immutable');
    });

    test('a contract with the cut off pays the whole month whatever the register says', () async {
      final karim = await monthlyWorker(db, cut: false);
      final f = (await db.payrollFor(oct)).singleWhere((p) => p.worker.id == karim).figures;
      expect((f.salaryFils, f.absenceFils), (310000, 0));
    });
  });

  group("a company's fewer hours carried into the worker's attendance (D-057)", () {
    late TenantDatabase db;

    setUp(() async {
      db = memoryDb();
      await ts.seed(db);
    });

    tearDown(() => db.close());

    Future<(String, TimesheetRow)> draftRow() async {
      final id = await db.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      return ((await db.timesheetView(id)).revision.id, (await db.timesheetView(id)).rows.single);
    }

    const agreed = TsAdjustment(status: AttendanceStatus.present, minutes: 7 * 60, amountFils: 10500, reason: 'Left early');

    test('the attendance takes the same hours with the note, so the pay follows, and the agreement stays on the draft', () async {
      await ts.work(db, '2020-10-05');
      final (revision, row) = await draftRow();
      await db.carryAgreedToAttendance(revision, row.entryId, agreed, note: 'Company: Left early', reopenReason: 'Edited');

      final entry = await (db.select(db.attendanceEntries)..where((e) => e.superseded.equals(false))).getSingle();
      expect((entry.id, entry.clientBillableMinutes, entry.workerPayableMinutes, entry.workerAmountFils, entry.clientAmountFils), (row.entryId, 420, 420, 7000, 10500));
      final edit = await (db.select(db.auditEvents)..where((a) => a.entity.equals('attendance_entries') & a.action.equals('update'))).getSingle();
      expect(edit.reason, 'Company: Left early');
      final now = (await db.timesheetView((await db.select(db.timesheets).getSingle()).id)).rows.single;
      expect((now.line.billableMinutes, now.line.amountFils, now.adjustReason), (420, 10500, 'Left early'));
      expect((await db.payrollFor(oct)).single.figures.earnedFils, 7000);
    });

    test('a row already paid is corrected, and the difference comes in the next payroll (ATT-08)', () async {
      await ts.work(db, '2020-10-05');
      await db.postPayroll(oct, operationId: newUuid());
      final (revision, row) = await draftRow();
      await db.carryAgreedToAttendance(revision, row.entryId, agreed, note: 'Company: Left early', reopenReason: 'Edited');

      final current = await (db.select(db.attendanceEntries)..where((e) => e.superseded.equals(false))).getSingle();
      expect((current.revisesEntryId, current.workerAmountFils), (row.entryId, 7000));
      expect((await db.payrollFor('2020-11')).single.figures.adjustmentFils, -2000);
      final now = (await db.timesheetView((await db.select(db.timesheets).getSingle()).id)).rows.single;
      expect((now.entryId, now.adjustReason), (current.id, 'Left early'));
    });
  });

  testWidgets("the worker's month shows the days cut and the advance instalment, and asks about one with none (D-057)", (tester) async {
    final app = memoryDb();
    late String karim;
    await real(tester, () async {
      await ts.seed(app);
      karim = await monthlyWorker(app);
      await october(app, karim);
      await app.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 50000, workerId: karim, instalmentFils: 20000);
      await app.addCashEntry(operationId: newUuid(), date: '2020-10-09', kind: CashKind.advanceGiven, amountFils: 30000, workerId: karim);
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute<void>(builder: (_) => PayrollWorkerScreen(workerId: karim, month: oct)));
    await settle(tester);

    expect(find.text(words.payrollAbsent(3, '5, 12, 26')), findsOneWidget);
    expect(find.text(words.payrollInstalmentAuto), findsOneWidget);
    expect(find.text(words.issueRecoveryAsk('AED 300.00')), findsOneWidget);
    await shutDown(tester, app);
  });
}
