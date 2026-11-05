import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/side_panel.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/closing.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/registers/register_defs.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';
import 'timesheets_test.dart' as ts;

String _describe(InvoiceLineView l) => 'Manpower ${l.basis?.name} ${l.unitPriceFils}';

final _year = int.parse(dubaiToday(DateTime.now()).substring(0, 4));

void main() {
  late TenantDatabase db;

  setUp(() async {
    db = memoryDb();
    await ts.seed(db);
  });

  tearDown(() => db.close());

  Future<String> approved({String? site}) async {
    final id = await db.createTimesheet(clientId: ts.emaar, siteId: site, from: ts.from, to: ts.to, operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
    return id;
  }

  Future<String> draft({String? site}) => db.createInvoice(clientId: ts.emaar, siteId: site, from: ts.from, to: ts.to, operationId: newUuid());

  Future<void> issue(String id, {String? operationId}) => db.issueInvoice(id, describe: _describe, operationId: operationId ?? newUuid());

  Future<void> register({String? trn = '100000000000003', String? from}) async {
    final profile = await db.select(db.tenantProfiles).getSingle();
    await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: TenantProfilesCompanion(vatRegistered: const Value(true), trn: Value(trn), vatEffectiveFrom: Value(from)));
  }

  Matcher refused(InvoiceProblem problem) => throwsA(isA<InvoiceRefused>().having((e) => e.problem, 'problem', problem));

  group('a draft (INV-01)', () {
    test('has no number and no stored lines, and reads its timesheets as they stand', () async {
      await ts.work(db, '2020-10-05');
      await ts.work(db, '2020-10-06', worker: ts.bilal);
      await approved();
      final id = await draft();
      final v = await db.invoiceView(id);
      expect(v.status, InvoiceStatus.draft);
      expect(v.invoice.number, isNull);
      expect(await db.select(db.invoiceLines).get(), isEmpty);
      // Bilal's trade gives him a line of his own, and each line charges the sum of its rows.
      expect([for (final l in v.lines) (l.basis, l.quantity, l.unitPriceFils, l.amountFils, l.trade)], [(RateBasis.hour, 540, 1500, 13500, null), (RateBasis.hour, 540, 1500, 13500, 'Helper')]);
      expect(v.lines.first.timesheetNumber, matches(RegExp(r'^TS-')));
    });

    test('nothing to bill is refused, and unapproved work is never billed', () async {
      await ts.work(db, '2020-10-05');
      await expectLater(draft(), refused(InvoiceProblem.nothingToBill));
      await db.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await expectLater(draft(), refused(InvoiceProblem.nothingToBill), reason: 'a draft timesheet is not approved');
      expect(await db.select(db.invoices).get(), isEmpty);
    });

    test('keeps to its site and dates, and a timesheet left out waits for another invoice', () async {
      await ts.work(db, '2020-10-05');
      await ts.work(db, '2020-10-06', site: ts.creek);
      await approved();
      final creekOnly = await draft(site: ts.creek);
      expect((await db.invoiceView(creekOnly)).lines.single.sources.single.workDate, '2020-10-06');

      final id = await draft();
      final source = (await db.invoiceView(id)).sources.single;
      expect(source.ready, 2);
      await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(InvoiceDraft(skipped: {source.timesheet.id}).toJson())), operationId: newUuid());
      final v = await db.invoiceView(id);
      expect(v.lines, isEmpty);
      expect(v.sources.single.skipped, isTrue);
      await expectLater(issue(id), refused(InvoiceProblem.nothingToBill));
    });

    test('says what waits: a disputed timesheet, and rows whose attendance changed', () async {
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final rev = (await db.timesheetView(sheet)).revision.id;
      await db.markTimesheetShared(rev, '2020-11-02', operationId: newUuid());
      await db.recordTimesheetResponse(rev, accepted: false, date: '2020-11-03', operationId: newUuid());
      await ts.work(db, '2020-10-07');
      await approved();
      final v = await db.invoiceView(await draft());
      expect([for (final s in v.sources) (s.ready, s.disputed)], [(0, 1), (1, 0)]);
      expect(v.lines.single.sources.single.workDate, '2020-10-07');
    });
  });

  group('VAT (INV-03, INV-04)', () {
    test('a company not registered charges none and prints no Tax Invoice, whatever the customer TRN', () async {
      await db.saveRow(db.clients, id: ts.emaar, operationId: newUuid(), fields: const ClientsCompanion(trn: Value('100000000000099'), vatRegistered: Value(true)));
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      final v = await db.invoiceView(id);
      expect((v.vatRegistered, v.bps, v.totals.vatFils, v.totals.totalFils, v.taxInvoice), (false, 0, 0, 13500, false));
    });

    test('a registered company charges 5% on each line, and needs its TRN first', () async {
      await register(trn: null);
      await ts.work(db, '2020-10-05');
      await ts.work(db, '2020-10-06', worker: ts.bilal);
      await approved();
      final id = await draft();
      await expectLater(issue(id), refused(InvoiceProblem.noTrn));
      await register();
      await issue(id);
      final v = await db.invoiceView(id);
      expect((v.vatRegistered, v.bps, v.taxInvoice), (true, 500, true));
      expect([for (final l in v.lines) l.tax.vatFils], [675, 675]);
      expect((v.totals.netFils, v.totals.vatFils, v.totals.totalFils), (27000, 1350, 28350));
      expect(v.parties.supplierTrn, '100000000000003');
    });

    test('registration counts from its effective date', () async {
      await register(from: addDays(dubaiToday(DateTime.now()), 1));
      await ts.work(db, '2020-10-05');
      await approved();
      expect((await db.invoiceView(await draft())).vatRegistered, isFalse);
    });

    test('zero-rated, exempt and out of scope charge nothing', () async {
      await register();
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      for (final c in [VatCategory.zeroRated, VatCategory.exempt, VatCategory.outOfScope]) {
        await db.saveInvoiceDraft(id, InvoicesCompanion(vatCategory: Value(c.name)), operationId: newUuid());
        expect((await db.invoiceView(id)).totals.vatFils, 0);
      }
      expect((await db.invoiceView(id)).taxInvoice, isFalse, reason: 'out of scope');
    });

    test('prices with VAT in have it taken out, and the parts add back exactly', () async {
      await register();
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await db.saveInvoiceDraft(id, const InvoicesCompanion(pricesIncludeVat: Value(true)), operationId: newUuid());
      final t = (await db.invoiceView(id)).totals;
      expect((t.netFils, t.vatFils, t.totalFils), (12857, 643, 13500));
    });

    test('a discount comes off before VAT, and one above its line is refused', () async {
      await register();
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      final key = (await db.invoiceView(id)).lines.single.key;
      await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(InvoiceDraft(discounts: {key: 3500}).toJson())), operationId: newUuid());
      final t = (await db.invoiceView(id)).totals;
      expect((t.netFils, t.vatFils), (10000, 500));
      await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(InvoiceDraft(discounts: {key: 13501}).toJson())), operationId: newUuid());
      await expectLater(issue(id), refused(InvoiceProblem.discountTooBig));
    });
  });

  group('issuing (INV-01, INV-08, MODEL-07)', () {
    test('gives the next number, today, its due date, and both parties as they stand', () async {
      await db.saveRow(db.clients, id: ts.emaar, operationId: newUuid(), fields: const ClientsCompanion(dueDays: Value(30), address: Value('Dubai Marina'), trn: Value('100000000000099')));
      await ts.work(db, '2020-10-05');
      await approved();
      final thrownAway = await draft();
      await db.deleteInvoiceDraft(thrownAway, operationId: newUuid());
      final id = await draft();
      await issue(id);
      final v = await db.invoiceView(id);
      final today = dubaiToday(DateTime.now());
      expect((v.status, v.invoice.number, v.invoice.issueDate, v.invoice.dueDate), (InvoiceStatus.issued, 'INV-$_year-0001', today, addDays(today, 30)));
      expect((v.parties.supplierName, v.parties.customerName, v.parties.customerAddress, v.parties.customerTrn), ('Test Labour LLC', 'Emaar', 'Dubai Marina', '100000000000099'));
      final stored = await db.select(db.invoiceLines).getSingle();
      expect((stored.description, stored.quantity, stored.amountFils, stored.netFils), ('Manpower hour 1500', 540, 13500, 13500));

      // What the company is called later doesn't reach an invoice already issued (DOC-05).
      await db.saveRow(db.clients, id: ts.emaar, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar Properties')));
      expect((await db.invoiceView(id)).parties.customerName, 'Emaar');

      await ts.work(db, '2020-10-06');
      await approved();
      final second = await draft();
      await issue(second);
      expect((await db.invoiceView(second)).invoice.number, 'INV-$_year-0002');
    });

    test('the company prefix leads the number', () async {
      final profile = await db.select(db.tenantProfiles).getSingle();
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(invoicePrefix: Value('ALN')));
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      expect((await db.invoiceView(id)).invoice.number, 'ALN-$_year-0001');
    });

    test('charges its work once: no second invoice can take the same rows', () async {
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final id = await draft();
      final other = await draft();
      await issue(id);
      expect((await db.select(db.billedAllocations).get()).map((b) => (b.invoiceId, b.amountFils)), [(id, 13500)]);
      await expectLater(draft(), refused(InvoiceProblem.nothingToBill));
      expect((await db.invoiceView(other)).lines, isEmpty, reason: 'the other draft reads the timesheet as it stands now');
      await expectLater(issue(other), refused(InvoiceProblem.nothingToBill));
      expect(await db.unbilledLines(sheet), isEmpty);
      expect((await db.billedRevisions(id)).single.timesheetId, sheet);
    });

    test('a retry of the same issue changes nothing', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      final op = newUuid();
      await issue(id, operationId: op);
      await issue(id, operationId: op);
      expect((await db.select(db.invoices).getSingle()).number, 'INV-$_year-0001');
      expect(await db.select(db.billedAllocations).get(), hasLength(1));
      expect(await db.select(db.invoiceLines).get(), hasLength(1));
    });

    test('an issued invoice never changes, by any path (INV-06)', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      await expectLater(db.saveInvoiceDraft(id, const InvoicesCompanion(poReference: Value('PO-9')), operationId: newUuid()), refused(InvoiceProblem.wrongStep));
      await expectLater(db.deleteInvoiceDraft(id, operationId: newUuid()), refused(InvoiceProblem.wrongStep));
      await expectLater(issue(id), refused(InvoiceProblem.wrongStep));
      for (final sql in [
        "UPDATE invoices SET po_reference = 'PO-9'",
        "UPDATE invoices SET status = 'draft'",
        'DELETE FROM invoices',
        'UPDATE invoice_lines SET net_fils = 1',
        'DELETE FROM invoice_lines',
      ]) {
        await expectLater(db.customStatement(sql), throwsA(anything), reason: sql);
      }
      expect((await db.invoiceView(id)).totals.totalFils, 13500);
    });
  });

  group('a credit note (INV-06)', () {
    test('takes the invoice back whole, keeps it on record, and frees its work for a new invoice', () async {
      await register();
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final id = await draft();
      await issue(id);
      final credit = await db.creditInvoice(id, reason: 'Wrong hours', operationId: newUuid());

      final original = await db.invoiceView(id);
      final note = await db.invoiceView(credit);
      expect(original.status, InvoiceStatus.credited);
      expect(original.creditNotes.single.id, credit);
      expect((note.isCreditNote, note.invoice.number, note.invoice.reason, note.original!.id), (true, 'CN-$_year-0001', 'Wrong hours', id));
      expect((note.totals.netFils, note.totals.vatFils, note.parties.customerName), (original.totals.netFils, original.totals.vatFils, 'Emaar'));
      expect(await db.unbilledLines(sheet), hasLength(1));

      final again = await draft();
      await issue(again);
      expect((await db.invoiceView(again)).invoice.number, 'INV-$_year-0002');
      await expectLater(db.creditInvoice(id, reason: 'Twice', operationId: newUuid()), refused(InvoiceProblem.wrongStep));
      await expectLater(db.creditInvoice(credit, reason: 'A credit of a credit', operationId: newUuid()), refused(InvoiceProblem.wrongStep));
      await expectLater(db.customStatement("UPDATE invoices SET status = 'issued' WHERE id = '$id'"), throwsA(anything));
    });

    test('for an amount takes back part with its VAT, leaves the work charged, and the rest can follow', () async {
      await register();
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final id = await draft();
      await issue(id);
      final part = await db.creditInvoice(id, reason: 'Rate agreed lower', amountFils: 3000, operationId: newUuid());

      final note = await db.invoiceView(part);
      expect((note.invoice.number, note.lines.single.description, note.lines.single.isItem, note.totals.netFils, note.totals.vatFils), ('CN-$_year-0001', 'Rate agreed lower', true, 3000, 150));
      var v = await db.invoiceView(id);
      expect((v.status, v.creditNotes.length, v.credited.totalFils, v.leftFils), (InvoiceStatus.issued, 1, 3150, 11025));
      expect(await db.unbilledLines(sheet), isEmpty, reason: 'the work stays charged');
      // 105.01 and its 5.25 of VAT is a fils more than is left.
      await expectLater(db.creditInvoice(id, reason: 'Too much', amountFils: 10501, operationId: newUuid()), refused(InvoiceProblem.creditTooBig));
      await expectLater(db.creditInvoice(id, reason: 'Nothing', amountFils: 0, operationId: newUuid()), refused(InvoiceProblem.creditTooBig));

      final rest = await db.creditInvoice(id, reason: 'Cancelled', operationId: newUuid());
      final last = await db.invoiceView(rest);
      expect((last.invoice.number, last.lines.length, last.totals.netFils, last.totals.vatFils), ('CN-$_year-0002', 1, 10500, 525));
      v = await db.invoiceView(id);
      expect((v.status, v.leftFils, v.creditNotes.length), (InvoiceStatus.credited, 0, 2));
      expect(await db.unbilledLines(sheet), hasLength(1), reason: 'taken back whole, the work is free again');
    });
  });

  group('a line the owner writes (INV-01)', () {
    test('goes on after the timesheet lines, with VAT at the invoice rate, and is stored as written', () async {
      await register();
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      const transport = InvoiceItem(key: 'item|1', description: 'Transport, October', quantity: 2, unitPriceFils: 25000);
      await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(const InvoiceDraft(items: [transport]).toJson())), operationId: newUuid());
      final v = await db.invoiceView(id);
      expect([for (final l in v.lines) (l.isItem, l.amountFils, l.tax.vatFils)], [(false, 13500, 675), (true, 50000, 2500)]);

      await issue(id);
      final issued = await db.invoiceView(id);
      final item = issued.lines.last;
      expect((item.isItem, item.description, item.quantity, item.unitPriceFils, item.timesheetId), (true, 'Transport, October', 2, 25000, null));
      expect(issued.totals.totalFils, 14175 + 52500);
      expect(await db.select(db.billedAllocations).get(), hasLength(1), reason: 'a written line charges no work');
    });

    test('a draft keeps its written lines when a timesheet is left out or a discount set', () {
      const draft = InvoiceDraft(items: [InvoiceItem(key: 'item|1', description: 'Transport', quantity: 1, unitPriceFils: 100)]);
      final again = InvoiceDraft.fromJson(draft.copyWith(skipped: {'t1'}, discounts: {'k': 5}).toJson());
      expect(again.items.single.description, 'Transport');
      expect(again.skipped, {'t1'});
      expect(again.discounts, {'k': 5});
    });
  });

  group('a monthly contract (TS-08)', () {
    late String fixed;
    late String tower;

    setUp(() async {
      fixed = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Fixed Fee')));
      tower = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(fixed), name: const Value('Tower')));
      await db.saveRow(
        db.billingContracts,
        id: null,
        operationId: newUuid(),
        fields: BillingContractsCompanion(clientId: Value(fixed), basis: Value(RateBasis.monthFixed.name), rateFils: const Value(500000), effectiveFrom: const Value('2020-01-01')),
      );
      for (final (w, date) in [(ts.asif, '2020-10-05'), (ts.bilal, '2020-10-05'), (ts.asif, '2020-10-20')]) {
        await db.saveAttendanceBatch(workDate: date, clientId: fixed, siteId: tower, inputs: [EntryInput(workerId: w, shift: ts.shift)], operationId: newUuid());
      }
      final sheet = await db.createTimesheet(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
    });

    test('is one line at its fee, never the rows, and the owner can change it', () async {
      final id = await db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      final line = (await db.invoiceView(id)).lines.single;
      expect((line.isFee, line.quantity, line.amountFils, line.fromDate, line.toDate, line.sources.length), (true, 1, 500000, '2020-10-05', '2020-10-20', 3));
      await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(InvoiceDraft(fees: {line.key: 400000}).toJson())), operationId: newUuid());
      expect((await db.invoiceView(id)).totals.totalFils, 400000);
    });

    test('is charged once: its rows go on record at nothing', () async {
      final id = await db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      await issue(id);
      expect((await db.select(db.billedAllocations).get()).map((b) => b.amountFils), [0, 0, 0]);
      await expectLater(db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid()), refused(InvoiceProblem.nothingToBill));
    });
  });

  group('closing a month (D-048)', () {
    Future<List<ClosingFinding>> notInvoiced() async => [for (final f in (await db.closingFor('2020-10')).findings) if (f.issue == ClosingIssue.notInvoiced) f];

    Future<List<(ClosingIssue, String)>> billing() async => [
      for (final f in (await db.closingFor('2020-10')).findings)
        if (const {ClosingIssue.notInvoiced, ClosingIssue.changedAfterInvoice, ClosingIssue.invoiceOutOfDate}.contains(f.issue)) (f.issue, f.names.join(', ')),
    ];

    test('work changed after it was invoiced stops the month until the timesheet is revised and the invoice put right (D-051)', () async {
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final id = await draft();
      await issue(id);
      expect(await billing(), isEmpty);

      final old = await db.select(db.attendanceEntries).getSingle();
      final same = await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: ts.shift, overlapReason: 'Two sites'), reason: 'Noted', operationId: newUuid());
      expect(await billing(), isEmpty, reason: 'the charge did not change');
      final current = await (db.select(db.attendanceEntries)..where((e) => e.id.equals(same))).getSingle();
      await db.correctEntry(current, EntryInput(workerId: old.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      final number = (await db.timesheetView(sheet)).sheet.number!;
      expect(await billing(), [(ClosingIssue.changedAfterInvoice, number)]);

      await db.startTimesheetRevision(sheet, reason: 'Left early', operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
      expect(await billing(), [(ClosingIssue.invoiceOutOfDate, 'INV-$_year-0001 (Emaar)')]);
      final change = (await db.invoiceView(id)).changes.single;
      expect((change.billedFils, change.nowFils), (13500, 10500));

      await db.creditInvoice(id, reason: 'Left early', operationId: newUuid());
      expect(await billing(), [(ClosingIssue.notInvoiced, 'Emaar')]);
      final again = await draft();
      await issue(again);
      expect(await billing(), isEmpty);
      expect((await db.invoiceView(again)).totals.totalFils, 10500);
    });

    test('a credit note for an amount does not put changed work right', () async {
      await ts.work(db, '2020-10-05');
      final sheet = await approved();
      final id = await draft();
      await issue(id);
      final old = await db.select(db.attendanceEntries).getSingle();
      await db.correctEntry(old, EntryInput(workerId: old.workerId, shift: const ShiftInput(startMinute: 8 * 60, endMinute: 16 * 60, breakMinutes: 60)), reason: 'Left early', operationId: newUuid());
      await db.startTimesheetRevision(sheet, reason: 'Left early', operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
      await db.creditInvoice(id, reason: 'Left early', amountFils: 3000, operationId: newUuid());
      expect([for (final (issue, _) in await billing()) issue], [ClosingIssue.invoiceOutOfDate]);
    });

    test('work with a company rate that no invoice charges stops the month, by company, until it is invoiced', () async {
      await ts.work(db, '2020-10-05');
      final f = (await notInvoiced()).single;
      expect(f.date, '2020-10-31');
      expect(f.names, ['Emaar']);
      await approved();
      expect(await notInvoiced(), hasLength(1), reason: 'a timesheet is not an invoice');
      final id = await draft();
      await issue(id);
      expect(await notInvoiced(), isEmpty);
      await db.creditInvoice(id, reason: 'Wrong', operationId: newUuid());
      expect(await notInvoiced(), hasLength(1), reason: 'a credit note gives the work back');
    });

    test('a row the company agreed not to pay has nothing to invoice', () async {
      await ts.work(db, '2020-10-05');
      final sheet = await db.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      final v = await db.timesheetView(sheet);
      await db.adjustTimesheetRow(
        v.revision.id,
        v.rows.single.entryId,
        const TsAdjustment(status: AttendanceStatus.absent, minutes: 0, amountFils: 0, reason: 'Site closed'),
        operationId: newUuid(),
      );
      await db.approveTimesheet(v.revision.id, operationId: newUuid());
      expect(await notInvoiced(), isEmpty);
    });
  });

  test('the list shows each invoice with its company and total', () async {
    await ts.work(db, '2020-10-05');
    await approved();
    final id = await draft();
    expect((await db.watchInvoices().first).single.totalFils, isNull, reason: 'a draft has no fixed lines');
    await issue(id);
    final row = (await db.watchInvoices().first).single;
    expect((row.clientName, row.totalFils, row.invoice.number), ('Emaar', 13500, 'INV-$_year-0001'));
  });

  test('the invoice register has every line as issued, and a credit note counts against (D-011)', () async {
    await register();
    await ts.work(db, '2020-10-05');
    await approved();
    final id = await draft();
    await issue(id);
    await db.creditInvoice(id, reason: 'Wrong', operationId: newUuid());
    final l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
    final data = await buildRegister(db, l10n, Section.invoiceRegister);
    expect([for (final e in data.entries) (e.cells[1], e.cells[12], e.cells[15], e.cells[16])], unorderedEquals([('INV-$_year-0001', 13500, 675, 14175), ('CN-$_year-0001', -13500, -675, -14175)]));
    expect(data.entries.first.cells[3], isNull, reason: 'Emaar has no TRN');
    expect(columnTotal(data.entries, 16), 0);
  });

  test('quantities print in their own unit', () {
    expect(quantityText(RateBasis.hour, 540), '9.00');
    expect(quantityText(RateBasis.hour, 545), '9.08');
    expect(quantityText(RateBasis.day, 25), '12.5');
    expect(quantityText(RateBasis.monthPerWorker, 3), '3');
    expect(quantityText(null, 2), '2');
  });
}
