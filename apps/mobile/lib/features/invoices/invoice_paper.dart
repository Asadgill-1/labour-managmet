import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:domain/money.dart';
import 'package:domain/timesheet.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show BuildContext, Locale, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/theme.dart';
import '../../data/documents.dart';
import '../../data/invoices.dart';
import '../../data/tenant_database.dart';
import '../../data/timesheets.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../documents/document_render.dart';
import '../rates/rate_labels.dart';
import '../registers/register_model.dart';
import '../timesheets/timesheet_paper.dart';

/// An invoice is in English whatever the app's language: the FTA reads a tax invoice in English or Arabic, and Roman
/// Urdu is neither.
final paperWords = lookupAppLocalizations(const Locale('en'));

/// The paper's title, which says "Tax" only when the FTA's rules say so (INV-02).
String invoiceTitle(AppLocalizations words, InvoiceView v) => switch ((v.isCreditNote, v.taxInvoice)) {
  (false, true) => words.invPTaxInvoice,
  (false, false) => words.invPInvoice,
  (true, true) => words.invPTaxCreditNote,
  (true, false) => words.invPCreditNote,
};

/// How a line is worded on the paper, and stored as it was printed.
String invoiceLineText(AppLocalizations words, InvoiceLineView l) {
  if (l.isItem) return l.description!;
  final dates = l.fromDate == null ? null : words.dateFromTo(showDate(l.fromDate!), showDate(l.toDate!));
  // A monthly contract amount names its month, since it covers all of it whichever days the brackets show (TS-08). A
  // fixed contract needs no more; a contract per worker says so.
  final what = l.isFee
      ? [words.invPLineFee(showMonth(l.fromDate!.substring(0, 7))), if (l.basis != RateBasis.monthFixed) basisLabel(words, l.basis!)]
      : [words.invPLineLabour, ?l.siteName, ?l.trade];
  return '${what.join(', ')} (${[?dates, ?l.timesheetNumber].join(', ')})';
}

/// The unit a line counts in. A line the owner wrote counts in nothing named.
String unitText(AppLocalizations words, RateBasis? basis) => switch (basis) {
  null => '',
  RateBasis.hour => words.invPUnitHour,
  RateBasis.day => words.invPUnitDay,
  RateBasis.shift => words.invPUnitShift,
  RateBasis.monthFixed => words.invPUnitMonth,
  RateBasis.month || RateBasis.monthPerWorker => words.invPUnitWorkerMonth,
};

/// A line's quantity on screen, in the app's language.
String quantityLabel(AppLocalizations l10n, InvoiceLineView l) {
  final basis = l.basis;
  if (basis == null) return l10n.invItemQuantity(l.quantity, formatAed(l.unitPriceFils));
  return switch (basis) {
    RateBasis.hour => billableText(l10n, basis, TsUnits(minutes: l.quantity)),
    RateBasis.day => billableText(l10n, basis, TsUnits(dayHalves: l.quantity)),
    RateBasis.shift => billableText(l10n, basis, TsUnits(shiftHalves: l.quantity)),
    RateBasis.monthFixed => basisLabel(l10n, basis),
    RateBasis.month || RateBasis.monthPerWorker => '${basisLabel(l10n, basis)}, ${l10n.tsPeople(l.quantity)}',
  };
}

String _categoryText(AppLocalizations words, VatCategory c) => switch (c) {
  VatCategory.standard => '',
  VatCategory.zeroRated => words.invPZeroRated,
  VatCategory.exempt => words.invPExempt,
  VatCategory.outOfScope => words.invPOutOfScope,
};

/// 500 -> "5%", without a fraction in sight.
String vatPercent(int bps) => '${bps ~/ 100}${bps % 100 == 0 ? '' : '.${(bps % 100).toString().padLeft(2, '0')}'}%';

/// What one invoice or credit note says. Plain text, so it can be stored with the paper and cross to a background
/// isolate (DOC-05).
class InvoicePaper {
  const InvoicePaper({
    required this.billTo,
    required this.customer,
    required this.customerLines,
    required this.details,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.bottomLabel,
    required this.bottomAmount,
    required this.notes,
    required this.bankLabel,
    required this.bank,
    required this.receiverLabel,
  });

