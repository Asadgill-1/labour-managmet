import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/calc.dart';
import 'package:domain/cash.dart';
import 'package:domain/payroll.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/attendance.dart';
import 'package:labour_app/data/cash.dart';
import 'package:labour_app/data/documents.dart';
import 'package:labour_app/data/masters.dart';
import 'package:labour_app/data/payroll.dart';
import 'package:labour_app/data/statement.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/documents/document_frame.dart';
import 'package:labour_app/features/documents/receipt.dart';
import 'package:labour_app/features/payroll/salary_slip.dart';
import 'package:labour_app/features/registers/register_export.dart';
import 'package:labour_app/features/registers/register_model.dart';
import 'package:labour_app/features/registers/register_pdf.dart';
import 'package:labour_app/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'support.dart';

/// A smallest real PNG, 1 x 1.
final png1 = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// A PNG header that claims a size, for checking what is read and how sharp it would print.
Uint8List pngOf(int width, int height) {
  final b = Uint8List.fromList(png1);
  ByteData.sublistView(b).setUint32(16, width);
  ByteData.sublistView(b).setUint32(20, height);
  return b;
}

Uint8List jpegOf(int width, int height) {
  final b = BytesBuilder()
    ..add([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00])
    ..add([0xFF, 0xC0, 0x00, 0x11, 0x08])
    ..add([height >> 8, height & 255, width >> 8, width & 255])
    ..add(List.filled(12, 0));
  return b.toBytes();
}

final regular = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
final bold = File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync();

const meta = DocumentMeta(title: 'Salary slip', subtitle: '10-2026', number: 'SLIP-2026-0001', dateLabel: '02-11-2026', pagePattern: 'Page {page} of {pages}', madeLabel: 'Made 02-11-2026');

int pagesOf(List<int> bytes) => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length;

