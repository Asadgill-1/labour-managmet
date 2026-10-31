import 'package:domain/cash.dart';
import 'package:domain/dates.dart' as dates;
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

const expenseCategories = ['transport', 'food', 'visa', 'tools', 'office', 'other'];

String categoryLabel(AppLocalizations l10n, String? category) => switch (category) {
  'transport' => l10n.catTransport,
  'food' => l10n.catFood,
  'visa' => l10n.catVisa,
  'tools' => l10n.catTools,
  'office' => l10n.catOffice,
  _ => l10n.catOther,
};

String kindLabel(AppLocalizations l10n, CashKind kind) => switch (kind) {
  CashKind.advanceGiven => l10n.kindAdvanceGiven,
  CashKind.salaryPaid => l10n.kindSalaryPaid,
  CashKind.roomRentPaid => l10n.kindRoomRentPaid,
  CashKind.expense => l10n.kindExpense,
  CashKind.advanceReturned => l10n.kindAdvanceReturned,
  CashKind.roomRentReceived => l10n.kindRoomRentReceived,
  CashKind.clientReceipt => l10n.kindClientReceipt,
};

/// Everything in a list that has been undone. Pass the list's own rows.
Set<String> undoneIds(Iterable<CashEntry> rows) => {for (final e in rows) ?e.reversesEntryId};

/// One line of the cash book. Tapping a live line offers to undo it.
class CashEntryRow extends ConsumerWidget {
  const CashEntryRow(this.entry, {required this.undone, this.showDate = false, this.onWorkerScreen = false, super.key});

  final CashEntry entry;

  /// A reversal of this line exists.
  final bool undone;
  final bool showDate;

  /// The worker's name is already the screen's title, so the row leads with what the money was.
  final bool onWorkerScreen;

  Future<void> _undo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.reverseTitle),
        content: Form(
          key: form,
          child: Field(l10n.reverseReason, reason, helper: l10n.reverseHelp, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(dialog).pop(true);
            },
            child: Text(l10n.reverseConfirm),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      await ref.read(dbProvider).reverseCashEntry(entry, reason: reason.text.trim(), operationId: newUuid());
      if (context.mounted) showSavedOnPhone(context, l10n.savedOnPhone);
    } on AdvanceTooHigh {
      if (context.mounted) showFormError(context, l10n.advanceUndoBlocked);
    } catch (_) {
      if (context.mounted) showFormError(context, l10n.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kind = CashKind.values.byName(entry.kind);
    final reversal = entry.reversesEntryId != null;
    final moneyIn = isMoneyIn(kind);
    final worker = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.id == entry.workerId).firstOrNull;
    final room = (ref.watch(roomsProvider).value ?? const <Room>[]).where((r) => r.id == entry.roomId).firstOrNull;
    final client = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.id == entry.clientId).firstOrNull;
    final site = (ref.watch(allSitesProvider).value ?? const <Site>[]).where((s) => s.id == entry.siteId).firstOrNull;
    final what = reversal ? l10n.reversalTag : kindLabel(l10n, kind);
    final title = onWorkerScreen ? what : (worker?.name ?? room?.name ?? client?.name ?? categoryLabel(l10n, entry.category));
    final signIsPlus = moneyIn != reversal;
    final amount = '${signIsPlus ? '+' : '-'}${formatAed(entry.amountFils)}';
    return GrowingRow(
      child: ListTile(
        leading: reversal || undone
            ? const RowTag.icon(Icons.undo, fill: paper, color: muted)
            : (moneyIn ? const RowTag.icon(Icons.south_west, fill: settledSoft, color: settled) : const RowTag.icon(Icons.north_east, fill: hiVisSoft, color: ink)),
        title: Text(title),
        subtitle: Text(
          [
            if (!onWorkerScreen) what,
            if (undone) l10n.reversedTag,
            if (worker != null) ?room?.name,
            ?site?.name,
            if (showDate) dates.showDate(entry.entryDate),
            if (entry.method == 'bank') l10n.methodBank,
            ?entry.note,
          ].join(', '),
        ),
        trailing: RowValue(
          amount,
          style: undone
              ? amountStyle.copyWith(color: muted, decoration: TextDecoration.lineThrough)
              : amountStyle.copyWith(color: reversal ? muted : (moneyIn ? settled : ink)),
        ),
        onTap: reversal || undone ? null : () => _undo(context, ref),
      ),
    );
  }
}
