import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/timesheet.dart';
import 'package:flutter/material.dart' show BuildContext, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/documents.dart';
import '../../data/timesheets.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../documents/document_render.dart';
import '../rates/rate_labels.dart';
import '../registers/register_export.dart';
import '../registers/register_model.dart';

/// A table walks all its rows again for every page it fills, so long papers go in slices, as registers do.
const _sliceRows = 300;

/// What one timesheet paper says. Plain text, so it can be stored with the paper and cross to a background isolate. A
/// worker's wage is not on any row this is made from, and without [priced] neither is a rate or an amount (TS-02).
class TimesheetPaper {
  const TimesheetPaper({
    required this.client,
    required this.clientLine,
    required this.period,
    required this.columns,
    required this.rows,
    required this.facts,
    required this.amountLabel,
    required this.amount,
    required this.monthly,
    required this.agreedHeading,
    required this.agreed,
    required this.notes,
    required this.clientLabel,
  });

  factory TimesheetPaper.fromJson(Map<String, Object?> j) => TimesheetPaper(
    client: j['client'] as String,
    clientLine: j['clientLine'] as String,
    period: j['period'] as String,
    columns: [for (final c in j['columns'] as List) ((c as List)[0] as String, c[1] as int, c[2] as bool)],
    rows: [for (final r in j['rows'] as List) (r as List).cast<String>()],
    facts: [for (final f in j['facts'] as List) ((f as List)[0] as String, f[1] as String)],
    amountLabel: j['amountLabel'] as String?,
    amount: j['amount'] as String?,
    monthly: (j['monthly'] as List).cast<String>(),
    agreedHeading: j['agreedHeading'] as String,
    agreed: (j['agreed'] as List).cast<String>(),
    notes: (j['notes'] as List).cast<String>(),
    clientLabel: j['clientLabel'] as String,
  );

  final String client;
  final String clientLine;
  final String period;

  /// Heading, share of the width, and whether its figures sit on the right.
  final List<(String, int, bool)> columns;
  final List<List<String>> rows;

  /// The totals, each under its own name. Hours, days and shifts are never added together (TS-03).
  final List<(String, String)> facts;
  final String? amountLabel;
  final String? amount;

  /// Each monthly contract's unit and the dates it covers (TS-08).
  final List<String> monthly;
  final String agreedHeading;
  final List<String> agreed;
  final List<String> notes;
  final String clientLabel;

  Map<String, Object?> toJson() => {
    'client': client,
    'clientLine': clientLine,
    'period': period,
    'columns': [for (final c in columns) [c.$1, c.$2, c.$3]],
    'rows': rows,
    'facts': [for (final f in facts) [f.$1, f.$2]],
    'amountLabel': amountLabel,
    'amount': amount,
    'monthly': monthly,
    'agreedHeading': agreedHeading,
    'agreed': agreed,
    'notes': notes,
    'clientLabel': clientLabel,
  };
}

/// How much a line or day's row bills, in its own unit.
String billableText(AppLocalizations l10n, RateBasis basis, TsUnits units) => switch (basis) {
  RateBasis.hour => l10n.tsHoursValue(showDuration(units.minutes)),
  RateBasis.day => l10n.tsDaysValue(showHalves(units.dayHalves)),
  RateBasis.shift => l10n.tsShiftsValue(showHalves(units.shiftHalves)),
  RateBasis.month || RateBasis.monthPerWorker || RateBasis.monthFixed => l10n.tsMonthlyRow,
};

/// The names and figures of a timesheet's totals. A unit nobody billed in isn't mentioned.
List<(String, String)> timesheetFacts(TsTotals t, AppLocalizations l10n) => [
  (l10n.tsUniqueWorkers, '${t.uniqueWorkers}'),
  (l10n.tsWorkerDays, '${t.workerDays}'),
  if (t.shifts != t.workerDays) (l10n.tsShiftsWorked, '${t.shifts}'),
  if (t.units.minutes > 0) (l10n.tsHoursBilled, showDuration(t.units.minutes)),
  if (t.units.dayHalves > 0) (l10n.tsDaysBilled, showHalves(t.units.dayHalves)),
  if (t.units.shiftHalves > 0) (l10n.tsShiftsBilled, showHalves(t.units.shiftHalves)),
];

