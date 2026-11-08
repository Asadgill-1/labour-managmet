import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart' show BuildContext, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/providers.dart';
import '../../data/documents.dart';
import '../../data/receipts.dart';
import '../../data/tenant_database.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../invoices/invoice_paper.dart' show paperWords;
import '../registers/register_export.dart';
import '../registers/register_model.dart';
import 'document_render.dart';

/// What a receipt says. Plain text, so it can be stored with the paper and cross to a background isolate.
class ReceiptContent {
  const ReceiptContent({required this.party, required this.partyLine, required this.lines, required this.amountLabel, required this.amount, required this.notes, required this.companyLabel, required this.receiverLabel});

  factory ReceiptContent.fromJson(Map<String, Object?> j) => ReceiptContent(
    party: j['party'] as String,
    partyLine: j['partyLine'] as String,
    lines: [for (final l in j['lines'] as List) ((l as List)[0] as String, l[1] as String)],
    amountLabel: j['amountLabel'] as String,
    amount: j['amount'] as String,
    notes: (j['notes'] as List).cast<String>(),
    companyLabel: j['companyLabel'] as String,
    receiverLabel: j['receiverLabel'] as String,
  );

  final String party;
  final String partyLine;
  final List<(String, String)> lines;
  final String amountLabel;
  final String amount;
  final List<String> notes;
  final String companyLabel;
  final String receiverLabel;

  Map<String, Object?> toJson() => {
    'party': party,
    'partyLine': partyLine,
    'lines': [for (final l in lines) [l.$1, l.$2]],
    'amountLabel': amountLabel,
    'amount': amount,
    'notes': notes,
    'companyLabel': companyLabel,
    'receiverLabel': receiverLabel,
  };
}

/// What a salary payment or advance was, for whoever took it. It says it is the company's record, not proof of a bank payment (PAY-09).
ReceiptContent receiptContent(CashEntry entry, Worker worker, List<SalaryAllocation> settles, AppLocalizations l10n) {
  final advance = entry.kind == CashKind.advanceGiven.name;
  return ReceiptContent(
    party: '${worker.name} (${worker.code})',
    partyLine: worker.trade ?? '',
    lines: [
      (l10n.colDate, showDate(entry.entryDate)),
      (l10n.receiptMethod, entry.method == 'bank' ? l10n.methodBank : l10n.methodCash),
      if (entry.reference != null) (l10n.receiptReference, entry.reference!),
      if (entry.receiver != null) (l10n.receiptReceiver, entry.receiver!),
      for (final a in settles) (l10n.receiptMonth(showMonth(a.month)), plainMoney(a.amountFils)),
      if (entry.note != null) (l10n.note, entry.note!),
    ],
    amountLabel: advance ? l10n.receiptAdvance : l10n.receiptPayment,
    amount: formatAed(entry.amountFils),
    notes: [l10n.receiptNote, l10n.regAmountsNote],
    companyLabel: l10n.receiptFromCompany,
    receiverLabel: l10n.receiptTakenBy,
  );
}

/// What a company paid and what it settled, in English like its invoices (D-050). Anything not set against an invoice
/// says it is kept as the company's credit (INV-05).
ReceiptContent clientReceiptContent(CashEntry entry, Client client, List<ReceiptPart> parts, AppLocalizations words) {
  final used = parts.fold(0, (total, p) => total + p.fils);
  return ReceiptContent(
    party: client.name,
    partyLine: client.trn == null ? '' : '${words.trn} ${client.trn}',
    lines: [
      (words.colDate, showDate(entry.entryDate)),
      (words.receiptMethod, entry.method == 'bank' ? words.methodBank : words.methodCash),
      if (entry.reference != null) (words.receiptReference, entry.reference!),
      for (final p in parts) (p.number == null ? words.receiptOldBalance : words.receiptForInvoice(p.number!), plainMoney(p.fils)),
      if (entry.amountFils > used) (words.receiptKeptAsCredit, plainMoney(entry.amountFils - used)),
      if (entry.note != null) (words.note, entry.note!),
    ],
    amountLabel: words.receiptReceived,
    amount: formatAed(entry.amountFils),
    notes: [words.receiptClientNote],
    companyLabel: words.receiptReceivedBy,
    receiverLabel: words.receiptPaidBy,
  );
}

