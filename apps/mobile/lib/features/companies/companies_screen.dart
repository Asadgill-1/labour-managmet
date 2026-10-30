import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  String _search = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = ref.watch(clientsProvider).value ?? const [];
    final shown = clients
        .where((c) => c.active != _showArchived && c.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCompanies),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showArchived = !_showArchived),
            child: Text(_showArchived ? l10n.showActive : l10n.showArchived),
          ),
        ],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.addClient,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ClientFormScreen())),
      ),
      body: Column(
        children: [
          SearchBox(onChanged: (v) => setState(() => _search = v)),
          const Divider(),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(l10n.companiesEmpty))
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => ListTile(
                      title: Text(shown[i].name),
                      subtitle: shown[i].contactPerson == null ? null : Text(shown[i].contactPerson!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => ClientDetailScreen(clientId: shown[i].id)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
