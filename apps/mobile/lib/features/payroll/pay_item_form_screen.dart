import 'dart:math';

import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/payroll.dart';
import '../../data/tenant_database.dart';
import '../../data/changes.dart';
import '../../l10n/app_localizations.dart';
import '../changes/change_notes.dart';

/// One allowance or deduction for one worker's month. A deduction needs a reason and an authorization (PAY-07).
/// A room charge carries the worker's note, or else the owner's own say-so (D-041).
class PayItemFormScreen extends ConsumerStatefulWidget {
  const PayItemFormScreen({required this.workerId, required this.month, required this.kind, this.item, super.key});

  final String workerId;
  final String month;
  final PayItemKind kind;
  final PayrollItem? item;

  @override
  ConsumerState<PayItemFormScreen> createState() => _PayItemFormScreenState();
}

class _PayItemFormScreenState extends ConsumerState<PayItemFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _amount = TextEditingController(text: widget.item == null ? _startAmount() : plainAmount(widget.item!.amountFils));
  late final _reason = TextEditingController(text: widget.item?.reason ?? _startReason());
  late final _authorizedBy = TextEditingController(text: widget.item?.authorizedBy);
  late final _note = TextEditingController(text: widget.item?.note);
  final _change = TextEditingController();

  Worker? get _worker => (ref.read(workersProvider).value ?? const <Worker>[]).where((w) => w.id == widget.workerId).firstOrNull;

  WorkerPayroll? get _row => (ref.read(payrollProvider(widget.month)).value ?? const <WorkerPayroll>[]).where((p) => p.worker.id == widget.workerId).firstOrNull;

  bool get _needsAuthorization => widget.kind == PayItemKind.deduction;

  String _startAmount() => switch (widget.kind) {
    PayItemKind.roomCharge when _worker?.roomChargeFils != null => plainAmount(_worker!.roomChargeFils!),
    PayItemKind.advanceRecovery when (_row?.autoRecoveryFils ?? 0) > 0 => plainAmount(_row!.autoRecoveryFils),
    PayItemKind.visaRecovery when (_row?.visaLeftFils ?? 0) > 0 => plainAmount(min(_worker?.visaInstalmentFils ?? _row!.visaLeftFils, _row!.visaLeftFils)),
    _ => '',
  };

  String _startReason() {
    final l10n = AppLocalizations.of(context);
    return switch (widget.kind) {
      PayItemKind.roomCharge => l10n.payKindRoom,
      PayItemKind.advanceRecovery => l10n.payKindRecovery,
      PayItemKind.visaRecovery => l10n.payKindVisa,
      _ => '',
    };
  }

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final text = _note.text.trim();
    try {
      await ref.read(dbProvider).savePayItem(
        id: widget.item?.id,
        workerId: widget.workerId,
        month: widget.month,
        kind: widget.kind,
        amountFils: parseAed(_amount.text)!,
        reason: _reason.text.trim(),
        authorizedBy: switch (widget.kind) {
          PayItemKind.deduction => _authorizedBy.text.trim(),
          PayItemKind.roomCharge => widget.item?.authorizedBy ?? _worker?.roomChargeNote ?? l10n.roomChargeByOwner,
          _ => null,
        },
        note: text.isEmpty ? null : text,
        roomId: widget.kind == PayItemKind.roomCharge ? _worker?.roomId : null,
        operationId: _operationId,
        changeNote: noteOf(_change),
      );
    } on AdvanceTooHigh {
      if (mounted) showFormError(context, l10n.advanceTooHigh);
      return;
    } on VisaTooHigh {
      if (mounted) showFormError(context, l10n.visaTooHigh);
      return;
    } catch (e) {
      if (mounted) showSaveError(context, e);
      return;
    }
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final db = ref.read(dbProvider);
    final gone = await deleteOrArchive(context, (note) => db.deleteRecord(db.payrollItems, widget.item!.id, note: note, operationId: newUuid()), reason: _change.text);
    if (gone && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = payKindLabel(l10n, widget.kind);
    String? required(String? v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null;
    final row = (ref.watch(payrollProvider(widget.month)).value ?? const <WorkerPayroll>[]).where((p) => p.worker.id == widget.workerId).firstOrNull;
    final advanceLeft = row?.advanceLeftFils;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            if (widget.kind == PayItemKind.advanceRecovery && advanceLeft != null) ...[
              Text(l10n.advanceBalance(formatAed(advanceLeft)), style: const TextStyle(color: muted)),
              fieldGap,
            ],
            if (widget.kind == PayItemKind.visaRecovery && row != null) ...[
              Text(l10n.visaBalance(formatAed(row.visaLeftFils)), style: const TextStyle(color: muted)),
              fieldGap,
            ],
            Field(
              l10n.amountAed,
              _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              // A recovery can be nothing: the owner's answer that none of the advance is cut this month (D-057).
              helper: widget.kind == PayItemKind.advanceRecovery ? l10n.recoveryZeroHelp : null,
              validator: (v) => switch (parseAed(v ?? '')) {
                final fils? when fils > 0 || (fils == 0 && widget.kind == PayItemKind.advanceRecovery) => null,
                _ => l10n.amountInvalid,
              },
            ),
            fieldGap,
            Field(l10n.payItemReason, _reason, validator: required),
            fieldGap,
            if (_needsAuthorization) ...[
              Field(l10n.payItemAuthorizedBy, _authorizedBy, helper: l10n.payItemAuthorizedHelp, validator: required),
              fieldGap,
            ],
            Field(l10n.note, _note),
            if (widget.item != null)
              EditFooter(entity: 'payroll_items', id: widget.item!.id, note: _change, label: l10n.changeNoteItem, onDelete: _delete),
          ],
        ),
      ),
    );
  }
}

String payKindLabel(AppLocalizations l10n, PayItemKind kind) => switch (kind) {
  PayItemKind.allowance => l10n.payKindAllowance,
  PayItemKind.deduction => l10n.payKindDeduction,
  PayItemKind.roomCharge => l10n.payKindRoom,
  PayItemKind.advanceRecovery => l10n.payKindRecovery,
  PayItemKind.visaRecovery => l10n.payKindVisa,
};
