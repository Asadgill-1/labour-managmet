import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'contract_form_screen.dart';
import 'opening_balance_form_screen.dart';
import 'rate_labels.dart';

void _open(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

String? _siteName(List<Site> sites, String? siteId) {
  if (siteId == null) return null;
  return sites.where((s) => s.id == siteId).map((s) => s.name).firstOrNull;
}

/// A worker's pay contracts and carried-over balances, on the worker's screen.
class WorkerRateSections extends ConsumerWidget {
  const WorkerRateSections({required this.workerId, super.key});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contracts = ref.watch(payContractsProvider(workerId)).value ?? const <PayContract>[];
    final sites = ref.watch(allSitesProvider).value ?? const <Site>[];
    return Column(
      children: [
        SectionHeader(
          l10n.payContractsHeading,
          action: TextButton(
            onPressed: () => _open(context, ContractFormScreen.pay(workerId: workerId)),
            child: Text(l10n.addPayContract),
          ),
        ),
        const Divider(),
        if (contracts.isEmpty) ListTile(title: Text(l10n.noPayContract)),
        for (final c in contracts) ...[
          ListTile(
            title: Text(rateSummary(l10n, c.basis, c.rateFils), style: amountStyle),
            subtitle: Text([dateRange(l10n, c.effectiveFrom, c.effectiveTo), ?_siteName(sites, c.siteId)].join(', ')),
            trailing: const Icon(Icons.edit),
            onTap: () => _open(context, ContractFormScreen.pay(workerId: workerId, pay: c)),
          ),
          const Divider(),
        ],
        SectionHeader(l10n.openingHeading),
        const Divider(),
        _OpeningTile(kind: salaryOwed, workerId: workerId),
        const Divider(),
        _OpeningTile(kind: workerAdvance, workerId: workerId),
        const Divider(),
      ],
    );
  }
}

/// A client's billing rates and carried-over receivable, on the client's screen.
class ClientRateSections extends ConsumerWidget {
  const ClientRateSections({required this.clientId, super.key});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contracts = ref.watch(billingContractsProvider(clientId)).value ?? const <BillingContract>[];
    final sites = ref.watch(allSitesProvider).value ?? const <Site>[];
    final workers = ref.watch(workersProvider).value ?? const <Worker>[];
    String? workerName(String? id) => id == null ? null : workers.where((w) => w.id == id).map((w) => w.name).firstOrNull;
    return Column(
      children: [
        SectionHeader(
          l10n.billingContractsHeading,
          action: TextButton(
            onPressed: () => _open(context, ContractFormScreen.billing(clientId: clientId)),
            child: Text(l10n.addBillingContract),
          ),
        ),
        const Divider(),
        if (contracts.isEmpty) ListTile(title: Text(l10n.noBillingContract)),
        for (final c in contracts) ...[
          ListTile(
            title: Text(rateSummary(l10n, c.basis, c.rateFils), style: amountStyle),
            subtitle: Text(
              [dateRange(l10n, c.effectiveFrom, c.effectiveTo), ?_siteName(sites, c.siteId), ?workerName(c.workerId)].join(', '),
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _open(context, ContractFormScreen.billing(clientId: clientId, billing: c)),
          ),
          const Divider(),
        ],
        SectionHeader(l10n.openingHeading),
        const Divider(),
        _OpeningTile(kind: clientReceivable, clientId: clientId),
        const Divider(),
      ],
    );
  }
}

class _OpeningTile extends ConsumerWidget {
  const _OpeningTile({required this.kind, this.workerId, this.clientId});

  final String kind;
  final String? workerId;
  final String? clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balances = ref.watch(openingBalancesProvider).value ?? const <OpeningBalance>[];
    final existing = balances.where((b) => b.kind == kind && b.workerId == workerId && b.clientId == clientId).firstOrNull;
    return ListTile(
      title: Text(openingLabel(l10n, kind)),
      trailing: Text(existing == null ? l10n.notEntered : formatAed(existing.amountFils), style: amountStyle),
      onTap: () => _open(
        context,
        OpeningBalanceFormScreen(kind: kind, workerId: workerId, clientId: clientId, existing: existing),
      ),
    );
  }
}
