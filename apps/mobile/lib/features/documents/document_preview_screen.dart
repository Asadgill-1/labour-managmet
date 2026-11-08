import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../registers/register_export.dart';

/// A paper on screen before it goes anywhere, and everything that can be done with it (DOC-06).
class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({required this.title, required this.bytes, required this.file, super.key});

  final String title;
  final Uint8List bytes;
  final File file;

  Future<void> _run(BuildContext context, ExportAction action) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await runExport(action, ExportFormat.pdf, file, bytes);
      if (!context.mounted) return;
      if (result == ExportResult.saved) showSavedOnPhone(context, l10n.exportSaved);
      if (result == ExportResult.noWhatsApp) showFormError(context, l10n.exportNoWhatsApp);
    } catch (_) {
      if (context.mounted) showFormError(context, l10n.exportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signal = action;
    Widget button(IconData icon, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: signal),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 13, color: ink)),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: rule)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              button(Icons.print, l10n.docPrint, () => Printing.layoutPdf(name: file.uri.pathSegments.last, onLayout: (_) async => bytes)),
              button(Icons.save_alt, l10n.exportSave, () => _run(context, ExportAction.save)),
              button(Icons.chat, l10n.exportWhatsApp, () => _run(context, ExportAction.whatsapp)),
              button(Icons.share, l10n.exportOther, () => _run(context, ExportAction.other)),
            ],
          ),
        ),
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        useActions: false,
        scrollViewDecoration: const BoxDecoration(color: paper),
        pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white, border: Border.fromBorderSide(BorderSide(color: rule))),
      ),
    );
  }
}