Future<Uint8List> pageWith(DocumentIdentity identity, {int rows = 3, DocumentMeta frame = meta}) {
  final doc = pw.Document();
  doc.addPage(
    documentPage(
      identity: identity,
      meta: frame,
      format: PdfPageFormat.a4,
      regularFont: regular,
      boldFont: bold,
      build: (_) => [
        pw.Table(
          border: docTableBorder,
          children: [
            pw.TableRow(repeat: true, decoration: docHeadDecoration, children: [docCell('Date', bold: true), docCell('Amount', bold: true)]),
            for (var r = 0; r < rows; r++) pw.TableRow(children: [docCell('Row $r'), docCell('999,999,999.00', align: pw.Alignment.topRight)]),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

void main() {
  late TenantDatabase db;
  late String asif;
  late String emaar;
  late String marina;
  late AppLocalizations l10n;
  const october = '2026-10';

  ExportText text() => ExportText(
    company: 'Test Labour LLC',
    title: l10n.slipTitle,
    filterLine: october,
    totalLabel: 'Total',
    madeLabel: 'Made',
    pagePattern: '{page}/{pages}',
    rollupSheet: 'Sums',
    clientNames: {emaar: 'Emaar'},
    siteNames: {marina: 'Marina'},
  );

  Future<SlipContent> slip() async => slipContent((await db.statementsFor(october, workerId: asif)).single, l10n, text());

  Future<IssuedDocument> issue(Map<String, Object?> data, {DocKind kind = DocKind.payslip, String? subject, String? period = october}) async {
    final identity = await db.currentIdentity(brandArgb: 0xFF0B2648, softArgb: 0xFFE0EEFF);
    return db.issueDocument(
      kind: kind,
      subjectId: subject ?? asif,
      period: period,
      title: 'Salary slip',
      summary: 'Asif Khan',
      data: data,
      identity: identity,
      metaFor: (number) => DocumentMeta(title: 'Salary slip', number: number, pagePattern: '{page}/{pages}', madeLabel: 'Made'),
      render: (m) => slipPdf(SlipContent.fromJson(data), identity, m, regularFont: regular, boldFont: bold),
      operationId: newUuid(),
    );
  }

  setUp(() async {
    db = memoryDb();
    l10n = await AppLocalizations.delegate.load(const Locale('en', 'PK'));
    await seedProfile(db);
    asif = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W1'), name: Value('Asif Khan'), trade: Value('Helper')));
    emaar = await db.saveRow(db.clients, id: null, operationId: newUuid(), fields: const ClientsCompanion(name: Value('Emaar')));
    marina = await db.saveRow(db.sites, id: null, operationId: newUuid(), fields: SitesCompanion(clientId: Value(emaar), name: const Value('Marina')));
    await db.saveRow(db.payContracts, id: null, operationId: newUuid(), fields: PayContractsCompanion(workerId: Value(asif), basis: Value(RateBasis.hour.name), rateFils: const Value(1000), effectiveFrom: const Value('2020-01-01')));
    for (final day in const ['05', '06']) {
      await db.saveAttendanceBatch(workDate: '2026-10-$day', clientId: emaar, siteId: marina, inputs: [EntryInput(workerId: asif, shift: const ShiftInput(startMinute: 480, endMinute: 1080, breakMinutes: 60))], operationId: newUuid());
    }
    await db.addCashEntry(operationId: newUuid(), date: '2026-10-08', kind: CashKind.advanceGiven, amountFils: 2000, workerId: asif);
    await db.savePayItem(id: null, workerId: asif, month: october, kind: PayItemKind.deduction, amountFils: 500, reason: 'Helmet', authorizedBy: 'Asif', note: null, roomId: null, operationId: newUuid());
  });

  tearDown(() => db.close());

  group('images (DOC-04)', () {
    test('type comes from the bytes, and size is read from them', () {
      final facts = readImageFacts(pngOf(2400, 600))!;
      expect((facts.mime, facts.width, facts.height), ('image/png', 2400, 600));
      final jpeg = readImageFacts(jpegOf(1600, 400))!;
      expect((jpeg.mime, jpeg.width, jpeg.height), ('image/jpeg', 1600, 400));
      expect(readImageFacts(Uint8List.fromList(utf8.encode('%PDF-1.7 pretending to be an image.......'))), isNull);
      expect(checkImage(Uint8List.fromList(utf8.encode('GIF89a..............................'))), ImageProblem.notPngOrJpeg);
    });

    test('too large is refused, and nothing is stored', () async {
      final big = Uint8List(maxImageBytes + 1)..setAll(0, png1);
      expect(checkImage(big), ImageProblem.tooLarge);
      await expectLater(db.saveDocumentImage(AssetKind.header, big, operationId: newUuid()), throwsA(isA<ImageRejected>()));
      expect(await db.select(db.documentAssets).get(), isEmpty);
    });

    test('a small image on a wide page is low resolution, and shrinking it helps', () {
      final image = DocumentImage(assetId: 'a', bytes: png1, width: 600, height: 150);
      expect(image.printDpi(539), lessThan(lowDpi));
      final smaller = DocumentImage(assetId: 'a', bytes: png1, width: 600, height: 150, placement: const Placement(scalePct: 40));
      expect(smaller.printDpi(539), greaterThanOrEqualTo(lowDpi));
      final trimmed = DocumentImage(assetId: 'a', bytes: png1, width: 2000, height: 500, placement: const Placement(cropLeft: 25, cropRight: 25));
      expect(trimmed.printDpi(539), closeTo(1000 / (539 / 72), 1));
    });

    test('the bytes stay out of the audit log and the outbox', () async {
      await db.saveDocumentImage(AssetKind.logo, png1, operationId: newUuid());
      final audit = await db.select(db.auditEvents).get();
      expect(audit.map((a) => a.toJson().toString()).join(), isNot(contains(base64Encode(png1))));
      expect((await db.documentTemplate())!.logoAssetId, isNotNull);
    });
  });

  group('the frame on every paper (DOC-01 to DOC-03, DOC-08)', () {
    test('one short page has no blank page after it, and text is real text', () async {
      final bytes = await pageWith(const DocumentIdentity(legalName: 'Al Noor Labour Supply LLC', contactLine: 'Dubai'));
      expect(pagesOf(bytes), 1);
      final raw = latin1.decode(bytes);
      expect(raw, contains('/Font'), reason: 'text is drawn with a font, not a picture of a page');
      expect(RegExp(r'/Subtype\s*/Image').allMatches(raw), isEmpty);
    });

    test('a long table runs over pages, repeating its headings, with no blank last page', () async {
      final bytes = await pageWith(const DocumentIdentity(legalName: 'Al Noor Labour Supply LLC'), rows: 200);
      final pages = pagesOf(bytes);
      expect(pages, greaterThan(2));
      final one = await pageWith(const DocumentIdentity(legalName: 'Al Noor Labour Supply LLC'), rows: 200);
      expect(pagesOf(one), pages, reason: 'same rows, same pages');
    });

    test('long names, large amounts and every image still fit: the header takes its own height, so rows move down rather than under it', () async {
      final long = 'A very long legal company name that goes on and on Trading and General Contracting Limited Liability Company ' * 3;
      final wide = DocumentImage(assetId: 'h', bytes: png1, width: 1, height: 1, placement: const Placement());
      final plain = pagesOf(await pageWith(DocumentIdentity(legalName: long), rows: 40));
      final tall = pagesOf(await pageWith(DocumentIdentity(legalName: long, header: wide, footer: wide), rows: 40));
      expect(tall, greaterThan(plain), reason: 'a tall letterhead pushes rows to more pages instead of covering them');
    });

    test('pre-printed paper leaves its space clear and prints none of the company, only the paper itself', () async {
      final blank = await pageWith(const DocumentIdentity(legalName: 'CompanyNameHere', printLetterhead: false, blankTopMm: 100, blankBottomMm: 80), rows: 90);
      final full = await pageWith(const DocumentIdentity(legalName: 'CompanyNameHere'), rows: 90);
      expect(pagesOf(blank), greaterThan(pagesOf(full)), reason: 'the blank space comes off every page');
    });

    test('a register uses the same frame, with no number', () async {
      final columns = [const RegisterColumn('Name', kind: CellKind.text, flex: 3), const RegisterColumn('Paid', kind: CellKind.money, total: true)];
      final bytes = await registerPdf(
        identity: const DocumentIdentity(legalName: 'Test'),
        meta: const DocumentMeta(title: 'Register', pagePattern: '{page}/{pages}', madeLabel: 'Made'),
        columns: columns,
        entries: [RegisterEntry(const ['Asif', 1000], group: '')],
        totalLabel: 'Total',
        regularFont: regular,
        boldFont: bold,
      );
      expect(pagesOf(bytes), 1);
    });
  });

  group('the slip (PAY-09)', () {
    test('earnings on what basis, each deduction, this month, what came before, and what was paid stay apart', () async {
      final s = await slip();
      expect(s.earnings.lines.first.$1, l10n.slipWorkBasis(2, '18:00'));
      expect(s.earnings.total, '180.00');
      expect(s.deductions.lines, contains((l10n.slipAdvance, '-20.00')));
      expect(s.deductions.lines, contains(('Helmet', '-5.00')));
      expect(s.deductions.total, '-25.00');
      expect(s.account.lines.first, (l10n.slipNet, '155.00'));
      expect(s.account.lines[1], (l10n.slipOpening, '-'));
      expect(s.account.lines[2], (l10n.slipPaid, '-'));
      expect(s.closingLabel, l10n.slipOwedToYou);
      expect(s.closingAmount, 'AED 155.00');
      expect(s.notes.join(' '), contains(l10n.slipNote));
    });

    test('what it says survives being stored', () async {
      final s = await slip();
      final back = SlipContent.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
    });
  });

  group('an issued paper stays as it went out (DOC-05)', () {
    test('asking again with nothing changed gives the same paper, number and file', () async {
      final s = (await slip()).toJson();
      final first = await issue(s);
      expect(first.number, 'SLIP-${first.year}-0001');
      final again = await issue((await slip()).toJson());
      expect(again.id, first.id);
      expect(await db.select(db.issuedDocuments).get(), hasLength(1));
    });

    test('a changed figure is a new revision with the same number, and the old file stays', () async {
      final first = await issue((await slip()).toJson());
      await db.addSalaryPayment(operationId: newUuid(), date: '2026-10-20', workerId: asif, amountFils: 5000, parts: {october: 5000}, extraNote: 'x');
      final second = await issue((await slip()).toJson());
      expect(second.seq, first.seq);
      expect(second.revision, 2);
      expect(second.number, '${first.number} R2');
      expect((await db.issuedDocument(first.id)).pdfBytes, first.pdfBytes);
      expect((await db.select(db.issuedDocuments).get()), hasLength(2));
    });

    test('another worker takes the next number', () async {
      final imran = await db.saveRow(db.workers, id: null, operationId: newUuid(), fields: const WorkersCompanion(code: Value('W2'), name: Value('Imran')));
      final first = await issue((await slip()).toJson());
      final second = await issue((await slip()).toJson(), subject: imran);
      expect(second.seq, first.seq + 1);
      expect(second.revision, 1);
    });

    test('a new logo or address never touches an old paper, and a later one gets a revision', () async {
      final first = await issue((await slip()).toJson());
      await db.saveDocumentImage(AssetKind.logo, png1, operationId: newUuid());
      final profile = await db.select(db.tenantProfiles).getSingle();
      await db.saveRow(db.tenantProfiles, id: profile.id, operationId: newUuid(), fields: const TenantProfilesCompanion(address: Value('New address')));

      final stored = await db.issuedDocument(first.id);
      expect(stored.pdfBytes, first.pdfBytes);
      final identity = await db.identityOf(stored);
      expect(identity.logo, isNull, reason: 'as it was issued');
      expect(identity.contactLine, isNot(contains('New address')));

      final later = await issue((await slip()).toJson());
      expect(later.revision, 2);
      expect((await db.identityOf(later)).contactLine, contains('New address'));
      expect((await db.identityOf(later)).logo, isNotNull);
    });

    test('an old image is still found after it is replaced or removed', () async {
      final oldId = await db.saveDocumentImage(AssetKind.logo, png1, operationId: newUuid());
      final first = await issue((await slip()).toJson());
      await db.setDocumentImage(AssetKind.logo, null, operationId: newUuid());
      final identity = await db.identityOf(first);
      expect(identity.logo?.assetId, oldId);
      expect(identity.logo?.bytes, png1);
    });

    test('changing the app colour alone is not a new paper', () async {
      final data = (await slip()).toJson();
      final first = await issue(data);
      final identity = await db.currentIdentity(brandArgb: 0xFF00301B, softArgb: 0xFFDDF3E6);
      final again = await db.issueDocument(
        kind: DocKind.payslip,
        subjectId: asif,
        period: october,
        title: 'Salary slip',
        summary: 'Asif Khan',
        data: data,
        identity: identity,
        metaFor: (number) => DocumentMeta(title: 'Salary slip', number: number, pagePattern: '{page}/{pages}', madeLabel: 'Made'),
        render: (m) async => Uint8List(0),
        operationId: newUuid(),
      );
      expect(again.id, first.id);
    });

    test('the database refuses to change or delete a paper, or an image a paper may use', () async {
      final doc = await issue((await slip()).toJson());
      await expectLater((db.update(db.issuedDocuments)..where((d) => d.id.equals(doc.id))).write(const IssuedDocumentsCompanion(summary: Value('x'))), throwsA(anything));
      await expectLater(db.delete(db.issuedDocuments).go(), throwsA(anything));
      await db.saveDocumentImage(AssetKind.logo, png1, operationId: newUuid());
      await expectLater(db.delete(db.documentAssets).go(), throwsA(anything));
    });

    test('a copy is the same number with COPY on it, drawn from what was stored', () async {
      final first = await issue((await slip()).toJson());
      await db.saveDocumentImage(AssetKind.logo, png1, operationId: newUuid());
      final stored = await db.issuedDocument(first.id);
      final copyMeta = DocumentMeta.fromJson(jsonDecode(stored.metaJson) as Map<String, Object?>, copyLabel: 'COPY');
      expect(copyMeta.number, first.number);
      final copy = await slipPdf(SlipContent.fromJson(jsonDecode(stored.dataJson) as Map<String, Object?>), await db.identityOf(stored), copyMeta, regularFont: regular, boldFont: bold);
      expect(copy.length, isNot(first.pdfBytes.length));
      expect(pagesOf(copy), pagesOf(first.pdfBytes));
    });

    test('the audit log holds the facts and never the file', () async {
      await issue((await slip()).toJson());
      final audit = (await db.select(db.auditEvents).get()).where((a) => a.action == 'issue').single;
      expect(audit.toJson().toString(), isNot(contains('%PDF')));
    });
  });

  group('a receipt (DOC-01)', () {
    test('a salary receipt says what it settled, and that it is the company\'s record', () async {
      await db.addSalaryPayment(operationId: newUuid(), date: '2026-10-20', workerId: asif, amountFils: 5000, parts: {october: 5000}, extraNote: 'x', reference: 'CHQ 12', receiver: 'Asif');
      final entry = (await db.select(db.cashEntries).get()).firstWhere((c) => c.kind == CashKind.salaryPaid.name);
      final worker = await (db.select(db.workers)..where((w) => w.id.equals(asif))).getSingle();
      final parts = await db.select(db.salaryAllocations).get();
      final r = receiptContent(entry, worker, parts, l10n);
      expect(r.party, 'Asif Khan (W1)');
      expect(r.amount, 'AED 50.00');
      expect(r.lines, contains((l10n.receiptReference, 'CHQ 12')));
      expect(r.lines, contains((l10n.receiptMonth('10-2026'), '50.00')));
      expect(r.notes.first, l10n.receiptNote);
      final back = ReceiptContent.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      final bytes = await receiptPdf(back, const DocumentIdentity(legalName: 'Test'), meta, regularFont: regular, boldFont: bold);
      expect(pagesOf(bytes), 1);
    });

    test('an advance gets its own series, and the same receipt comes back the same', () async {
      await db.addCashEntry(operationId: newUuid(), date: '2026-10-09', kind: CashKind.advanceGiven, amountFils: 1500, workerId: asif, note: 'Rent');
      final entry = (await db.select(db.cashEntries).get()).firstWhere((c) => c.amountFils == 1500);
      final worker = await (db.select(db.workers)..where((w) => w.id.equals(asif))).getSingle();
      final content = receiptContent(entry, worker, const [], l10n);
      expect(content.amountLabel, l10n.receiptAdvance);
      expect(content.lines, contains((l10n.note, 'Rent')));
      Future<IssuedDocument> make() async {
        final identity = await db.currentIdentity(brandArgb: 0xFF0B2648, softArgb: 0xFFE0EEFF);
        return db.issueDocument(
          kind: DocKind.advanceReceipt,
          subjectId: entry.id,
          period: null,
          title: 'Advance',
          summary: 'Asif Khan',
          data: content.toJson(),
          identity: identity,
          metaFor: (number) => DocumentMeta(title: 'Advance', number: number, pagePattern: '{page}/{pages}', madeLabel: 'Made'),
          render: (m) => receiptPdf(content, identity, m, regularFont: regular, boldFont: bold),
          operationId: newUuid(),
        );
      }

      final first = await make();
      expect(first.number, startsWith('ADV-'));
      expect((await make()).id, first.id);
    });
  });

  testWidgets('the sheet names what is leaving, offers COPY only on an issued paper, and the list shows what was issued', (tester) async {
    final app = memoryDb();
    await real(tester, () => seedProfile(app));
    await pumpApp(tester, app);
    final loc = await real(tester, () => AppLocalizations.delegate.load(const Locale('en', 'PK')));
    await goTo(tester, loc.docsTab);
    expect(find.text(loc.docsEmpty), findsOneWidget);
    await goTo(tester, loc.lhTab);
    expect(find.text(loc.lhOld), findsOneWidget);
    await tester.tap(find.text(loc.lhPrinted));
    await settle(tester);
    expect(find.text(loc.lhBlankTop), findsOneWidget);
    expect((await real(tester, app.documentTemplate))!.printLetterhead, isFalse);
    expect(find.text(loc.lhLogo), findsNothing, reason: 'nothing of the company prints on pre-printed paper');
    expect(find.text(loc.lhSignature), findsOneWidget);
    await shutDown(tester, app);
  });
}