TimesheetPaper timesheetPaper(TimesheetView v, {required bool workers, required bool priced, required AppLocalizations l10n}) {
  final trades = v.lines.any((l) => l.trade != null);
  final moreShifts = v.daily.any((d) => d.shifts != d.persons);
  String amountOf(int? fils) => fils == null ? '-' : plainMoney(fils);

  // A monthly fee shows once, under the rows, so no row reads as charging it again (TS-08).
  String rateOf(RateBasis basis, int fils) => isPeriodBasis(basis) ? basisLabel(l10n, basis) : rateSummary(l10n, basis.name, fils);

  final columns = <(String, int, bool)>[
    (l10n.colDate, 3, false),
    (l10n.colSite, 5, false),
    if (workers) ...[(l10n.colWorker, 6, false), (l10n.colCode, 2, false)],
    if (trades) (l10n.colTrade, 3, false),
    if (!workers) ...[(l10n.colPersons, 2, true), if (moreShifts) (l10n.colShifts, 2, true)],
    (l10n.colClock, 2, true),
    (l10n.colBreak, 2, true),
    (l10n.colBillable, 3, true),
    if (priced) ...[(l10n.colRate, 5, true), (l10n.tsAmount, 3, true)],
  ];
  final rows = workers
      ? [
          for (final r in v.rows)
            [
              showDate(r.line.workDate),
              r.siteName,
              r.workerName,
              r.workerCode,
              if (trades) r.line.trade ?? '',
              showDuration(r.line.clockMinutes),
              showDuration(r.line.breakMinutes),
              '${r.line.status == AttendanceStatus.absent ? l10n.tsNotCharged : billableText(l10n, r.line.basis, unitsOf(r.line))}${r.adjustReason == null ? '' : ' *'}',
              if (priced) ...[rateOf(r.line.basis, r.line.rateFils), amountOf(r.line.amountFils)],
            ],
        ]
      : [
          for (final d in v.daily)
            [
              showDate(d.workDate),
              v.siteNames[d.siteId] ?? '',
              if (trades) d.trade ?? '',
              '${d.persons}',
              if (moreShifts) '${d.shifts}',
              showDuration(d.clockMinutes),
              showDuration(d.breakMinutes),
              billableText(l10n, d.basis, d.units),
              if (priced) ...[rateOf(d.basis, d.rateFils), amountOf(d.amountFils)],
            ],
        ];
  return TimesheetPaper(
    client: v.clientName,
    clientLine: v.clientLine,
    period: [l10n.dateFromTo(showDate(v.sheet.fromDate), showDate(v.sheet.toDate)), v.siteName ?? l10n.tsAllSites].join('   '),
    columns: columns,
    rows: rows,
    facts: timesheetFacts(v.totals, l10n),
    amountLabel: priced && v.lines.any((l) => l.amountFils != null) ? l10n.tsTotalAmount : null,
    amount: priced && v.lines.any((l) => l.amountFils != null) ? formatAed(v.totals.amountFils) : null,
    monthly: [
      for (final m in v.monthly)
        priced
            ? l10n.tsMonthlyLine(basisLabel(l10n, m.basis), formatAed(m.rateFils), showDate(m.fromDate), showDate(m.toDate), m.persons)
            : l10n.tsMonthlyLinePlain(basisLabel(l10n, m.basis), showDate(m.fromDate), showDate(m.toDate), m.persons),
    ],
    agreedHeading: l10n.tsAgreedHeading,
    agreed: [
      for (final r in v.rows)
        if (r.adjustReason != null) '* ${showDate(r.line.workDate)}, ${r.workerName}: ${r.adjustReason}',
    ],
    notes: [
      if (v.revision.reason != null) l10n.tsRevisedBecause(v.revision.reason!),
      l10n.tsNotInvoice,
      if (priced) l10n.regAmountsNote,
    ],
    clientLabel: l10n.tsClientSign(v.clientName),
  );
}