  factory InvoicePaper.fromJson(Map<String, Object?> j) => InvoicePaper(
    billTo: j['billTo'] as String,
    customer: j['customer'] as String,
    customerLines: (j['customerLines'] as List).cast<String>(),
    details: [for (final d in j['details'] as List) ((d as List)[0] as String, d[1] as String)],
    columns: [for (final c in j['columns'] as List) ((c as List)[0] as String, c[1] as int, c[2] as bool)],
    rows: [for (final r in j['rows'] as List) (r as List).cast<String>()],
    totals: [for (final t in j['totals'] as List) ((t as List)[0] as String, t[1] as String)],
    bottomLabel: j['bottomLabel'] as String,
    bottomAmount: j['bottomAmount'] as String,
    notes: (j['notes'] as List).cast<String>(),
    bankLabel: j['bankLabel'] as String,
    bank: j['bank'] as String?,
    receiverLabel: j['receiverLabel'] as String,
  );

  final String billTo;
  final String customer;
  final List<String> customerLines;
  final List<(String, String)> details;

  /// Heading, share of the width, and whether its figures sit on the right.
  final List<(String, int, bool)> columns;
  final List<List<String>> rows;
  final List<(String, String)> totals;
  final String bottomLabel;
  final String bottomAmount;
  final List<String> notes;
  final String bankLabel;
  final String? bank;
  final String receiverLabel;

  Map<String, Object?> toJson() => {
    'billTo': billTo,
    'customer': customer,
    'customerLines': customerLines,
    'details': [for (final d in details) [d.$1, d.$2]],
    'columns': [for (final c in columns) [c.$1, c.$2, c.$3]],
    'rows': rows,
    'totals': [for (final t in totals) [t.$1, t.$2]],
    'bottomLabel': bottomLabel,
    'bottomAmount': bottomAmount,
    'notes': notes,
    'bankLabel': bankLabel,
    'bank': bank,
    'receiverLabel': receiverLabel,
  };
}

/// INV-02's fields, in English. A draft's lines are worded as they would be issued.
InvoicePaper invoicePaper(InvoiceView v, AppLocalizations words) {
  final p = v.parties;
  final vat = v.vatRegistered;
  final discounts = v.lines.any((l) => l.discountFils > 0);
  final inv = v.invoice;
  final timesheets = {for (final l in v.lines) ?l.timesheetNumber};
  final columns = <(String, int, bool)>[
    (words.invPColNo, 1, false),
    (words.invPColDescription, 9, false),
    (words.invPColQty, 2, true),
    (words.invPColUnit, 2, false),
    (words.invPColRate, 3, true),
    if (discounts) (words.invPColDiscount, 3, true),
    (vat ? words.invPColNet : words.invPColAmount, 3, true),
    if (vat) ...[(words.invPColVatRate, 2, true), (words.invPColVat, 3, true), (words.invPColTotal, 3, true)],
  ];
  return InvoicePaper(
    billTo: v.isCreditNote ? words.invPCreditTo : words.invPBillTo,
    customer: p.customerName,
    customerLines: [?p.customerAddress, if (p.customerTrn != null) 'TRN ${p.customerTrn}'],
    details: [
      if (vat && p.supplierTrn != null) (words.invPSupplierTrn, p.supplierTrn!),
      if (inv.issueDate != null) (words.invPIssueDate, showDate(inv.issueDate!)),
      (words.invPSupplyPeriod, words.dateFromTo(showDate(inv.fromDate), showDate(inv.toDate))),
      if (v.original != null) (words.invPAgainst, '${v.original!.number} ${showDate(v.original!.issueDate!)}'),
      if (!v.isCreditNote && inv.dueDate != null) (words.invPDueDate, showDate(inv.dueDate!)),
      if (inv.poReference != null) (words.invPReference, inv.poReference!),
    ],
    columns: columns,
    rows: [
      for (final (i, l) in v.lines.indexed)
        [
          '${i + 1}',
          l.description ?? invoiceLineText(words, l),
          quantityText(l.basis, l.quantity),
          unitText(words, l.basis),
          plainMoney(l.unitPriceFils),
          if (discounts) l.discountFils == 0 ? '' : plainMoney(l.discountFils),
          plainMoney(l.tax.netFils),
          if (vat) ...[vatPercent(v.bps), plainMoney(l.tax.vatFils), plainMoney(l.tax.totalFils)],
        ],
    ],
    totals: [
      if (vat) ...[(words.invPTotalNet, plainMoney(v.totals.netFils)), (words.invPTotalVat(vatPercent(v.bps)), plainMoney(v.totals.vatFils))],
    ],
    bottomLabel: v.isCreditNote ? words.invPCredited : words.invPTotal,
    bottomAmount: formatAed(v.totals.totalFils),
    notes: [
      if (vat && v.category != VatCategory.standard) _categoryText(words, v.category),
      if (inv.reason != null) words.invPReason(inv.reason!),
      if (timesheets.isNotEmpty) words.invPTimesheets(timesheets.join(', ')),
      if (inv.pricesIncludeVat && vat) words.invPInclusive,
      words.regAmountsNote,
      words.invPNotEInvoice,
    ],
    bankLabel: words.invPBank,
    bank: v.isCreditNote ? null : p.bankDetails,
    receiverLabel: words.tsClientSign(p.customerName),
  );
}

