import 'dart:isolate';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart' show BuildContext, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/statement.dart';
import '../../l10n/app_localizations.dart';
import '../rates/rate_labels.dart';
import '../registers/export_flow.dart';
import '../registers/register_export.dart';
import '../registers/register_model.dart';
import '../today/attendance_review_screen.dart' show statusLabel;

/// A table on the slip, as plain text so it can cross to a background isolate.
class SlipTable {
  const SlipTable({required this.title, required this.headings, required this.flex, required this.rows, required this.total, required this.emptyText, this.rightFrom = 0});

  final String title;
  final List<String> headings;
  final List<int> flex;
  final List<List<String>> rows;
  final List<String> total;
  final String emptyText;

  /// Columns from here on hold figures.
  final int rightFrom;
}

/// Everything printed on one worker's slip. It goes to the worker, so nothing here says what any company pays (D-042).
class SlipContent {
  const SlipContent({
    required this.company,
    required this.companyLine,
    required this.title,
    required this.month,
    required this.worker,
    required this.workerLine,
    required this.summaryTitle,
    required this.summary,
    required this.closingLabel,
    required this.closingAmount,
    required this.days,
    required this.money,
    required this.notes,
    required this.madeLabel,
    required this.pagePattern,
    this.footer,
  });

  final String company;
  final String companyLine;
  final String title;
  final String month;
  final String worker;
  final String workerLine;
  final String summaryTitle;
  final List<(String, String)> summary;
  final String closingLabel;
  final String closingAmount;
  final SlipTable days;
  final SlipTable money;
  final List<String> notes;
  final String madeLabel;
  final String pagePattern;
  final String? footer;
}

/// What the slip's lines say, from the worker's month. Worked out here so a test can read it without drawing a page.
SlipContent slipContent(WorkerStatement s, AppLocalizations l10n, ExportText text) {
  String money(int fils) => fils == 0 ? '-' : plainMoney(fils);
  String taken(int fils) => fils == 0 ? '-' : '-${plainMoney(fils)}';
  String whatFor(StatementMoneyKind kind) => switch (kind) {
    StatementMoneyKind.advance => l10n.kindAdvanceGiven,
    StatementMoneyKind.advanceReturned => l10n.kindAdvanceReturned,
    StatementMoneyKind.room => l10n.payKindRoom,
    StatementMoneyKind.visa => l10n.payKindVisa,
    StatementMoneyKind.deduction => l10n.slipOther,
    StatementMoneyKind.paid => l10n.slipPaid,
  };
  String noteOf(StatementMoney m) => switch (m.note) {
    'cash' => l10n.methodCash,
    'bank' => l10n.methodBank,
    final note? when note != whatFor(m.kind) => note,
    _ => '',
  };

  final overtime = s.work.any((e) => e.overtimeMinutes > 0);
  final worked = s.work.where((e) => e.attendanceStatus != AttendanceStatus.absent.name);
  final closing = s.closingFils;
  final minutes = worked.fold(0, (total, e) => total + e.workerPayableMinutes);

  return SlipContent(
    company: text.company,
    companyLine: text.companyLine,
    title: text.title,
    month: showMonth(s.month),
    worker: '${s.worker.name} (${s.worker.code})',
    workerLine: [?s.worker.trade].join('   '),
    summaryTitle: l10n.slipSummary,
    summary: [
      (l10n.slipOpening, money(s.openingFils)),
      (l10n.slipWork, money(s.workFils)),
      if (s.salaryFils != 0) (l10n.payrollSalary, money(s.salaryFils)),
      if (s.allowanceFils != 0) (l10n.payKindAllowance, money(s.allowanceFils)),
      (l10n.slipAdvance, taken(s.advanceFils)),
      (l10n.slipRoom, taken(s.roomFils)),
      (l10n.slipVisa, taken(s.visaFils)),
      (l10n.slipOther, taken(s.otherFils)),
      (l10n.slipPaid, taken(s.paidFils)),
    ],
    closingLabel: closing > 0 ? l10n.slipOwedToYou : (closing < 0 ? l10n.slipYouOwe : l10n.slipSettled),
    closingAmount: formatAed(closing.abs()),
    days: SlipTable(
      title: l10n.slipDays,
      emptyText: l10n.slipNoWork,
      headings: [l10n.colDate, l10n.colCompany, l10n.colSite, l10n.filterStatus, l10n.colHours, if (overtime) l10n.colOvertime, l10n.colRate, l10n.regTotal],
      flex: [3, 5, 4, 3, 2, if (overtime) 2, 4, 3],
      rightFrom: 4,
      rows: [
        for (final e in s.work)
          () {
            final absent = e.attendanceStatus == AttendanceStatus.absent.name;
            return [
              showDate(e.workDate),
              text.clientNames[e.clientId] ?? '',
              text.siteNames[e.siteId] ?? '',
              statusLabel(l10n, AttendanceStatus.values.byName(e.attendanceStatus)),
              absent ? '-' : showDuration(e.workerPayableMinutes),
              if (overtime) e.overtimeMinutes == 0 ? '-' : showDuration(e.overtimeMinutes),
              absent ? '-' : (e.workerRateFils == null ? l10n.issueNoRate : '${plainMoney(e.workerRateFils!)} ${basisLabel(l10n, RateBasis.values.byName(e.workerBasis!))}'),
              money(e.workerAmountFils ?? 0),
            ];
          }(),
      ],
      total: [l10n.regTotal, l10n.slipDayCount(worked.length), '', '', showDuration(minutes), if (overtime) showDuration(s.work.fold(0, (total, e) => total + e.overtimeMinutes)), '', plainMoney(s.workFils)],
    ),
    money: SlipTable(
      title: l10n.slipMoney,
      emptyText: l10n.slipNoMoney,
      headings: [l10n.colDate, l10n.colWhat, l10n.note, l10n.amountAed],
      flex: [3, 5, 8, 3],
      rightFrom: 3,
      rows: [
        for (final m in s.money) [showDate(m.date), whatFor(m.kind), noteOf(m), plainMoney(m.fils)],
      ],
      total: [l10n.regTotal, '', '', plainMoney(s.takenFils)],
    ),
    notes: [if (s.visaLeftFils > 0) l10n.slipVisaLeft(formatAed(s.visaLeftFils)), l10n.slipNote, l10n.regAmountsNote],
    madeLabel: text.madeLabel,
    pagePattern: text.pagePattern,
    footer: text.footer,
  );
}

