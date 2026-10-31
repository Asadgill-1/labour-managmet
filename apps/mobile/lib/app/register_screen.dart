import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'form_bits.dart';
import 'side_panel.dart';
import 'theme.dart';

class RegisterRow {
  const RegisterRow({required this.tag, required this.title, this.subtitle, required this.active, required this.onTap});

  final String tag;
  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback onTap;

  bool matches(String needle) => '$title ${subtitle ?? ''} $tag'.toLowerCase().contains(needle);
}

/// A main screen holding one register: search, archived toggle, rows and its one action (UX-03, UX-05).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.title,
    required this.rows,
    required this.emptyIcon,
    required this.emptyText,
    required this.addLabel,
    required this.onAdd,
    super.key,
  });

  final String title;
  final List<RegisterRow> rows;
  final IconData emptyIcon;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

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
        actions: [
          TextButton(
            onPressed: () => setState(() => _showArchived = !_showArchived),
            child: Text(_showArchived ? l10n.showActive : l10n.showArchived),
          ),
        ],
      ),
      bottomNavigationBar: MainActionBar(label: widget.addLabel, onPressed: widget.onAdd),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: hiVis, child: SearchBox(onChanged: (v) => setState(() => _search = v))),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(icon: widget.emptyIcon, text: widget.emptyText)
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => GrowingRow(
                      child: ListTile(
                        leading: RowTag(shown[i].tag),
                        title: Text(shown[i].title),
                        subtitle: shown[i].subtitle == null ? null : Text(shown[i].subtitle!),
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
