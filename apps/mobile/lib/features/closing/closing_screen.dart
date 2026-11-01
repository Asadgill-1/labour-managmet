import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/closing.dart';
import '../../data/payroll.dart';
import '../../data/statement.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../payroll/payroll_worker_screen.dart';
import '../rates/contract_form_screen.dart';
import '../today/attendance_entry_screen.dart';
import '../today/row_editor_screen.dart';

String findingText(AppLocalizations l10n, ClosingFinding f) {
  final count = f.names.length;
  final names = f.names.take(5).join(', ');
  return switch (f.issue) {
    ClosingIssue.noWorkerRate => l10n.findingNoWorkerRate(count, names),
    ClosingIssue.payrollNotPosted => l10n.findingNotPosted(count, names),
    ClosingIssue.noCompanyRate => l10n.findingNoCompanyRate(count, names),
    ClosingIssue.noHazri => l10n.findingNoHazri(count, names),
    ClosingIssue.overlap => l10n.findingOverlap(count, names),
    ClosingIssue.noMonthChosen => l10n.findingNoMonth(count, names),
  };
}

/// One month's closing: what is still left, date by date, how the month adds up, then the owner's confirmation (REP-04, D-045).
class ClosingScreen extends ConsumerStatefulWidget {
  const ClosingScreen({super.key});

  @override
  ConsumerState<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends ConsumerState<ClosingScreen> {
  String? _picked;

  /// The month just ended is the one usually being closed.
  String get _month => _picked ?? addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1);

