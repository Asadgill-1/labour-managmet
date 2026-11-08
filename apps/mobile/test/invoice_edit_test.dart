import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/receipts.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/features/invoices/invoice_paper.dart';
import 'package:labour_app/features/invoices/invoice_screen.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';
import 'timesheets_test.dart' as ts;

String _describe(InvoiceLineView l) => 'Manpower ${l.basis?.name} ${l.unitPriceFils}';

final _year = int.parse(dubaiToday(DateTime.now()).substring(0, 4));

/// Edit on an issued invoice: a whole credit note and a new draft with the same choices, in one step (D-056).
void main() {
  group('edit on an issued invoice (D-056)', () {
    late TenantDatabase db;

    setUp(() async {
      db = memoryDb();
      await ts.seed(db);
    });

    tearDown(() => db.close());

    Future<String> approved() async {
      final id = await db.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
      return id;
    }

    Future<String> draft() => db.createInvoice(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
    Future<void> issue(String id) => db.issueInvoice(id, describe: _describe, operationId: newUuid());
    Future<String> edit(String id, [String reason = 'Wrong hours']) => db.editInvoice(id, reason: reason, operationId: newUuid());
    Matcher refused(InvoiceProblem problem) => throwsA(isA<InvoiceRefused>().having((e) => e.problem, 'problem', problem));

    Future<void> register() async {
      final profile = await db.select(db.tenantProfiles).getSingle();
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(vatRegistered: Value(true), trn: Value('100000000000003')));
    }

    test('takes it back whole and opens a draft of the same dates and choices, which issues as the next number', () async {
      await register();
      await ts.work(db, '2020-10-05');
      await ts.work(db, '2020-10-06', worker: ts.bilal);
      final sheet = await approved();
      final id = await draft();
      final key = (await db.invoiceView(id)).lines.first.key;
      const item = InvoiceItem(key: 'item|1', description: 'Transport', quantity: 2, unitPriceFils: 5000);
      await db.saveInvoiceDraft(
        id,
        InvoicesCompanion(
          draft: Value(InvoiceDraft(discounts: {key: 1000}, items: const [item]).toJson()),
          poReference: const Value('PO-77'),
          pricesIncludeVat: const Value(true),
          dueDate: const Value('2099-01-31'),
        ),
        operationId: newUuid(),
      );
      await issue(id);
      final old = await db.invoiceView(id);

      final next = await edit(id);

      final was = await db.invoiceView(id);
      expect((was.status, was.creditNotes.single.reason, was.credited.totalFils, was.replacedBy!.id), (InvoiceStatus.credited, 'Wrong hours', old.totals.totalFils, next));
      final d = await db.invoiceView(next);
      final inv = d.invoice;
      expect(
        (d.status, inv.number, inv.clientId, inv.siteId, inv.fromDate, inv.toDate, inv.poReference, inv.pricesIncludeVat, inv.vatCategory),
        (InvoiceStatus.draft, null, ts.emaar, null, ts.from, ts.to, 'PO-77', true, old.invoice.vatCategory),
      );
      expect((d.replaces!.invoice.id, d.replaces!.creditNote!.number, inv.dueDate), (id, 'CN-$_year-0001', null), reason: 'the due date counts again from the day it issues');
      expect([for (final l in d.lines) (l.discountFils, l.tax.netFils, l.tax.vatFils)], [for (final l in old.lines) (l.discountFils, l.tax.netFils, l.tax.vatFils)]);
      expect(d.lines.last.description, 'Transport');
      expect((d.totals.totalFils, d.sources.single.skipped), (old.totals.totalFils, false));

      await issue(next);
      final again = await db.invoiceView(next);
      expect((again.invoice.number, again.replaces!.invoice.number), ('INV-$_year-0002', old.invoice.number));
      expect(again.invoice.dueDate, isNot('2099-01-31'));
      expect(invoicePaper(again, paperWords).notes, contains('Replaces invoice ${old.invoice.number}.'));
      expect(invoicePaper(old, paperWords).notes.where((n) => n.startsWith('Replaces')), isEmpty);
      expect(await db.unbilledLines(sheet), isEmpty, reason: 'the work is charged once, on the new invoice');
    });

    test('only an issued invoice with something left can be edited, and a refusal writes nothing', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      Future<int> count() async => (await db.select(db.invoices).get()).length;

      await expectLater(edit(id), refused(InvoiceProblem.wrongStep), reason: 'a draft changes in place');
      expect(await count(), 1);
      await issue(id);
      final credit = await db.creditInvoice(id, reason: 'Cancelled', operationId: newUuid());
      await expectLater(edit(id), refused(InvoiceProblem.wrongStep), reason: 'taken back already');
      await expectLater(edit(credit), refused(InvoiceProblem.wrongStep), reason: 'a credit note');
      expect(await count(), 2);
    });

    test('with part credited, the credit note takes what is left, and a draft thrown away lets a new one start', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      await db.creditInvoice(id, reason: 'Rate agreed lower', amountFils: 3000, operationId: newUuid());

      final next = await edit(id);
      final was = await db.invoiceView(id);
      expect((was.status, was.leftFils, was.creditNotes.length, was.creditNotes.last.number), (InvoiceStatus.credited, 0, 2, 'CN-$_year-0002'));
      expect((await db.invoiceView(next)).replaces!.creditNote!.number, 'CN-$_year-0002');

      await db.deleteInvoiceDraft(next, operationId: newUuid());
      expect((await db.invoiceView(id)).replacedBy, isNull);
      expect((await db.invoiceView(await draft())).lines, hasLength(1));
    });

    test('money received on it waits as the company credit, which the new invoice uses', () async {
      await ts.work(db, '2020-10-05');
      await approved();
      final id = await draft();
      await issue(id);
      await db.addClientReceipt(operationId: newUuid(), date: '2020-11-10', clientId: ts.emaar, amountFils: 5000, parts: {id: 5000}, method: 'bank', reference: 'TT 1');

      final next = await edit(id);
      expect((await db.receivables()).creditOf(ts.emaar), 5000);
      await issue(next);
      await db.useClientCredit(next, operationId: newUuid());
      final money = await db.receivables();
      expect((money.creditOf(ts.emaar), money.invoices[next]!.receivedFils), (0, 5000));
    });
  });

  testWidgets('from the screens: Edit makes the credit note and opens the new draft in the edited colour (D-056)', (tester) async {
    final app = memoryDb();
    await real(tester, () async {
      await ts.seed(app);
      await ts.work(app, '2020-10-05');
      final sheet = await app.createTimesheet(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await app.approveTimesheet((await app.timesheetView(sheet)).revision.id, operationId: newUuid());
      final id = await app.createInvoice(clientId: ts.emaar, from: ts.from, to: ts.to, operationId: newUuid());
      await app.issueInvoice(id, describe: _describe, operationId: newUuid());
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    final number = 'INV-$_year-0001';
    await pumpApp(tester, app);
    await goTo(tester, words.invTab);

    await tester.tap(find.text('Emaar'));
    await settle(tester);
    await tester.tap(find.text(words.invEdit));
    await settle(tester);
    expect(find.text(words.invEditHelp(number)), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, words.changeNoteItem), 'Ghante ghalat');
    await tester.tap(find.text(words.invEditConfirm));
    await settle(tester);

    expect(find.text(words.invDraftTitle), findsOneWidget);
    expect(find.text(words.invEditedNote(number, 'CN-$_year-0001')), findsOneWidget);
    expect(find.text(words.changeUserNote('Ghante ghalat')), findsOneWidget);
    expect(find.text(words.invOpenInvoice(number)), findsOneWidget);
    final note = (await real(tester, () => app.select(app.invoices).get())).singleWhere((i) => i.kind == 'credit');
    expect(note.reason, 'Ghante ghalat');

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.textContaining(words.editedTag), findsOneWidget, reason: 'the new draft, in the list');
    await shutDown(tester, app);
  });

  testWidgets("from the screens: a fixed contract's second part says what the month already charged (D-058)", (tester) async {
    final app = memoryDb();
    final draft = await real(tester, () async {
      await ts.seed(app);
      final fixed = await app.saveRow(app.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Fajr')));
      final tower = await app.saveRow(app.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(fixed), name: const Value('Tower')));
      await app.saveRow(
        app.billingContracts,
        id: null,
        operationId: newUuid(),
        fields: BillingContractsCompanion(clientId: Value(fixed), basis: Value(RateBasis.monthFixed.name), rateFils: const Value(500000), effectiveFrom: const Value('2020-01-01')),
      );
      for (final date in ['2020-10-05', '2020-10-20']) {
        await app.saveAttendanceBatch(workDate: date, clientId: fixed, siteId: tower, inputs: [EntryInput(workerId: ts.asif, shift: ts.shift)], operationId: newUuid());
      }
      final sheet = await app.createTimesheet(clientId: fixed, from: ts.from, to: ts.to, operationId: newUuid());
      await app.approveTimesheet((await app.timesheetView(sheet)).revision.id, operationId: newUuid());
      final first = await app.createInvoice(clientId: fixed, from: ts.from, to: '2020-10-15', operationId: newUuid());
      final key = (await app.invoiceView(first)).lines.single.key;
      await app.saveInvoiceDraft(first, InvoicesCompanion(draft: Value(InvoiceDraft(fees: {key: 250000}).toJson())), operationId: newUuid());
      await app.issueInvoice(first, describe: _describe, operationId: newUuid());
      return app.createInvoice(clientId: fixed, from: '2020-10-16', to: ts.to, operationId: newUuid());
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);
    tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(builder: (_) => InvoiceScreen(invoiceId: draft)));
    await settle(tester);

    expect(find.textContaining(words.invFeeChargedBefore(formatAed(250000), 'INV-$_year-0001')), findsOneWidget);
    expect(find.text(formatAed(250000)), findsWidgets, reason: 'the line starts at the rest');
    await shutDown(tester, app);
  });
}
