import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/form_bits.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'export_flow.dart';
import 'ledger_screen.dart';

/// Every report the owner can run, each with what it shows and which date it goes by (REP-01). Each opens the register
/// that already holds it, so a figure is never worked out twice.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _busy = false;

  void _open(Section section) => StatefulNavigationShell.of(context).goBranch(section.index);

  void _openCash(CashKind kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LedgerScreen(
        Section.cashRegister,
        chosen: {
          'kind': {kind.name},
        },
      ),
    ),
  );

  Future<void> _ownerSheet() async {
    final l10n = AppLocalizations.of(context);
    final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);
    final month = await chooseOne(context, l10n.repChooseMonth, [
      for (var i = 0; i < 12; i++) (value: addMonths(thisMonth, -i), label: showMonth(addMonths(thisMonth, -i))),
    ]);
    if (month == null || !mounted) return;
    await exportOwnerSheet(context, ref, month, onBusy: (busy) {
      if (mounted) setState(() => _busy = busy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget report(String title, String what, VoidCallback onTap) => RowCard(
      child: ListTile(
        title: Text(title),
        subtitle: Text(what),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : onTap,
      ),
    );
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.menuReports), bottom: const SubTabs(Section.reports)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(l10n.reportsIntro, style: const TextStyle(fontSize: 14, color: muted)),
          ),
          SectionHeader(l10n.reportsHeadWork),
          report(l10n.regAttendance, l10n.repAttendance, () => _open(Section.attendanceRegister)),
          report(l10n.regWork, l10n.repWork, () => _open(Section.workRegister)),
          SectionHeader(l10n.reportsHeadCompanies),
          report(l10n.regAging, l10n.repAging, () => _open(Section.agingRegister)),
          report(l10n.regInvoices, l10n.repInvoices, () => _open(Section.invoiceRegister)),
          report(l10n.repReceiptsTitle, l10n.repReceipts, () => _openCash(CashKind.clientReceipt)),
          report(l10n.regStatement, l10n.repStatement, () => _open(Section.statementRegister)),
          SectionHeader(l10n.reportsHeadWorkers),
          report(l10n.regWorkers, l10n.repWorkers, () => _open(Section.workerRegister)),
          report(l10n.regPayroll, l10n.repPayroll, () => _open(Section.payrollRegister)),
          report(l10n.regAdvance, l10n.repAdvance, () => _open(Section.advanceRegister)),
          SectionHeader(l10n.reportsHeadBusiness),
          report(l10n.repExpensesTitle, l10n.repExpenses, () => _openCash(CashKind.expense)),
          report(l10n.ownerSheet, l10n.repMargin, _ownerSheet),
        ],
      ),
    );
  }
}
