import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/register_screen.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return RegisterScreen(
      title: l10n.tabCompanies,
      emptyIcon: Icons.apartment,
      emptyText: l10n.companiesEmpty,
      addLabel: l10n.addClient,
      onAdd: () => open(const ClientFormScreen()),
      rows: [
        for (final c in ref.watch(clientsProvider).value ?? const <Client>[])
          RegisterRow(
            tag: initial(c.name),
            title: c.name,
            subtitle: c.contactPerson,
            active: c.active,
            onTap: () => open(ClientDetailScreen(clientId: c.id)),
          ),
      ],
    );
  }
}
