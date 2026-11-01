import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/closing.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

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

/// One month's closing: what is wrong with it, how it adds up, then the owner's confirmation (REP-04).
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
    final checks = c.findings.length;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.closeTitle(showMonth(c.month))),
        content: Text([l10n.closeBody, if (checks > 0) l10n.closeWithChecks(checks)].join('\n\n')),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = ref.watch(closingProvider(_month)).value;
    final stops = c?.findings.where((f) => f.stops).toList() ?? const <ClosingFinding>[];
    final checks = c?.findings.where((f) => !f.stops).toList() ?? const <ClosingFinding>[];
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.tabClosing), bottom: const SubTabs(Section.closing)),
      bottomNavigationBar: c == null || c.closed ? null : MainActionBar(label: l10n.closeButton(showMonth(_month)), onPressed: c.canClose ? () => _close(c) : null),
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
          const SizedBox(height: 8),
          if (c != null && !c.finished) _Line(Icons.schedule, l10n.closingNotOver, muted),
          if (c?.closed == true) _Line(Icons.lock, l10n.closingIsClosed, settled),
          if (stops.isNotEmpty) ...[
            SectionHeader(l10n.closingStops),
            for (final f in stops) _Line(Icons.error_outline, findingText(l10n, f), due),
          ],
          if (checks.isNotEmpty) ...[
            SectionHeader(l10n.closingChecks),
            for (final f in checks) _Line(Icons.info_outline, findingText(l10n, f), warn),
          ],
          if (c != null && c.canClose && checks.isEmpty) _Line(Icons.task_alt, l10n.closingAllClear, settled),
          if (c != null) ...[
            SectionHeader(l10n.closingSummary),
            const Divider(),
            for (final (label, fils) in [
              (l10n.slipOpening, c.openingFils),
              (l10n.colEarned, c.earnedFils),
              (l10n.slipAdvance, c.advanceFils),
              (l10n.closingCuts, c.cutFils),
              (l10n.slipPaid, c.paidFils),
              (l10n.closingWorkersLeft, c.closingFils),
              (l10n.closingExpenses, c.expensesFils),
            ]) ...[
              InfoRow(label, formatAed(fils)),
              const Divider(),
            ],
          ],
          if (c != null && c.canReopen) TextButton(onPressed: () => _reopen(c), child: Text(l10n.reopenButton)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RowCard(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}
