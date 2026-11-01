import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart' show BuildContext, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/providers.dart';
import '../../data/documents.dart';
import '../../data/statement.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../documents/document_render.dart';
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

  factory SlipTable.fromJson(Map<String, Object?> j) => SlipTable(
    title: j['title'] as String,
    headings: (j['headings'] as List).cast<String>(),
    flex: (j['flex'] as List).cast<int>(),
    rows: [for (final r in j['rows'] as List) (r as List).cast<String>()],
    total: (j['total'] as List).cast<String>(),
    emptyText: j['empty'] as String,
    rightFrom: j['right'] as int,
  );

  Map<String, Object?> toJson() => {'title': title, 'headings': headings, 'flex': flex, 'rows': rows, 'total': total, 'empty': emptyText, 'right': rightFrom};
}

/// Figures that belong together on the slip, with what they come to (PAY-09).
class SlipBlock {
  const SlipBlock(this.title, this.lines, {this.totalLabel, this.total});

  factory SlipBlock.fromJson(Map<String, Object?> j) => SlipBlock(
    j['title'] as String,
    [for (final l in j['lines'] as List) ((l as List)[0] as String, l[1] as String)],
    totalLabel: j['totalLabel'] as String?,
    total: j['total'] as String?,
  );

  final String title;
  final List<(String, String)> lines;
  final String? totalLabel;
  final String? total;

  Map<String, Object?> toJson() => {
    'title': title,
    'lines': [for (final l in lines) [l.$1, l.$2]],
    'totalLabel': totalLabel,
    'total': total,
  };
}

/// Everything printed on one worker's slip. It goes to the worker, so nothing here says what any company pays (D-042).
class SlipContent {
  const SlipContent({
    required this.month,
    required this.worker,
    required this.workerLine,
    required this.earnings,
    required this.deductions,
    required this.account,
    required this.closingLabel,
    required this.closingAmount,
    required this.days,
    required this.money,
    required this.notes,
  });

  factory SlipContent.fromJson(Map<String, Object?> j) => SlipContent(
    month: j['month'] as String,
    worker: j['worker'] as String,
    workerLine: j['workerLine'] as String,
    earnings: SlipBlock.fromJson(j['earnings'] as Map<String, Object?>),
    deductions: SlipBlock.fromJson(j['deductions'] as Map<String, Object?>),
    account: SlipBlock.fromJson(j['account'] as Map<String, Object?>),
    closingLabel: j['closingLabel'] as String,
    closingAmount: j['closingAmount'] as String,
    days: SlipTable.fromJson(j['days'] as Map<String, Object?>),
    money: SlipTable.fromJson(j['money'] as Map<String, Object?>),
    notes: (j['notes'] as List).cast<String>(),
  );

  final String month;
  final String worker;
  final String workerLine;

  /// What the month earned, on what basis.
  final SlipBlock earnings;

  /// What came out of it, item by item.
  final SlipBlock deductions;

  /// This month's net, what was left from before, and what has been paid.
  final SlipBlock account;
  final String closingLabel;
  final String closingAmount;
  final SlipTable days;
  final SlipTable money;
  final List<String> notes;

  /// Every line of the three blocks.
  List<(String, String)> get summary => [
    for (final block in [earnings, deductions, account]) ...[...block.lines, if (block.total != null) (block.totalLabel!, block.total!)],
  ];

  Map<String, Object?> toJson() => {
    'month': month,
    'worker': worker,
    'workerLine': workerLine,
    'earnings': earnings.toJson(),
    'deductions': deductions.toJson(),
    'account': account.toJson(),
    'closingLabel': closingLabel,
    'closingAmount': closingAmount,
    'days': days.toJson(),
    'money': money.toJson(),
    'notes': notes,
  };
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
  final others = s.money.where((m) => m.kind == StatementMoneyKind.deduction).toList();
  final deducted = s.advanceFils + s.roomFils + s.visaFils + s.otherFils;

  return SlipContent(
    month: showMonth(s.month),
    worker: '${s.worker.name} (${s.worker.code})',
    workerLine: [?s.worker.trade].join('   '),
    earnings: SlipBlock(
      l10n.slipEarnings,
      [
        (worked.isEmpty ? l10n.slipWork : l10n.slipWorkBasis(worked.length, showDuration(minutes)), money(s.workFils)),
        if (s.salaryFils != 0) (l10n.payrollSalary, money(s.salaryFils)),
        if (s.allowanceFils != 0) (l10n.payKindAllowance, money(s.allowanceFils)),
      ],
      totalLabel: l10n.slipEarned,
      total: money(s.earnedFils),
    ),
    deductions: SlipBlock(
      l10n.slipDeductions,
      [
        (l10n.slipAdvance, taken(s.advanceFils)),
        (l10n.slipRoom, taken(s.roomFils)),
        (l10n.slipVisa, taken(s.visaFils)),
        if (others.isEmpty) (l10n.slipOther, '-'),
        for (final m in others) (m.note ?? l10n.slipOther, taken(m.fils)),
      ],
      totalLabel: l10n.slipDeducted,
      total: taken(deducted),
    ),
    account: SlipBlock(l10n.slipAccount, [
      (l10n.slipNet, s.earnedFils == deducted ? '-' : plainMoney(s.earnedFils - deducted)),
      (l10n.slipOpening, money(s.openingFils)),
      (l10n.slipPaid, taken(s.paidFils)),
    ]),
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
  );
}

