import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'contract_form_screen.dart';
import 'rate_labels.dart';

/// All rates in one place, so a missing one is easy to spot (D-027). Editing uses the same forms
/// as the company and worker screens.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final workers = ref.watch(workersProvider).value ?? const <Worker>[];
    final siteNames = {for (final s in ref.watch(allSitesProvider).value ?? const <Site>[]) s.id: s.name};
    final billing = ref.watch(allBillingContractsProvider).value ?? const <BillingContract>[];
    final pay = ref.watch(allPayContractsProvider).value ?? const <PayContract>[];
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: Text(l10n.tabRates),
          bottom: SubTabs(
            Section.rates,
            below: TabBar(tabs: [Tab(text: l10n.billingContractsHeading), Tab(text: l10n.payContractsHeading)]),
          ),
        ),
        body: TabBarView(
          children: [
            _RateTab(
              emptyText: l10n.noBillingRates,
              addLabel: l10n.addBillingContract,
              onAdd: () async {
                final id = await chooseOne(context, l10n.chooseClient, [
                  for (final c in clients.where((c) => c.active)) (value: c.id, label: c.name),
                ]);
                if (id != null && context.mounted) open(ContractFormScreen.billing(clientId: id));
              },
              rows: [
                for (final client in clients)
                  for (final c in billing.where((c) => c.clientId == client.id))
                    _RateRow(
                      tag: initial(client.name),
                      name: client.name,
                      details: [
                        rateSummary(l10n, c.basis, c.rateFils),
                        dateRange(l10n, c.effectiveFrom, c.effectiveTo),
                        ?siteNames[c.siteId],
                      ],
                      onTap: () => open(ContractFormScreen.billing(clientId: client.id, billing: c)),
                    ),
              ],
            ),
            _RateTab(
              emptyText: l10n.noPayRates,
              addLabel: l10n.addPayContract,
              onAdd: () async {
                final id = await chooseOne(context, l10n.chooseWorker, [
                  for (final w in workers.where((w) => w.active)) (value: w.id, label: '${w.name} (${w.code})'),
                ]);
                if (id != null && context.mounted) open(ContractFormScreen.pay(workerId: id));
              },
              rows: [
                for (final worker in workers)
                  for (final c in pay.where((c) => c.workerId == worker.id))
                    _RateRow(
                      tag: worker.code,
                      name: worker.name,
                      details: [
                        rateSummary(l10n, c.basis, c.rateFils),
                        dateRange(l10n, c.effectiveFrom, c.effectiveTo),
                        ?siteNames[c.siteId],
                      ],
                      onTap: () => open(ContractFormScreen.pay(workerId: worker.id, pay: c)),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RateTab extends StatelessWidget {
  const _RateTab({required this.rows, required this.emptyText, required this.addLabel, required this.onAdd});

  final List<Widget> rows;
  final String emptyText;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: rows.isEmpty
              ? EmptyState(icon: Icons.sell, text: emptyText)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => rows[i],
                ),
        ),
        MainActionBar(label: addLabel, onPressed: onAdd),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.tag, required this.name, required this.details, required this.onTap});

  final String tag;
  final String name;
  final List<String> details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RowCard(
      child: ListTile(
        leading: RowTag(tag),
        title: Text(name),
        subtitle: Text(details.join(', ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
