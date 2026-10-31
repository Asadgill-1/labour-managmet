import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/register_screen.dart';
import '../../app/side_panel.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'site_form_screen.dart';

/// Every site of every company, in one place (D-027).
class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final names = {for (final c in clients) c.id: c.name};
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return RegisterScreen(
      section: Section.sites,
      title: l10n.sitesHeading,
      emptyIcon: Icons.location_on,
      emptyText: l10n.sitesEmpty,
      addLabel: l10n.addSite,
      onAdd: () async {
        final clientId = await chooseOne(context, l10n.chooseClient, [
          for (final c in clients.where((c) => c.active)) (value: c.id, label: c.name),
        ]);
        if (clientId != null && context.mounted) open(SiteFormScreen(clientId: clientId));
      },
      rows: [
        for (final s in ref.watch(allSitesProvider).value ?? const <Site>[])
          RegisterRow(
            tag: initial(s.name),
            title: s.name,
            subtitle: [?names[s.clientId], ?s.location].join(', '),
            active: s.active,
            onTap: () => open(SiteFormScreen(clientId: s.clientId, site: s)),
          ),
      ],
    );
  }
}
