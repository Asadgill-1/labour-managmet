import 'dart:convert';
import 'dart:io';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/data/timesheets.dart';
import 'package:labour_app/documents/document_frame.dart';
import 'package:labour_app/features/timesheets/timesheet_paper.dart';
import 'package:labour_app/l10n/app_localizations.dart';

import 'support.dart';

const from = '2020-10-01';
const to = '2020-10-31';
const shift = ShiftInput(startMinute: 8 * 60, endMinute: 18 * 60, breakMinutes: 60);

final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();

int pagesOf(List<int> bytes) => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

/// A figure on its own, so 15.00 isn't found inside 115.00.
Matcher hasFigure(String figure) => contains(RegExp('(?<![\\d,.])${RegExp.escape(figure)}'));

late String asif;
late String bilal;
late String emaar;
late String marina;

Future<void> seed(TenantDatabase db) async {
  await seedProfile(db);
  asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif')));
  bilal = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Bilal')));
  emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar'), address: Value('Downtown Dubai'), trn: Value('100200300')));
  marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
  for (final w in [asif, bilal]) {
    await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(w), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
  }
  await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(emaar), basis: Value(RateBasis.hour.name), rateFils: const Value(1500), effectiveFrom: const Value('2020-01-01')));
}

Future<void> work(TenantDatabase db, String date, {String? worker, ShiftInput input = shift}) =>
    db.saveAttendanceBatch(workDate: date, clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: worker ?? asif, shift: input)], operationId: newUuid());

