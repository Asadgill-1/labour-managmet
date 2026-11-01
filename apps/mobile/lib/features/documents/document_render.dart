import 'dart:convert';
import 'dart:isolate';

import 'package:domain/dates.dart';
import 'package:flutter/material.dart' show BuildContext, ValueChanged;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/documents.dart';
import '../../data/tenant_database.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../payroll/salary_slip.dart';
import '../registers/export_flow.dart';
import '../timesheets/timesheet_paper.dart';
import 'receipt.dart';

/// Draws an issued paper on a background isolate, so a long one doesn't freeze the screen.
Future<Uint8List> renderIssued(DocKind kind, Map<String, Object?> data, DocumentIdentity identity, DocumentMeta meta) async {
  final regular = (await rootBundle.load('assets/fonts/Roboto-Regular.ttf')).buffer.asUint8List();
  final bold = (await rootBundle.load('assets/fonts/Roboto-Bold.ttf')).buffer.asUint8List();
  return Isolate.run(
    () => switch (kind) {
      DocKind.payslip => slipPdf(SlipContent.fromJson(data), identity, meta, regularFont: regular, boldFont: bold),
      DocKind.paymentReceipt || DocKind.advanceReceipt => receiptPdf(ReceiptContent.fromJson(data), identity, meta, regularFont: regular, boldFont: bold),
      DocKind.timesheetDaily || DocKind.timesheetDailyPriced || DocKind.timesheetWorkers || DocKind.timesheetWorkersPriced => timesheetPdf(TimesheetPaper.fromJson(data), identity, meta, regularFont: regular, boldFont: bold),
    },
  );
}

/// The date line and "made at" for a paper made now.
DocumentMeta metaForNow(AppLocalizations l10n, {required String title, required String subtitle, String? number}) {
  final now = DateTime.now().toUtc().add(dubaiOffset);
  return DocumentMeta(
    title: title,
    subtitle: subtitle,
    number: number,
    dateLabel: showDate(ymd(now)),
    pagePattern: l10n.regPage('{page}', '{pages}'),
    madeLabel: l10n.regMade('${showDate(ymd(now))} ${showMinuteOfDay(now.hour * 60 + now.minute)}'),
  );
}

/// Says what is about to leave the phone, then issues the paper when the owner picks how to send it (DOC-05, DOC-07).
Future<void> issueAndExport(
  BuildContext context,
  WidgetRef ref, {
  required DocKind kind,
  required String subjectId,
  required String? period,
  required String title,
  required String subtitle,
  required String summary,
  required String detail,
  required Map<String, Object?> data,
  required String fileName,
  required ValueChanged<bool> onBusy,
  ({int year, int seq, int revision})? fixed,
  int rows = 0,
}) {
  final l10n = AppLocalizations.of(context);
  return chooseAndExport(
    context,
    title: title,
    summary: summary,
    detail: detail,
    pdfOnly: true,
    rows: rows,
    onBusy: onBusy,
    fileName: (_) => fileName,
    make: (_, _) async {
      final db = ref.read(dbProvider);
      final identity = await db.currentIdentity(brandArgb: brand.toARGB32(), softArgb: brandSoft.toARGB32());
      final doc = await db.issueDocument(
        kind: kind,
        subjectId: subjectId,
        period: period,
        title: title,
        summary: summary,
        data: data,
        identity: identity,
        metaFor: (number) => metaForNow(l10n, title: title, subtitle: subtitle, number: number),
        render: (meta) => renderIssued(kind, data, identity, meta),
        operationId: newUuid(),
        fixed: fixed,
      );
      return doc.pdfBytes;
    },
  );
}

/// A stored paper as issued, or the same paper drawn again from what was stored, marked as a copy (DOC-05).
Future<Uint8List> issuedBytes(TenantDatabase db, String id, {String? copyLabel}) async {
  final doc = await db.issuedDocument(id);
  if (copyLabel == null) return doc.pdfBytes;
  final meta = DocumentMeta.fromJson(jsonDecode(doc.metaJson) as Map<String, Object?>, copyLabel: copyLabel);
  return renderIssued(DocKind.values.byName(doc.kind), jsonDecode(doc.dataJson) as Map<String, Object?>, await db.identityOf(doc), meta);
}
