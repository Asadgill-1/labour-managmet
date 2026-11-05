import 'dart:convert';
import 'dart:io';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/invoices.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/documents/document_frame.dart';
import 'package:labour_app/features/invoices/invoice_paper.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const from = '2020-10-01';
const to = '2020-10-31';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();

/// A figure on its own, so 15.00 isn't found inside 115.00.
Matcher hasFigure(String figure) => contains(RegExp('(?<![\\d,.])${RegExp.escape(figure)}'));

late String emaar;
late String marina;
late String asif;

/// AED 10 an hour to Asif, AED 15 to Emaar, nine hours on 5 October.
Future<void> seed(TenantDatabase db, {bool vat = true}) async {
  await db.saveRow(
    db.tenantProfiles,
    id: null,
    operationId: newUuid(),
    fields: TenantProfilesCompanion(legalName: const Value('Al Noor Labour Supply LLC'), trn: const Value('100234567800003'), vatRegistered: Value(vat), bankDetails: const Value('Emirates NBD 1234')),
  );
  asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif'), trade: Value('Mason')));
  emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar'), address: Value('Downtown Dubai'), trn: Value('100987654300003'), dueDays: Value(30)));
  marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(asif), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
  await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')));
}

Future<void> work(TenantDatabase db, String date) =>
    db.saveAttendanceBatch(workDate: date, clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: shift)], operationId: newUuid());

Future<String> issued(TenantDatabase db, {String start = from, String end = to}) async {
  final sheet = await db.createTimesheet(clientId: emaar, from: start, to: end, operationId: newUuid());
  await db.approveTimesheet((await db.timesheetView(sheet)).revision.id, operationId: newUuid());
  final id = await db.createInvoice(clientId: emaar, from: start, to: end, operationId: newUuid());
  await db.issueInvoice(id, describe: (l) => invoiceLineText(paperWords, l), operationId: newUuid());
  return id;
}

