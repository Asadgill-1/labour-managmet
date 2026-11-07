import 'package:domain/cash.dart';
import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/changes.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_row.dart';
import '../payroll/pay_item_form_screen.dart' show payKindLabel;
import '../rates/opening_balance_form_screen.dart' show openingLabel;
import '../rates/rate_labels.dart';
import '../today/attendance_review_screen.dart' show statusLabel;

/// Asks once before a delete. Nothing needs approving: the entry stays whole on the Delete tab (D-056).
Future<bool> confirmDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.deleteTitle),
      content: Text(l10n.deleteBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: due),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  return yes ?? false;
}

/// Asks before a delete and takes the user's note, which may be left empty. Null means they kept the entry.
Future<String?> askDeleteNote(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final note = TextEditingController();
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.deleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteBody),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: l10n.changeNote),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: due),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.deleteAction),
        ),
      ],
    ),
  );
  // Not disposed here: the dialog's field still draws while it closes.
  return yes == true ? note.text.trim() : null;
}

String factLabel(AppLocalizations l10n, Fact fact) => switch (fact) {
  Fact.date => l10n.colDate,
  Fact.month => l10n.colMonth,
  Fact.worker => l10n.colWorker,
  Fact.company => l10n.colCompany,
  Fact.site => l10n.colSite,
  Fact.room => l10n.colRoom,
  Fact.code => l10n.workerCode,
  Fact.name => l10n.factName,
  Fact.status => l10n.filterStatus,
  Fact.time => l10n.factTime,
  Fact.breakMinutes => l10n.colBreak,
  Fact.overtimeMinutes => l10n.colOvertime,
  Fact.bill => l10n.colBill,
  Fact.pay => l10n.colPay,
  Fact.kind || Fact.payKind || Fact.balanceKind => l10n.colKind,
  Fact.amount => l10n.tsAmount,
  Fact.basis => l10n.rateBasis,
  Fact.rate => l10n.colRate,
  Fact.halfAmount => l10n.halfAmount,
  Fact.includedMinutes => l10n.includedMinutes,
  Fact.overtimeRate => l10n.overtimeRate,
  Fact.breakPaid => l10n.breakIsPaid,
  Fact.partialMethod => l10n.partialMethod,
  Fact.partialDivisor => l10n.partialDivisor,
  Fact.halfDayIsHalf => l10n.halfDayIsHalf,
  Fact.members => l10n.workersHeading,
  Fact.from => l10n.effectiveFrom,
  Fact.to => l10n.effectiveTo,
  Fact.activeFrom => l10n.activeFrom,
  Fact.activeTo => l10n.activeTo,
  Fact.trade => l10n.trade,
  Fact.phone => l10n.phone,
  Fact.contactPerson => l10n.contactPerson,
  Fact.email => l10n.email,
  Fact.address => l10n.address,
  Fact.invoiceAddress => l10n.invoiceAddress,
  Fact.vatRegistered => l10n.clientVatRegistered,
  Fact.trn => l10n.trn,
  Fact.dueDays => l10n.dueDays,
  Fact.poReference => l10n.poReference,
  Fact.location => l10n.siteLocation,
  Fact.joined => l10n.joiningDate,
  Fact.roomCharge => l10n.roomCharge,
  Fact.roomChargeNote => l10n.roomChargeNote,
  Fact.visaInstalment => l10n.visaInstalment,
  Fact.method => l10n.receiptMethod,
  Fact.reference => l10n.factReference,
  Fact.category => l10n.expenseCategory,
  Fact.reason => l10n.payItemReason,
  Fact.authorizedBy => l10n.payItemAuthorizedBy,
  Fact.source => l10n.sourceNote,
  Fact.note => l10n.note,
  Fact.active => l10n.filterActive,
};

/// A fact in words, or a dash when it had none.
String factValue(AppLocalizations l10n, Fact fact, Object? value) {
  if (value == null) return '-';
  T? named<T extends Enum>(List<T> values) => values.asNameMap()[value];
  return switch (fact) {
    Fact.date || Fact.joined || Fact.from || Fact.to || Fact.activeFrom || Fact.activeTo => showDate(value as String),
    Fact.month => showMonth(value as String),
    Fact.status => named(AttendanceStatus.values) == null ? '$value' : statusLabel(l10n, named(AttendanceStatus.values)!),
    Fact.breakMinutes || Fact.overtimeMinutes || Fact.includedMinutes => showDuration(value as int),
    Fact.bill || Fact.pay || Fact.amount || Fact.rate || Fact.halfAmount || Fact.overtimeRate || Fact.roomCharge || Fact.visaInstalment =>
      formatAed(value as int),
    Fact.kind => named(CashKind.values) == null ? '$value' : kindLabel(l10n, named(CashKind.values)!),
    Fact.payKind => named(PayItemKind.values) == null ? '$value' : payKindLabel(l10n, named(PayItemKind.values)!),
    Fact.balanceKind => openingLabel(l10n, value as String),
    Fact.basis => named(RateBasis.values) == null ? '$value' : basisLabel(l10n, named(RateBasis.values)!),
    Fact.partialMethod => switch (named(PartialMethod.values)) {
      PartialMethod.calendarDays => l10n.partialCalendarDays,
      PartialMethod.fixedDivisor => l10n.partialFixedDivisor,
      null => '$value',
    },
    Fact.breakPaid || Fact.halfDayIsHalf || Fact.vatRegistered => value == true ? l10n.yes : l10n.no,
    Fact.active => value == true ? l10n.stateActive : l10n.stateArchived,
    Fact.method => methodLabel(l10n, value as String),
    Fact.category => categoryLabel(l10n, value as String),
    _ => '$value',
  };
}

