import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/documents.dart';
import '../../l10n/app_localizations.dart';
import '../registers/export_flow.dart';
import '../registers/register_export.dart';
import 'document_render.dart';

/// Every paper the company has issued, each exactly as it went out (DOC-05).
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _search = '';
  bool _busy = false;

  Future<void> _open(IssuedRow row) {
    final l10n = AppLocalizations.of(context);
    return chooseAndExport(
      context,
      title: row.title,
      summary: row.summary,
      detail: row.number,
      pdfOnly: true,
      offerCopy: true,
      onBusy: (busy) {
        if (mounted) setState(() => _busy = busy);
      },
      fileName: (_) => exportFileName(row.number, null, null, ExportFormat.pdf),
      make: (_, copy) => issuedBytes(ref.read(dbProvider), row.id, copyLabel: copy ? l10n.docCopyLabel : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(issuedDocumentsProvider).value ?? const <IssuedRow>[];
    final needle = _search.toLowerCase();
    final shown = needle.isEmpty ? rows : rows.where((r) => '${r.number} ${r.title} ${r.summary}'.toLowerCase().contains(needle)).toList();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.docsTab), bottom: const SubTabs(Section.documents)),
      body: ListView(
        children: [
          if (rows.length > 6) ColoredBox(color: brand, child: SearchBox(onChanged: (v) => setState(() => _search = v))),
          if (rows.isEmpty) EmptyState(icon: Icons.description, text: l10n.docsEmpty),
          for (final row in shown)
            RowCard(
              child: ListTile(
                title: Text(row.summary),
                subtitle: Text('${row.title}, ${showDate(dubaiToday(row.issuedAtUtc))}\n${row.number}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _open(row),
              ),
            ),
        ],
      ),
    );
  }
}