/// A timesheet on A4 landscape, in the same frame as every other paper, separate from any invoice (DOC-01, TS-07).
Future<Uint8List> timesheetPdf(TimesheetPaper p, DocumentIdentity identity, DocumentMeta meta, {required Uint8List regularFont, required Uint8List boldFont}) {
  final brand = PdfColor.fromInt(identity.brandArgb);
  final soft = PdfColor.fromInt(identity.softArgb);
  pw.Alignment alignOf((String, int, bool) c) => c.$3 ? pw.Alignment.topRight : pw.Alignment.topLeft;
  final head = pw.TableRow(
    repeat: true,
    decoration: docHeadDecoration,
    verticalAlignment: pw.TableCellVerticalAlignment.bottom,
    children: [for (final c in p.columns) docCell(c.$1, align: alignOf(c), bold: true, size: 7.5, vertical: 2.5)],
  );
  final widths = {for (var i = 0; i < p.columns.length; i++) i: pw.FlexColumnWidth(p.columns[i].$2.toDouble())};
  final doc = pw.Document(title: '${meta.title} ${p.client}', author: identity.legalName, creator: identity.legalName);
  doc.addPage(
    documentPage(
      identity: identity,
      meta: meta,
      format: PdfPageFormat.a4.landscape,
      regularFont: regularFont,
      boldFont: boldFont,
      build: (context) => [
        pw.Container(
          color: soft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(p.client, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand)),
                    if (p.clientLine.isNotEmpty) pw.Text(p.clientLine, style: const pw.TextStyle(fontSize: 8, color: docMuted)),
                  ],
                ),
              ),
              pw.Text(p.period, style: const pw.TextStyle(fontSize: 9, color: docMuted)),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        for (var start = 0; start < p.rows.length; start += _sliceRows)
          pw.Table(
            border: docTableBorder,
            columnWidths: widths,
            children: [
              head,
              for (final row in p.rows.sublist(start, (start + _sliceRows).clamp(0, p.rows.length)))
                pw.TableRow(children: [for (var i = 0; i < row.length; i++) docCell(row[i], align: alignOf(p.columns[i]), size: 8)]),
            ],
          ),
        pw.SizedBox(height: 8),
        // Room for the totals, notes and signatures together, so a signature never sits alone on a page.
        pw.NewPage(freeSpace: 190),
        pw.Wrap(
          spacing: 18,
          runSpacing: 4,
          children: [
            for (final (label, value) in p.facts)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: docInk)),
                  pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: docMuted)),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (p.amount != null) ...[docBottomLine(p.amountLabel!, p.amount!), pw.SizedBox(height: 8)],
        for (final line in p.monthly) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(line, style: const pw.TextStyle(fontSize: 9, color: docInk))),
        if (p.agreed.isNotEmpty) ...[
          docHeading(p.agreedHeading, brand),
          for (final line in p.agreed) pw.Text(line, style: const pw.TextStyle(fontSize: 8.5, color: docInk)),
          pw.SizedBox(height: 6),
        ],
        for (final note in p.notes) pw.Text(note, style: const pw.TextStyle(fontSize: 8.5, color: docMuted)),
        pw.SizedBox(height: 16),
        docSignatures(identity, companyLabel: identity.shownName, receiverLabel: p.clientLabel),
      ],
    ),
  );
  return doc.save();
}

/// The way this paper goes out: all four are the same revision under the same number, each kept as issued (DOC-05).
DocKind timesheetKind({required bool workers, required bool priced}) => workers ? (priced ? DocKind.timesheetWorkersPriced : DocKind.timesheetWorkers) : (priced ? DocKind.timesheetDailyPriced : DocKind.timesheetDaily);

/// Issues this revision's paper the way the owner chose, or gives the one already issued that way. A later letterhead
/// doesn't reach it: the revision is what went to the company (DOC-05, TS-06).
Future<void> shareTimesheet(BuildContext context, WidgetRef ref, TimesheetView v, {required bool workers, required bool priced, required ValueChanged<bool> onBusy}) {
  final l10n = AppLocalizations.of(context);
  final view = workers ? l10n.tsViewWorkers : l10n.tsViewDaily;
  final paper = timesheetPaper(v, workers: workers, priced: priced, l10n: l10n);
  return issueAndExport(
    context,
    ref,
    kind: timesheetKind(workers: workers, priced: priced),
    fixed: (year: v.sheet.year!, seq: v.sheet.seq!, revision: v.revision.revision),
    subjectId: v.revision.id,
    period: null,
    title: l10n.tsTitle,
    subtitle: '$view, ${priced ? l10n.tsPricedLabel : l10n.tsHoursOnlyLabel}',
    summary: '${v.clientName}, $view',
    detail: paper.period,
    data: paper.toJson(),
    fileName: exportFileName('${l10n.tsTitle} ${v.clientName}', v.sheet.fromDate, v.sheet.toDate, ExportFormat.pdf),
    rows: paper.rows.length,
    onBusy: onBusy,
  );
}
