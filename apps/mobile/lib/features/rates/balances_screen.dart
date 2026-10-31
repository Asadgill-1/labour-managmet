import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'opening_balance_form_screen.dart';

/// Every figure carried over from before this app, in one place (D-027). Entered with the same
/// form as the company and worker screens, so the date, source and confirmation rules still apply.
class BalancesScreen extends ConsumerWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final workers = ref.watch(workersProvider).value ?? const <Worker>[];
    final balances = ref.watch(openingBalancesProvider).value ?? const <OpeningBalance>[];
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    Future<void> add() async {
      final kind = await chooseOne(context, l10n.balanceKind, [
        (value: salaryOwed, label: l10n.openingSalaryOwed),
        (value: workerAdvance, label: l10n.openingAdvance),
        (value: clientReceivable, label: l10n.openingReceivable),
      ]);
      if (kind == null || !context.mounted) return;
      final forClient = kind == clientReceivable;
      final id = await chooseOne(context, forClient ? l10n.chooseClient : l10n.chooseWorker, [
        if (forClient)
          for (final c in clients.where((c) => c.active)) (value: c.id, label: c.name)
        else
          for (final w in workers.where((w) => w.active)) (value: w.id, label: '${w.name} (${w.code})'),
      ]);
      if (id == null || !context.mounted) return;
      final workerId = forClient ? null : id;
      final clientId = forClient ? id : null;
      final existing = balances.where((b) => b.kind == kind && b.workerId == workerId && b.clientId == clientId).firstOrNull;
      open(OpeningBalanceFormScreen(kind: kind, workerId: workerId, clientId: clientId, existing: existing));
    }

    Widget row(OpeningBalance b, String tag, String name) => ListTile(
      leading: RowTag(tag),
      title: Text(name),
      subtitle: Text('${openingLabel(l10n, b.kind)}, ${showDate(b.asOfDate)}'),
      trailing: RowValue(formatAed(b.amountFils)),
      onTap: () => open(OpeningBalanceFormScreen(kind: b.kind, workerId: b.workerId, clientId: b.clientId, existing: b)),
    );

    final rows = [
      for (final w in workers)
        for (final b in balances.where((b) => b.workerId == w.id)) row(b, w.code, w.name),
      for (final c in clients)
        for (final b in balances.where((b) => b.clientId == c.id)) row(b, initial(c.name), c.name),
    ];

    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.openingHeading)),
      bottomNavigationBar: MainActionBar(label: l10n.addBalance, onPressed: add),
      body: rows.isEmpty
          ? EmptyState(icon: Icons.history, text: l10n.balancesEmpty)
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) => rows[i],
            ),
    );
  }
}
