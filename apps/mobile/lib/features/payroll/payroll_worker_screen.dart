import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/payroll.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_entry_form_screen.dart';
import 'pay_item_form_screen.dart';
import 'payroll_screen.dart';

/// One worker's month, with current earnings and old balance kept apart (PAY-02, PAY-09).
class PayrollWorkerScreen extends ConsumerWidget {
  const PayrollWorkerScreen({required this.workerId, required this.month, super.key});

  final String workerId;

  /// YYYY-MM.
  final String month;

  Future<void> _undo(BuildContext context, WidgetRef ref, PayrollLine line) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(context, title: l10n.payrollUndoTitle, helper: l10n.payrollUndoHelp, confirm: l10n.reverseConfirm);
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(dbProvider).reversePayrollLine(line, reason: reason, operationId: newUuid());
      if (context.mounted) showSavedOnPhone(context, l10n.savedOnPhone);
    } on LaterMonthPosted {
      if (context.mounted) showFormError(context, l10n.payrollUndoLater);
    } catch (_) {
      if (context.mounted) showFormError(context, l10n.saveFailed);
    }
  }

  Widget _addButton(BuildContext context, PayItemKind kind, String label) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayItemFormScreen(workerId: workerId, month: month, kind: kind))),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = (ref.watch(payrollProvider(month)).value ?? const <WorkerPayroll>[]).where((r) => r.worker.id == workerId).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: Text(showMonth(month))),
        body: EmptyState(icon: Icons.payments, text: l10n.payrollEmpty),
      );
    }
    final f = p.figures;
    final closing = p.closingFils;
    return Scaffold(
      appBar: AppBar(title: Text(p.worker.name)),
      bottomNavigationBar: p.posted && closing > 0
          ? MainActionBar(
              label: l10n.payrollPayNow,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(kind: CashKind.salaryPaid, workerId: workerId, amountFils: closing)),
              ),
            )
          : null,
      body: ListView(
        children: [
          ColoredBox(
            color: hiVis,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: closing < 0
                        ? BandFigure(formatAed(-closing), l10n.payrollOverpaid)
                        : BandFigure(formatAed(closing), p.posted ? l10n.payrollClosing : l10n.payrollToPay),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: BandFigure(showMonth(month), p.posted ? l10n.payrollStatePosted : l10n.payrollStateDraft, size: 19)),
                ],
              ),
            ),
          ),
          for (final issue in f.issues)
            ListTile(
              leading: const Icon(Icons.warning_amber, color: due),
              title: Text(issueText(l10n, issue, p), style: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w600, color: due)),
            ),
          SectionHeader(l10n.payrollEarnedHeading),
          const Divider(),
          if (f.earnedFils != 0 || f.salaryFils == 0) ...[
            InfoRow(l10n.payrollEarned, formatAed(f.earnedFils)),
            const Divider(),
          ],
          if (f.salaryFils != 0) ...[
            InfoRow(l10n.payrollSalary, formatAed(f.salaryFils)),
            const Divider(),
          ],
          SectionHeader(l10n.payrollItemsHeading),
          const Divider(),
          for (final item in p.items) ...[
            _ItemRow(item, month: month, posted: p.posted),
            const Divider(),
          ],
          if (p.items.isEmpty) ...[
            ListTile(subtitle: Text(l10n.payrollNoItems)),
            const Divider(),
          ],
          if (!p.posted)
            _TwoColumns(
              children: [
                _addButton(context, PayItemKind.allowance, l10n.payKindAllowance),
                _addButton(context, PayItemKind.deduction, l10n.payKindDeduction),
                if (p.needsRoomCharge) _addButton(context, PayItemKind.roomCharge, l10n.payKindRoom),
                if (p.advanceLeftFils > 0) _addButton(context, PayItemKind.advanceRecovery, l10n.payKindRecovery),
              ],
            ),
          SectionHeader(l10n.payrollSumHeading),
          const Divider(),
          InfoRow(l10n.payrollNet, formatAed(f.netFils)),
          const Divider(),
          if (f.adjustmentFils != 0) ...[
            InfoRow(l10n.payrollAdjustment, formatAed(f.adjustmentFils)),
            const Divider(),
          ],
          if (p.openingFils < 0)
            InfoRow(l10n.payrollPaidAhead, formatAed(-p.openingFils))
          else
            InfoRow(l10n.payrollOpening, formatAed(p.openingFils)),
          const Divider(),
          InfoRow(l10n.payrollPayable, formatAed(p.payableFils)),
          const Divider(),
          if (p.posted) ...[
            InfoRow(l10n.payrollPaid, formatAed(p.paidFils)),
            const Divider(),
            if (closing < 0) InfoRow(l10n.payrollOverpaid, formatAed(-closing)) else InfoRow(l10n.payrollClosing, formatAed(closing)),
            const Divider(),
            TextButton(onPressed: () => _undo(context, ref, p.line!), child: Text(l10n.payrollUndo)),
          ],
        ],
      ),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: children[i]),
                  const SizedBox(width: 8),
                  Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(this.item, {required this.month, required this.posted});

  final PayrollItem item;
  final String month;
  final bool posted;

  @override
  Widget build(BuildContext context) {
    final kind = PayItemKind.values.byName(item.kind);
    final plus = kind == PayItemKind.allowance;
    return GrowingRow(
      child: ListTile(
        title: Text(item.reason),
        subtitle: item.authorizedBy == null && item.note == null ? null : Text([?item.authorizedBy, ?item.note].join(', ')),
        trailing: RowValue('${plus ? '+' : '-'}${formatAed(item.amountFils)}'),
        onTap: posted
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PayItemFormScreen(workerId: item.workerId, month: month, kind: kind, item: item)),
              ),
      ),
    );
  }
}