/// An invoice or credit note on A4, in the same frame as every other paper, separate from any timesheet (DOC-01, TS-07).
Future<Uint8List> invoicePdf(InvoicePaper p, DocumentIdentity identity, DocumentMeta meta, {required Uint8List regularFont, required Uint8List boldFont}) {
  final brand = PdfColor.fromInt(identity.brandArgb);
  final soft = PdfColor.fromInt(identity.softArgb);
  pw.Alignment alignOf((String, int, bool) c) => c.$3 ? pw.Alignment.topRight : pw.Alignment.topLeft;
  pw.Widget pair(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 92, child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5, color: docMuted))),
        pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, color: docInk, fontWeight: bold ? pw.FontWeight.bold : null))),
      ],
    ),
  );
  final doc = pw.Document(title: '${meta.title} ${meta.number ?? ''} ${p.customer}', author: identity.legalName, creator: identity.legalName);
  doc.addPage(
    documentPage(
      identity: identity,
      meta: meta,
      format: PdfPageFormat.a4,
      regularFont: regularFont,
      boldFont: boldFont,
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Container(
                color: soft,
                padding: const pw.EdgeInsets.all(7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(p.billTo, style: const pw.TextStyle(fontSize: 8, color: docMuted)),
                    pw.Text(p.customer, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand)),
                    for (final line in p.customerLines) pw.Text(line, style: const pw.TextStyle(fontSize: 8.5, color: docInk)),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 16),
            pw.SizedBox(width: 210, child: pw.Column(children: [for (final (label, value) in p.details) pair(label, value)])),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: docTableBorder,
          columnWidths: {for (var i = 0; i < p.columns.length; i++) i: pw.FlexColumnWidth(p.columns[i].$2.toDouble())},
          children: [
            pw.TableRow(
              repeat: true,
              decoration: docHeadDecoration,
              verticalAlignment: pw.TableCellVerticalAlignment.bottom,
              children: [for (final c in p.columns) docCell(c.$1, align: alignOf(c), bold: true, size: 7.5, vertical: 2.5)],
            ),
            for (final row in p.rows) pw.TableRow(children: [for (var i = 0; i < row.length; i++) docCell(row[i], align: alignOf(p.columns[i]), size: 8)]),
          ],
        ),
        pw.SizedBox(height: 8),
        // The totals, notes and signatures stay together, so a signature never sits alone on a page.
        pw.NewPage(freeSpace: 200),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Spacer(),
            pw.SizedBox(
              width: 240,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  for (final (label, value) in p.totals) pair(label, value),
                  pw.SizedBox(height: 3),
                  docBottomLine(p.bottomLabel, p.bottomAmount),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        for (final note in p.notes) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 2), child: pw.Text(note, style: const pw.TextStyle(fontSize: 8.5, color: docMuted))),
        if (p.bank != null) ...[docHeading(p.bankLabel, brand), pw.Text(p.bank!, style: const pw.TextStyle(fontSize: 8.5, color: docInk))],
        pw.SizedBox(height: 18),
        docSignatures(identity, companyLabel: identity.shownName, receiverLabel: p.receiverLabel),
      ],
    ),
  );
  return doc.save();
}

