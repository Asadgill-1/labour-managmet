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
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/receipts.dart';
import 'package:domain/cash.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/invoices/invoice_paper.dart';
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

    test('numbers run by year with no gap: a failure part way uses none, and the database refuses one twice (INV-08)', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await expectLater(db.issueInvoice(id, describe: (_) => throw StateError('printer'), operationId: newUuid()), throwsStateError);
      final left = await db.invoiceView(id);
      expect((left.status, left.invoice.number), (InvoiceStatus.draft, null));
      expect(await db.select(db.invoiceLines).get(), isEmpty);
      expect(await db.select(db.billedAllocations).get(), isEmpty);
      await issue(id);
      final first = await (db.select(db.invoices)..where((i) => i.id.equals(id))).getSingle();
      expect(first.number, 'INV-$_year-0001');

      // Last year's numbers don't count, and this year's can't be used twice, whatever path writes it.
      await db.into(db.invoices).insert(first.copyWith(id: newUuid(), year: Value(_year - 1), seq: const Value(41), number: Value('INV-${_year - 1}-0041')));
      await expectLater(db.into(db.invoices).insert(first.copyWith(id: newUuid())), throwsA(predicate((e) => '$e'.contains('UNIQUE'))));
      await ts.work(db, '2020-10-06');
      await approved();
      final second = await draft();
      await issue(second);
      expect((await db.invoiceView(second)).invoice.number, 'INV-$_year-0002');
      await db.creditInvoice(second, reason: 'Wrong', operationId: newUuid());
      final note = await (db.select(db.invoices)..where((i) => i.kind.equals('credit'))).getSingle();
      expect(note.number, 'CN-$_year-0001', reason: 'credit notes count on their own');
      await expectLater(db.into(db.invoices).insert(note.copyWith(id: newUuid())), throwsA(predicate((e) => '$e'.contains('UNIQUE'))));
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

    test('a month invoiced in two parts, or with work added later, charges its fee once (TS-05)', () async {
      final first = await db.createInvoice(clientId: fixed, from: ts.from, to: '2020-10-15', operationId: newUuid());
      expect((await db.invoiceView(first)).lines.single.amountFils, 500000);
      await issue(first);
      await expectLater(db.createInvoice(clientId: fixed, from: '2020-10-16', to: ts.to, operationId: newUuid()), refused(InvoiceProblem.nothingToBill));

      // Work entered after the fee was charged goes on a timesheet of its own.
      await db.saveAttendanceBatch(workDate: '2020-10-25', clientId: fixed, siteId: tower, inputs: [EntryInput(workerId: ts.bilal, shift: ts.shift)], operationId: newUuid());
      final late = await db.createTimesheet(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(late)).revision.id, operationId: newUuid());
      await expectLater(db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid()), refused(InvoiceProblem.nothingToBill));
      expect([for (final f in (await db.closingFor('2020-10')).findings) if (f.issue == ClosingIssue.notInvoiced) f], isEmpty, reason: 'the fee charged covers the month');

      // A credit note gives the month back, and one fee then covers both timesheets.
      await db.creditInvoice(first, reason: 'Wrong dates', operationId: newUuid());
      final again = await db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      final line = (await db.invoiceView(again)).lines.single;
      expect((line.amountFils, line.sources.length), (500000, 4));
      expect(invoiceLineText(paperWords, line), startsWith('Monthly contract amount for 10-2020 ('), reason: 'the paper names the month the amount covers, and says contract once');
    });

    test('a month billed in parts charges what is left of its amount, however many parts (D-058)', () async {
      Future<InvoiceLineView> fee(String id) async => (await db.invoiceView(id)).lines.single;
      Future<String> charge(String from, String to, int fils) async {
        final id = await db.createInvoice(clientId: fixed, from: from, to: to, operationId: newUuid());
        await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(InvoiceDraft(fees: {(await fee(id)).key: fils}).toJson())), operationId: newUuid());
        await issue(id);
        return id;
      }

      final first = await charge(ts.from, '2020-10-15', 250000);
      final number = (await db.invoiceView(first)).invoice.number!;
      final second = await db.createInvoice(clientId: fixed, from: '2020-10-16', to: ts.to, operationId: newUuid());
      var line = await fee(second);
      expect((line.amountFils, line.quantity, line.unitPriceFils), (250000, 1, 250000), reason: 'the rest of the month, printed as one month at that price');
      expect(line.chargedBefore, [(number: number, fils: 250000)], reason: 'and where the first part went');
      await db.deleteInvoiceDraft(second, operationId: newUuid());
      await charge('2020-10-16', ts.to, 100000);

      // A third part: work entered later takes what is still left.
      await db.saveAttendanceBatch(workDate: '2020-10-25', clientId: fixed, siteId: tower, inputs: [EntryInput(workerId: ts.bilal, shift: ts.shift)], operationId: newUuid());
      final late = await db.createTimesheet(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(late)).revision.id, operationId: newUuid());
      expect(await db.uninvoicedWork(to: ts.to), {(fixed, '2020-10')}, reason: 'part of the month is still to charge');
      final third = await db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      expect((await fee(third)).amountFils, 150000);
      await issue(third);
      await expectLater(db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid()), refused(InvoiceProblem.nothingToBill));
      expect([for (final f in (await db.closingFor('2020-10')).findings) if (f.issue == ClosingIssue.notInvoiced) f], isEmpty);

      // A credit note for an amount corrects the price and gives nothing back; a whole one gives its part back.
      await db.creditInvoice(first, reason: 'Agreed less', amountFils: 50000, operationId: newUuid());
      await expectLater(db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid()), refused(InvoiceProblem.nothingToBill));
      await db.creditInvoice(third, reason: 'Wrong amount', operationId: newUuid());
      line = await fee(await db.createInvoice(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid()));
      expect((line.amountFils, line.sources.length), (150000, 1));
    });

    test('a fee per worker charges each worker once a month', () async {
      final crew = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Crew')));
      final yard = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(crew), name: const Value('Yard')));
      await db.saveRow(
        db.billingContracts,
        id: null,
        operationId: newUuid(),
        fields: BillingContractsCompanion(clientId: Value(crew), basis: Value(RateBasis.monthPerWorker.name), rateFils: const Value(200000), effectiveFrom: const Value('2020-01-01')),
      );
      Future<void> billed(String date, List<String> workers) async {
        await db.saveAttendanceBatch(workDate: date, clientId: crew, siteId: yard, inputs: [for (final w in workers) EntryInput(workerId: w, shift: ts.shift)], operationId: newUuid());
        final sheet = await db.createTimesheet(clientId: crew, from: ts.from, to: ts.to, operationId: newUuid());
        await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
      }

      await billed('2020-10-06', [ts.asif]);
      await issue(await db.createInvoice(clientId: crew, from: ts.from, to: ts.to, operationId: newUuid()));
      await billed('2020-10-21', [ts.asif, ts.bilal]);
      final second = await db.createInvoice(clientId: crew, from: ts.from, to: ts.to, operationId: newUuid());
      final line = (await db.invoiceView(second)).lines.single;
      expect((line.quantity, line.amountFils), (1, 200000), reason: 'Asif is charged for October already');
      expect(invoiceLineText(paperWords, line), startsWith('Monthly contract amount for 10-2020, Per month, each worker ('));
    });
  });

  group('receipts (INV-05, INV-07)', () {
    Future<String> issued() async {
      await register();
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      return id;
    }

    Future<String> receive(int fils, Map<String?, int> parts, {String? operationId}) =>
        db.addClientReceipt(operationId: operationId ?? newUuid(), date: '2020-11-10', clientId: ts.emaar, amountFils: fils, parts: parts, method: 'bank', reference: 'TT 4471');

    Future<InvoiceMoney> money(String id) async => (await db.receivables()).invoices[id]!;
    Future<int> credit() async => (await db.receivables()).creditOf(ts.emaar);
    final today = dubaiToday(DateTime.now());

    test('part received leaves the rest owed, a receipt holds its date, method and reference, and a retry changes nothing', () async {
      final id = await issued();
      expect((await money(id)).totalFils, 14175);
      final op = newUuid();
      final receipt = await receive(6000, {id: 5000}, operationId: op);
      await receive(6000, {id: 5000}, operationId: op);

      final m = await money(id);
      expect((m.receivedFils, m.leftFils, m.state(today)), (5000, 9175, PayState.partlyPaid));
      expect(await credit(), 1000, reason: 'what the receipt left waits as credit, never as more revenue');
      final row = await (db.select(db.cashEntries)..where((c) => c.id.equals(receipt))).getSingle();
      expect((row.kind, row.entryDate, row.method, row.reference, row.amountFils), (CashKind.clientReceipt.name, '2020-11-10', 'bank', 'TT 4471', 6000));
      final v = await db.invoiceView(id);
      expect((v.receipts.single.fils, v.clientCreditFils, v.money!.leftFils), (5000, 1000, 9175));
    });

    test('more than an invoice still owes, more than was received, or nothing, is refused and nothing is written', () async {
      final id = await issued();
      await expectLater(receive(20000, {id: 14176}), throwsA(isA<ReceiptTooHigh>()));
      await expectLater(receive(1000, {id: 2000}), throwsA(isA<ReceiptTooHigh>()));
      await expectLater(receive(1000, {id: 0}), throwsA(isA<ReceiptTooHigh>()));
      await expectLater(receive(0, {}), throwsA(isA<ReceiptTooHigh>()));
      expect(await db.select(db.cashEntries).get(), isEmpty);
      expect(await db.select(db.invoiceAllocations).get(), isEmpty);
    });

    test('money received before the invoice waits as credit, then settles it when used', () async {
      await receive(20000, {});
      expect(await credit(), 20000);
      final id = await issued();
      await db.useClientCredit(id, operationId: newUuid());
      expect(((await money(id)).state(today), await credit()), (PayState.paid, 20000 - 14175));
      await expectLater(db.useClientCredit(id, operationId: newUuid()), throwsA(isA<ReceiptTooHigh>()), reason: 'nothing is left to settle');
    });

    test('undoing a receipt in the cash book sets aside what it settled', () async {
      final id = await issued();
      final receipt = await receive(14175, {id: 14175});
      expect((await money(id)).state(today), PayState.paid);
      final row = await (db.select(db.cashEntries)..where((c) => c.id.equals(receipt))).getSingle();
      await db.reverseCashEntry(row, reason: 'Cheque bounced', operationId: newUuid());
      expect(((await money(id)).leftFils, await credit()), (14175, 0));
    });

    test('a credit note on a paid invoice gives the money back as credit, which the new invoice can use', () async {
      final id = await issued();
      await receive(14175, {id: 14175});
      await db.creditInvoice(id, reason: 'Rate agreed lower', amountFils: 3000, operationId: newUuid());
      expect(((await money(id)).leftFils, await credit()), (0, 3150));
      expect((await db.invoiceView(id)).returnedFils, 3150, reason: 'the invoice says its money went to credit');

      await db.creditInvoice(id, reason: 'Wrong hours', operationId: newUuid());
      expect(((await money(id)).leftFils, await credit()), (0, 14175));
      expect((await db.invoiceView(id)).returnedFils, 14175);
      final again = await db.createInvoice(clientId: ts.emaar, from: ts.from, to: ts.to, replaces: id, operationId: newUuid());
      expect((await db.invoiceView(id)).replacedBy?.id, again, reason: 'asking for a new invoice again opens this draft, not a second one');
      await issue(again);
      await db.useClientCredit(again, operationId: newUuid());
      expect(((await money(again)).state(today), await credit()), (PayState.paid, 0));
    });

    test("the company's balance from before the app is owed first, and takes receipts like an invoice", () async {
      await db.saveRow(db.openingBalances, id: null, operationId: newUuid(), fields: OpeningBalancesCompanion(kind: const Value('client_receivable'), clientId: Value(ts.emaar), amountFils: const Value(10000), asOfDate: const Value('2020-09-30'), sourceNote: const Value('Old ledger')));
      final id = await issued();
      final open = (await db.receivables()).openOf(ts.emaar);
      expect([for (final o in open) (o.invoiceId, o.leftFils)], [(null, 10000), (id, 14175)]);
      await receive(12000, {null: 10000, id: 2000});
      final after = await db.receivables();
      expect((after.openingLeftFils[ts.emaar], after.invoices[id]!.leftFils, after.creditOf(ts.emaar)), (0, 12175, 0));
    });

    test('what settled an invoice never changes or goes', () async {
      final id = await issued();
      await receive(5000, {id: 5000});
      await expectLater(db.update(db.invoiceAllocations).write(const InvoiceAllocationsCompanion(amountFils: Value(1))), throwsA(anything));
      await expectLater(db.delete(db.invoiceAllocations).go(), throwsA(anything));
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

    test("an invoice due by the month's last day with money left stops it, until paid or closed as lost with a reason (D-048)", () async {
      final month = dubaiToday(DateTime.now()).substring(0, 7);
      Future<List<ClosingFinding>> overdue(String m) async => [for (final f in (await db.closingFor(m)).findings) if (f.issue == ClosingIssue.overdue) f];
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      final due = (await db.invoiceView(id)).invoice.dueDate;
      expect(await overdue('2020-10'), isEmpty, reason: 'it falls due long after October 2020');
      final found = (await overdue(month)).single;
      expect((found.date, found.names.join()), (due, 'INV-$_year-0001 (Emaar)'), reason: 'counted from the last day, whatever day the owner closes');

      await db.addClientReceipt(operationId: newUuid(), date: dubaiToday(DateTime.now()), clientId: ts.emaar, amountFils: 5000, parts: {id: 5000});
      expect(await overdue(month), hasLength(1), reason: 'part paid is still money left');

      await db.closeInvoiceAsLost(id, reason: 'Company shut down', operationId: newUuid());
      final closed = (await db.receivables()).invoices[id]!;
      expect((closed.receivedFils, closed.lostFils, closed.leftFils, closed.state(dubaiToday(DateTime.now()))), (5000, 8500, 0, PayState.closed));
      expect(await overdue(month), isEmpty);
      await expectLater(db.closeInvoiceAsLost(id, reason: 'Again', operationId: newUuid()), refused(InvoiceProblem.wrongStep));
      expect((await db.invoiceView(id)).status, InvoiceStatus.issued, reason: 'the invoice stays as issued');

      await db.undoInvoiceLoss(id, reason: 'They paid after all', operationId: newUuid());
      expect(await overdue(month), hasLength(1));
      await db.addClientReceipt(operationId: newUuid(), date: dubaiToday(DateTime.now()), clientId: ts.emaar, amountFils: 8500, parts: {id: 8500});
      expect(await overdue(month), isEmpty);
      expect((await db.receivables()).invoices[id]!.state(dubaiToday(DateTime.now())), PayState.paid);
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

  test("the invoice register keeps each paper's lines together, even when two are made in one second", () async {
    await ts.work(db, '2020-10-05');
    await ts.work(db, '2020-10-05', worker: ts.bilal, site: ts.creek);
    await approved();
    final id = await draft();
    await issue(id);
    await db.creditInvoice(id, reason: 'Wrong', operationId: newUuid());
    final data = await buildRegister(db, await AppLocalizations.delegate.load(const Locale('en', 'PK')), Section.invoiceRegister);
    final numbers = [for (final e in data.entries) e.cells[1]];
    expect(numbers, hasLength(4));
    expect([for (var i = 1; i < numbers.length; i++) if (numbers[i] != numbers[i - 1]) i], hasLength(1), reason: '$numbers');
  });

  test('the invoice register keeps a line the owner wrote and a credit for an amount, which have no unit', () async {
    await ts.work(db, '2020-10-05');
    await approved();
    final id = await draft();
    const transport = InvoiceItem(key: 'item|1', description: 'Transport', quantity: 2, unitPriceFils: 2500);
    await db.saveInvoiceDraft(id, InvoicesCompanion(draft: Value(const InvoiceDraft(items: [transport]).toJson())), operationId: newUuid());
    await issue(id);
    await db.creditInvoice(id, reason: 'Rate agreed lower', amountFils: 1000, operationId: newUuid());
    final l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
    final data = await buildRegister(db, l10n, Section.invoiceRegister);
    expect([for (final e in data.entries) if (e.cells[9] == '') (e.cells[7], e.cells[8], e.cells[16])], unorderedEquals([('Transport', '2', 5000), ('Rate agreed lower', '1', -1000)]));
  });

  test('a company statement runs invoice, receipt and credit note to a balance that agrees with what is owed less credit (INV-07)', () async {
    final today = dubaiToday(DateTime.now());
    await ts.work(db, '2020-10-05');
    await approved();
    final id = await draft();
    await issue(id);
    await db.addClientReceipt(operationId: newUuid(), date: today, clientId: ts.emaar, amountFils: 6000, parts: {id: 5000}, reference: 'CHQ 12');
    await db.creditInvoice(id, reason: 'Rate agreed lower', amountFils: 1000, operationId: newUuid());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final data = await buildRegister(db, l10n, Section.statementRegister);
    // All three fall today, and a test writes them within one second, so only the balance at the end is in a fixed order.
    expect([for (final e in data.entries) (e.cells[2], e.cells[3], e.cells[4], e.cells[5], e.cells[6])], unorderedEquals([
      (l10n.invTab, 'INV-$_year-0001', 13500, null, null),
      (l10n.kindClientReceipt, 'CHQ 12', null, null, 6000),
      (l10n.invCreditNoteLabel, 'CN-$_year-0001', null, 1000, null),
    ]));
    expect(data.entries.last.cells[8], 6500);
    final money = await db.receivables();
    expect(money.invoices[id]!.leftFils - money.creditOf(ts.emaar), 6500, reason: '7,500 still owed less 1,000 of credit');
    expect(data.groupFeet['Emaar'], contains(l10n.regCompanyOwes('AED 65.00')));
  });

  test('quantities print in their own unit', () {
    expect(quantityText(RateBasis.hour, 540), '9.00');
    expect(quantityText(RateBasis.hour, 545), '9.08');
    expect(quantityText(RateBasis.day, 25), '12.5');
    expect(quantityText(RateBasis.monthPerWorker, 3), '3');
    expect(quantityText(null, 2), '2');
  });
}
