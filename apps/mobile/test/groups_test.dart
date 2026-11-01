import 'package:domain/calc.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'support.dart';

const date = '2026-11-01';

class Team {
  Team(this.client, this.site, this.workers);

  final String client;
  final String site;
  final List<String> workers;
}

Future<Team> seedTeam(TenantDatabase db, {int size = 3}) async {
  await seedProfile(db);
  final client = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
  final site = await db.saveRow(
    db.sites,
    id: null,
    operationId: newUuid(),
    fields: SitesCompanion(clientId: Value(client), name: const Value('Marina')),
  );
  await db.saveRow(
    db.billingContracts,
    id: null,
    operationId: newUuid(),
    fields: BillingContractsCompanion(clientId: Value(client), basis: Value(RateBasis.day.name), rateFils: const Value(15000), effectiveFrom: const Value('2026-01-01')),
  );
  final workers = <String>[];
  for (var i = 1; i <= size; i++) {
    workers.add(await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value('W00$i'), name: Value('Worker $i'))));
  }
  return Team(client, site, workers);
}

/// A member's own rate is per day here, unless a test says otherwise.
Future<String> saveGroup(TenantDatabase db, Team team, Map<String, int?> members, {int? wage = 10000, String? id, String? op, RateBasis basis = RateBasis.day}) {
  return db.saveWorkerGroup(
    id: id,
    operationId: op ?? newUuid(),
    members: {for (final MapEntry(key: worker, value: fils) in members.entries) worker: fils == null ? null : (fils: fils, basis: basis)},
    fields: WorkerGroupsCompanion(name: const Value('Emaar West'), clientId: Value(team.client), siteId: Value(team.site), dailyRateFils: Value(wage)),
  );
}

ShiftInput get shift => const ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60);

