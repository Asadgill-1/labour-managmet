import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/statement.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_entry_form_screen.dart';

/// A reminder wherever the owner starts their day, while any finished month is still unpaid (PAY-08).
class WagesDueBanner extends ConsumerWidget {
  const WagesDueBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final due = ref.watch(wagesDueProvider).value ?? const <WorkerWagesDue>[];
    if (due.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: warnSoft,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          tileColor: Colors.transparent,
          leading: const Icon(Icons.schedule, color: warn),
          title: Text(
            l10n.wagesDueBanner(due.length, formatAed(due.fold(0, (total, w) => total + w.totalFils))),
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: warn),
          ),
          subtitle: Text(l10n.wagesDueOldest(showMonth(due.first.wages.first.month)), style: const TextStyle(color: warn)),
          trailing: const Icon(Icons.chevron_right, color: warn),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WagesDueScreen())),
        ),
      ),
    );
  }
}

/// Who is still waiting for pay, for which month, and how late it is. Tapping a worker opens their payment.
class WagesDueScreen extends ConsumerWidget {
  const WagesDueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(wagesDueProvider).value ?? const <WorkerWagesDue>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wagesDueTitle)),
      body: ListView(
        children: [
          TopBand(
            child: Row(
              children: [
                Expanded(child: BandFigure(formatAed(rows.fold(0, (total, w) => total + w.totalFils)), l10n.wagesDueTotal, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure('${rows.length}', l10n.wagesDueWorkers, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty) EmptyState(icon: Icons.task_alt, text: l10n.wagesDueNone),
          for (final w in rows)
            RowCard(
              child: ListTile(
                leading: RowTag(initial(w.worker.name)),
                title: Row(
                  children: [
                    Expanded(child: Text(w.worker.name)),
                    const SizedBox(width: 8),
                    RowValue(formatAed(w.totalFils)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final wage in w.wages)
                      Text(
                        '${showMonth(wage.month)}: ${formatAed(wage.fils)}, ${wage.overdue ? l10n.wagesDueLate(wage.daysLate) : l10n.wagesDueInTime}',
                        style: TextStyle(color: wage.overdue ? due : muted),
                      ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(kind: CashKind.salaryPaid, workerId: w.worker.id, amountFils: w.totalFils)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(l10n.wagesDueNote, style: const TextStyle(color: muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