/// One worker's month on A4, upright so it reads on a phone: earnings beside deductions, the account, then each day and
/// the money taken. Text stays real text (DOC-08).
Future<Uint8List> slipPdf(SlipContent slip, DocumentIdentity identity, DocumentMeta meta, {required Uint8List regularFont, required Uint8List boldFont}) {
  final brand = PdfColor.fromInt(identity.brandArgb);
  final soft = PdfColor.fromInt(identity.softArgb);

  pw.Widget cell(String text, {bool right = false, bool bold = false, double size = 8.5}) => docCell(text, align: right ? pw.Alignment.topRight : pw.Alignment.topLeft, bold: bold, size: size);

  pw.Widget block(SlipBlock b) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      docHeading(b.title, brand),
      pw.Table(
        border: docTableBorder,
        columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4)},
        children: [
          for (final (label, value) in b.lines) pw.TableRow(children: [cell(label, size: 9), cell(value, right: true, size: 9)]),
          if (b.total != null) pw.TableRow(decoration: docTotalDecoration, children: [cell(b.totalLabel!, bold: true, size: 9), cell(b.total!, right: true, bold: true, size: 9)]),
        ],
      ),
    ],
  );

  List<pw.Widget> table(SlipTable t) => [
    // So a heading never sits alone at the foot of a page with its table on the next.
    pw.NewPage(freeSpace: 70),
    docHeading(t.title, brand),
    if (t.rows.isEmpty)
      pw.Text(t.emptyText, style: const pw.TextStyle(fontSize: 9, color: docMuted))
    else
      pw.Table(
        border: docTableBorder,
        columnWidths: {for (var c = 0; c < t.flex.length; c++) c: pw.FlexColumnWidth(t.flex[c].toDouble())},
        children: [
          pw.TableRow(
            repeat: true,
            decoration: docHeadDecoration,
            children: [for (var c = 0; c < t.headings.length; c++) cell(t.headings[c], right: c >= t.rightFrom, bold: true, size: 8)],
          ),
          for (final row in t.rows) pw.TableRow(children: [for (var c = 0; c < row.length; c++) cell(row[c], right: c >= t.rightFrom)]),
          pw.TableRow(decoration: docTotalDecoration, children: [for (var c = 0; c < t.total.length; c++) cell(t.total[c], right: c >= t.rightFrom, bold: true)]),
        ],
      ),
  ];

  final doc = pw.Document(title: '${meta.title} ${slip.worker} ${slip.month}', author: identity.legalName, creator: identity.legalName);
  doc.addPage(
    documentPage(
      identity: identity,
      meta: meta,
      format: PdfPageFormat.a4,
      regularFont: regularFont,
      boldFont: boldFont,
      build: (context) => [
        pw.Container(
          color: soft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text(slip.worker, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand))),
              pw.Text(slip.workerLine, style: const pw.TextStyle(fontSize: 9, color: docMuted)),
            ],
          ),
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: block(slip.earnings)),
            pw.SizedBox(width: 18),
            pw.Expanded(child: block(slip.deductions)),
          ],
        ),
        block(slip.account),
        pw.SizedBox(height: 4),
        docBottomLine(slip.closingLabel, slip.closingAmount),
        ...table(slip.days),
        ...table(slip.money),
        pw.SizedBox(height: 6),
        for (final note in slip.notes) pw.Text(note, style: const pw.TextStyle(fontSize: 8.5, color: docMuted)),
        if (identity.signature != null || identity.stamp != null) ...[pw.SizedBox(height: 10), docSignatures(identity, companyLabel: identity.shownName)],
      ],
    ),
  );
  return doc.save();
}

/// One slip for one worker, kept as issued. Slips never go out in a bundle, because each is private to its worker (DOC-05, DOC-07).
Future<void> shareSalarySlip(BuildContext context, WidgetRef ref, {required String workerId, required String month, required ValueChanged<bool> onBusy}) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final statement = (await db.statementsFor(month, workerId: workerId)).single;
  final clientNames = {for (final c in await db.select(db.clients).get()) c.id: c.name};
  final siteNames = {for (final s in await db.select(db.sites).get()) s.id: s.name};
  if (!context.mounted) return;
  final text = exportTextFor(ref, l10n, title: l10n.slipTitle, filterLine: showMonth(month), clientNames: clientNames, siteNames: siteNames);
  final slip = slipContent(statement, l10n, text);
  await issueAndExport(
    context,
    ref,
    kind: DocKind.payslip,
    subjectId: workerId,
    period: month,
    title: l10n.slipTitle,
    subtitle: slip.month,
    summary: '${slip.worker}, ${slip.month}',
    detail: '${slip.closingLabel} ${slip.closingAmount}',
    data: slip.toJson(),
    fileName: exportFileName('${l10n.slipTitle} ${statement.worker.name} ${statement.worker.code}', month, null, ExportFormat.pdf),
    onBusy: onBusy,
  );
}
