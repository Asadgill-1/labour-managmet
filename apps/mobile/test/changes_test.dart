import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:domain/dates.dart';
import 'package:flutter/material.dart' show Locale, TextFormField;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/changes.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/cash/cash_row.dart';
import 'package:labour_app/features/changes/change_notes.dart' show deletedWhen;
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'closing_test.dart' as cl;
import 'support.dart';
import 'timesheets_test.dart' as ts;

void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await ts.seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => db.close());

  Future<AttendanceEntry> row(String date) async =>
      (await (db.select(db.attendanceEntries)..where((e) => e.workDate.equals(date) & e.superseded.equals(false) & e.deleted.equals(false))).get()).single;
  EntryInput leftAt(int hour) => EntryInput(workerId: ts.asif, shift: ShiftInput(startMinute: 8 * 60, endMinute: hour * 60, breakMinutes: 60));
  Future<Map<String, List<ChangeNote>>> edits(String entity) => db.watchEdits(entity).first;
  String fact(FactChange c) => '${c.fact.name}: ${c.from} > ${c.to}';

  group('attendance (D-056)', () {
    test("an edit before approval changes the row in place, and the app notes each field from and to beside the user's note", () async {
      await ts.work(db, '2020-10-05');
      final old = await row('2020-10-05');
      await db.editAttendance(old, leftAt(15), note: 'Left early', reopenReason: 'x', operationId: newUuid());
      final notes = (await edits('attendance_entries'))[old.id]!;
      expect(notes.single.note, 'Left early');
      expect(notes.single.changes.map(fact), ['time: 08:00-18:00 > 08:00-15:00', 'bill: 13500 > 9000', 'pay: 9000 > 6000']);
      expect((await row('2020-10-05')).id, old.id);
    });

    test('after approval an edit is a correction that keeps the original, and the notes follow the row', () async {
      await ts.work(db, '2020-10-05');
      await db.approveEntries([await row('2020-10-05')], operationId: newUuid());
      final approved = await row('2020-10-05');
      await db.editAttendance(approved, leftAt(15), reopenReason: 'x', operationId: newUuid());
      final corrected = await row('2020-10-05');
      expect(corrected.revisesEntryId, approved.id);
      await db.editAttendance(corrected, leftAt(13), note: 'Rain', reopenReason: 'x', operationId: newUuid());
      final latest = await row('2020-10-05');
      final notes = (await edits('attendance_entries'))[latest.id]!;
      expect([for (final n in notes) (n.note, n.changes.firstWhere((c) => c.fact == Fact.time).to)], [(null, '08:00-15:00'), ('Rain', '08:00-13:00')]);
      expect(await db.select(db.attendanceEntries).get(), hasLength(2), reason: 'the approved original stays; its correction changes in place until it is approved');
    });

    test('an edit that changes nothing is not shown as one', () async {
      await ts.work(db, '2020-10-05');
      final old = await row('2020-10-05');
      await db.editAttendance(old, leftAt(18), reopenReason: 'x', operationId: newUuid());
      expect((await edits('attendance_entries'))[old.id], isNull);
    });

    test('a draft deleted leaves pay and every list, and stays whole on the Delete tab with its note', () async {
      await ts.work(db, '2020-10-05');
      await db.deleteAttendance(await row('2020-10-05'), note: 'Wrong worker', reopenReason: 'x', operationId: newUuid());
      expect(await db.select(db.attendanceEntries).get(), isEmpty);
      final pay = (await db.payrollFor('2020-10')).where((p) => p.worker.id == ts.asif).firstOrNull;
      expect(pay?.figures.earnedFils ?? 0, 0);
      final tab = await buildRegister(db, l10n, Section.deletedAttendance);
      expect(tab.entries.single.cells.sublist(1), ['2020-10-05', 'Asif (W1)', 'Emaar', 'Marina', l10n.statusPresent, '08:00-18:00', 13500, 9000, 'Wrong worker', null]);
      expect(tab.columns.last.label, l10n.colClarification);
      expect((tab.columns.last.inPdf, tab.columns.last.onScreen), (true, false), reason: 'blank on paper and in Excel, for whoever it is sent to');
    });

    test('a paid row deleted gives its pay back in the next payroll, and leaves every list and register', () async {
      await ts.work(db, '2020-10-05');
      await db.postPayroll('2020-10', operationId: newUuid());
      final paid = await row('2020-10-05');
      expect(paid.payrollLineId, isNotNull);
      await db.deleteAttendance(paid, reopenReason: 'x', operationId: newUuid());
      expect(await (db.select(db.attendanceEntries)..where((e) => e.workDate.equals('2020-10-05') & e.superseded.equals(false) & e.deleted.equals(false))).get(), isEmpty);
      final november = (await db.payrollFor('2020-11')).firstWhere((p) => p.worker.id == ts.asif);
      expect(november.figures.adjustmentFils, -9000, reason: 'what was paid for a row that never was comes back');
      expect((await buildRegister(db, l10n, Section.attendanceRegister)).entries, isEmpty);
      expect((await buildRegister(db, l10n, Section.deletedAttendance)).entries.single.cells[8], 9000);
    });
  });

  group('the cash book (D-056)', () {
    test('a deleted line is cancelled on its own date, leaves the cash book, and shows on the Delete tab', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: ts.asif);
      final line = await db.select(db.cashEntries).getSingle();
      await db.deleteCash(line, note: 'Typed twice', reopenReason: 'x', operationId: newUuid());
      final all = await db.select(db.cashEntries).get();
      expect(all.map((c) => (c.entryDate, c.reversesEntryId)), unorderedEquals([('2020-10-08', null), ('2020-10-08', line.id)]));
      expect(liveCash(all), isEmpty);
      expect(await db.advanceLeft(ts.asif), 0);
      final tab = await buildRegister(db, l10n, Section.deletedCash);
      expect(tab.entries.single.cells.sublist(1), ['2020-10-08', l10n.kindAdvanceGiven, 'Asif', 2000, l10n.methodCash, '', 'Typed twice', null]);
      expect((await buildRegister(db, l10n, Section.cashRegister)).entries, isEmpty);
    });

    test('an edited line replaces the old one, notes what changed, is not a delete, and a retry changes nothing', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2020-10-08', kind: CashKind.expense, amountFils: 5000, category: 'transport');
      final old = await db.select(db.cashEntries).getSingle();
      final op = newUuid();
      Future<void> edit() => db.replaceCash(
        old,
        () => db.addCashEntry(operationId: op, date: '2020-10-09', kind: CashKind.expense, amountFils: 4500, category: 'transport'),
        note: 'Bill said 45',
        newDate: '2020-10-09',
        reopenReason: 'x',
        operationId: op,
      );
      await edit();
      await edit();
      final live = liveCash(await db.select(db.cashEntries).get());
      expect(live.map((c) => (c.entryDate, c.amountFils)), [('2020-10-09', 4500)]);
      final notes = (await edits('cash_entries'))[live.single.id]!;
      expect(notes.single.note, 'Bill said 45');
      expect(notes.single.changes.map(fact), ['date: 2020-10-08 > 2020-10-09', 'amount: 5000 > 4500']);
      expect((await buildRegister(db, l10n, Section.deletedCash)).entries, isEmpty);
    });
  });

  test('an entry in a closed month can still be edited or deleted: the month opens again with the note as its reason (D-056)', () async {
    final closed = memoryDb();
    addTearDown(closed.close);
    await cl.seed(closed);
    await closed.postPayroll(cl.sep, operationId: newUuid());
    await cl.restOff(closed, cl.sep);
    await closed.closeMonth(cl.sep, operationId: newUuid());
    await closed.postPayroll(cl.oct, operationId: newUuid());
    await cl.restOff(closed, cl.oct);
    await closed.closeMonth(cl.oct, operationId: newUuid());
    final september = (await (closed.select(closed.attendanceEntries)..where((e) => e.workDate.equals('2020-09-10'))).get()).single;

    final opened = await closed.deleteAttendance(september, note: 'Worked elsewhere', reopenReason: 'x', operationId: newUuid());
    expect(opened, [cl.oct, cl.sep], reason: 'the latest first, down to the entry');
    expect(await closed.lockedThrough(), isNull);
    final reasons = await (closed.select(closed.auditEvents)..where((a) => a.action.equals('reopen'))).map((a) => a.reason).get();
    expect(reasons, ['Worked elsewhere', 'Worked elsewhere']);
    expect((await closed.payrollFor(cl.nov)).firstWhere((p) => p.worker.id == cl.asif).figures.adjustmentFils, -9000);
  });

  testWidgets('from the screens: an edited row turns its colour with both notes, then a delete takes it to the Delete tab (D-056)', (tester) async {
    final app = memoryDb();
    final today = dubaiToday(DateTime.now());
    await real(tester, () async {
      await ts.seed(app);
      await ts.work(app, today);
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);

    await tester.tap(find.text('Asif'));
    await settle(tester);
    await tester.tap(find.text(words.statusHalf));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, words.changeNote), 'Dopahar ko gaya');
    await tester.tap(find.text(words.applyChanges));
    await settle(tester);
    expect(find.textContaining(words.editedTag), findsOneWidget);
    expect(find.text(words.changeLine(words.filterStatus, words.statusPresent, words.statusHalf)), findsOneWidget, reason: "the app's own note");
    expect(find.text(words.changeUserNote('Dopahar ko gaya')), findsOneWidget, reason: "the user's note");

    await tester.tap(find.text('Asif'));
    await settle(tester);
    await tester.ensureVisible(find.text(words.deleteRow));
    await tester.tap(find.text(words.deleteRow));
    await settle(tester);
    await tester.tap(find.text(words.deleteAction));
    await settle(tester);
    expect(find.text(words.deletedDone), findsOneWidget);
    expect(find.textContaining(words.editedTag), findsNothing, reason: 'gone from the day');

    await goTo(tester, words.regDeletedAttendance);
    expect(find.text('Asif (W1)'), findsOneWidget);
    await shutDown(tester, app);
  });

  test("a change's time is Dubai's even when the database hands it back in the phone's own zone", () {
    final at = DateTime.utc(2026, 11, 7, 20, 49);
    expect((deletedWhen(at), deletedWhen(at.toLocal())), ('08-11-2026 00:49', '08-11-2026 00:49'));
  });
}