/// The stored paper of an issued invoice or credit note, issued now if it never was. It stays as it went out (DOC-05).
Future<IssuedDocument> issueInvoicePaper(TenantDatabase db, InvoiceView v) {
  final inv = v.invoice;
  final title = invoiceTitle(paperWords, v);
  return issuePaper(
    db,
    paperWords,
    kind: v.isCreditNote ? DocKind.creditNote : DocKind.invoice,
    subjectId: inv.id,
    period: null,
    title: title,
    subtitle: '',
    summary: '${v.parties.customerName}, ${formatAed(v.totals.totalFils)}',
    data: invoicePaper(v, paperWords).toJson(),
    fixed: (year: inv.year!, seq: inv.seq!, revision: 1),
    number: inv.number,
  );
}

String invoiceFileName(InvoiceView v) => '${v.invoice.number ?? paperWords.invPDraft} ${v.parties.customerName}.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

/// Says what is about to leave the phone, then sends, saves or shows the paper (DOC-07).
Future<void> shareInvoice(BuildContext context, WidgetRef ref, InvoiceView v, {required ValueChanged<bool> onBusy}) {
  final title = invoiceTitle(paperWords, v);
  return issueAndExport(
    context,
    ref,
    kind: v.isCreditNote ? DocKind.creditNote : DocKind.invoice,
    fixed: (year: v.invoice.year!, seq: v.invoice.seq!, revision: 1),
    number: v.invoice.number,
    words: paperWords,
    subjectId: v.invoice.id,
    period: null,
    title: title,
    subtitle: '',
    summary: '${v.invoice.number}, ${v.parties.customerName}',
    detail: formatAed(v.totals.totalFils),
    data: invoicePaper(v, paperWords).toJson(),
    fileName: invoiceFileName(v),
    onBusy: onBusy,
  );
}

/// A draft as it would print, marked as a draft and with no number, to check before issuing (INV-01).
Future<Uint8List> draftPdf(TenantDatabase db, InvoiceView v) async {
  final identity = await db.currentIdentity(brandArgb: brand.toARGB32(), softArgb: brandSoft.toARGB32());
  final meta = metaForNow(paperWords, title: invoiceTitle(paperWords, v), subtitle: paperWords.invPDraftNote);
  final marked = DocumentMeta(title: meta.title, subtitle: meta.subtitle, dateLabel: meta.dateLabel, pagePattern: meta.pagePattern, madeLabel: meta.madeLabel, copyLabel: paperWords.invPDraft);
  return renderIssued(DocKind.invoice, invoicePaper(v, paperWords).toJson(), identity, marked);
}

/// The invoice and each timesheet it charged, as files to send in one go (TS-07). A timesheet goes as it was last
/// issued for that revision, or with rates by day if it never went out.
Future<List<(String, Uint8List)>> invoiceWithTimesheets(TenantDatabase db, AppLocalizations l10n, InvoiceView v) async {
  final files = [(invoiceFileName(v), (await issueInvoicePaper(db, v)).pdfBytes)];
  const kinds = [DocKind.timesheetDaily, DocKind.timesheetDailyPriced, DocKind.timesheetWorkers, DocKind.timesheetWorkersPriced];
  for (final rev in await db.billedRevisions(v.invoice.id)) {
    final sent = await (db.select(db.issuedDocuments)
          ..where((d) => d.subjectId.equals(rev.id) & d.kind.isIn([for (final k in kinds) k.name]))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAtUtc)])
          ..limit(1))
        .getSingleOrNull();
    final view = await db.timesheetView(rev.timesheetId, revision: rev.revision);
    final doc = sent ?? await issueTimesheetPaper(db, l10n, view, workers: false, priced: true);
    files.add(('${doc.number} ${view.clientName}.pdf'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-'), doc.pdfBytes));
  }
  return files;
}
