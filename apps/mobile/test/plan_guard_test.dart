import 'dart:typed_data';

import 'package:domain/cash.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/import.dart';
import 'package:labour_app/data/licence.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/plan_guard.dart';
import 'package:labour_app/data/restore.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/documents/document_frame.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/features/registers/register_xlsx.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

final _now = DateTime.utc(2026, 11, 13, 10);

/// What the licence on the phone shows: a plan with its numbers, and whether it works now.
LicenceView view({LicenceStatus status = LicenceStatus.active, String state = 'paid', int? workers, int? clients}) => (
  licence: status == LicenceStatus.none
      ? null
      : Licence(
          tenantId: testTenant,
          deviceId: 'device-1',
          state: state,
          issuedAt: _now,
          leaseUntil: _now.add(const Duration(days: 7)),
          endsAt: _now.add(const Duration(days: 30)),
          workers: workers,
          clients: clients,
        ),
  status: status,
  problem: null,
);

final _trial = view(state: 'trial');
final _small = view(workers: 15, clients: 5);

/// Every kind of row the app writes through the single write path, beside the few safe mode lets through.
const _entries = [
  'workers', 'clients', 'sites', 'rooms', 'worker_groups', 'pay_contracts', 'billing_contracts', 'opening_balances', 'attendance_batches',
  'attendance_entries', 'cash_entries', 'day_offs', 'period_locks', 'payroll_runs', 'payroll_lines', 'payroll_items', 'timesheets',
  'timesheet_revisions', 'billed_allocations', 'invoices', //
];
const _alwaysAllowed = ['tenant_profiles', 'document_templates', 'document_assets', 'issued_documents', 'restores'];

PlanRefused? ask(LicenceView v, String entity, {WriteEffect effect = WriteEffect.entry, int workers = 0, int clients = 0}) =>
    planRefusal(v, entity: entity, effect: effect, workers: workers, clients: clients);