void main() {
  group('saving a group', () {
    late TenantDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('keeps its members, and a retry of the same operation changes nothing', () async {
      final team = await seedTeam(db);
      final op = newUuid();
      await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: 12000}, op: op);
      await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: 12000}, op: op);
      expect(await db.select(db.workerGroups).get(), hasLength(1));
      final members = await db.select(db.workerGroupMembers).get();
      expect(members, hasLength(2));
      expect(members.singleWhere((m) => m.workerId == team.workers[1]).rateFils, 12000);
    });

    test('a member left out of the list leaves the group, and their past rows stay', () async {
      final team = await seedTeam(db);
      final id = await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: null});
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [EntryInput(workerId: team.workers[1], groupId: id, shift: shift)],
      );
      await saveGroup(db, team, {team.workers[0]: null}, id: id);
      expect((await db.select(db.workerGroupMembers).get()).single.workerId, team.workers[0]);
      expect(await db.select(db.attendanceEntries).get(), hasLength(1));
    });
  });

  group('attendance through a group', () {
    late TenantDatabase db;
    setUp(() => db = memoryDb());
    tearDown(() => db.close());

    test('each worker gets the group wage or their own, per day', () async {
      final team = await seedTeam(db);
      final id = await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: 12000});
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [for (final w in team.workers.take(2)) EntryInput(workerId: w, groupId: id, shift: shift)],
      );
      final rows = await db.select(db.attendanceEntries).get();
      expect(rows.singleWhere((r) => r.workerId == team.workers[0]).workerAmountFils, 10000);
      expect(rows.singleWhere((r) => r.workerId == team.workers[1]).workerAmountFils, 12000);
      expect(rows.every((r) => r.workerBasis == 'day' && r.groupId == id && r.state == 'submitted'), isTrue);
      expect((await db.select(db.attendanceBatches).getSingle()).groupId, id);
    });

    test('someone outside the group gets the group wage, or the wage typed for that day', () async {
      final team = await seedTeam(db);
      final id = await saveGroup(db, team, {team.workers[0]: null});
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [
          EntryInput(workerId: team.workers[1], groupId: id, shift: shift),
          EntryInput(
            workerId: team.workers[2],
            groupId: id,
            overrideReason: 'Typed',
            shift: ShiftInput(startMinute: shift.startMinute, endMinute: shift.endMinute, workerOverrideFils: 9000),
          ),
        ],
      );
      final rows = await db.select(db.attendanceEntries).get();
      expect(rows.singleWhere((r) => r.workerId == team.workers[1]).workerAmountFils, 10000);
      expect(rows.singleWhere((r) => r.workerId == team.workers[2]).workerAmountFils, 9000);
      expect(await db.select(db.workerGroupMembers).get(), hasLength(1), reason: 'the group itself does not change');
    });

    test('a monthly worker in a group stays monthly (ATT-03)', () async {
      final team = await seedTeam(db);
      await db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(
          workerId: Value(team.workers[0]),
          basis: Value(RateBasis.month.name),
          rateFils: const Value(200000),
          effectiveFrom: const Value('2026-01-01'),
          partialMethod: Value(PartialMethod.calendarDays.name),
        ),
      );
      final id = await saveGroup(db, team, {team.workers[0]: null});
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [EntryInput(workerId: team.workers[0], groupId: id, shift: shift)],
      );
      final row = await db.select(db.attendanceEntries).getSingle();
      expect(row.workerBasis, 'month');
      expect(row.workerAmountFils, isNull);
    });

    test("a worker's own rate comes before the group wage, and a rate set in the group comes before that, per day or per hour (D-042)", () async {
      final team = await seedTeam(db);
      Future<void> hourly(String worker, int fils) => db.saveRow(
        db.payContracts,
        id: null,
        operationId: newUuid(),
        fields: PayContractsCompanion(workerId: Value(worker), basis: Value(RateBasis.hour.name), rateFils: Value(fils), effectiveFrom: const Value('2026-01-01')),
      );
      await hourly(team.workers[0], 1000);
      await hourly(team.workers[1], 1000);
      final id = await db.saveWorkerGroup(
        id: null,
        operationId: newUuid(),
        members: {team.workers[0]: null, team.workers[1]: (fils: 1400, basis: RateBasis.hour), team.workers[2]: null},
        fields: WorkerGroupsCompanion(name: const Value('Melboard'), clientId: Value(team.client), siteId: Value(team.site), dailyRateFils: const Value(10000)),
      );
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [for (final w in team.workers.take(3)) EntryInput(workerId: w, groupId: id, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 15 * 60))],
      );
      final rows = await db.select(db.attendanceEntries).get();
      AttendanceEntry of(int i) => rows.singleWhere((r) => r.workerId == team.workers[i]);
      expect(of(0).workerBasis, 'hour');
      expect(of(0).workerAmountFils, 7000, reason: 'AED 10 for 7 hours, not the AED 100 a day of the group');
      expect(of(1).workerBasis, 'hour');
      expect(of(1).workerAmountFils, 9800);
      expect(of(2).workerBasis, 'day');
      expect(of(2).workerAmountFils, 10000);
    });

    test('a batch of many rows flags only the worker whose time overlaps, the same as one row at a time (ATT-05)', () async {
      final team = await seedTeam(db);
      await db.saveAttendanceBatch(workDate: date, clientId: team.client, siteId: team.site, operationId: newUuid(), inputs: [EntryInput(workerId: team.workers[0], shift: shift)]);
      final previews = await db.previewRows(workDate: date, clientId: team.client, siteId: team.site, inputs: [for (final w in team.workers.take(2)) EntryInput(workerId: w, shift: shift)]);
      expect(previews.map((p) => p.overlaps), [true, false]);
      final one = await db.previewRow(workDate: date, clientId: team.client, siteId: team.site, input: EntryInput(workerId: team.workers[0], shift: shift));
      expect(one.overlaps, isTrue);
    });

    test('a changed group wage reaches unapproved rows, and approved rows keep theirs (D-026)', () async {
      final team = await seedTeam(db);
      final id = await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: null});
      await db.saveAttendanceBatch(
        workDate: date,
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [EntryInput(workerId: team.workers[0], groupId: id, shift: shift)],
      );
      await db.approveEntries(await db.select(db.attendanceEntries).get(), operationId: newUuid());
      await db.saveAttendanceBatch(
        workDate: '2026-11-02',
        clientId: team.client,
        siteId: team.site,
        operationId: newUuid(),
        inputs: [EntryInput(workerId: team.workers[1], groupId: id, shift: shift)],
      );

      await saveGroup(db, team, {team.workers[0]: null, team.workers[1]: null}, wage: 11000, id: id);
      final pending = await (db.select(db.attendanceEntries)..where((e) => e.state.equals('submitted'))).get();
      await db.approveEntries(pending, operationId: newUuid());

      final rows = await db.select(db.attendanceEntries).get();
      expect(rows.singleWhere((r) => r.workerId == team.workers[0]).workerAmountFils, 10000);
      expect(rows.singleWhere((r) => r.workerId == team.workers[1]).workerAmountFils, 11000);
    });
  });

  testWidgets('make a group, then mark it: skip one for today, add one with a typed wage, and the group stays', (tester) async {
    final db = memoryDb();
    late Team team;
    await real(tester, () async => team = await seedTeam(db, size: 5));
    await pumpApp(tester, db);

    await goTo(tester, 'Mazdoor group');
    expect(find.text('Abhi koi group nahin. Jo mazdoor aksar saath jate hain un ka group banayein.'), findsOneWidget);
    await tester.tap(find.text('Group banayein'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Group ka naam'), 'Emaar West');
    await tester.enterText(find.widgetWithText(TextFormField, 'Dehari (AED)'), '100');
    await settle(tester);
    await tester.tap(find.text('Company'));
    await settle(tester);
    await tester.tap(find.text('Emaar').last);
    await settle(tester);
    await tester.tap(find.text('Site'));
    await settle(tester);
    await tester.tap(find.text('Marina').last);
    await settle(tester);
    for (final name in ['Worker 1', 'Worker 2', 'Worker 3']) {
      await tester.tap(find.text(name));
      await settle(tester);
    }
    // Everyone ticked with no pay of their own shows the group's wage, and one can be changed from right there.
    expect(find.text('Group ki dehari: AED 100.00, Fi din'), findsNWidgets(3));
    await tester.tap(find.text('Badlein').at(1));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Raqam (AED)').last, '120');
    await tester.tap(find.text('Theek hai'));
    await settle(tester);
    expect(find.text('Is group mein: AED 120.00, Fi din'), findsOneWidget);
    await tester.tap(find.text('Save karein (3 mazdoor)'));
    await settle(tester);
    expect(find.text('Emaar West'), findsOneWidget);

    await goTo(tester, 'Aaj');
    await tester.tap(find.text('Hazri lagayein'));
    await settle(tester);

    // Choosing the group ticks its members and fills the company and site.
    await tester.tap(find.text('Emaar West'));
    await settle(tester);
    expect(find.text('Aage (3 mazdoor)'), findsOneWidget);
    expect(find.text('Marina'), findsOneWidget);

    // Two separate searches: the worker search does not touch the groups.
    await tester.enterText(find.widgetWithText(TextField, 'Mazdoor talash karein'), 'Worker 4');
    await settle(tester);
    expect(find.text('Emaar West'), findsOneWidget);
    expect(find.text('Worker 1'), findsNothing);

    // Someone new is asked about first, starting from the group's wage.
    await tester.tap(find.text('Worker 4').last);
    await settle(tester);
    expect(find.text('100.00'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Fi din'), '90');
    await tester.tap(find.text('Theek hai'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mazdoor talash karein'), '');
    await settle(tester);

    // Skipped for today only.
    await tester.tap(find.text('Worker 3'));
    await settle(tester);
    expect(find.text('Aage (3 mazdoor)'), findsOneWidget);

    await tester.tap(find.text('Shuru'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.text('Khatam'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.text('Aage (3 mazdoor)'));
    await settle(tester);
    expect(find.text('Mazdoor ko dena hai'), findsOneWidget);
    expect(find.text('AED 310.00'), findsOneWidget);
    await tester.tap(find.text('Save karein'));
    await settle(tester);

    final rows = await real(tester, () => db.select(db.attendanceEntries).get());
    expect(rows, hasLength(3));
    int amount(int i) => rows.singleWhere((r) => r.workerId == team.workers[i]).workerAmountFils!;
    expect(amount(0), 10000);
    expect(amount(1), 12000);
    expect(amount(3), 9000);
    expect(rows.singleWhere((r) => r.workerId == team.workers[3]).overrideReason, 'Hazri lagate waqt dehari likhi');
    expect(rows.any((r) => r.workerId == team.workers[2]), isFalse);

    final members = await real(tester, () => db.select(db.workerGroupMembers).get());
    expect(members.map((m) => m.workerId).toSet(), team.workers.take(3).toSet(), reason: 'next time the group is whole again');
    await shutDown(tester, db);
  });
}
