import 'package:domain/cash.dart';
import 'package:domain/dates.dart' as dates;
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/changes.dart';
import '../../data/receipts.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../changes/change_notes.dart';
import '../documents/receipt.dart';
import 'cash_entry_form_screen.dart';

const expenseCategories = ['transport', 'food', 'visa', 'tools', 'office', 'other'];

String categoryLabel(AppLocalizations l10n, String? category) => switch (category) {
  'transport' => l10n.catTransport,
  'food' => l10n.catFood,
  'visa' => l10n.catVisa,
  'tools' => l10n.catTools,
  'office' => l10n.catOffice,
  _ => l10n.catOther,
};

String methodLabel(AppLocalizations l10n, String? method) => switch (method) {
  'cash' => l10n.methodCash,
  'bank' => l10n.methodBank,
  _ => '',
};

String kindLabel(AppLocalizations l10n, CashKind kind) => switch (kind) {
  CashKind.advanceGiven => l10n.kindAdvanceGiven,
  CashKind.salaryPaid => l10n.kindSalaryPaid,
  CashKind.roomRentPaid => l10n.kindRoomRentPaid,
  CashKind.expense => l10n.kindExpense,
  CashKind.advanceReturned => l10n.kindAdvanceReturned,
  CashKind.roomRentReceived => l10n.kindRoomRentReceived,
  CashKind.clientReceipt => l10n.kindClientReceipt,
  CashKind.visaPaid => l10n.kindVisaPaid,
  CashKind.visaReturned => l10n.kindVisaReturned,
};

/// "09-2026: AED 500.00" for each month a salary payment settled (PAY-06).
List<String> salaryPartLabels(Iterable<SalaryAllocation> parts) => [for (final p in parts) '${dates.showMonth(p.month)}: ${formatAed(p.amountFils)}'];

/// "INV-2026-0001: AED 500.00" for each invoice a company's receipt settled (INV-05).
List<String> receiptPartLabels(AppLocalizations l10n, Iterable<ReceiptPart> parts) => [
  for (final p in parts) '${p.number ?? l10n.receiptOldBalance}: ${formatAed(p.fils)}',
];

/// Everything in a list that has been undone. Pass the list's own rows.
Set<String> undoneIds(Iterable<CashEntry> rows) => {for (final e in rows) ?e.reversesEntryId};

/// The lines a list shows: a deleted line and its reversal both leave it, for the Delete tab (D-056). Totals still
/// come from every row, where the two cancel. A reversal from before, on another day, still shows with its tag.
List<CashEntry> liveCash(Iterable<CashEntry> rows) {
  final ids = {for (final e in rows) e.id};
  final undone = undoneIds(rows);
  return [
    for (final e in rows)
      if (!undone.contains(e.id) && !ids.contains(e.reversesEntryId)) e,
  ];
}

/// One line of the cash book. Tapping a live line offers to edit or delete it, and a receipt where there is one.
class CashEntryRow extends ConsumerWidget {
  const CashEntryRow(this.entry, {required this.undone, this.showDate = false, this.onWorkerScreen = false, super.key});

  final CashEntry entry;

  /// A reversal of this line exists.
  final bool undone;
  final bool showDate;

  /// The worker's name is already the screen's title, so the row leads with what the money was.
  final bool onWorkerScreen;

