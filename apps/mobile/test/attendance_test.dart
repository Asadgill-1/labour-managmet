import 'package:domain/calc.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/providers.dart';
import 'package:labour_app/app/theme.dart' show saveErrorText;
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/changes.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/companies/site_form_screen.dart';
import 'package:labour_app/features/groups/group_form_screen.dart';
import 'package:labour_app/features/today/row_editor_screen.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const date = '2026-11-01';
const eightToEight = ShiftInput(startMinute: 8 * 60, endMinute: 20 * 60, breakMinutes: 60);

class World {
  World(this.db, this.clientId, this.siteId, this.workers);

  final TenantDatabase db;
  final String clientId;
  final String siteId;
  final List<String> workers;

  List<EntryInput> rows([ShiftInput shift = eightToEight]) => [for (final w in workers) EntryInput(workerId: w, shift: shift)];

  Future<List<AttendanceEntry>> stored() => db.select(db.attendanceEntries).get();

  Future<String> save(List<EntryInput> inputs, {String? op, String workDate = date}) => db.saveAttendanceBatch(
    workDate: workDate,
    clientId: clientId,
    siteId: siteId,
    inputs: inputs,
    operationId: op ?? newUuid(),
  );
}

/// 10 workers paid AED 8 an hour, at a client charged AED 10 an hour: the PRD's own example.
Future<World> seedWorld(TenantDatabase db, {int workerCount = 10, bool withClientRate = true, bool withPayRate = true}) async {
  await seedProfile(db);
  final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  final site = await db.saveRow(
    db.sites,
    id: null,
    operationId: newUuid(),
    fields: SitesCompanion(
      clientId: Value(client),
      name: const Value('Marina'),
      defaultStartMinute: const Value(8 * 60),
      defaultEndMinute: const Value(20 * 60),
      defaultBreakMinutes: const Value(60),
    ),
  );
  if (withClientRate) {
    await db.saveRow(
      db.billingContracts,
      id: null,
      operationId: newUuid(),
      fields: BillingContractsCompanion(
        clientId: Value(client),
        basis: Value(RateBasis.hour.name),
        rateFils: const Value(1000),
        effectiveFrom: const Value('2026-01-01'),
      ),
    );
  }
  final workers = <String>[];
  for (var i = 1; i <= workerCount; i++) {
    final worker = await db.saveRow(
      db.workers,
      id: null,
      operationId: newUuid(),
      fields: WorkersCompanion(code: Value('W00$i'), name: Value('Worker $i')),
    );
    workers.add(worker);
    if (withPayRate) {
      await db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(
          workerId: Value(worker),
          basis: Value(RateBasis.hour.name),
          rateFils: const Value(800),
          effectiveFrom: const Value('2026-01-01'),
        ),
      );
    }
  }
  return World(db, client, site, workers);
}

