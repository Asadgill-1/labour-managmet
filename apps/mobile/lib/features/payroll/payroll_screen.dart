import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/payroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/payroll.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'payroll_worker_screen.dart';
import 'room_charge_screen.dart';

String issueText(AppLocalizations l10n, PayrollIssue issue, WorkerPayroll p) => switch (issue) {
  PayrollIssue.missingRate => l10n.issueMissingRate(p.unpricedRows),
  PayrollIssue.missingPartialMethod => l10n.issuePartial,
  PayrollIssue.negativeNet => l10n.issueNegative,
  PayrollIssue.recoveryAboveAdvance => l10n.issueRecovery,
  PayrollIssue.recoveryAboveVisa => l10n.issueVisa,
  PayrollIssue.deductionAboveLimit => l10n.issueLimit,
  PayrollIssue.earlierMonthMissing => l10n.issueEarlier,
  PayrollIssue.laterMonthPosted => l10n.issueLater,
  PayrollIssue.monthNotStarted => l10n.issueNotStarted,
};

/// One month's pay for everyone: review, then post with one confirmation (PAY-01).
class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  String? _picked;

  /// Follows the calendar until the owner picks a month, so an app left open overnight doesn't sit on last month.
  String get _month => _picked ?? dubaiToday(DateTime.now()).substring(0, 7);

  Future<void> _post(List<WorkerPayroll> ready) async {
    final l10n = AppLocalizations.of(context);
    final total = ready.fold(0, (sum, p) => sum + p.figures.dueFils);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.payrollPostTitle(showMonth(_month))),
        content: Text(l10n.payrollPostBody(ready.length, formatAed(total))),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.payrollPostConfirm)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    var count = 0;
    final saved = await saveOrExplain(context, () async {
      count = await ref.read(dbProvider).postPayroll(_month, operationId: newUuid());
    });
    if (saved && mounted) showSavedOnPhone(context, l10n.payrollPosted(count));
  }

  Future<void> _applyVisaInstalments() async {
    final l10n = AppLocalizations.of(context);
    var added = 0;
    final saved = await saveOrExplain(context, () async {
      added = await ref.read(dbProvider).applyVisaInstalments(_month, reason: l10n.payKindVisa, operationId: newUuid());
    });
    if (saved && mounted) showSavedOnPhone(context, l10n.visaInstalmentsApplied(added));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(payrollProvider(_month)).value ?? const <WorkerPayroll>[];
    final ready = rows.where((p) => p.canPost).toList();
    final visaInstalments = rows.where((p) => p.needsVisaInstalment).length;
    final earned = rows.fold(0, (sum, p) => sum + p.figures.grossFils);
    final cut = rows.fold(0, (sum, p) => sum + p.figures.deductionsFils + p.figures.recoveryFils + p.figures.visaFils);
    final toPay = rows.fold(0, (sum, p) => sum + (p.closingFils > 0 ? p.closingFils : 0));
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.menuPayroll), bottom: const SubTabs(Section.payroll)),
      bottomNavigationBar: MainActionBar(label: l10n.payrollPost(ready.length), onPressed: ready.isEmpty ? null : () => _post(ready)),
      body: ListView(
        children: [
          TopBand(
            child: Column(
              children: [
                MonthSwitcher(month: _month, onChanged: (m) => setState(() => _picked = m)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BandFigure(formatAed(earned), l10n.payrollEarned, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(cut), l10n.payrollCut, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(toPay), l10n.payrollToPay, size: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RoomChargeScreen(month: _month))),
                  child: Text(l10n.applyRoomCharges),
                ),
                if (visaInstalments > 0) OutlinedButton(onPressed: _applyVisaInstalments, child: Text(l10n.applyVisaInstalments(visaInstalments))),
              ],
            ),
          ),
          if (rows.isEmpty) EmptyState(icon: Icons.payments, text: l10n.payrollEmpty),
          for (final p in rows) _PayrollRow(p, month: _month),
        ],
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  const _PayrollRow(this.p, {required this.month});

  final WorkerPayroll p;
  final String month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final issue = p.figures.issues.firstOrNull;
    final (state, color) = p.posted
        ? (l10n.payrollStatePosted, settled)
        : (issue != null ? (issueText(l10n, issue, p), due) : (l10n.payrollStateReady, muted));
    return RowCard(
      child: ListTile(
        leading: RowTag(initial(p.worker.name)),
        title: Text(p.worker.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.payrollSplit(formatAed(p.figures.grossFils), formatAed(p.figures.deductionsFils + p.figures.recoveryFils + p.figures.visaFils))),
            Text(state, style: TextStyle(fontFamily: headingFont, fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        trailing: RowValue(formatAed(p.closingFils > 0 ? p.closingFils : 0)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayrollWorkerScreen(workerId: p.worker.id, month: month))),
      ),
    );
  }
}
