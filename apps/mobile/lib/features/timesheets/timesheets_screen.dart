import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/tenant_database.dart';
import '../../data/timesheets.dart';
import '../../l10n/app_localizations.dart';
import 'timesheet_screen.dart';

String tsStatusLabel(AppLocalizations l10n, TsStatus status) => switch (status) {
  TsStatus.draft => l10n.tsStatusDraft,
  TsStatus.approved => l10n.tsStatusApproved,
  TsStatus.shared => l10n.tsStatusShared,
  TsStatus.accepted => l10n.tsStatusAccepted,
  TsStatus.disputed => l10n.tsStatusDisputed,
};

/// Every timesheet and how far each has gone (TS-04).
class TimesheetsScreen extends ConsumerStatefulWidget {
  const TimesheetsScreen({super.key});

  @override
  ConsumerState<TimesheetsScreen> createState() => _TimesheetsScreenState();
}

class _TimesheetsScreenState extends ConsumerState<TimesheetsScreen> {
  String _search = '';

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = ref.watch(timesheetsProvider).value ?? const <TimesheetListRow>[];
    final needle = _search.toLowerCase();
    final shown = needle.isEmpty ? rows : rows.where((r) => '${r.clientName} ${r.siteName ?? ''} ${r.number ?? ''}'.toLowerCase().contains(needle)).toList();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.tsTab), bottom: const SubTabs(Section.timesheets)),
      bottomNavigationBar: MainActionBar(label: l10n.tsNew, onPressed: () => _open(const NewTimesheetScreen())),
      body: ListView(
        children: [
          if (rows.length > 6) ColoredBox(color: brand, child: SearchBox(onChanged: (v) => setState(() => _search = v))),
          if (rows.isEmpty) EmptyState(icon: Icons.assignment, text: l10n.tsEmpty),
          for (final row in shown)
            RowCard(
              child: ListTile(
                title: Text(row.clientName),
                subtitle: Text(
                  [
                    [l10n.dateFromTo(showDate(row.fromDate), showDate(row.toDate)), ?row.siteName].join(', '),
                    [?row.number, if (row.revision > 1) 'R${row.revision}', tsStatusLabel(l10n, row.status)].join(', '),
                  ].join('\n'),
                ),
                trailing: row.amountFils == null ? const Icon(Icons.chevron_right) : RowValue(formatAed(row.amountFils!)),
                onTap: () => _open(TimesheetScreen(timesheetId: row.id)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A company, its dates and perhaps one site. It says what would go on before anything is made (TS-01).
class NewTimesheetScreen extends ConsumerStatefulWidget {
  const NewTimesheetScreen({super.key});

  @override
  ConsumerState<NewTimesheetScreen> createState() => _NewTimesheetScreenState();
}

class _NewTimesheetScreenState extends ConsumerState<NewTimesheetScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();

  String? _clientId;
  String? _siteId;

  /// The month just ended is the one usually billed.
  late String _from = monthFirstDay(addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1));
  late String _to = monthLastDay(addMonths(dubaiToday(DateTime.now()).substring(0, 7), -1));
  Future<TimesheetPreview>? _preview;

  bool get _datesOk => _from.compareTo(_to) <= 0;

  void _changed(VoidCallback change) => setState(() {
    change();
    _preview = _clientId == null || !_datesOk ? null : ref.read(dbProvider).timesheetPreview(clientId: _clientId!, siteId: _siteId, from: _from, to: _to);
  });

  void _month(String month) => _changed(() {
    _from = monthFirstDay(month);
    _to = monthLastDay(month);
  });

  Future<void> _create() async {
    if (!validateAndReveal(_form)) return;
    final navigator = Navigator.of(context);
    String? id;
    final saved = await saveOrExplain(context, () async => id = await ref.read(dbProvider).createTimesheet(clientId: _clientId!, siteId: _siteId, from: _from, to: _to, operationId: _operationId));
    if (saved && id != null && mounted) await navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => TimesheetScreen(timesheetId: id!)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active);
    final sites = _clientId == null ? const <Site>[] : (ref.watch(sitesOfClientProvider(_clientId!)).value ?? const <Site>[]);
    final thisMonth = dubaiToday(DateTime.now()).substring(0, 7);
    return FutureBuilder<TimesheetPreview>(
      future: _preview,
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final canMake = _datesOk && (preview?.rows.isNotEmpty ?? false);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.tsNew)),
          bottomNavigationBar: MainActionBar(label: l10n.tsCreate, onPressed: canMake ? _create : null),
          body: Form(
            key: _form,
            child: FormBody(
              children: [
                PickField(
                  l10n.colCompany,
                  selected: _clientId,
                  options: [for (final c in clients) (value: c.id, label: c.name)],
                  onChanged: (v) => _changed(() {
                    _clientId = v;
                    _siteId = null;
                  }),
                ),
                fieldGap,
                PickField(
                  l10n.colSite,
                  selected: _siteId ?? '',
                  options: [(value: '', label: l10n.tsAllSites), for (final s in sites) (value: s.id, label: s.name)],
                  onChanged: (v) => _changed(() => _siteId = v.isEmpty ? null : v),
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
                    Expanded(child: DateField(l10n.tsFrom, value: _from, required: true, onChanged: (v) => _changed(() => _from = v!))),
                    const SizedBox(width: 12),
                    Expanded(child: DateField(l10n.tsTo, value: _to, required: true, onChanged: (v) => _changed(() => _to = v!))),
                  ],
                ),
                if (!_datesOk) NoteRow(icon: Icons.error_outline, text: l10n.tsBadDates, color: due),
                if (preview != null) ...[
                  if (preview.rows.isEmpty) NoteRow(icon: Icons.info_outline, text: l10n.tsNothing, color: muted) else NoteRow(icon: Icons.task_alt, text: l10n.tsWillHold(preview.rows.length), color: settled),
                  ...leftOutNotes(l10n, preview.leftOut),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Why rows in the dates aren't on it, so nothing goes missing without a word.
List<Widget> leftOutNotes(AppLocalizations l10n, TsLeftOut left) => [
  if (left.noCompanyRate > 0) NoteRow(icon: Icons.error_outline, text: l10n.tsLeftNoRate(left.noCompanyRate), color: due),
  if (left.noWorkerRate > 0) NoteRow(icon: Icons.error_outline, text: l10n.tsLeftNoWage(left.noWorkerRate), color: due),
  if (left.onOtherTimesheet > 0) NoteRow(icon: Icons.info_outline, text: l10n.tsLeftOther(left.onOtherTimesheet), color: muted),
];
