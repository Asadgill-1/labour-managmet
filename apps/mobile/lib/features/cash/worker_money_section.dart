import 'package:domain/cash.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'cash_entry_form_screen.dart';
import 'cash_row.dart';

/// This worker's account: pay still owed from posted months, advance, and what the cash book has sent here (REP-08).
class WorkerMoneySection extends ConsumerWidget {
  const WorkerMoneySection({required this.workerId, super.key});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(cashOfWorkerProvider(workerId)).value ?? const <CashEntry>[];
    final balances = ref.watch(openingBalancesProvider).value ?? const <OpeningBalance>[];
    int openingOf(String kind) => balances.where((b) => b.kind == kind && b.workerId == workerId).fold(0, (total, b) => total + b.amountFils);
    final posted = ref.watch(linesOfWorkerProvider(workerId)).value ?? const <PayrollLine>[];
    final recovered = posted.fold(0, (total, l) => total + l.recoveryFils);
    final deductedRent = (ref.watch(roomChargesOfWorkerProvider(workerId)).value ?? const <PayrollItem>[]).fold(0, (total, i) => total + i.amountFils);
    final lines = rows.map(cashLine).toList();
    final owed = salaryOwed(openingOf('worker_salary_owed'), posted.fold(0, (total, l) => total + l.netFils + l.adjustmentFils), lines);
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
        if (owed < 0) InfoRow(l10n.payrollOverpaid, formatAed(-owed)) else InfoRow(l10n.salaryOwed, formatAed(owed)),
        const Divider(),
        InfoRow(l10n.advanceOutstanding, formatAed(advanceOutstanding(openingOf('worker_advance'), lines, recoveredFils: recovered))),
        const Divider(),
        InfoRow(l10n.visaLeft, formatAed(visaOutstanding(lines, recoveredFils: posted.fold(0, (total, l) => total + l.visaRecoveryFils)))),
        const Divider(),
        InfoRow(l10n.salaryPaidTotal, formatAed(salaryPaidTotal(lines))),
        const Divider(),
        InfoRow(l10n.workerRentTotal, formatAed(roomResult(lines, deductedFils: deductedRent).receivedFils)),
        const Divider(),
        for (final entry in rows) ...[
          CashEntryRow(entry, undone: undone.contains(entry.id), showDate: true, onWorkerScreen: true),
          const Divider(),
        ],
      ],
    );
  }
}
