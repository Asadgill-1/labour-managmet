import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_entry_form_screen.dart';
import '../cash/cash_row.dart';

/// One worker's visa money, their monthly instalment and every line behind the figures (D-039).
class VisaWorkerScreen extends ConsumerWidget {
  const VisaWorkerScreen({required this.workerId, super.key});

  final String workerId;

  Future<void> _setInstalment(BuildContext context, WidgetRef ref, Worker worker) async {
    final l10n = AppLocalizations.of(context);
    final picked = await askDailyWage(
      context,
      title: l10n.visaInstalment,
      label: l10n.visaInstalment,
      helper: l10n.visaInstalmentHelp,
      initial: worker.visaInstalmentFils,
    );
    if (picked == null || !context.mounted) return;
    final fils = picked.fils == 0 ? null : picked.fils;
    final saved = await saveOrExplain(
      context,
      () => ref.read(dbProvider).saveRow(ref.read(dbProvider).workers, id: worker.id, operationId: newUuid(), fields: WorkersCompanion(visaInstalmentFils: Value(fils))),
    );
    if (saved && context.mounted) showSavedOnPhone(context, l10n.savedOnPhone);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final worker = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.id == workerId).firstOrNull;
    if (worker == null) return Scaffold(appBar: AppBar());
    final rows = (ref.watch(cashOfWorkerProvider(workerId)).value ?? const <CashEntry>[])
        .where((c) => c.kind == CashKind.visaPaid.name || c.kind == CashKind.visaReturned.name)
        .toList();
    final posted = (ref.watch(linesOfWorkerProvider(workerId)).value ?? const <PayrollLine>[]).where((l) => l.visaRecoveryFils > 0).toList()
      ..sort((a, b) => b.periodFrom.compareTo(a.periodFrom));
    final lines = rows.map(cashLine).toList();
    final recovered = posted.fold(0, (total, l) => total + l.visaRecoveryFils);
    final undone = undoneIds(rows);
    final instalment = worker.visaInstalmentFils;
    return Scaffold(
      appBar: AppBar(title: Text(worker.name)),
      bottomNavigationBar: MainActionBar(
        label: l10n.visaAdd,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(kind: CashKind.visaPaid, workerId: workerId))),
      ),
      body: ListView(
        children: [
          TopBand(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: BandFigure(formatAed(visaPaidTotal(lines)), l10n.visaSpent, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure(formatAed(visaReturnedTotal(lines) + recovered), l10n.visaBack, size: 18)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure(formatAed(visaOutstanding(lines, recoveredFils: recovered)), l10n.visaLeft, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RowCard(
            child: ListTile(
              title: Text(l10n.visaInstalment),
              subtitle: Text(instalment == null ? l10n.visaInstalmentOff : formatAed(instalment)),
              trailing: const Icon(Icons.edit),
              onTap: () => _setInstalment(context, ref, worker),
            ),
          ),
          SectionHeader(
            l10n.entriesHeading,
            action: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(kind: CashKind.visaReturned, workerId: workerId))),
              child: Text(l10n.visaReturnAdd),
            ),
          ),
          if (rows.isEmpty && posted.isEmpty) ListTile(subtitle: Text(l10n.cashEmpty)),
          for (final line in posted)
            RowCard(
              child: ListTile(
                leading: const RowTag.icon(Icons.payments, fill: settledSoft, color: settled),
                title: Text(l10n.payKindVisa),
                subtitle: Text(showMonth(line.periodFrom.substring(0, 7))),
                trailing: RowValue('+${formatAed(line.visaRecoveryFils)}', style: amountStyle.copyWith(color: settled)),
              ),
            ),
          for (final entry in rows) CashEntryRow(entry, undone: undone.contains(entry.id), showDate: true, onWorkerScreen: true),
        ],
      ),
    );
  }
}