  /// Deletes the line by its reversal on its own date, opening a closed month first (D-056).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final note = await askDeleteNote(context);
    if (note == null || !context.mounted) return;
    try {
      final opened = await ref.read(dbProvider).deleteCash(entry, note: note.isEmpty ? null : note, reopenReason: l10n.reopenByEdit, operationId: newUuid());
      if (context.mounted) showSavedOnPhone(context, opened.isNotEmpty ? l10n.monthsOpened(opened.map(dates.showMonth).join(', ')) : l10n.deletedDone);
    } on AdvanceTooHigh {
      if (context.mounted) showFormError(context, l10n.advanceUndoBlocked);
    } on VisaTooHigh {
      if (context.mounted) showFormError(context, l10n.visaUndoBlocked);
    } catch (e) {
      if (context.mounted) showFormError(context, saveErrorText(l10n, e));
    }
  }

  /// Money handed to a worker, or paid by a company, can have a receipt. Every line can be edited or deleted (D-056).
  Future<void> _tap(BuildContext context, WidgetRef ref, CashKind kind) async {
    final forWorker = (kind == CashKind.salaryPaid || kind == CashKind.advanceGiven) && entry.workerId != null;
    final fromCompany = kind == CashKind.clientReceipt && entry.reversesEntryId == null;
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (forWorker || fromCompany) ...[
              ListTile(leading: const Icon(Icons.receipt_long), title: Text(l10n.receiptMake), onTap: () => Navigator.of(sheet).pop('receipt')),
              const Divider(),
            ],
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.cashEdit), onTap: () => Navigator.of(sheet).pop('edit')),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: due),
              title: Text(l10n.deleteAction, style: const TextStyle(color: due)),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'receipt' when fromCompany:
        await shareClientReceipt(context, ref, entry, onBusy: (_) {});
      case 'receipt':
        await shareReceipt(context, ref, entry, onBusy: (_) {});
      case 'edit':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(editing: entry)));
      default:
        await _delete(context, ref);
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
    final settles = kind == CashKind.salaryPaid && !reversal
        ? ref.watch(allocationsOfPaymentProvider(entry.id)).value ?? const <SalaryAllocation>[]
        : const <SalaryAllocation>[];
    final parts = kind == CashKind.clientReceipt && !reversal ? ref.watch(receiptPartsProvider(entry.id)).value : null;
    final invoiced = parts ?? const <ReceiptPart>[];
    final credit = parts == null ? 0 : entry.amountFils - parts.fold<int>(0, (total, p) => total + p.fils);
    final title = onWorkerScreen ? what : (worker?.name ?? room?.name ?? client?.name ?? categoryLabel(l10n, entry.category));
    final signIsPlus = moneyIn != reversal;
    final amount = '${signIsPlus ? '+' : '-'}${formatAed(entry.amountFils)}';
    final changes = (ref.watch(editsProvider('cash_entries')).value ?? const <String, List<ChangeNote>>{})[entry.id] ?? const <ChangeNote>[];
    return RowCard(
      edited: changes.isNotEmpty,
      child: ListTile(
        leading: reversal || undone
            ? const RowTag.icon(Icons.undo, fill: paper, color: muted)
            : (moneyIn
                  ? const RowTag.icon(Icons.south_west, fill: settledSoft, color: settled)
                  : const RowTag.icon(Icons.north_east, fill: warnSoft, color: warn)),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (!onWorkerScreen) what,
                if (changes.isNotEmpty) l10n.editedTag,
                if (undone) l10n.reversedTag,
                if (worker != null) ?room?.name,
                ?site?.name,
                if (showDate) dates.showDate(entry.entryDate),
                if (entry.method == 'bank') l10n.methodBank,
                ...salaryPartLabels(settles),
                ...receiptPartLabels(l10n, invoiced),
                if (credit > 0 && !undone) '${l10n.receiptKeptAsCredit}: ${formatAed(credit)}',
                ?entry.reference,
                ?entry.receiver,
                ?entry.note,
              ].join(', '),
            ),
            if (changes.isNotEmpty) ChangeNotes(changes),
          ],
        ),
        trailing: RowValue(
          amount,
          style: undone
              ? amountStyle.copyWith(color: muted, decoration: TextDecoration.lineThrough)
              : amountStyle.copyWith(color: reversal ? muted : (moneyIn ? settled : due)),
        ),
        onTap: reversal || undone ? null : () => _tap(context, ref, kind),
      ),
    );
  }
}
