import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'form_bits.dart';
import 'side_panel.dart';
import 'theme.dart';

class RegisterRow {
  const RegisterRow({required this.tag, required this.title, this.subtitle, required this.active, this.edited = false, required this.onTap});

  final String tag;
  final String title;
  final String? subtitle;
  final bool active;

  /// Someone changed it since it was added (D-056).
  final bool edited;
  final VoidCallback onTap;

  bool matches(String needle) => '$title ${subtitle ?? ''} $tag'.toLowerCase().contains(needle);
}

/// A main screen holding one register: search, archived toggle, rows and its one action (UX-03, UX-05).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.section,
    required this.title,
    required this.rows,
    required this.emptyIcon,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    this.onImport,
    super.key,
  });

  final Section section;
  final String title;
  final List<RegisterRow> rows;
  final IconData emptyIcon;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

  /// Brings many rows in from a file, beside adding one by hand (MASTER-08).
  final VoidCallback? onImport;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _search = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = _search.toLowerCase();
    final shown = widget.rows.where((r) => r.active != _showArchived && r.matches(needle)).toList();
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(widget.title),
        bottom: SubTabs(widget.section),
        actions: [BarButton(_showArchived ? l10n.showActive : l10n.showArchived, onPressed: () => setState(() => _showArchived = !_showArchived))],
      ),
      bottomNavigationBar: MainActionBar(label: widget.addLabel, onPressed: widget.onAdd),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBand(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(child: SearchBox(onChanged: (v) => setState(() => _search = v))),
                // Beside the search, since the header has no room left on a narrow phone.
                if (widget.onImport != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                    child: Semantics(
                      button: true,
                      label: l10n.importCsv,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: widget.onImport,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_file, color: Colors.white),
                              Text(l10n.importShort, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(icon: widget.emptyIcon, text: widget.emptyText)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => RowCard(
                      edited: shown[i].edited,
                      child: ListTile(
                        leading: RowTag(shown[i].tag),
                        title: Text(shown[i].title),
                        subtitle: (shown[i].subtitle ?? '').isEmpty ? null : Text(shown[i].subtitle!),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: shown[i].onTap,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
