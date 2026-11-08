import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/invoices.dart';
import '../../data/receipts.dart';
import 'package:domain/invoice.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'invoice_screen.dart';

/// Draft, issued, partly paid, paid, overdue, closed or credited (INV-07). Without [money] an issued invoice is only issued.
String invoiceStatusLabel(AppLocalizations l10n, Invoice i, [InvoiceMoney? money]) => switch ((i.kind, InvoiceStatus.values.byName(i.status))) {
  ('credit', _) => l10n.invCreditNoteLabel,
  (_, InvoiceStatus.draft) => l10n.invDraftLabel,
  (_, InvoiceStatus.credited) => l10n.invStatusCredited,
  (_, InvoiceStatus.issued) => switch (money?.state(dubaiToday(DateTime.now()))) {
    null || PayState.unpaid => l10n.invStatusIssued,
    PayState.partlyPaid => l10n.invStatusPartlyPaid,
    PayState.overdue => l10n.invStatusOverdue,
    PayState.paid => l10n.invStatusPaid,
    PayState.closed => l10n.invStatusClosed,
  },
};

/// Every invoice and credit note, newest first (INV-07).
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _search = '';

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(invoicesProvider).value ?? const <InvoiceListRow>[];
    final today = dubaiToday(DateTime.now());
    final needle = _search.toLowerCase();
    final shown = needle.isEmpty ? rows : rows.where((r) => '${r.clientName} ${r.invoice.number ?? ''}'.toLowerCase().contains(needle)).toList();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.invTab), bottom: const SubTabs(Section.invoices)),
      bottomNavigationBar: MainActionBar(label: l10n.invNew, onPressed: () => _open(const NewInvoiceScreen())),
      body: ListView(
        children: [
          if (rows.length > 6) ColoredBox(color: brand, child: SearchBox(onChanged: (v) => setState(() => _search = v))),
          if (rows.isEmpty) EmptyState(icon: Icons.receipt, text: l10n.invEmpty),
          for (final row in shown)
            RowCard(
              // One that puts an invoice right, in the edited colour (D-056).
              edited: row.replaces,
              child: ListTile(
                title: Text(row.clientName),
                subtitle: Text(
                  [
                    [?row.invoice.number, invoiceStatusLabel(l10n, row.invoice, row.money), if (row.replaces) l10n.editedTag].join(', '),
                    [
                      if (row.invoice.issueDate != null) showDate(row.invoice.issueDate!) else l10n.dateFromTo(showDate(row.invoice.fromDate), showDate(row.invoice.toDate)),
                      if (row.invoice.status == InvoiceStatus.issued.name && row.invoice.kind == 'invoice') l10n.invDue(showDate(row.invoice.dueDate!)),
                      if (row.money case final m? when row.invoice.status == InvoiceStatus.issued.name && m.leftFils > 0 && m.leftFils < m.totalFils) l10n.invToPayShort(formatAed(m.leftFils)),
                    ].join(', '),
                  ].join('\n'),
                ),
                trailing: row.totalFils == null
                    ? const Icon(Icons.chevron_right)
                    : RowValue(
                        formatAed(row.invoice.kind == 'credit' ? -row.totalFils! : row.totalFils!),
                        style: row.invoice.status == InvoiceStatus.issued.name && row.money?.state(today) == PayState.overdue ? amountStyle.copyWith(color: due) : amountStyle,
                      ),
                onTap: () => _open(InvoiceScreen(invoiceId: row.invoice.id)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A company, its dates and perhaps one site. The draft then shows which timesheets it reads and what each holds (INV-01).
class NewInvoiceScreen extends ConsumerStatefulWidget {
  const NewInvoiceScreen({this.clientId, this.month, super.key});

  final String? clientId;
  final String? month;

  @override
  ConsumerState<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends ConsumerState<NewInvoiceScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();

  late String? _clientId = widget.clientId;
  String? _siteId;

  /// The month just ended is the one usually invoiced.
  late final String _start = widget.month ?? addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1);
  late String _from = monthFirstDay(_start);
  late String _to = monthLastDay(_start);

  bool get _datesOk => _from.compareTo(_to) <= 0;

  void _month(String month) => setState(() {
    _from = monthFirstDay(month);
    _to = monthLastDay(month);
  });

  Future<void> _create() async {
    if (!validateAndReveal(_form)) return;
    final navigator = Navigator.of(context);
    String? id;
    final saved = await saveOrExplain(context, () async => id = await ref.read(dbProvider).createInvoice(clientId: _clientId!, siteId: _siteId, from: _from, to: _to, operationId: _operationId));
    if (saved && id != null && mounted) await navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => InvoiceScreen(invoiceId: id!)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active || c.id == widget.clientId);
    final sites = _clientId == null ? const <Site>[] : (ref.watch(sitesOfClientProvider(_clientId!)).value ?? const <Site>[]);
    final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.invNew)),
      bottomNavigationBar: MainActionBar(label: l10n.invCreate, onPressed: _clientId != null && _datesOk ? _create : null),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            PickField(
              l10n.colCompany,
              selected: _clientId,
              options: [for (final c in clients) (value: c.id, label: c.name)],
              onChanged: (v) => setState(() {
                _clientId = v;
                _siteId = null;
              }),
            ),
            fieldGap,
            PickField(
              l10n.colSite,
              selected: _siteId ?? '',
              options: [(value: '', label: l10n.tsAllSites), for (final s in sites) (value: s.id, label: s.name)],
              onChanged: (v) => setState(() => _siteId = v.isEmpty ? null : v),
            ),
            fieldGap,
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _month(addMonths(thisMonth, -1)), child: Text(l10n.regLastMonth))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _month(thisMonth), child: Text(l10n.regThisMonth))),
              ],
            ),
            fieldGap,
            Row(
              children: [
                Expanded(child: DateField(l10n.tsFrom, value: _from, required: true, onChanged: (v) => setState(() => _from = v!))),
                const SizedBox(width: 12),
                Expanded(child: DateField(l10n.tsTo, value: _to, required: true, onChanged: (v) => setState(() => _to = v!))),
              ],
            ),
            if (!_datesOk) NoteRow(icon: Icons.error_outline, text: l10n.tsBadDates, color: due),
            NoteRow(icon: Icons.info_outline, text: l10n.invNewHelp, color: muted),
          ],
        ),
      ),
    );
  }
}
