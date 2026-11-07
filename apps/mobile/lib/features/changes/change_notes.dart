import 'package:domain/cash.dart';
import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/changes.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_row.dart';
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
  Fact.worker => l10n.colWorker,
  Fact.company => l10n.colCompany,
  Fact.site => l10n.colSite,
  Fact.room => l10n.colRoom,
  Fact.status => l10n.filterStatus,
  Fact.time => l10n.factTime,
  Fact.breakMinutes => l10n.colBreak,
  Fact.overtimeMinutes => l10n.colOvertime,
  Fact.bill => l10n.colBill,
  Fact.pay => l10n.colPay,
  Fact.kind => l10n.colKind,
  Fact.amount => l10n.tsAmount,
  Fact.method => l10n.receiptMethod,
  Fact.reference => l10n.factReference,
  Fact.category => l10n.expenseCategory,
  Fact.note => l10n.note,
};

/// A fact in words, or a dash when it had none.
String factValue(AppLocalizations l10n, Fact fact, Object? value) {
  if (value == null) return '-';
  return switch (fact) {
    Fact.date => showDate(value as String),
    Fact.status => AttendanceStatus.values.asNameMap()[value] == null ? '$value' : statusLabel(l10n, AttendanceStatus.values.byName(value as String)),
    Fact.breakMinutes || Fact.overtimeMinutes => showDuration(value as int),
    Fact.bill || Fact.pay || Fact.amount => formatAed(value as int),
    Fact.kind => CashKind.values.asNameMap()[value] == null ? '$value' : kindLabel(l10n, CashKind.values.byName(value as String)),
    Fact.method => methodLabel(l10n, value as String),
    Fact.category => categoryLabel(l10n, value as String),
    _ => '$value',
  };
}

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
