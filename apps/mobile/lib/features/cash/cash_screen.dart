import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'cash_entry_form_screen.dart';
import 'cash_row.dart';

/// The day's money in one place (D-030). Each line goes to the worker, room or company it belongs to by itself.
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen> {
  String _date = dubaiToday(DateTime.now());

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(cashOnDateProvider(_date)).value ?? const <CashEntry>[];
    final totals = cashTotals(rows.map(cashLine));
    final undone = undoneIds(rows);
    final today = dubaiToday(DateTime.now());
    final closed = isClosed(_date, ref.watch(lockedThroughProvider).value);
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('${_date == today ? l10n.tabToday : dayName(l10n, _date)}, ${showDate(_date)}'),
        ),
        bottom: const SubTabs(Section.cash),
        actions: [
          if (_date != today) BarButton(l10n.tabToday, onPressed: () => setState(() => _date = today)),
          IconButton(tooltip: l10n.pickDate, icon: const Icon(Icons.calendar_month), onPressed: _chooseDate),
        ],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.addCash,
        onPressed: closed ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(date: _date))),
      ),
      body: ListView(
        children: [
          TopBand(
            child: Column(
              children: [
                DayStrip(selected: _date, onPick: (date) => setState(() => _date = date)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BandFigure(formatAed(totals.inFils), l10n.moneyIn, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(totals.outFils), l10n.moneyOut, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(totals.inFils - totals.outFils), l10n.cashDifference, size: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (closed) const ClosedNote(),
          if (rows.isEmpty) EmptyState(icon: Icons.receipt_long, text: l10n.cashEmpty),
          for (final entry in rows) CashEntryRow(entry, undone: undone.contains(entry.id)),
        ],
      ),
    );
  }
}
