import 'package:domain/cash.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'cash_entry_form_screen.dart';
import 'cash_row.dart';

/// What the daily cash book has sent to this worker's account. Earned wages join this with payroll in T11.
class WorkerMoneySection extends ConsumerWidget {
  const WorkerMoneySection({required this.workerId, super.key});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(cashOfWorkerProvider(workerId)).value ?? const <CashEntry>[];
    final opening = (ref.watch(openingBalancesProvider).value ?? const <OpeningBalance>[])
        .where((b) => b.kind == 'worker_advance' && b.workerId == workerId)
        .fold(0, (total, b) => total + b.amountFils);
    final lines = rows.map(cashLine).toList();
    final undone = undoneIds(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l10n.moneyHeading,
          action: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(workerId: workerId))),
            child: Text(l10n.addCash),
          ),
        ),
        const Divider(),
        InfoRow(l10n.advanceOutstanding, formatAed(advanceOutstanding(opening, lines))),
        const Divider(),
        InfoRow(l10n.salaryPaidTotal, formatAed(salaryPaidTotal(lines))),
        const Divider(),
        InfoRow(l10n.workerRentTotal, formatAed(roomResult(lines).receivedFils)),
        const Divider(),
        for (final entry in rows) ...[
          CashEntryRow(entry, undone: undone.contains(entry.id), showDate: true, onWorkerScreen: true),
          const Divider(),
        ],
      ],
    );
  }
}
