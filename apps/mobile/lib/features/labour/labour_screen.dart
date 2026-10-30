import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'worker_detail_screen.dart';
import 'worker_form_screen.dart';

class LabourScreen extends ConsumerStatefulWidget {
  const LabourScreen({super.key});

  @override
  ConsumerState<LabourScreen> createState() => _LabourScreenState();
}

class _LabourScreenState extends ConsumerState<LabourScreen> {
  String _search = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workers = ref.watch(workersProvider).value ?? const [];
    final needle = _search.toLowerCase();
    final shown = workers
        .where((w) => w.active != _showArchived && (w.name.toLowerCase().contains(needle) || w.code.toLowerCase().contains(needle)))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabLabour),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showArchived = !_showArchived),
            child: Text(_showArchived ? l10n.showActive : l10n.showArchived),
          ),
        ],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.addWorker,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkerFormScreen())),
      ),
      body: Column(
        children: [
          SearchBox(onChanged: (v) => setState(() => _search = v)),
          const Divider(),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(l10n.labourEmpty))
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => ListTile(
                      title: Text(shown[i].name),
                      subtitle: Text([shown[i].code, ?shown[i].trade].join(', ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => WorkerDetailScreen(workerId: shown[i].id)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