/// One worker's month on A4, upright so it reads on a phone: the account, then each day, then the money taken.
Future<Uint8List> slipPdf(SlipContent slip, {required int brandArgb, required int softArgb, required Uint8List regularFont, required Uint8List boldFont}) {
  final brand = PdfColor.fromInt(brandArgb);
  final soft = PdfColor.fromInt(softArgb);
  const rule = PdfColor.fromInt(0xFFD5DAE3);
  const grey = PdfColor.fromInt(0xFF5B667A);
  const zebra = PdfColor.fromInt(0xFFF7F8FB);
  const totalFill = PdfColor.fromInt(0xFFE2E5EB);

  pw.Widget cell(String text, {bool right = false, bool bold = false, PdfColor? color, double size = 8.5}) => pw.Container(
    alignment: right ? pw.Alignment.topRight : pw.Alignment.topLeft,
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.8),
    child: pw.Text(
      text,
      textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
      style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
    ),
  );

  pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 9, bottom: 3),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: brand)),
  );

  const lines = pw.TableBorder(
    left: pw.BorderSide(color: rule, width: 0.4),
    right: pw.BorderSide(color: rule, width: 0.4),
    top: pw.BorderSide(color: rule, width: 0.4),
    bottom: pw.BorderSide(color: rule, width: 0.4),
    horizontalInside: pw.BorderSide(color: rule, width: 0.4),
    verticalInside: pw.BorderSide(color: rule, width: 0.4),
  );

  List<pw.Widget> table(SlipTable t) => [
    heading(t.title),
    if (t.rows.isEmpty)
      pw.Text(t.emptyText, style: const pw.TextStyle(fontSize: 9, color: grey))
    else
      pw.Table(
        border: lines,
        columnWidths: {for (var c = 0; c < t.flex.length; c++) c: pw.FlexColumnWidth(t.flex[c].toDouble())},
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: brand),
            children: [for (var c = 0; c < t.headings.length; c++) cell(t.headings[c], right: c >= t.rightFrom, bold: true, color: PdfColors.white, size: 8)],
          ),
          for (var r = 0; r < t.rows.length; r++)
            pw.TableRow(
              decoration: r.isOdd ? const pw.BoxDecoration(color: zebra) : null,
              children: [for (var c = 0; c < t.rows[r].length; c++) cell(t.rows[r][c], right: c >= t.rightFrom)],
            ),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: totalFill),
            children: [for (var c = 0; c < t.total.length; c++) cell(t.total[c], right: c >= t.rightFrom, bold: true)],
          ),
        ],
      ),
  ];

  final doc = pw.Document(title: '${slip.title} ${slip.worker} ${slip.month}', author: slip.company, creator: slip.company);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 22),
      theme: pw.ThemeData.withFont(base: pw.Font.ttf(regularFont.buffer.asByteData()), bold: pw.Font.ttf(boldFont.buffer.asByteData())),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: brand, width: 1.4))),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(slip.company, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand)),
                  if (slip.companyLine.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(slip.companyLine, style: const pw.TextStyle(fontSize: 8, color: grey))),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(slip.title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text(slip.month, style: const pw.TextStyle(fontSize: 10, color: grey)),
              ],
            ),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        children: [
          pw.Expanded(child: pw.Text([?slip.footer, slip.madeLabel].join('   '), style: const pw.TextStyle(fontSize: 7.5, color: grey))),
          pw.Text(slip.pagePattern.replaceAll('{page}', '${context.pageNumber}').replaceAll('{pages}', '${context.pagesCount}'), style: const pw.TextStyle(fontSize: 7.5, color: grey)),
        ],
      ),
      build: (context) => [
        pw.Container(
          color: soft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text(slip.worker, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand))),
              pw.Text(slip.workerLine, style: const pw.TextStyle(fontSize: 9, color: grey)),
            ],
          ),
        ),
        heading(slip.summaryTitle),
        pw.Table(
          border: lines,
          columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth()},
          children: [
            for (var i = 0; i < slip.summary.length; i++)
              pw.TableRow(
                decoration: i.isOdd ? const pw.BoxDecoration(color: zebra) : null,
                children: [cell(slip.summary[i].$1, size: 9), cell(slip.summary[i].$2, right: true, size: 9)],
              ),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: brand),
              children: [
                cell(slip.closingLabel, bold: true, color: PdfColors.white, size: 10.5),
                cell(slip.closingAmount, right: true, bold: true, color: PdfColors.white, size: 10.5),
              ],
            ),
          ],
        ),
        ...table(slip.days),
        ...table(slip.money),
        pw.SizedBox(height: 6),
        for (final note in slip.notes) pw.Text(note, style: const pw.TextStyle(fontSize: 8.5, color: grey)),
      ],
    ),
  );
  return doc.save();
}

