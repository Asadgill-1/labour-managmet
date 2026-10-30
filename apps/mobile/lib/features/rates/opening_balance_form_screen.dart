import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

const salaryOwed = 'worker_salary_owed';
const workerAdvance = 'worker_advance';
const clientReceivable = 'client_receivable';

/// A figure carried over from before this app (MASTER-05). Three kinds, kept apart,
/// each with a date, a source and the owner's confirmation. Never counted as this month's expense.
class OpeningBalanceFormScreen extends ConsumerStatefulWidget {
  const OpeningBalanceFormScreen({required this.kind, this.workerId, this.clientId, this.existing, super.key});

  final String kind;
  final String? workerId;
  final String? clientId;
  final OpeningBalance? existing;

  @override
  ConsumerState<OpeningBalanceFormScreen> createState() => _OpeningBalanceFormScreenState();
}

class _OpeningBalanceFormScreenState extends ConsumerState<OpeningBalanceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _amount = TextEditingController(text: widget.existing == null ? '' : plainAmount(widget.existing!.amountFils));
  late final _note = TextEditingController(text: widget.existing?.sourceNote);
  late String? _asOf = widget.existing?.asOfDate ?? dubaiToday(DateTime.now());
  bool _confirmed = false;
  String? _confirmError;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _confirmError = _confirmed ? null : l10n.confirmRequired);
    if (!validateAndReveal(_form) || !_confirmed) return;
    final db = ref.read(dbProvider);
    await db.saveRow(
      db.openingBalances,
      id: widget.existing?.id,
      operationId: _operationId,
      fields: OpeningBalancesCompanion(
        kind: Value(widget.kind),
        workerId: Value(widget.workerId),
        clientId: Value(widget.clientId),
        amountFils: Value(parseAed(_amount.text)!),
        asOfDate: Value(_asOf!),
        sourceNote: Value(_note.text.trim()),
      ),
    );
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(openingLabel(l10n, widget.kind))),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            Text(l10n.openingHelp),
            fieldGap,
            Field(
              l10n.amountAed,
              _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => parseAed(v ?? '') == null ? l10n.amountInvalid : null,
            ),
            fieldGap,
            DateField(l10n.asOfDate, value: _asOf, onChanged: (v) => setState(() => _asOf = v), required: true),
            fieldGap,
            Field(
              l10n.sourceNote,
              _note,
              helper: l10n.sourceNoteHelp,
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.openingConfirm),
              subtitle: _confirmError == null
                  ? null
                  : Text(_confirmError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v!),
            ),
          ],
        ),
      ),
    );
  }
}

String openingLabel(AppLocalizations l10n, String kind) => switch (kind) {
  salaryOwed => l10n.openingSalaryOwed,
  workerAdvance => l10n.openingAdvance,
  _ => l10n.openingReceivable,
};
