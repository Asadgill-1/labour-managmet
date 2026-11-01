import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/features/registers/register_xlsx.dart';
import 'package:labour_app/features/registers/salary_sheet.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const workers = 1000;
const month = '2020-10';
const days = 26;

/// A thousand workers' month, written straight to the tables. The owner asked for this size by name (D-042).
Future<void> seed(TenantDatabase db) async {
  final now = DateTime.now().toUtc();
  const op = 'seed';
  await db.batch((b) {
    for (var i = 0; i < 5; i++) {
      b.insert(db.clients, ClientsCompanion.insert(id: 'client$i', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, name: 'Company $i'));
      b.insert(
        db.billingContracts,
        BillingContractsCompanion.insert(id: 'rate$i', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, clientId: 'client$i', basis: 'hour', rateFils: 1500, effectiveFrom: '2020-01-01'),
      );
      b.insert(db.sites, SitesCompanion.insert(id: 'site$i', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, clientId: 'client$i', name: 'Site $i'));
    }
    for (var w = 0; w < workers; w++) {
      b.insert(db.workers, WorkersCompanion.insert(id: 'w$w', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, code: 'W$w', name: 'Worker $w'));
      b.insert(
        db.payContracts,
        PayContractsCompanion.insert(id: 'pay$w', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, workerId: 'w$w', basis: 'hour', rateFils: 1000, effectiveFrom: '2020-01-01'),
      );
    }
    for (var d = 1; d <= days; d++) {
      final date = '$month-${d.toString().padLeft(2, '0')}';
      b.insert(
        db.attendanceBatches,
        AttendanceBatchesCompanion.insert(id: 'b$date', tenantId: testTenant, createdAtUtc: now, updatedAtUtc: now, actorId: 'a', sourceOperationId: op, workDate: date, clientId: 'client0', siteId: 'site0'),
      );
      for (var w = 0; w < workers; w++) {
        b.insert(
          db.attendanceEntries,
          AttendanceEntriesCompanion.insert(
            id: 'e$date$w',
            tenantId: testTenant,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: 'a',
            sourceOperationId: op,
            batchId: 'b$date',
            workerId: 'w$w',
            clientId: 'client${w % 5}',
            siteId: 'site${w % 5}',
            workDate: date,
            startUtc: Value(dubaiToUtc(date, 480)),
            endUtc: Value(dubaiToUtc(date, 1080)),
            clockMinutes: 600,
            breakMinutes: 60,
            breakPaidClient: false,
            breakPaidWorker: false,
            clientBillableMinutes: 540,
            workerPayableMinutes: 540,
            attendanceStatus: 'present',
            state: const Value('submitted'),
            clientBasis: const Value('hour'),
            clientRateFils: const Value(1500),
            clientAmountFils: const Value(13500),
            workerBasis: const Value('hour'),
            workerRateFils: const Value(1000),
            workerAmountFils: const Value(9000),
          ),
        );
      }
    }
  });
}

void main() {
  // The limits are far above what this takes, and far below what work growing with the square of the rows would take.
  const limit = Duration(seconds: 45);

  test('a thousand workers: registers, Excel, the owner\'s sheet, payroll and posting all finish in step with the rows', () async {
    final db = memoryDb();
    addTearDown(db.close);
    await seedProfile(db);
    await seed(db);
    final l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));

    Future<T> timed<T>(String what, Future<T> Function() work) async {
      final watch = Stopwatch()..start();
      final result = await work();
      expect(watch.elapsed, lessThan(limit), reason: what);
      return result;
    }

    final register = await timed('attendance register', () => buildRegister(db, l10n, Section.attendanceRegister, from: monthFirstDay(month), to: monthLastDay(month)));
    expect(register.entries, hasLength(workers * days));

    final accounts = await timed('worker register', () => buildRegister(db, l10n, Section.workerRegister, from: monthFirstDay(month), to: monthLastDay(month)));
    expect(groupEntries(accounts.entries), hasLength(workers));

    final file = await timed(
      'attendance Excel',
      () async => registerXlsx(company: 'Co', title: register.title, filterLine: '', columns: register.columns, entries: register.entries, totalLabel: 'Total', brandHex: '1F3A8A', rollups: register.rollupsOf!(register.entries), rollupSheet: 'Khulasa'),
    );
    final sheet1 = utf8.decode(ZipDecoder().decodeBytes(file).findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(RegExp('<row ').allMatches(sheet1).length, workers * days + 5, reason: 'four lines and headings above, a total below, every row in between');

    final sheet = await timed('owner sheet', () => buildSalarySheet(db, l10n, month));
    expect(sheet.entries, hasLength(workers), reason: 'one line a worker when each stays at one site on one rate');
    final [_, byCompany, people] = sheet.rollupsOf!(sheet.entries);
    expect(byCompany.rows, hasLength(5));
    expect(people.rows, hasLength(workers));
    expect(columnTotal(byCompany.rows, 4), workers * days * 13500);

    final one = await timed('one slip', () => db.statementsFor(month, workerId: 'w7'));
    expect(one.single.work, hasLength(days));
    expect(one.single.closingFils, days * 9000);

    final payroll = await timed('payroll', () => db.payrollFor(month));
    expect(payroll, hasLength(workers));
    expect(payroll.fold(0, (total, p) => total + p.figures.earnedFils), workers * days * 9000);

    final inputs = [for (var w = 0; w < workers; w++) EntryInput(workerId: 'w$w', shift: const ShiftInput(startMinute: 480, endMinute: 1080, breakMinutes: 60))];
    final previews = await timed('previewing a day', () => db.previewRows(workDate: '$month-27', clientId: 'client0', siteId: 'site0', inputs: inputs));
    expect(previews.where((p) => p.overlaps), isEmpty);

    final posted = await timed('posting', () => db.postPayroll(month, operationId: newUuid()));
    expect(posted, workers);
    final after = await timed('slip after posting', () => db.statementsFor(month, workerId: 'w7'));
    expect(after.single.closingFils, days * 9000);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
