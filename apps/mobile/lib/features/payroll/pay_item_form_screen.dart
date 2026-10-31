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
import '../../l10n/app_localizations.dart';

/// One allowance or deduction for one worker's month. A deduction needs a reason and an authorization (PAY-07).
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
  late final _authorizedBy = TextEditingController(text: widget.item?.authorizedBy ?? (widget.kind == PayItemKind.roomCharge ? _worker?.roomChargeNote : null));
  late final _note = TextEditingController(text: widget.item?.note);

  Worker? get _worker => (ref.read(workersProvider).value ?? const <Worker>[]).where((w) => w.id == widget.workerId).firstOrNull;

  WorkerPayroll? get _row => (ref.read(payrollProvider(widget.month)).value ?? const <WorkerPayroll>[]).where((p) => p.worker.id == widget.workerId).firstOrNull;

  bool get _needsAuthorization => widget.kind == PayItemKind.deduction || widget.kind == PayItemKind.roomCharge;

  String _startAmount() => switch (widget.kind) {
    PayItemKind.roomCharge when _worker?.roomChargeFils != null => plainAmount(_worker!.roomChargeFils!),
    PayItemKind.advanceRecovery when (_row?.advanceLeftFils ?? 0) > 0 => plainAmount(_row!.advanceLeftFils),
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
        authorizedBy: _needsAuthorization ? _authorizedBy.text.trim() : null,
        note: text.isEmpty ? null : text,
        roomId: widget.kind == PayItemKind.roomCharge ? _worker?.roomId : null,
        operationId: _operationId,
      );
    } on AdvanceTooHigh {
      if (mounted) showFormError(context, l10n.advanceTooHigh);
      return;
    } on VisaTooHigh {
      if (mounted) showFormError(context, l10n.visaTooHigh);
      return;
    } catch (_) {
      if (mounted) showFormError(context, l10n.saveFailed);
      return;
    }
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final saved = await saveOrExplain(context, () => ref.read(dbProvider).deletePayItem(widget.item!, operationId: newUuid()));
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (widget.kind) {
      PayItemKind.allowance => l10n.payKindAllowance,
      PayItemKind.deduction => l10n.payKindDeduction,
      PayItemKind.roomCharge => l10n.payKindRoom,
      PayItemKind.advanceRecovery => l10n.payKindRecovery,
      PayItemKind.visaRecovery => l10n.payKindVisa,
    };
    String? required(String? v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null;
    final row = (ref.watch(payrollProvider(widget.month)).value ?? const <WorkerPayroll>[]).where((p) => p.worker.id == widget.workerId).firstOrNull;
    final advanceLeft = row?.advanceLeftFils;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.item != null) IconButton(tooltip: l10n.payItemDelete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
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
              validator: (v) => (parseAed(v ?? '') ?? 0) <= 0 ? l10n.amountInvalid : null,
            ),
            fieldGap,
            Field(l10n.payItemReason, _reason, validator: required),
            fieldGap,
            if (_needsAuthorization) ...[
              Field(l10n.payItemAuthorizedBy, _authorizedBy, helper: l10n.payItemAuthorizedHelp, validator: required),
              fieldGap,
            ],
            Field(l10n.note, _note),
          ],
        ),
      ),
    );
  }
}