/// Every fact of a deleted record, each in words, for the Delete tab.
String factsInWords(AppLocalizations l10n, Facts facts, {Set<Fact> leaving = const {}}) => [
  for (final f in Fact.values)
    if (facts[f] != null && !leaving.contains(f)) '${factLabel(l10n, f)}: ${factValue(l10n, f, facts[f])}',
].join('; ');

String _when(DateTime utc) {
  final local = utc.add(dubaiOffset);
  return '${showDate(ymd(local))} ${showMinuteOfDay(local.hour * 60 + local.minute)}';
}

/// The app's own note of one change: when, then each field from and to on a line of its own, in words rather than an
/// arrow the font may lack, so it reads easily.
List<String> systemNote(AppLocalizations l10n, ChangeNote note) {
  final when = _when(note.atUtc);
  if (note.changes.isEmpty) return [l10n.changeNoDetail(when)];
  return [
    l10n.changeSystemNote(when),
    for (final c in note.changes) l10n.changeLine(factLabel(l10n, c.fact), factValue(l10n, c.fact, c.from), factValue(l10n, c.fact, c.to)),
  ];
}

/// When a delete happened, for the Delete tab.
String deletedWhen(DateTime utc) => _when(utc);

/// Under an edited entry: the app's note of each change, then the user's own, oldest first (D-056).
class ChangeNotes extends StatelessWidget {
  const ChangeNotes(this.notes, {super.key});

  final List<ChangeNote> notes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in notes) ...[
            for (final (i, line) in systemNote(l10n, n).indexed)
              Text(line, style: TextStyle(fontSize: 13, height: 1.35, color: editInk, fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400)),
            if (n.note != null)
              Text(
                l10n.changeUserNote(n.note!),
                style: const TextStyle(fontSize: 13, height: 1.35, color: ink, fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
    );
  }
}

/// The notes of one record's edits, oldest first (D-056).
List<ChangeNote> notesOf(WidgetRef ref, String entity, String id) =>
    (ref.watch(editsProvider(entity)).value ?? const <String, List<ChangeNote>>{})[id] ?? const <ChangeNote>[];

/// At the end of a saved record's form: what was changed before, a note for this change, and the record's delete.
class EditFooter extends ConsumerWidget {
  const EditFooter({required this.entity, required this.id, required this.note, this.label, this.onDelete, super.key});

  final String entity;
  final String id;
  final TextEditingController note;

  /// For a form that has a "why" of its own already.
  final String? label;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notes = notesOf(ref, entity, id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fieldGap,
        Field(label ?? l10n.changeNote, note, helper: l10n.changeNoteHelp),
        if (notes.isNotEmpty) ...[fieldGap, ChangeNotes(notes)],
        if (onDelete != null) ...[
          fieldGap,
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            style: OutlinedButton.styleFrom(foregroundColor: due),
            onPressed: onDelete,
            label: Text(l10n.deleteAction),
          ),
        ],
      ],
    );
  }
}

/// A note field's text, or null when it was left empty.
String? noteOf(TextEditingController note) => note.text.trim().isEmpty ? null : note.text.trim();

/// Deletes a saved record after asking once. When entries name it, offers [archive] instead, so they keep its name
/// (D-056). True when it is gone or archived, so the screen can close.
Future<bool> deleteOrArchive(BuildContext context, Future<void> Function(String? note) delete, {Future<void> Function(String? note)? archive}) async {
  final l10n = AppLocalizations.of(context);
  final note = await askDeleteNote(context);
  if (note == null || !context.mounted) return false;
  final why = note.isEmpty ? null : note;
  try {
    await delete(why);
  } on RecordInUse {
    if (!context.mounted) return false;
    if (archive == null) {
      showFormError(context, l10n.inUseArchived);
      return false;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.inUseTitle),
        content: Text(l10n.inUseBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.archive)),
        ],
      ),
    );
    if (yes != true || !context.mounted) return false;
    if (!await saveOrExplain(context, () => archive(why))) return false;
    if (context.mounted) showSavedOnPhone(context, l10n.archivedDone);
    return true;
  } catch (e) {
    if (context.mounted) showFormError(context, saveErrorText(l10n, e));
    return false;
  }
  if (context.mounted) showSavedOnPhone(context, l10n.deletedDone);
  return true;
}