void main() {
  late TenantDatabase db;

  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  group('what an invoice says (INV-02, INV-09)', () {
    test('a tax invoice: both parties, the dates, each line with its VAT, and that it is not an e-invoice', () async {
      await seed(db);
      await work(db, '2020-10-05');
      final v = await db.invoiceView(await issued(db));
      final p = invoicePaper(v, paperWords);
      expect(invoiceTitle(paperWords, v), 'Tax Invoice');
      expect((p.billTo, p.customer), ('Bill to', 'Emaar'));
      expect(p.customerLines, ['Downtown Dubai', 'TRN 100987654300003']);
      final details = {for (final (k, val) in p.details) k: val};
      expect(details['Supplier TRN'], '100234567800003');
      expect(details['Date of issue'], showDate(dubaiToday(DateTime.now())));
      expect(details['Period of supply'], paperWords.dateFromTo('01-10-2020', '31-10-2020'));
      expect(details['Due date'], showDate(addDays(dubaiToday(DateTime.now()), 30)));
      expect(p.rows.single, ['1', 'Manpower supply, Marina, Mason (05-10-2020 to 05-10-2020, ${v.lines.single.timesheetNumber})', '9.00', 'Hour', '15.00', '135.00', '5%', '6.75', '141.75']);
      expect(p.totals, [('Total before VAT', '135.00'), ('VAT at 5%', '6.75')]);
      expect((p.bottomLabel, p.bottomAmount), ('Total due', 'AED 141.75'));
      expect(p.notes, containsAll(['This PDF is not a UAE structured e-invoice.', 'Supported by timesheet ${v.lines.single.timesheetNumber}, which is a separate paper.']));
      expect(p.bank, 'Emirates NBD 1234');
      final text = jsonEncode(p.toJson());
      expect(text, isNot(hasFigure('10.00')), reason: "the worker's rate");
      expect(text, isNot(hasFigure('90.00')), reason: "the worker's pay");
    });

    test('is in English whatever the app speaks', () async {
      await seed(db);
      await work(db, '2020-10-05');
      final v = await db.invoiceView(await issued(db));
      final urdu = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
      expect(urdu.invTab, isNot('Invoices'), reason: 'the screens are in Roman Urdu');
      expect(invoicePaper(v, paperWords).columns.first.$1, 'No.');
      expect(v.lines.single.description, startsWith('Manpower supply'), reason: 'the line was stored as printed');
    });

    test('a company not registered for VAT prints Invoice, with no VAT and no supplier TRN', () async {
      await seed(db, vat: false);
      await work(db, '2020-10-05');
      final v = await db.invoiceView(await issued(db));
      final p = invoicePaper(v, paperWords);
      expect(invoiceTitle(paperWords, v), 'Invoice');
      expect([for (final c in p.columns) c.$1], ['No.', 'Description', 'Qty', 'Unit', 'Unit price', 'Amount']);
      expect(p.totals, isEmpty);
      expect(p.bottomAmount, 'AED 135.00');
      expect([for (final (k, _) in p.details) k], isNot(contains('Supplier TRN')));
    });

    test('a credit note names the invoice it takes back, and why', () async {
      await seed(db);
      await work(db, '2020-10-05');
      final id = await issued(db);
      final credit = await db.creditInvoice(id, reason: 'Wrong hours', operationId: newUuid());
      final v = await db.invoiceView(credit);
      final p = invoicePaper(v, paperWords);
      expect(invoiceTitle(paperWords, v), 'Tax Credit Note');
      expect(p.billTo, 'Credit to');
      final original = await db.invoiceView(id);
      expect({for (final (k, val) in p.details) k: val}['Against invoice'], '${original.invoice.number} ${showDate(original.invoice.issueDate!)}');
      expect(p.notes, contains('Reason: Wrong hours'));
      expect((p.bottomLabel, p.bottomAmount, p.bank), ('Total credited', 'AED 141.75', null));
    });

    test('the PDF draws on one page in the shared frame, and keeps its number', () async {
      await seed(db);
      await work(db, '2020-10-05');
      final v = await db.invoiceView(await issued(db));
      final identity = await db.currentIdentity(brandArgb: 0xFF0B2648, softArgb: 0xFFE0EEFF);
      final meta = DocumentMeta(title: 'Tax Invoice', number: v.invoice.number, dateLabel: '04-11-2026', pagePattern: 'Page {page} of {pages}', madeLabel: 'Made');
      final bytes = await invoicePdf(invoicePaper(v, paperWords), identity, meta, regularFont: regular, boldFont: bold);
      expect(RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length, 1);
    });
  });

  testWidgets('from an approved timesheet to an issued invoice and a credit note, through the screens', (tester) async {
    final app = memoryDb();
    final last = addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1);
    await real(tester, () async {
      await seed(app);
      await work(app, '$last-05');
      final sheet = await app.createTimesheet(clientId: emaar, from: monthFirstDay(last), to: monthLastDay(last), operationId: newUuid());
      await app.approveTimesheet((await app.timesheetView(sheet)).revision.id, operationId: newUuid());
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);

    await goTo(tester, words.invTab);
    expect(find.text(words.invEmpty), findsOneWidget);
    await tester.tap(find.text(words.invNew));
    await settle(tester);
    await tester.tap(find.text(words.colCompany));
    await settle(tester);
    await tester.tap(find.text('Emaar').last);
    await settle(tester);
    await tester.tap(find.text(words.invCreate));
    await settle(tester);

    // A draft: no number, the timesheet it reads, and VAT on each line.
    expect(find.text(words.invDraftTitle), findsOneWidget);
    expect(find.textContaining(words.invNoteDraft), findsOneWidget);
    expect(find.text(words.invSourceRows(1)), findsOneWidget);
    expect(find.text('Marina, Mason'), findsOneWidget);
    expect(find.text('AED 141.75'), findsWidgets);
    expect(await real(tester, () => app.select(app.invoiceLines).get()), isEmpty);

    // A discount comes off before VAT.
    await tester.tap(find.text('Marina, Mason'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, words.invDiscount), '35');
    await tester.tap(find.text(words.save));
    await settle(tester);
    expect(find.text('AED 105.00'), findsWidgets, reason: '100 and 5% VAT');

    // Issuing asks first, then gives the number.
    await tester.tap(find.text(words.invIssue));
    await settle(tester);
    expect(find.text(words.invIssueBody), findsOneWidget);
    await tester.tap(find.text(words.invIssue).last);
    await settle(tester);
    final year = dubaiToday(DateTime.now()).substring(0, 4);
    expect(find.text('INV-$year-0001'), findsWidgets);
    expect(find.text(words.invShareBoth), findsOneWidget);
    expect(find.text(words.invPreview), findsNothing);

    // Taken back whole, with a reason.
    await tester.tap(find.text(words.invCredit));
    await settle(tester);
    expect(find.text(words.invCreditHelp), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, words.invCreditReason), 'Wrong rate');
    await tester.tap(find.text(words.invCreditConfirm).last);
    await settle(tester);
    expect(find.text(words.invStatusCredited), findsWidgets);
    expect(find.textContaining(words.invNoteCredited('CN-$year-0001')), findsOneWidget);
    expect(find.text(words.invCredit), findsNothing);
    await shutDown(tester, app);
  });
}
