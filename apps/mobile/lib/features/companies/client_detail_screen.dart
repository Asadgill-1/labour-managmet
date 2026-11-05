import 'dart:collection';

import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../../app/side_panel.dart';
import '../rates/rate_sections.dart';
import '../registers/ledger_screen.dart';
import 'client_form_screen.dart';
import 'site_form_screen.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({required this.clientId, super.key});

  final String clientId;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(clientsProvider).value?.where((c) => c.id == clientId).firstOrNull;
    if (client == null) return Scaffold(appBar: AppBar());
    final sites = ref.watch(sitesOfClientProvider(clientId)).value ?? const <Site>[];
    final money = ref.watch(clientMoneyProvider(clientId)).value;
    final today = dubaiToday(DateTime.now());
    final owed = money?.openOf(clientId).fold(0, (total, o) => total + o.leftFils) ?? 0;
    final overdue = money?.invoices.values.where((m) => m.invoice.status == 'issued' && m.state(today) == PayState.overdue).fold(0, (total, m) => total + m.leftFils) ?? 0;
    final credit = money?.creditOf(clientId) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(client.name),
        actions: [
          IconButton(
            tooltip: l10n.editClient,
            icon: const Icon(Icons.edit),
            onPressed: () => _open(context, ClientFormScreen(client: client)),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (!client.active) ListTile(title: Text(l10n.archivedLabel)),
          SectionHeader(
            l10n.clientMoneyHeading,
            action: TextButton(
              onPressed: () => _open(context, LedgerScreen(Section.statementRegister, chosen: {'client': {clientId}}, allDates: true)),
              child: Text(l10n.regStatement),
            ),
          ),
          RowCard(child: InfoRow(l10n.invToPay, formatAed(owed))),
          if (overdue > 0) RowCard(child: InfoRow(l10n.invStatusOverdue, formatAed(overdue))),
          if (credit > 0) RowCard(child: InfoRow(l10n.clientCreditUnused, formatAed(credit))),
          SectionHeader(
            l10n.sitesHeading,
            action: TextButton(
              onPressed: () => _open(context, SiteFormScreen(clientId: clientId)),
              child: Text(l10n.addSite),
            ),
          ),
          const Divider(),
          if (sites.isEmpty) ListTile(subtitle: Text(l10n.sitesEmpty)),
          for (final site in sites) ...[
            ListTile(
              leading: RowTag(initial(site.name)),
              title: Text(site.name),
              subtitle: site.active ? (site.location == null ? null : Text(site.location!)) : Text(l10n.archivedLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, SiteFormScreen(clientId: clientId, site: site)),
            ),
            const Divider(),
          ],
          ClientRateSections(clientId: clientId),
          fieldGap,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () {
                final db = ref.read(dbProvider);
                saveOrExplain(
                  context,
                  () => db.saveRow(
                    db.clients,
                    id: clientId,
                    operationId: newUuid(),
                    fields: ClientsCompanion(active: Value(!client.active)),
                  ),
                );
              },
              child: Text(client.active ? l10n.archive : l10n.reactivate),
            ),
          ),
          fieldGap,
        ],
      ),
    );
  }
}