  Future<void> _close(MonthClosing c) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.closeTitle(showMonth(c.month))),
        content: Text(l10n.closeBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.closeConfirm)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final saved = await saveOrExplain(context, () => ref.read(dbProvider).closeMonth(c.month, operationId: newUuid()));
    if (saved && mounted) showSavedOnPhone(context, l10n.closeDone(showMonth(c.month)));
  }

  Future<void> _reopen(MonthClosing c) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(context, title: l10n.reopenTitle(showMonth(c.month)), helper: l10n.reopenHelp, confirm: l10n.reopenConfirm);
    if (reason == null || !mounted) return;
    final saved = await saveOrExplain(context, () => ref.read(dbProvider).reopenMonth(c.lock!, reason: reason, operationId: newUuid()));
    if (saved && mounted) showSavedOnPhone(context, l10n.reopenDone(showMonth(c.month)));
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// Takes the owner to the place that clears this finding. Where several names share it, they choose one first.
  Future<void> _fix(ClosingFinding f) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    Future<void> act(Future<void> Function() work, String done) async {
      final saved = await saveOrExplain(context, work);
      if (saved && mounted) showSavedOnPhone(context, done);
    }

    final (help, actions, onName) = switch (f.issue) {
      ClosingIssue.noHazri => (
        l10n.closingDayOffHelp,
        <_FixAction>[
          (label: l10n.closingEnterHazri, run: () async => _open(AttendanceEntryScreen(date: f.date))),
          (label: l10n.closingDayOff, run: () => act(() => db.markDayOff(f.date, [for (final t in f.targets) t.id], operationId: newUuid()), l10n.closingDayOffDone)),
        ],
        null,
      ),
      ClosingIssue.payrollNotPosted => (
        l10n.closingPostHelp,
        <_FixAction>[
          (label: l10n.closingPostReady, run: () => act(() => db.postPayroll(f.date.substring(0, 7), operationId: newUuid()), l10n.savedOnPhone)),
        ],
        (ClosingTarget t) async => _open(PayrollWorkerScreen(workerId: t.id, month: f.date.substring(0, 7))),
      ),
      ClosingIssue.noMonthChosen => (
        l10n.closingSettleHelp,
        <_FixAction>[
          (
            label: l10n.closingSettle,
            run: () => act(() async {
              for (final t in f.targets) {
                final payment = await (db.select(db.cashEntries)..where((c) => c.id.equals(t.id))).getSingle();
                await db.settleOldPayment(payment, operationId: newUuid());
              }
            }, l10n.closingSettled),
          ),
        ],
        null,
      ),
      ClosingIssue.noWorkerRate => (null, const <_FixAction>[], (ClosingTarget t) async => _open(ContractFormScreen.pay(workerId: t.id))),
      ClosingIssue.noCompanyRate => (null, const <_FixAction>[], (ClosingTarget t) async => _open(ContractFormScreen.billing(clientId: t.id))),
      ClosingIssue.overlap => (
        null,
        const <_FixAction>[],
        (ClosingTarget t) async {
          final row = await (db.select(db.attendanceEntries)..where((e) => e.id.equals(t.id))).getSingle();
          if (mounted) await openAttendanceRow(context, ref, row, t.name);
        },
      ),
    };

    if (actions.isEmpty && f.targets.length == 1) return onName!(f.targets.single);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _FixSheet(
        title: '${dayName(l10n, f.date)}, ${showDate(f.date)}',
        help: help,
        actions: actions,
        targets: f.targets,
        onName: onName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = ref.watch(closingProvider(_month)).value;
    final findings = c?.findings ?? const <ClosingFinding>[];
    final left = findings.fold(0, (total, f) => total + f.targets.length);
    final (label, press) = c == null || !c.finished ? (l10n.closeButton(showMonth(_month)), null) : (left > 0 ? (l10n.closeBlocked(left), null) : (l10n.closeButton(showMonth(_month)), () => _close(c)));
    String? lastDate;
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.tabClosing), bottom: const SubTabs(Section.closing)),
      bottomNavigationBar: c == null || c.closed ? null : MainActionBar(label: label, onPressed: press),
      body: ListView(
        children: [
          TopBand(
            child: Column(
              children: [
                MonthSwitcher(month: _month, onChanged: (m) => setState(() => _picked = m)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BandFigure(formatAed(c?.closingFils ?? 0), l10n.closingWorkersLeft, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(c?.closed == true ? l10n.closingClosed : l10n.closingOpen, l10n.closingState, size: 18)),
                  ],
                ),
              ],
            ),
          ),
          if (c != null && !c.finished) NoteRow(icon: Icons.schedule, text: l10n.closingNotOver, color: muted),
          if (c?.closed == true) ...[
            const SizedBox(height: 20),
            Center(child: ClosedStamp(l10n.closingClosed, showDate(monthLastDay(_month)))),
            const SizedBox(height: 12),
            NoteRow(icon: Icons.lock, text: l10n.closingIsClosed, color: muted),
          ],
          if (left > 0) NoteRow(icon: Icons.error_outline, text: l10n.closingLeft(left), color: due),
          for (final f in findings) ...[
            if (f.date != lastDate) SectionHeader('${dayName(l10n, lastDate = f.date)}, ${showDate(f.date)}'),
            RowCard(
              child: ListTile(
                title: Text(findingText(l10n, f), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ink)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _fix(f),
              ),
            ),
          ],
          if (c != null && c.canClose) NoteRow(icon: Icons.task_alt, text: l10n.closingAllClear, color: settled),
          if (c != null) ...[
            SectionHeader(l10n.closingSummary),
            for (final (label, fils) in [
              (l10n.slipOpening, c.openingFils),
              (l10n.colEarned, c.earnedFils),
              (l10n.slipAdvance, c.advanceFils),
              (l10n.closingCuts, c.cutFils),
              (l10n.slipPaid, c.paidFils),
              (l10n.closingExpenses, c.expensesFils),
            ])
              RowCard(child: InfoRow(label, formatAed(fils))),
            TotalRow(l10n.closingWorkersLeft, formatAed(c.closingFils)),
            if (c.closingFils > 0 && !c.closed) NoteRow(icon: Icons.info_outline, text: l10n.closingUnpaidNote, color: muted),
          ],
          if (c != null && c.canReopen) TextButton(onPressed: () => _reopen(c), child: Text(l10n.reopenButton)),
        ],
      ),
    );
  }
}

typedef _FixAction = ({String label, Future<void> Function() run});

/// Everything one finding covers, and what clears it. Closes after an action, since the list behind it has changed.
class _FixSheet extends StatelessWidget {
  const _FixSheet({required this.title, required this.help, required this.actions, required this.targets, required this.onName});

  final String title;
  final String? help;
  final List<_FixAction> actions;
  final List<ClosingTarget> targets;
  final Future<void> Function(ClosingTarget)? onName;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: Text(title, style: sectionTitleStyle),
            ),
            if (help != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(help!, style: const TextStyle(fontSize: 14, height: 1.4, color: muted)),
              ),
            for (final (index, action) in actions.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: index == actions.length - 1
                    ? FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          action.run();
                        },
                        child: Text(action.label),
                      )
                    : OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          action.run();
                        },
                        child: Text(action.label),
                      ),
              ),
            for (final target in targets) ...[
              const Divider(),
              ListTile(
                tileColor: Colors.transparent,
                title: Text(target.name),
                trailing: onName == null ? null : const Icon(Icons.chevron_right),
                onTap: onName == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        onName!(target);
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