void main() {
  late TenantDatabase db;
  late AppLocalizations l10n;

  setUp(() async {
    db = memoryDb();
    await seed(db);
    l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
  });

  tearDown(() => db.close());

  Future<String> approved() async {
    final id = await db.createTimesheet(clientId: emaar, from: from, to: to, operationId: newUuid());
    await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
    return id;
  }

  Future<IssuedDocument> issue(TimesheetView v, {bool workers = false, bool priced = false}) async {
    final identity = await db.currentIdentity(brandArgb: 0xFF0B2648, softArgb: 0xFFE0EEFF);
    final data = timesheetPaper(v, workers: workers, priced: priced, l10n: l10n).toJson();
    return db.issueDocument(
      kind: timesheetKind(workers: workers, priced: priced),
      fixed: (year: v.sheet.year!, seq: v.sheet.seq!, revision: v.revision.revision),
      subjectId: v.revision.id,
      period: null,
      title: l10n.tsTitle,
      summary: v.clientName,
      data: data,
      identity: identity,
      metaFor: (number) => DocumentMeta(title: l10n.tsTitle, subtitle: '', number: number, dateLabel: '02-11-2026', pagePattern: 'Page {page} of {pages}', madeLabel: 'Made'),
      render: (m) => timesheetPdf(TimesheetPaper.fromJson(data), identity, m, regularFont: regular, boldFont: bold),
      operationId: newUuid(),
    );
  }

  group('what a company sees (TS-02, TC-038)', () {
    test('hours only: no rate and no amount anywhere in what is stored, and never a wage', () async {
      await work(db, '2020-10-05');
      final v = await db.timesheetView(await approved());
      for (final workers in [false, true]) {
        final text = jsonEncode(timesheetPaper(v, workers: workers, priced: false, l10n: l10n).toJson());
        expect(text, isNot(hasFigure('15.00')), reason: "the company's rate");
        expect(text, isNot(hasFigure('135.00')), reason: "the day's amount");
        expect(text, isNot(hasFigure('10.00')), reason: "the worker's rate");
        expect(text, isNot(hasFigure('90.00')), reason: "the worker's pay");
        expect(text, isNot(contains('AED')));
      }
    });

    test('with rates: rate and amount show, and still never a wage', () async {
      await work(db, '2020-10-05');
      final v = await db.timesheetView(await approved());
      for (final workers in [false, true]) {
        final text = jsonEncode(timesheetPaper(v, workers: workers, priced: true, l10n: l10n).toJson());
        expect(text, hasFigure('15.00'));
        expect(text, hasFigure('135.00'));
        expect(text, isNot(hasFigure('10.00')), reason: "the worker's rate");
        expect(text, isNot(hasFigure('90.00')), reason: "the worker's pay");
      }
    });

    test('nothing about pay reaches the stored lines either', () async {
      await work(db, '2020-10-05');
      await approved();
      final line = (await db.select(db.timesheetLines).getSingle()).toJson();
      expect(line.keys.where((k) => k.toLowerCase().contains('worker') && !{'workerId', 'workerName', 'workerCode'}.contains(k)), isEmpty);
      expect(line.values, isNot(contains(1000)));
      expect(line.values, isNot(contains(9000)));
    });

    test('the daily summary names no worker, and the detail names each one', () async {
      await work(db, '2020-10-05');
      final v = await db.timesheetView(await approved());
      expect(jsonEncode(timesheetPaper(v, workers: false, priced: true, l10n: l10n).toJson()), isNot(contains('Asif')));
      final detail = timesheetPaper(v, workers: true, priced: true, l10n: l10n);
      expect(detail.rows.single, containsAll(<String>['05-10-2020', 'Marina', 'Asif', 'W1', '10:00', '1:00', '9:00 ghante']));
    });

    test('says who it is for, the dates, and that it is no invoice', () async {
      await work(db, '2020-10-05');
      final p = timesheetPaper(await db.timesheetView(await approved()), workers: false, priced: true, l10n: l10n);
      expect(p.client, 'Emaar');
      expect(p.clientLine, 'Downtown Dubai   TRN 100200300');
      expect(p.period, contains('01-10-2020'));
      expect(p.period, contains(l10n.tsAllSites));
      expect(p.notes, contains(l10n.tsNotInvoice));
      expect(p.clientLabel, l10n.tsClientSign('Emaar'));
    });
  });

  group('rows and totals on the paper (TS-03, TC-039)', () {
    test('different rates stay on different rows, and each total has its own name', () async {
      await work(db, '2020-10-05');
      final overridden = ShiftInput(startMinute: shift.startMinute, endMinute: shift.endMinute, breakMinutes: 60, clientOverrideFils: 2000);
      await db.saveAttendanceBatch(workDate: '2020-10-05', clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: bilal, shift: overridden, overrideReason: 'Agreed rate')], operationId: newUuid());
      final p = timesheetPaper(await db.timesheetView(await approved()), workers: false, priced: true, l10n: l10n);
      expect(p.rows, hasLength(2));
      expect(p.facts, containsAll(<(String, String)>[(l10n.tsUniqueWorkers, '2'), (l10n.tsWorkerDays, '2'), (l10n.tsHoursBilled, '18:00')]));
      expect(p.amount, 'AED 315.00');
      expect(p.facts.map((f) => f.$1), isNot(contains(l10n.tsDaysBilled)), reason: 'nobody billed by the day');
    });

    test('a second shift on a day adds a column only then', () async {
      await work(db, '2020-10-05');
      await work(db, '2020-10-05', input: const ShiftInput(startMinute: 19 * 60, endMinute: 21 * 60));
      final p = timesheetPaper(await db.timesheetView(await approved()), workers: false, priced: false, l10n: l10n);
      expect(p.columns.map((c) => c.$1), contains(l10n.colShifts));
      expect(p.facts, contains((l10n.tsShiftsWorked, '2')));
    });

    test('an agreed row is marked, and says why', () async {
      await work(db, '2020-10-05');
      final id = await db.createTimesheet(clientId: emaar, from: from, to: to, operationId: newUuid());
      final entry = await db.select(db.attendanceEntries).getSingle();
      await db.adjustTimesheetRow((await db.timesheetView(id)).revision.id, entry.id, const TsAdjustment(status: AttendanceStatus.present, minutes: 480, amountFils: 12000, reason: 'Site says eight hours'), operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
      final p = timesheetPaper(await db.timesheetView(id), workers: true, priced: true, l10n: l10n);
      expect(p.rows.single, contains('8:00 ghante *'));
      expect(p.agreed.single, '* 05-10-2020, Asif: Site says eight hours');
    });

    test('a revision says why it was made', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      await db.startTimesheetRevision(id, reason: 'Company asked', operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
      final p = timesheetPaper(await db.timesheetView(id), workers: false, priced: false, l10n: l10n);
      expect(p.notes, contains(l10n.tsRevisedBecause('Company asked')));
    });
  });

  group('a monthly contract on paper (TS-08)', () {
    late String fixedClient;
    late String tower;

    setUp(() async {
      fixedClient = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Fixed Fee')));
      tower = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(fixedClient), name: const Value('Tower')));
      await db.saveRow(db.billingContracts, id: null, operationId: newUuid(), fields: BillingContractsCompanion(clientId: Value(fixedClient), basis: Value(RateBasis.monthFixed.name), rateFils: const Value(500000), effectiveFrom: const Value('2020-01-01')));
      for (final w in [asif, bilal]) {
        await db.saveAttendanceBatch(workDate: '2020-10-05', clientId: fixedClient, siteId: tower, inputs: [EntryInput(workerId: w, shift: shift)], operationId: newUuid());
      }
    });

    Future<TimesheetView> monthly() async {
      final id = await db.createTimesheet(clientId: fixedClient, from: from, to: to, operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
      return db.timesheetView(id);
    }

    test('the attendance shows as evidence, with no daily amount and no total to count again', () async {
      final p = timesheetPaper(await monthly(), workers: true, priced: true, l10n: l10n);
      expect(p.rows, hasLength(2));
      expect(p.rows.first.last, '-');
      expect(p.rows.first, contains(l10n.tsMonthlyRow));
      expect(p.amount, isNull);
      expect(jsonEncode(p.rows), isNot(contains('5,000')), reason: 'the fee shows once, under the rows');
    });

    test('names the unit, the fee and the dates, and says the fee is charged once', () async {
      final p = timesheetPaper(await monthly(), workers: false, priced: true, l10n: l10n);
      expect(p.monthly.single, contains(l10n.basisMonthFixed));
      expect(p.monthly.single, contains('AED 5,000.00'));
      expect(p.monthly.single, contains('05-10-2020'));
      expect(p.monthly.single, contains('aik dafa'));
    });

    test('hours only hides the fee and keeps the unit and dates', () async {
      final p = timesheetPaper(await monthly(), workers: false, priced: false, l10n: l10n);
      expect(p.monthly.single, contains(l10n.basisMonthFixed));
      expect(p.monthly.single, isNot(contains('5,000')));
    });
  });

  group('the issued paper (DOC-05, TS-07)', () {
    test('all four ways share a number and are each kept, and asking again gives the same one', () async {
      await work(db, '2020-10-05');
      final v = await db.timesheetView(await approved());
      final daily = await issue(v);
      final dailyPriced = await issue(v, priced: true);
      final detail = await issue(v, workers: true);
      final detailPriced = await issue(v, workers: true, priced: true);
      expect({daily.number, dailyPriced.number, detail.number, detailPriced.number}, {v.sheet.number});
      expect({daily.id, dailyPriced.id, detail.id, detailPriced.id}, hasLength(4));
      expect((await issue(v)).id, daily.id);
      expect(await db.select(db.issuedDocuments).get(), hasLength(4));
    });

    test('a later letterhead does not reach a revision already issued, and a new revision says R2', () async {
      await work(db, '2020-10-05');
      final id = await approved();
      final first = await issue(await db.timesheetView(id));
      await db.saveRow(db.tenantProfiles, id: (await db.select(db.tenantProfiles).getSingle()).id, operationId: newUuid(), fields: const TenantProfilesCompanion(legalName: Value('New Name LLC')));
      expect((await issue(await db.timesheetView(id))).pdfBytes, first.pdfBytes);
      await db.startTimesheetRevision(id, reason: 'Again', operationId: newUuid());
      await db.approveTimesheet((await db.timesheetView(id)).revision.id, operationId: newUuid());
      final second = await issue(await db.timesheetView(id));
      expect(second.number, '${first.number} R2');
      expect(second.identityJson, contains('New Name LLC'));
      expect(first.identityJson, isNot(contains('New Name LLC')));
    });

    test('what is stored draws again as the same pages', () async {
      await work(db, '2020-10-05');
      final doc = await issue(await db.timesheetView(await approved()), workers: true, priced: true);
      final again = await timesheetPdf(TimesheetPaper.fromJson(jsonDecode(doc.dataJson) as Map<String, Object?>), await db.identityOf(doc), DocumentMeta.fromJson(jsonDecode(doc.metaJson) as Map<String, Object?>), regularFont: regular, boldFont: bold);
      expect(pagesOf(again), pagesOf(doc.pdfBytes));
    });

    test('a long paper runs over pages, past a slice of rows, with no blank last page', () async {
      final people = [
        for (var i = 0; i < 40; i++) await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: WorkersCompanion(code: Value('L$i'), name: Value('A very long worker name that keeps on going number $i'))),
      ];
      for (final w in people) {
        await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(w), basis: Value(RateBasis.day.name), rateFils: const Value(9000), effectiveFrom: const Value('2020-01-01')));
      }
      for (var day = 1; day <= 26; day++) {
        await db.saveAttendanceBatch(workDate: '2020-10-${day.toString().padLeft(2, '0')}', clientId: emaar, siteId: marina, inputs: [for (final w in people) EntryInput(workerId: w, shift: shift)], operationId: newUuid());
      }
      final doc = await issue(await db.timesheetView(await approved()), workers: true, priced: true);
      final pages = pagesOf(doc.pdfBytes);
      expect(pages, greaterThan(10));
      expect(pages, lessThan(120));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('what is stored survives the trip to the isolate and back', () async {
      await work(db, '2020-10-05');
      final p = timesheetPaper(await db.timesheetView(await approved()), workers: true, priced: true, l10n: l10n);
      final back = TimesheetPaper.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(jsonEncode(back.toJson()), jsonEncode(p.toJson()));
    });
  });

  testWidgets('from a company and dates to an accepted timesheet and a new revision, through the screens', (tester) async {
    final app = memoryDb();
    final last = addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1);
    await real(tester, () async {
      await seed(app);
      await work(app, '$last-05');
      await work(app, '$last-05', worker: bilal);
    });
    final words = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await pumpApp(tester, app);

    await goTo(tester, words.tsTab);
    expect(find.text(words.tsEmpty), findsOneWidget);
    await tester.tap(find.text(words.tsNew));
    await settle(tester);

    // Nothing can be made until a company says what would go on it.
    await tester.tap(find.text(words.tsCreate));
    await settle(tester);
    expect(find.text(words.tsNew), findsWidgets);
    await tester.tap(find.text(words.colCompany));
    await settle(tester);
    await tester.tap(find.text('Emaar').last);
    await settle(tester);
    expect(find.text(words.tsWillHold(2)), findsOneWidget);
    await tester.tap(find.text(words.tsCreate));
    await settle(tester);

    // A draft: one row on the daily summary, nothing frozen yet.
    expect(find.textContaining(words.tsDraftNote), findsOneWidget);
    expect(find.text('${words.tsPeople(2)}, 18:00 ghante\nAED 15.00, ${words.basisHour}'), findsOneWidget);
    expect((await real(tester, () => app.select(app.attendanceEntries).get())).every((e) => e.state == 'submitted'), isTrue);

    // Agreeing eight hours for one worker changes the company's side.
    await tester.tap(find.text(words.tsViewWorkers));
    await settle(tester);
    await tester.tap(find.text('Asif (W1)'));
    await settle(tester);
    expect(find.text(words.tsAdjustHelp), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, words.tsAdjustHours), '8');
    await tester.enterText(find.widgetWithText(TextFormField, words.tsAdjustReason), 'Site says eight hours');
    await tester.tap(find.text(words.tsAdjustSave));
    await settle(tester);
    expect(find.textContaining(words.tsAgreedRow('Site says eight hours')), findsOneWidget);
    expect(find.text('AED 120.00'), findsOneWidget);

    // Approving freezes the attendance and gives the number.
    await tester.tap(find.text(words.tsApprove));
    await settle(tester);
    expect(find.text(words.tsApproveBody), findsOneWidget);
    await tester.tap(find.text(words.tsApprove).last);
    await settle(tester);
    final year = dubaiToday(DateTime.now()).substring(0, 4);
    expect(find.text('TS-$year-0001'), findsOneWidget);
    expect((await real(tester, () => app.select(app.attendanceEntries).get())).every((e) => e.state == 'approved'), isTrue);

    // The paper starts with hours only, and a wage is never on offer.
    await tester.tap(find.text(words.tsPaper));
    await settle(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    expect(find.text(words.tsPaperPricedHelp), findsOneWidget);
    Navigator.of(tester.element(find.text(words.tsPaperPriced))).pop();
    await settle(tester);

    // Sent, then accepted and locked.
    await tester.tap(find.text(words.tsShared));
    await settle(tester);
    expect(find.textContaining(words.tsNoteShared), findsOneWidget);
    await tester.tap(find.text(words.tsAccepted));
    await settle(tester);
    expect(find.text(words.tsEvidenceNote), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, words.tsRespondNote), 'Manager agreed');
    await tester.tap(find.text(words.tsAdjustSave));
    await settle(tester);
    expect(find.text(words.tsStatusAccepted), findsOneWidget);
    expect(find.text('Manager agreed'), findsOneWidget);

    // A new revision leaves the old one on record.
    await tester.tap(find.text(words.tsNewRevision));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), 'Company asked again');
    await tester.tap(find.text(words.tsRevisionConfirm));
    await settle(tester);
    expect(find.textContaining(words.tsRevisedBecause('Company asked again')), findsOneWidget);
    expect(find.text(words.tsRevisionLabel(2)), findsOneWidget);
    await tester.tap(find.text(words.tsRevisionLabel(1)));
    await settle(tester);
    expect(find.text(words.tsOldRevisionNote), findsOneWidget);
    expect(find.text(words.tsStatusAccepted), findsWidgets);
    Navigator.of(tester.element(find.text(words.tsOldRevisionNote))).pop();
    await settle(tester);

    // Throwing the new draft away goes back to the accepted one.
    await tester.tap(find.text(words.tsDeleteDraft));
    await settle(tester);
    expect(find.text(words.tsStatusAccepted), findsOneWidget);
    await shutDown(tester, app);
  });
}