void main() {
  group('planRefusal', () {
    test('a trial, and a plan within its numbers, let every write through', () {
      for (final v in [_trial, _small]) {
        for (final entity in [..._entries, ..._alwaysAllowed]) {
          for (final effect in WriteEffect.values) {
            expect(ask(v, entity, effect: effect, workers: 14, clients: 4), isNull, reason: '$entity $effect');
          }
        }
      }
    });

    test('a plan that ended, a lease past its end, a clock moved back and no licence each refuse every entry, saying which', () {
      final states = {
        LicenceStatus.ended: PlanBlock.ended,
        LicenceStatus.leaseOver: PlanBlock.leaseOver,
        LicenceStatus.clockBack: PlanBlock.clockBack,
        LicenceStatus.none: PlanBlock.noLicence,
      };
      for (final MapEntry(key: status, value: block) in states.entries) {
        final v = view(status: status, workers: 15, clients: 5);
        for (final entity in _entries) {
          for (final effect in [WriteEffect.entry, WriteEffect.activates]) {
            expect(ask(v, entity, effect: effect)?.block, block, reason: '$status $entity $effect');
          }
        }
      }
    });

    test('safe mode still lets a row be archived, a paper issued, the company and letterhead saved and a restore recorded', () {
      for (final status in [LicenceStatus.ended, LicenceStatus.leaseOver, LicenceStatus.clockBack, LicenceStatus.none]) {
        final v = view(status: status, workers: 15, clients: 5);
        for (final entity in _entries) {
          expect(ask(v, entity, effect: WriteEffect.archives, workers: 40), isNull, reason: 'archiving $entity, $status');
        }
        for (final entity in _alwaysAllowed) {
          expect(ask(v, entity, workers: 40), isNull, reason: '$entity, $status');
        }
      }
    });

    test('the 16th worker on Small is refused with the number from the licence; the 15th is not', () {
      expect(ask(_small, 'workers', effect: WriteEffect.activates, workers: 14), isNull);
      final refused = ask(_small, 'workers', effect: WriteEffect.activates, workers: 15)!;
      expect(refused.block, PlanBlock.workerLimit);
      expect(refused.limit, 15);
      expect(ask(_small, 'workers', workers: 15), isNull, reason: 'editing a worker at the limit adds nobody');
      expect(ask(_small, 'attendance_entries', workers: 15, clients: 5), isNull, reason: 'at the limit is within it');
    });

    test('the 6th client company on Small is refused the same way, and workers do not count for it', () {
      expect(ask(_small, 'clients', effect: WriteEffect.activates, clients: 4, workers: 15), isNull);
      final refused = ask(_small, 'clients', effect: WriteEffect.activates, clients: 5)!;
      expect(refused.block, PlanBlock.clientLimit);
      expect(refused.limit, 5);
      expect(ask(_small, 'sites', effect: WriteEffect.activates, workers: 15, clients: 5), isNull, reason: 'only workers and client companies are counted');
    });

    test('a company over its plan waits: archiving and safe-mode writes only, until it is back within', () {
      final over = ask(_small, 'attendance_entries', workers: 40)!;
      expect(over.block, PlanBlock.workersOver);
      expect(over.limit, 15);
      expect(ask(_small, 'cash_entries', clients: 6)?.block, PlanBlock.clientsOver);
      expect(ask(_small, 'cash_entries', clients: 6)?.limit, 5);
      expect(ask(_small, 'workers', effect: WriteEffect.activates, workers: 40)?.block, PlanBlock.workersOver);
      expect(ask(_small, 'workers', effect: WriteEffect.archives, workers: 40, clients: 6), isNull);
      for (final entity in _alwaysAllowed) {
        expect(ask(_small, entity, workers: 40, clients: 6), isNull, reason: entity);
      }
      expect(ask(_small, 'attendance_entries', workers: 15, clients: 5), isNull);
    });

    test('an unlimited plan never counts', () {
      expect(ask(view(), 'workers', effect: WriteEffect.activates, workers: 5000, clients: 900), isNull);
    });
  });

  group('the single write path', () {
    late TenantDatabase db;
    late LicenceView now;

    setUp(() {
      db = memoryDb();
      now = _trial;
      db.guard = planGuard(db, () => now);
    });
    tearDown(() => db.close());

    Future<String> addWorker(int n, {String? operationId}) =>
        db.saveRow(db.workers, id: null, operationId: operationId ?? newUuid(), fields: WorkersCompanion(code: Value('W$n'), name: Value('Worker $n')));

    Future<void> setActive(String id, bool active) => db.saveRow(db.workers, id: id, operationId: newUuid(), fields: WorkersCompanion(active: Value(active)));

    Matcher refuses(PlanBlock block, {int? limit}) =>
        throwsA(isA<PlanRefused>().having((e) => e.block, 'block', block).having((e) => e.limit, 'limit', limit));

    test('with the plan ended a new entry is refused and nothing is written, while archiving and the company profile go through', () async {
      final worker = await addWorker(1);
      await seedProfile(db);
      final written = (await db.select(db.outbox).get()).length;
      now = view(status: LicenceStatus.ended, state: 'trial');

      await expectLater(addWorker(2), refuses(PlanBlock.ended));
      await expectLater(db.addCashEntry(operationId: newUuid(), date: '2026-11-13', kind: CashKind.advanceGiven, amountFils: 5000, workerId: worker), refuses(PlanBlock.ended));
      await expectLater(db.saveRow(db.workers, id: worker, operationId: newUuid(), fields: const WorkersCompanion(name: Value('Renamed'))), refuses(PlanBlock.ended));
      expect(await db.select(db.workers).get(), hasLength(1));
      expect(await db.select(db.cashEntries).get(), isEmpty);
      expect(await db.select(db.outbox).get(), hasLength(written), reason: 'a refused write leaves no outbox row');
      expect(await db.select(db.auditEvents).get(), hasLength(written), reason: 'and no audit event');

      await setActive(worker, false);
      expect((await db.select(db.workers).getSingle()).active, isFalse);
      final profile = await db.select(db.tenantProfiles).getSingle();
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(legalName: Value('New Name LLC')));
      expect((await db.select(db.tenantProfiles).getSingle()).legalName, 'New Name LLC');

      await expectLater(setActive(worker, true), refuses(PlanBlock.ended), reason: 'bringing a worker back is a new entry');
    });

    test('with the plan ended a paper of what exists is still issued, a register still made into Excel, and a restore still recorded', () async {
      final worker = await addWorker(1);
      await seedProfile(db);
      now = view(status: LicenceStatus.ended, state: 'trial');

      final identity = await db.currentIdentity(brandArgb: 0xFF0B2648, softArgb: 0xFFE0EEFF);
      final paper = await db.issueDocument(
        kind: DocKind.payslip,
        subjectId: worker,
        period: '2026-10',
        title: 'Salary slip',
        summary: 'Worker 1',
        data: const {'net': 0},
        identity: identity,
        metaFor: (number) => DocumentMeta(title: 'Salary slip', number: number, pagePattern: '{page}/{pages}', madeLabel: 'Made'),
        render: (_) async => Uint8List(4),
        operationId: newUuid(),
      );
      expect(paper.number, isNotEmpty);

      final l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
      final register = await buildRegister(db, l10n, Section.workerRegister, from: '2026-10-01', to: '2026-10-31');
      final excel = registerXlsx(company: 'Co', title: register.title, filterLine: '', columns: register.columns, entries: register.entries, totalLabel: 'Total', brandHex: '1F3A8A', softHex: 'E0EEFF');
      expect(excel, isNotEmpty);

      await db.recordRestore(from: 'backup', year: 2026, phone: const {'invoice': 12}, owner: const {}, operationId: newUuid());
      expect(await db.lastNumbers(2026), containsPair('invoice', 12));
    });

    test('the 16th worker on Small is refused, and a second tap on the 15th is not', () async {
      now = _small;
      for (var n = 1; n <= 14; n++) {
        await addWorker(n);
      }
      final fifteenth = newUuid();
      await addWorker(15, operationId: fifteenth);
      await addWorker(15, operationId: fifteenth);
      expect(await db.select(db.workers).get(), hasLength(15));

      await expectLater(addWorker(16), refuses(PlanBlock.workerLimit, limit: 15));
      expect(await db.select(db.workers).get(), hasLength(15));
    });

    test('bringing a worker back from the archive past the limit is refused, until another is archived', () async {
      final ids = [for (var n = 1; n <= 16; n++) await addWorker(n)];
      await setActive(ids[15], false);
      now = _small;

      await expectLater(setActive(ids[15], true), refuses(PlanBlock.workerLimit, limit: 15));
      await setActive(ids[0], false);
      await setActive(ids[15], true);
      final active = await (db.select(db.workers)..where((w) => w.active.equals(true))).get();
      expect(active, hasLength(15));
      expect(active.map((w) => w.id), isNot(contains(ids[0])));
    });

    test('a worker added as archived does not count, and a client company past the limit is refused', () async {
      now = view(workers: 1, clients: 1);
      await addWorker(1);
      await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Old hand'), active: Value(false)));
      await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
      await expectLater(
        db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Nakheel'))),
        refuses(PlanBlock.clientLimit, limit: 1),
      );
    });

    test('an import that would pass the limit saves nothing', () async {
      now = view(workers: 2, clients: 5);
      const file =
          'Code,Name,Trade,Phone,Joining date,Pay basis,Pay rate,Rate from\r\n'
          'W10,Rashid,Mason,,,,,\r\n'
          'W11,Asif,Helper,,,,,\r\n'
          'W12,Karim,Helper,,,,,\r\n';
      final plan = await db.planImport(ImportKind.workers, file);
      expect(plan.ready, isTrue);
      await expectLater(db.applyImport(plan), refuses(PlanBlock.workerLimit, limit: 2));
      expect(await db.select(db.workers).get(), isEmpty, reason: 'two saved and one refused would leave half a file in');
    });

    test('a company over its plan chooses who stays: exactly the rest are archived, their money stays, and entries go on (PLAN-04)', () async {
      final ids = [for (var n = 1; n <= 40; n++) await addWorker(n)];
      Future<void> advance(String worker, int fils) =>
          db.addCashEntry(operationId: newUuid(), date: '2026-11-05', kind: CashKind.advanceGiven, amountFils: fils, workerId: worker);
      await advance(ids[0], 20000);
      await advance(ids[39], 30000);
      Future<List<int>> money(String id) async {
        final s = (await db.statementsFor('2026-11', workerId: id)).single;
        return [s.openingFils, s.advanceFils, s.paidFils, s.visaLeftFils];
      }

      final before = [await money(ids[0]), await money(ids[39])];
      expect(before[1][1], isNot(0), reason: 'the advance shows in the statement');
      final events = (await db.select(db.auditEvents).get()).length;
      now = _small;
      await expectLater(advance(ids[0], 1000), refuses(PlanBlock.workersOver, limit: 15), reason: 'new entries wait until the choice is made');

      final keep = ids.take(15).toSet();
      expect(await db.archiveAllBut(db.workers, const WorkersCompanion(active: Value(false)), keep, reason: 'Plan ki limit'), 25);
      final all = await db.select(db.workers).get();
      expect(all, hasLength(40), reason: 'nobody is deleted or hidden');
      expect({for (final w in all.where((w) => w.active)) w.id}, keep);
      expect([await money(ids[0]), await money(ids[39])], before, reason: 'history and balances are untouched');
      expect(await db.select(db.cashEntries).get(), hasLength(2));
      final audit = await db.select(db.auditEvents).get();
      expect(audit, hasLength(events + 25), reason: 'each archive is in the record of changes');
      expect(audit.last.reason, 'Plan ki limit');

      await advance(ids[0], 1000);
      expect(await db.archiveAllBut(db.workers, const WorkersCompanion(active: Value(false)), keep, reason: 'Plan ki limit'), 0, reason: 'a second tap archives nobody');
    });

    test('client companies over the plan are chosen the same way', () async {
      final ids = [
        for (final name in ['Emaar', 'Nakheel', 'Damac']) await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: ClientsCompanion(name: Value(name))),
      ];
      now = view(workers: 15, clients: 1);
      await expectLater(addWorker(1), refuses(PlanBlock.clientsOver, limit: 1));
      expect(await db.archiveAllBut(db.clients, const ClientsCompanion(active: Value(false)), {ids[1]}, reason: 'Plan ki limit'), 2);
      expect((await (db.select(db.clients)..where((c) => c.active.equals(true))).getSingle()).name, 'Nakheel');
      await addWorker(1);
    });

    test('a database with no guard, as in a build without accounts, has no plans', () async {
      db.guard = null;
      now = view(status: LicenceStatus.ended);
      await addWorker(1);
      expect(await db.select(db.workers).get(), hasLength(1));
    });
  });
}
