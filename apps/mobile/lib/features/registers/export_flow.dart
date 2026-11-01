import 'dart:typed_data';

import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'register_export.dart';
import 'register_model.dart';

/// What every file says about who made it and when (DOC-01).
ExportText exportTextFor(
  WidgetRef ref,
  AppLocalizations l10n, {
  required String title,
  required String filterLine,
  String? note,
  String? mainSheet,
  bool summaryFirst = false,
  Map<String, String> clientNames = const {},
  Map<String, String> siteNames = const {},
}) {
  final profile = ref.read(profileProvider).value;
  final now = DateTime.now().toUtc().add(dubaiOffset);
  return ExportText(
    company: profile?.tradingName ?? profile?.legalName ?? '',
    companyLine: [?profile?.address, ?profile?.phone, ?profile?.email].join('   '),
    title: title,
    filterLine: [if (filterLine.isNotEmpty) filterLine, l10n.regAmountsNote].join('   |   '),
    totalLabel: l10n.regTotal,
    madeLabel: l10n.regMade('${showDate(ymd(now))} ${showMinuteOfDay(now.hour * 60 + now.minute)}'),
    pagePattern: l10n.regPage('{page}', '{pages}'),
    rollupSheet: l10n.regSummarySheet,
    footer: profile?.documentFooter,
    note: note,
    mainSheet: mainSheet,
    summaryFirst: summaryFirst,
    clientNames: clientNames,
    siteNames: siteNames,
  );
}

/// Asks how to send a file, makes it, sends it, and tells the owner only what is really known (DOC-06, DOC-07).
Future<void> chooseAndExport(
  BuildContext context, {
  required String title,
  required String detail,
  required String Function(ExportFormat format) fileName,
  required Future<Uint8List> Function(ExportFormat format) make,
  required ValueChanged<bool> onBusy,
  String? summary,
  bool pdfOnly = false,
  int rows = 0,
}) async {
  final l10n = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<(ExportFormat, ExportAction)>(
    context: context,
    builder: (_) => _ExportSheet(title: title, detail: detail, summary: summary, pdfOnly: pdfOnly, slowPdf: rows > pdfSlowRows),
  );
  if (choice == null || !context.mounted) return;
  final (format, action) = choice;
  if (rows > (format == ExportFormat.pdf ? pdfRowLimit : excelRowLimit)) {
    showFormError(context, l10n.exportTooLong);
    return;
  }
  onBusy(true);
  try {
    final bytes = await make(format);
    final file = await writeExportFile(fileName(format), bytes);
    final result = await runExport(action, format, file, bytes);
    if (!context.mounted) return;
    switch (result) {
      case ExportResult.saved:
        showSavedOnPhone(context, l10n.exportSaved);
      case ExportResult.noWhatsApp:
        showFormError(context, l10n.exportNoWhatsApp);
      case ExportResult.noApp:
        showFormError(context, l10n.exportNoApp);
      case ExportResult.done || ExportResult.cancelled:
        break;
    }
  } catch (_) {
    if (context.mounted) showFormError(context, l10n.exportFailed);
  } finally {
    onBusy(false);
  }
}

/// A register's rows as a file.
Future<void> exportRegister(
  BuildContext context,
  WidgetRef ref, {
  required RegisterData data,
  required List<RegisterEntry> shown,
  required String filterLine,
  required ValueChanged<bool> onBusy,
  String? from,
  String? to,
}) {
  final l10n = AppLocalizations.of(context);
  return chooseAndExport(
    context,
    title: data.title,
    summary: l10n.regRows(shown.length),
    detail: filterLine,
    rows: shown.length,
    onBusy: onBusy,
    fileName: (format) => exportFileName(data.title, from, to, format),
    make: (format) => makeExportBytes(
      format,
      exportTextFor(ref, l10n, title: data.title, filterLine: filterLine, note: data.note, mainSheet: data.mainSheet, summaryFirst: data.summaryFirst),
      data.columns,
      data.groupsByName ? shown : oldestFirst(shown),
      brandArgb: brand.toARGB32(),
      softArgb: brandSoft.toARGB32(),
      rollups: data.rollupsOf?.call(shown) ?? const [],
      groupHeads: data.groupHeads,
      groupFeet: data.groupFeet,
      sections: data.groupsByName,
    ),
  );
}

/// Says what is about to leave the phone, then lets the owner choose how (DOC-07).
class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.title, required this.detail, this.summary, this.pdfOnly = false, this.slowPdf = false});

  final String title;
  final String detail;

  /// A second line for what the file holds, such as its row count.
  final String? summary;
  final bool pdfOnly;
  final bool slowPdf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget section(String heading, IconData icon, Color color, ExportFormat format, String viewLabel) {
      Widget action(IconData actionIcon, String label, ExportAction action, {Color? tint}) {
        return Expanded(
          child: Material(
            color: paper,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop((format, action)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    Icon(actionIcon, color: tint ?? brand),
                    const SizedBox(height: 4),
                    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(heading, style: sectionTitleStyle.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  action(Icons.visibility, viewLabel, ExportAction.view),
                  const SizedBox(width: 6),
                  action(Icons.save_alt, l10n.exportSave, ExportAction.save),
                  const SizedBox(width: 6),
                  action(Icons.chat, l10n.exportWhatsApp, ExportAction.whatsapp, tint: const Color(0xFF128C4A)),
                  const SizedBox(width: 6),
                  action(Icons.share, l10n.exportOther, ExportAction.other),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sectionTitleStyle),
                const SizedBox(height: 2),
                if (summary != null) Text(summary!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
                Text(detail, style: const TextStyle(fontSize: 13, color: muted)),
                if (slowPdf) Text(l10n.exportSlowPdf, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: due)),
              ],
            ),
          ),
          section('PDF', Icons.picture_as_pdf, const Color(0xFFC62828), ExportFormat.pdf, l10n.exportView),
          if (!pdfOnly) section('Excel', Icons.table_chart, const Color(0xFF1D7044), ExportFormat.excel, l10n.exportOpen),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