/// One payment on a short A4 page, the same frame as every other paper (DOC-01).
Future<Uint8List> receiptPdf(ReceiptContent r, DocumentIdentity identity, DocumentMeta meta, {required Uint8List regularFont, required Uint8List boldFont}) {
  final brand = PdfColor.fromInt(identity.brandArgb);
  final soft = PdfColor.fromInt(identity.softArgb);
  final doc = pw.Document(title: '${meta.title} ${r.party}', author: identity.legalName, creator: identity.legalName);
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
              pw.Expanded(child: pw.Text(r.party, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: brand))),
              pw.Text(r.partyLine, style: const pw.TextStyle(fontSize: 9, color: docMuted)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: docTableBorder,
          columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
          children: [
            for (final (label, value) in r.lines)
              pw.TableRow(
                children: [docCell(label, size: 9.5, color: docMuted), docCell(value, size: 9.5, align: pw.Alignment.topRight)],
              ),
          ],
        ),
        pw.SizedBox(height: 6),
        docBottomLine(r.amountLabel, r.amount),
        pw.SizedBox(height: 8),
        for (final note in r.notes) pw.Text(note, style: const pw.TextStyle(fontSize: 8.5, color: docMuted)),
        pw.SizedBox(height: 16),
        docSignatures(identity, companyLabel: r.companyLabel, receiverLabel: r.receiverLabel),
      ],
    ),
  );
  return doc.save();
}

/// A receipt for a company's payment, kept as issued (INV-05, DOC-05).
Future<void> shareClientReceipt(BuildContext context, WidgetRef ref, CashEntry entry, {required ValueChanged<bool> onBusy}) async {
  final db = ref.read(dbProvider);
  final client = await (db.select(db.clients)..where((c) => c.id.equals(entry.clientId!))).getSingle();
  final parts = await db.receiptParts(entry.id);
  if (!context.mounted) return;
  final content = clientReceiptContent(entry, client, parts, paperWords);
  final title = paperWords.receiptClientTitle;
  await issueAndExport(
    context,
    ref,
    kind: DocKind.clientReceipt,
    words: paperWords,
    subjectId: entry.id,
    period: null,
    title: title,
    subtitle: showDate(entry.entryDate),
    summary: '${client.name}, ${content.amount}',
    detail: showDate(entry.entryDate),
    data: content.toJson(),
    fileName: exportFileName('$title ${client.name}', entry.entryDate, null, ExportFormat.pdf),
    onBusy: onBusy,
  );
}

/// A receipt for one salary payment or advance, kept as issued (DOC-01, DOC-05).
Future<void> shareReceipt(BuildContext context, WidgetRef ref, CashEntry entry, {required ValueChanged<bool> onBusy}) async {
  final l10n = AppLocalizations.of(context);
  final db = ref.read(dbProvider);
  final worker = await (db.select(db.workers)..where((w) => w.id.equals(entry.workerId!))).getSingle();
  final settles = await (db.select(db.salaryAllocations)
        ..where((a) => a.paymentId.equals(entry.id))
        ..orderBy([(a) => OrderingTerm.asc(a.month)]))
      .get();
  if (!context.mounted) return;
  final advance = entry.kind == CashKind.advanceGiven.name;
  final title = advance ? l10n.receiptAdvanceTitle : l10n.receiptPaymentTitle;
  final content = receiptContent(entry, worker, settles, l10n);
  await issueAndExport(
    context,
    ref,
    kind: advance ? DocKind.advanceReceipt : DocKind.paymentReceipt,
    subjectId: entry.id,
    period: null,
    title: title,
    subtitle: showDate(entry.entryDate),
    summary: '${content.party}, ${content.amount}',
    detail: showDate(entry.entryDate),
    data: content.toJson(),
    fileName: exportFileName('$title ${worker.name} ${worker.code}', entry.entryDate, null, ExportFormat.pdf),
    onBusy: onBusy,
  );
}
