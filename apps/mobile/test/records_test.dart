import 'package:domain/calc.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show AlertDialog, Locale, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/changes.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';
import 'timesheets_test.dart' as ts;

/// Part 2 of D-056: workers, companies, sites, rooms, groups, rates, pay items and opening balances.
void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await ts.seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => db.close());

  Future<Map<String, List<ChangeNote>>> edits(String entity) => db.watchEdits(entity).first;
  String fact(FactChange c) => '${c.fact.name}: ${c.from} > ${c.to}';
  Future<String> worker(String code, String name) =>
      db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value(code), name: Value(name), trade: const Value('Mason')));
  Future<PayContract> asifRate() async => (await (db.select(db.payContracts)..where((c) => c.workerId.equals(ts.asif))).get()).single;

  test("a worker edited notes each field from and to beside the user's note; archiving notes it too; a save of nothing shows nothing", () async {
    await db.saveRow(db.workers, id: ts.asif, operationId: newUuid(), reason: 'Full name', fields: const WorkersCompanion(name: Value('Asif Khan'), trade: Value('Mason')));
    await db.saveRow(db.workers, id: ts.bilal, operationId: newUuid(), fields: const WorkersCompanion(active: Value(false)));
    await db.saveRow(db.clients, id: ts.emaar, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
    final workers = await edits('workers');
    expect(workers[ts.asif]!.single.note, 'Full name');
    expect(workers[ts.asif]!.single.changes.map(fact), ['name: Asif > Asif Khan', 'trade: null > Mason']);
    expect(workers[ts.bilal]!.single.changes.map(fact), ['active: true > false']);
    expect(await edits('clients'), isEmpty, reason: 'nothing changed');
  });

  test('a group edited notes who left it and the rate set for them there', () async {
    final group = await db.saveWorkerGroup(
      id: null,
      operationId: newUuid(),
      members: {ts.asif: null, ts.bilal: (fils: 1200, basis: RateBasis.day)},
      fields: const WorkerGroupsCompanion(name: Value('Night')),
    );
    await db.saveWorkerGroup(id: group, operationId: newUuid(), reason: 'Bilal moved', members: {ts.asif: null}, fields: const WorkerGroupsCompanion(name: Value('Night')));
    expect((await edits('worker_groups'))[group]!.single.changes.map(fact), ['members: Asif (W1), Bilal (W2) ${formatAed(1200)} > Asif (W1)']);
  });

  test('a worker or company that entries name is not deleted, only archived; one nothing names is deleted whole, with its places in groups (D-056)', () async {
    await ts.work(db, '2020-10-05');
    await expectLater(db.deleteRecord(db.workers, ts.asif, operationId: newUuid()), throwsA(isA<RecordInUse>()));
    await expectLater(db.deleteRecord(db.clients, ts.emaar, operationId: newUuid()), throwsA(isA<RecordInUse>()));
    expect(await db.select(db.workers).get(), hasLength(2));

    final kamran = await worker('W3', 'Kamran');
    await db.saveWorkerGroup(id: null, operationId: newUuid(), members: {ts.asif: null, kamran: null}, fields: const WorkerGroupsCompanion(name: Value('Night')));
    await db.deleteRecord(db.workers, kamran, note: 'Added twice', operationId: newUuid());
    expect(await (db.select(db.workers)..where((w) => w.id.equals(kamran))).get(), isEmpty);
    expect((await db.select(db.workerGroupMembers).get()).map((m) => m.workerId), [ts.asif]);

    final tab = await buildRegister(db, l10n, Section.deletedRecords);
    expect(tab.entries.single.cells.sublist(1), [
      l10n.colWorker,
      'Kamran',
      '${l10n.workerCode}: W3; ${l10n.trade}: Mason',
      'Added twice',
      null,
    ]);
    expect(tab.columns.last.label, l10n.colClarification);
  });

  test('a rate edited notes the rate; a rate deleted re-prices open rows and shows whole on the Delete tab', () async {
    await ts.work(db, '2020-10-05');
    final rate = await asifRate();
    await db.saveRow(db.payContracts, id: rate.id, operationId: newUuid(), reason: 'Raise', fields: const PayContractsCompanion(rateFils: Value(1100)));
    expect((await edits('pay_contracts'))[rate.id]!.single.changes.map(fact), ['rate: 1000 > 1100']);

    await db.savingRate(() => db.deleteRecord(db.payContracts, rate.id, note: 'Wrong worker', operationId: newUuid()), workerId: ts.asif);
    final row = (await db.select(db.attendanceEntries).get()).single;
    expect(row.workerRateFils, isNull, reason: 'the open row has no pay rate now');
    final cells = (await buildRegister(db, l10n, Section.deletedRecords)).entries.single.cells;
    expect(cells.sublist(1, 3), [l10n.payContractsHeading, 'Asif (W1)']);
    expect(cells[3], contains('${l10n.colRate}: ${formatAed(1100)}'));
    expect(cells[4], 'Wrong worker');
  });

  test("a pay item edited keeps the user's note; deleted, it leaves the month and shows on its own Delete tab", () async {
    Future<void> allowance(String? id, int fils, {String? note}) => db.savePayItem(
      id: id,
      workerId: ts.asif,
      month: '2020-10',
      kind: PayItemKind.allowance,
      amountFils: fils,
      reason: 'Food',
      authorizedBy: null,
      note: null,
      roomId: null,
      operationId: newUuid(),
      changeNote: note,
    );
    await allowance(null, 5000);
    final item = (await db.select(db.payrollItems).get()).single;
    await allowance(item.id, 6000, note: 'Two more days');
    final notes = (await edits('payroll_items'))[item.id]!;
    expect(notes.single.note, 'Two more days');
    expect(notes.single.changes.map(fact), ['amount: 5000 > 6000']);

    await db.deleteRecord(db.payrollItems, item.id, note: 'Not owed', operationId: newUuid());
    expect(await db.select(db.payrollItems).get(), isEmpty);
    final tab = await buildRegister(db, l10n, Section.deletedPayItems);
    expect(tab.entries.single.cells.sublist(1), ['10-2020', 'Asif (W1)', l10n.payKindAllowance, 6000, 'Food', 'Not owed', null]);
  });

  test('an opening balance deleted leaves what the worker is owed', () async {
    await ts.work(db, '2020-10-05');
    final id = await db.saveRow(
      db.openingBalances,
      id: null,
      operationId: newUuid(),
      fields: OpeningBalancesCompanion(kind: const Value('worker_salary_owed'), workerId: Value(ts.asif), amountFils: const Value(50000), asOfDate: const Value('2020-09-30'), sourceNote: const Value('Old book')),
    );
    Future<int> owed() async => (await db.payrollFor('2020-10')).firstWhere((p) => p.worker.id == ts.asif).openingFils;
    expect(await owed(), 50000);
    await db.deleteRecord(db.openingBalances, id, operationId: newUuid());
    expect(await owed(), 0);
    final cells = (await buildRegister(db, l10n, Section.deletedRecords)).entries.single.cells;
    expect(cells.sublist(1, 3), [l10n.openingHeading, 'Asif (W1)']);
    expect(cells[3], contains('${l10n.tsAmount}: ${formatAed(50000)}'));
  });

  testWidgets('from the screens: an unused worker is deleted to the Delete tab, and one with entries is archived instead (D-056)', (tester) async {
    final app = memoryDb();
    await real(tester, () async {
      await ts.seed(app);
      await ts.work(app, '2020-10-05');
      await app.saveRow(app.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W3'), name: Value('Kamran')));
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    final inDialog = find.descendant(of: find.byType(AlertDialog), matching: find.text(words.deleteAction));
    await pumpApp(tester, app);
    await goTo(tester, words.tabLabour);

    await tester.tap(find.text('Kamran'));
    await settle(tester);
    await tester.tap(find.text(words.deleteAction));
    await settle(tester);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Do baar daala');
    await tester.tap(inDialog);
    await settle(tester);
    expect(find.text(words.deletedDone), findsOneWidget);
    expect(find.text('Kamran'), findsNothing);

    await tester.tap(find.text('Asif'));
    await settle(tester);
    await tester.tap(find.text(words.deleteAction));
    await settle(tester);
    await tester.tap(inDialog);
    await settle(tester);
    expect(find.text(words.inUseTitle), findsOneWidget);
    await tester.tap(find.text(words.archive).last);
    await settle(tester);
    expect(find.text(words.archivedDone), findsOneWidget);
    expect(find.text('Asif'), findsNothing, reason: 'archived, so off the active list');

    await goTo(tester, words.regDeletedRecords);
    expect(find.text('Kamran'), findsOneWidget);
    expect(find.textContaining('Do baar daala'), findsOneWidget);
    await shutDown(tester, app);
  });
}