void main() {
  group('saving a batch', () {
    late TenantDatabase db;
    late World world;

    setUp(() async {
      db = memoryDb();
      world = await seedWorld(db);
    });
    tearDown(() => db.close());

    test('the PRD example: 10 workers total AED 1,100 billed and AED 880 wages', () async {
      await world.save(world.rows());
      final rows = await world.stored();
      expect(rows, hasLength(10));
      expect(rows.fold<int>(0, (s, r) => s + r.clientAmountFils!), 110000);
      expect(rows.fold<int>(0, (s, r) => s + r.workerAmountFils!), 88000);
      expect(rows.first.clockMinutes, 720);
      expect(rows.first.clientBillableMinutes, 660);
      expect(rows.every((r) => r.state == 'submitted'), isTrue);
    });

    test('TC-024: one bad row saves nothing, and is named', () async {
      final bad = EntryInput(workerId: world.workers[3], shift: const ShiftInput(startMinute: 480, endMinute: 540, breakMinutes: 90));
      final rows = [...world.rows().where((r) => r.workerId != world.workers[3]), bad];
      await expectLater(
        world.save(rows),
        throwsA(isA<AttendanceInvalid>().having((e) => e.workerIds, 'workers', [world.workers[3]])),
      );
      expect(await world.stored(), isEmpty);
      expect(await db.select(db.attendanceBatches).get(), isEmpty);
      expect(await db.select(db.outbox).get(), hasLength(greaterThan(0)));
      final outbox = await db.select(db.outbox).get();
      expect(outbox.where((o) => o.entity == 'attendance_batches'), isEmpty);
    });

    test('D-080 (9) a worked row whose end equals its start is never written, new, edited or corrected; absent, or an end before the start, is', () async {
      const same = ShiftInput(startMinute: 8 * 60, endMinute: 8 * 60);
      await expectLater(world.save(world.rows(same)), throwsA(isA<SameStartEnd>()));
      expect(await world.stored(), isEmpty);

      await world.save([
        EntryInput(workerId: world.workers[0], shift: const ShiftInput(status: AttendanceStatus.absent, startMinute: 8 * 60, endMinute: 8 * 60)),
        EntryInput(workerId: world.workers[1], shift: const ShiftInput(startMinute: 20 * 60, endMinute: 8 * 60)),
      ]);
      Future<AttendanceEntry> night() async => (await world.stored()).singleWhere((e) => e.workerId == world.workers[1] && !e.superseded);
      expect((await night()).clockMinutes, 12 * 60, reason: 'an end before the start is the next day (ATT-06)');

      EntryInput typo(AttendanceEntry e) => EntryInput(workerId: e.workerId, shift: same);
      await expectLater(db.editAttendance(await night(), typo(await night()), reopenReason: 'Edited', operationId: newUuid()), throwsA(isA<SameStartEnd>()));
      await db.approveEntries(await world.stored(), operationId: newUuid());
      await expectLater(db.editAttendance(await night(), typo(await night()), reopenReason: 'Edited', operationId: newUuid()), throwsA(isA<SameStartEnd>()), reason: 'a correction after approval too');
      expect([for (final e in await world.stored()) (e.workerId, e.clockMinutes, e.superseded)], unorderedEquals([(world.workers[0], 0, false), (world.workers[1], 12 * 60, false)]));

      for (final locale in const [Locale('en'), Locale('en', 'PK')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(saveErrorText(l10n, const SameStartEnd()), l10n.timesSame, reason: 'the screens say it in plain words');
      }
    });

    test('TC-008: a retry with the same operation saves once', () async {
      await world.save(world.rows(), op: 'op-1');
      await world.save(world.rows(), op: 'op-1');
      expect(await world.stored(), hasLength(10));
      expect(await db.select(db.attendanceBatches).get(), hasLength(1));
    });

    test('TC-025: overlapping time needs a reason, a second job later that day does not', () async {
      final one = [world.rows().first];
      await world.save(one);

      await expectLater(world.save(one), throwsA(isA<AttendanceInvalid>()));

      final withReason = [
        EntryInput(workerId: one.first.workerId, shift: eightToEight, overlapReason: 'Owner confirmed double booking'),
      ];
      await world.save(withReason);

      final evening = [
        EntryInput(workerId: world.workers[1], shift: const ShiftInput(startMinute: 21 * 60, endMinute: 23 * 60)),
      ];
      await world.save([EntryInput(workerId: world.workers[1], shift: const ShiftInput(startMinute: 8 * 60, endMinute: 12 * 60))]);
      await world.save(evening);
      expect((await world.stored()).where((r) => r.workerId == world.workers[1]), hasLength(2));
    });

    test('a midnight shift does not overlap the next morning, but does overlap that night', () async {
      final worker = world.workers.first;
      await world.save([EntryInput(workerId: worker, shift: const ShiftInput(startMinute: 20 * 60, endMinute: 8 * 60))]);
      final row = (await world.stored()).single;
      expect(row.clockMinutes, 720);
      expect(row.workDate, date);

      await world.save([EntryInput(workerId: worker, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 12 * 60))], workDate: '2026-11-02');
      await expectLater(
        world.save([EntryInput(workerId: worker, shift: const ShiftInput(startMinute: 7 * 60, endMinute: 9 * 60))], workDate: '2026-11-02'),
        throwsA(isA<AttendanceInvalid>()),
      );
    });

    test('an override with no reason is refused', () async {
      final rows = [EntryInput(workerId: world.workers.first, shift: const ShiftInput(startMinute: 480, endMinute: 1200, clientOverrideFils: 1200))];
      await expectLater(world.save(rows), throwsA(isA<AttendanceInvalid>()));
    });

    test('TC-023: a group rate reaches the client side only, and mixed pay is not converted', () async {
      final monthlyWorker = world.workers[1];
      final contract = await (db.select(db.payContracts)..where((c) => c.workerId.equals(monthlyWorker))).getSingle();
      await db.saveRow(
        db.payContracts,
        id: contract.id,
        operationId: newUuid(),
        fields: PayContractsCompanion(
          basis: Value(RateBasis.month.name),
          rateFils: const Value(200000),
          partialMethod: Value(PartialMethod.calendarDays.name),
        ),
      );
      const shift = ShiftInput(startMinute: 480, endMinute: 1200, breakMinutes: 60, clientOverrideFils: 1200);
      await world.save([
        EntryInput(workerId: world.workers[0], shift: shift, overrideReason: 'Holiday rate agreed'),
        EntryInput(workerId: monthlyWorker, shift: shift, overrideReason: 'Holiday rate agreed'),
      ]);

      final rows = await world.stored();
      final hourly = rows.firstWhere((r) => r.workerId == world.workers[0]);
      final monthly = rows.firstWhere((r) => r.workerId == monthlyWorker);
      expect(hourly.clientAmountFils, 13200);
      expect(monthly.clientAmountFils, 13200);
      expect(hourly.workerAmountFils, 8800);
      expect(monthly.workerBasis, 'month');
      expect(monthly.workerRateFils, 200000);
      expect(monthly.workerAmountFils, isNull);
      expect(monthly.state, 'submitted');
    });

    test('a batch writes one audit event and one outbox row with every entry', () async {
      await world.save(world.rows(), op: 'op-9');
      final out = await (db.select(db.outbox)..where((o) => o.operationId.equals('op-9'))).getSingle();
      expect(out.entity, 'attendance_batches');
      expect(out.payload, contains(world.workers.last));
      expect(await (db.select(db.auditEvents)..where((a) => a.operationId.equals('op-9'))).get(), hasLength(1));
    });

    test('BUILD-04: a 10-row save is well under a second on this machine', () async {
      final watch = Stopwatch()..start();
      await world.save(world.rows());
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('approval and correction', () {
    test('TC-021: a missing rate saves as a draft, cannot be approved, then approves once a rate exists', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final world = await seedWorld(db, workerCount: 1, withPayRate: false);
      await world.save(world.rows());
      var row = (await world.stored()).single;
      expect(row.state, 'draft');
      expect(row.workerAmountFils, isNull);
      expect(row.clientAmountFils, 11000);

      expect(await db.approveEntries([row], operationId: newUuid()), 0);
      expect((await world.stored()).single.state, 'draft');

      await db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(
          workerId: Value(world.workers.single),
          basis: const Value('hour'),
          rateFils: const Value(800),
          effectiveFrom: const Value('2026-01-01'),
        ),
      );
      row = (await world.stored()).single;
      expect(await db.approveEntries([row], operationId: newUuid()), 1);
      row = (await world.stored()).single;
      expect(row.state, 'approved');
      expect(row.workerAmountFils, 8800);
    });

    test('TC-021: an approved row keeps its rate snapshot when the contract changes', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final world = await seedWorld(db, workerCount: 1);
      await world.save(world.rows());
      await db.approveEntries(await world.stored(), operationId: newUuid());

      final contract = await db.select(db.payContracts).getSingle();
      await db.saveRow(db.payContracts, id: contract.id, operationId: newUuid(), fields: const PayContractsCompanion(rateFils: Value(5000)));

      final row = (await world.stored()).single;
      expect(row.workerRateFils, 800);
      expect(row.workerAmountFils, 8800);
    });

    test('TC-027: a correction keeps the original and records the reason', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final world = await seedWorld(db, workerCount: 1);
      await world.save(world.rows());
      await db.approveEntries(await world.stored(), operationId: newUuid());
      final original = (await world.stored()).single;

      await db.correctEntry(
        original,
        EntryInput(workerId: original.workerId, shift: const ShiftInput(startMinute: 480, endMinute: 1080, breakMinutes: 60)),
        reason: 'Left two hours early',
        operationId: 'fix-1',
      );

      final rows = await world.stored();
      expect(rows, hasLength(2));
      final old = rows.firstWhere((r) => r.id == original.id);
      final fixed = rows.firstWhere((r) => r.id != original.id);
      expect(old.superseded, isTrue);
      expect(old.clockMinutes, 720);
      expect(old.workerAmountFils, 8800);
      expect(fixed.revisesEntryId, original.id);
      expect(fixed.clockMinutes, 600);
      expect(fixed.state, 'submitted');
      final audit = await (db.select(db.auditEvents)..where((a) => a.operationId.equals('fix-1'))).getSingle();
      expect(audit.reason, 'Left two hours early');
    });

    test('approved rows reject direct edits and deletes, and linked rows keep their state', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final world = await seedWorld(db, workerCount: 1);
      await world.save(world.rows());
      await db.approveEntries(await world.stored(), operationId: newUuid());

      await expectLater(db.customStatement('UPDATE attendance_entries SET clock_minutes = 1'), throwsA(isA<SqliteException>()));
      await expectLater(db.customStatement('UPDATE attendance_entries SET worker_amount_fils = 1'), throwsA(isA<SqliteException>()));
      await expectLater(db.customStatement('DELETE FROM attendance_entries'), throwsA(isA<SqliteException>()));

      await db.customStatement("UPDATE attendance_entries SET state = 'linked'");
      await expectLater(db.customStatement("UPDATE attendance_entries SET state = 'approved'"), throwsA(isA<SqliteException>()));
    });

    test('an unapproved row edits in place, reprices, and can be removed', () async {
      final db = memoryDb();
      addTearDown(db.close);
      final world = await seedWorld(db, workerCount: 1);
      await world.save(world.rows());
      var row = (await world.stored()).single;

      await db.updateUnapprovedEntry(
        row,
        EntryInput(workerId: row.workerId, shift: const ShiftInput(status: AttendanceStatus.absent)),
        operationId: newUuid(),
      );
      row = (await world.stored()).single;
      expect(row.attendanceStatus, 'absent');
      expect(row.clockMinutes, 0);
      expect(row.workerAmountFils, 0);
      expect(row.version, 2);

      await db.deleteUnapprovedEntry(row, operationId: newUuid());
      expect(await world.stored(), isEmpty);
    });
  });

  test('TC-026: last team finds the latest earlier day, skipping absent workers, and is not approval', () async {
    final db = memoryDb();
    addTearDown(db.close);
    final world = await seedWorld(db, workerCount: 3);
    await world.save(
      [
        EntryInput(workerId: world.workers[0], shift: eightToEight),
        EntryInput(workerId: world.workers[1], shift: const ShiftInput(status: AttendanceStatus.absent)),
      ],
      workDate: '2026-10-31',
    );
    final team = await db.lastTeam(world.siteId, date);
    expect(team, [world.workers[0]]);
    expect(await db.lastTeam(world.siteId, '2026-10-31'), isEmpty);
    expect((await db.lastBatch())!.siteId, world.siteId);
  });

  testWidgets('10 workers, one exception, saved in one flow', (tester) async {
    final db = memoryDb();
    late World world;
    await real(tester, () async => world = await seedWorld(db));
    await pumpApp(tester, db);

    await tester.tap(find.text('Hazri lagayein'));
    await settle(tester);

    await tester.tap(find.text('Company').last);
    await settle(tester);
    await tester.tap(find.text('Emaar').last);
    await settle(tester);
    await tester.tap(find.text('Site').last);
    await settle(tester);
    await tester.tap(find.text('Marina').last);
    await settle(tester);

    await tester.tap(find.text('Sab ko select'));
    await settle(tester);
    await tester.tap(find.text('Aage (10 mazdoor)'));
    await settle(tester);

    expect(find.text('AED 1,100.00'), findsOneWidget);
    expect(find.text('AED 880.00'), findsOneWidget);

    await tester.tap(find.textContaining('Worker 1 (W001)'));
    await settle(tester);
    await tester.tap(find.text('Ghair hazir'));
    await settle(tester);
    await tester.tap(find.text('Theek hai'));
    await settle(tester);

    expect(find.text('AED 990.00'), findsOneWidget);
    expect(find.text('AED 792.00'), findsOneWidget);

    await tester.tap(find.text('Save karein'));
    await settle(tester);

    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '9 mazdoor, 9 shifts, 9 worker-days'), findsOneWidget);
    final rows = await real(tester, world.stored);
    expect(rows, hasLength(10));
    expect(rows.where((r) => r.attendanceStatus == 'absent'), hasLength(1));
    expect(rows.every((r) => r.state == 'submitted'), isTrue);
    await shutDown(tester, db);
  });

  group('F02-9 a shift whose end equals its start is refused at the field, so a typo is not paid as 24 hours (D-080 (9))', () {
    const same = 'Shuru aur khatam ka waqt ek hi hai. Khatam ka waqt theek karein.';

    /// Opens [screen] over a blank page, as the app does, so a screen that saves shows it by closing with [closed].
    Future<void> open(WidgetTester tester, TenantDatabase db, Widget screen, {ValueChanged<Object?>? closed}) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            locale: const Locale('en', 'PK'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => closed?.call(await Navigator.of(context).push<Object?>(MaterialPageRoute<Object?>(builder: (_) => screen))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets("the day's attendance says so at the end field and does not go on", (tester) async {
      final db = memoryDb();
      // A site file brings its usual times in as written, so a site can hold 08:00 to 08:00.
      await real(tester, () async {
        final world = await seedWorld(db, workerCount: 1);
        await db.saveRow(db.sites, id: world.siteId, operationId: newUuid(), fields: const SitesCompanion(defaultStartMinute: Value(8 * 60), defaultEndMinute: Value(8 * 60)));
      });
      await pumpApp(tester, db);
      await tester.tap(find.text('Hazri lagayein'));
      await settle(tester);
      await tester.tap(find.text('Company').last);
      await settle(tester);
      await tester.tap(find.text('Emaar').last);
      await settle(tester);
      await tester.tap(find.text('Site').last);
      await settle(tester);
      await tester.tap(find.text('Marina').last);
      await settle(tester);
      expect(find.text(same), findsOneWidget, reason: 'said at the field as soon as the times match');

      await tester.tap(find.text('Sab ko select'));
      await settle(tester);
      await tester.tap(find.text('Aage (1 mazdoor)'));
      await settle(tester);
      expect(find.text('Hazri review karein'), findsNothing, reason: 'a 24-hour shift never reaches the review');
      expect(find.text(same), findsWidgets);
      await shutDown(tester, db);
    });

    testWidgets('a row, a site and a group say so too and keep the screen open; an end before the start is still next day (ATT-06)', (tester) async {
      final db = memoryDb();
      late World world;
      late WorkerGroup group;
      await real(tester, () async {
        world = await seedWorld(db, workerCount: 1);
        await db.saveRow(db.sites, id: world.siteId, operationId: newUuid(), fields: const SitesCompanion(defaultStartMinute: Value(8 * 60), defaultEndMinute: Value(8 * 60)));
        final id = await db.saveWorkerGroup(
          id: null,
          operationId: newUuid(),
          members: {world.workers.single: null},
          fields: const WorkerGroupsCompanion(name: Value('Team A'), startMinute: Value(8 * 60), endMinute: Value(8 * 60)),
        );
        group = await (db.select(db.workerGroups)..where((g) => g.id.equals(id))).getSingle();
      });
      EntryInput row(int end) => EntryInput(workerId: world.workers.single, shift: ShiftInput(startMinute: 8 * 60, endMinute: end));
      Object? closed = 'open';

      await open(tester, db, RowEditorScreen(title: 'Worker 1', input: row(8 * 60)), closed: (v) => closed = v);
      expect(find.text(same), findsOneWidget);
      await tester.tap(find.text('Theek hai'));
      await settle(tester);
      expect(closed, 'open', reason: 'the row is not handed back');

      await open(tester, db, RowEditorScreen(title: 'Worker 1', input: row(7 * 60)), closed: (v) => closed = v);
      expect(find.text(same), findsNothing);
      await tester.tap(find.text('Theek hai'));
      await settle(tester);
      expect((closed! as RowEdit).input!.shift.endMinute, 7 * 60, reason: '08:00 to 07:00 is 23 hours, ending the next day');

      final site = await real(tester, () => db.select(db.sites).getSingle());
      closed = 'open';
      await open(tester, db, SiteFormScreen(clientId: world.clientId, site: site), closed: (v) => closed = v);
      expect(find.text(same), findsOneWidget);
      await tester.tap(find.text('Save karein'));
      await settle(tester);
      expect(closed, 'open');
      expect((await real(tester, () => db.select(db.sites).getSingle())).version, site.version, reason: 'nothing written');

      await open(tester, db, GroupFormScreen(group: group), closed: (v) => closed = v);
      expect(find.text(same), findsOneWidget);
      await tester.tap(find.textContaining('Save karein'));
      await settle(tester);
      expect(closed, 'open');
      expect((await real(tester, () => db.select(db.workerGroups).getSingle())).version, group.version);
      await shutDown(tester, db);
    });
  });
}