/// One slip for one worker. Slips never go out in a bundle, because each is private to its worker (DOC-07).
Future<void> shareSalarySlip(BuildContext context, WidgetRef ref, {required String workerId, required String month, required ValueChanged<bool> onBusy}) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final statement = (await db.statementsFor(month, workerId: workerId)).single;
  final clientNames = {for (final c in await db.select(db.clients).get()) c.id: c.name};
  final siteNames = {for (final s in await db.select(db.sites).get()) s.id: s.name};
  if (!context.mounted) return;
  final text = exportTextFor(ref, l10n, title: l10n.slipTitle, filterLine: showMonth(month), clientNames: clientNames, siteNames: siteNames);
  final slip = slipContent(statement, l10n, text);
  final brandArgb = brand.toARGB32();
  final softArgb = brandSoft.toARGB32();
  await chooseAndExport(
    context,
    title: l10n.slipTitle,
    summary: slip.worker,
    detail: '${slip.month}   ${slip.closingLabel} ${slip.closingAmount}',
    pdfOnly: true,
    onBusy: onBusy,
    fileName: (_) => exportFileName('${l10n.slipTitle} ${statement.worker.name} ${statement.worker.code}', month, null, ExportFormat.pdf),
    make: (_) async {
      final regular = (await rootBundle.load('assets/fonts/Roboto-Regular.ttf')).buffer.asUint8List();
      final bold = (await rootBundle.load('assets/fonts/Roboto-Bold.ttf')).buffer.asUint8List();
      return Isolate.run(() => slipPdf(slip, brandArgb: brandArgb, softArgb: softArgb, regularFont: regular, boldFont: bold));
    },
  );
}
