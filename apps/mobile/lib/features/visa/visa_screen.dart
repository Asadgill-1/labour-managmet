import 'package:domain/cash.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/visa.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_entry_form_screen.dart';
import 'visa_worker_screen.dart';

/// Visa money for everyone: what the company spent, what came back and what is left (D-039).
class VisaScreen extends ConsumerWidget {
  const VisaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(visaAccountsProvider).value ?? const <VisaAccount>[];
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.tabVisa), bottom: const SubTabs(Section.visa)),
      bottomNavigationBar: MainActionBar(
        label: l10n.visaAdd,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CashEntryFormScreen(kind: CashKind.visaPaid))),
      ),
      body: ListView(
        children: [
          TopBand(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: BandFigure(formatAed(accounts.fold(0, (total, a) => total + a.paidFils)), l10n.visaSpent, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure(formatAed(accounts.fold(0, (total, a) => total + a.backFils)), l10n.visaBack, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure(formatAed(accounts.fold(0, (total, a) => total + a.leftFils)), l10n.visaLeft, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (accounts.isEmpty) EmptyState(icon: Icons.badge, text: l10n.visaEmpty),
          for (final a in accounts)
            RowCard(
              child: ListTile(
                leading: RowTag(initial(a.worker.name)),
                title: Text(a.worker.name),
                subtitle: Text(
                  [
                    l10n.visaSplit(formatAed(a.paidFils), formatAed(a.backFils)),
                    if (a.worker.visaInstalmentFils != null) l10n.visaInstalmentShort(formatAed(a.worker.visaInstalmentFils!)),
                  ].join('\n'),
                ),
                trailing: RowValue(formatAed(a.leftFils), style: amountStyle.copyWith(color: a.leftFils > 0 ? due : settled)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VisaWorkerScreen(workerId: a.worker.id))),
              ),
            ),
        ],
      ),
    );
  }
}
