import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/changes.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../changes/change_notes.dart';
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
        if (contracts.isEmpty) ListTile(subtitle: Text(l10n.noPayContract)),
        for (final c in contracts)
          _RateTile(
            entity: 'pay_contracts',
            id: c.id,
            title: rateSummary(l10n, c.basis, c.rateFils),
            about: [dateRange(l10n, c.effectiveFrom, c.effectiveTo), ?_siteName(sites, c.siteId)],
            onTap: () => _open(context, ContractFormScreen.pay(workerId: workerId, pay: c)),
          ),
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
        if (contracts.isEmpty) ListTile(subtitle: Text(l10n.noBillingContract)),
        for (final c in contracts)
          _RateTile(
            entity: 'billing_contracts',
            id: c.id,
            title: rateSummary(l10n, c.basis, c.rateFils),
            about: [dateRange(l10n, c.effectiveFrom, c.effectiveTo), ?_siteName(sites, c.siteId), ?workerName(c.workerId)],
            onTap: () => _open(context, ContractFormScreen.billing(clientId: clientId, billing: c)),
          ),
        SectionHeader(l10n.openingHeading),
        const Divider(),
        _OpeningTile(kind: clientReceivable, clientId: clientId),
        const Divider(),
      ],
    );
  }
}

/// One rate, tinted with what changed under it when someone edited it (D-056).
class _RateTile extends ConsumerWidget {
  const _RateTile({required this.entity, required this.id, required this.title, required this.about, required this.onTap});

  final String entity;
  final String id;
  final String title;
  final List<String> about;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notes = notesOf(ref, entity, id);
    return RowCard(
      edited: notes.isNotEmpty,
      child: ListTile(
        title: Text(title, style: amountStyle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([...about, if (notes.isNotEmpty) l10n.editedTag].join(', ')),
            if (notes.isNotEmpty) ChangeNotes(notes),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
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
    final notes = existing == null ? const <ChangeNote>[] : notesOf(ref, 'opening_balances', existing.id);
    final row = InfoRow(
      openingLabel(l10n, kind),
      existing == null ? l10n.notEntered : formatAed(existing.amountFils),
      onTap: () => _open(
        context,
        OpeningBalanceFormScreen(kind: kind, workerId: workerId, clientId: clientId, existing: existing),
      ),
    );
    if (notes.isEmpty) return row;
    return RowCard(
      edited: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: ChangeNotes(notes)),
        ],
      ),
    );
  }
}
