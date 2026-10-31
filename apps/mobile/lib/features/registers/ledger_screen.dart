import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import 'register_defs.dart';
import 'register_export.dart';
import 'register_model.dart';

typedef RegisterQuery = ({Section section, String? from, String? to, AppLocalizations l10n});

/// Sends a fresh copy whenever anything changes, so an open register is never stale.
/// ponytail: rebuilds on any write, which is fine at one owner's write rate. Narrow to each register's tables if entry ever feels slow.
final registerProvider = StreamProvider.autoDispose.family<RegisterData, RegisterQuery>((ref, query) async* {
  final db = ref.watch(dbProvider);
  Future<RegisterData> build() => buildRegister(db, query.l10n, query.section, from: query.from, to: query.to);
  yield await build();
  await for (final _ in db.tableUpdates()) {
    yield await build();
  }
});

/// One register: date range, filters, rows under their dates with every field showing, and export (D-038).
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen(this.section, {super.key});

  final Section section;

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  late String? _from = monthFirstDay(_thisMonth);
  late String? _to = monthLastDay(_thisMonth);
  final _chosen = <String, Set<String>>{};
  RegisterData? _last;
  bool _busy = false;

  String get _thisMonth => dubaiToday(DateTime.now()).substring(0, 7);

  void _setRange(String? from, String? to) => setState(() {
    _from = from;
    _to = to;
  });

  Future<void> _pick(FilterTarget target) async {
    final current = target == FilterTarget.from ? _from : _to;
    final picked = await pickDate(context, current ?? dubaiToday(DateTime.now()));
    if (picked == null) return;
    if (target == FilterTarget.from) {
      _setRange(picked, _to != null && _to!.compareTo(picked) < 0 ? picked : _to);
    } else {
      _setRange(_from != null && _from!.compareTo(picked) > 0 ? picked : _from, picked);
    }
  }

  Future<void> _chooseFilter(RegisterFilter filter) async {
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(filter: filter, chosen: _chosen[filter.key] ?? const {}),
    );
    if (picked != null) setState(() => _chosen[filter.key] = picked);
  }

  /// What the file says it shows, so a report always names its filters and dates (REP-01).
  String _filterLine(AppLocalizations l10n, RegisterData data) {
    final parts = <String>[
      if (data.dated) l10n.regFilterDates(_from == null && _to == null ? l10n.regAllDates : '${_from == null ? '' : showDate(_from!)} - ${_to == null ? '' : showDate(_to!)}'),
      for (final filter in data.filters)
        if (_chosen[filter.key]?.isNotEmpty ?? false)
          () {
            final names = filter.options.where((o) => _chosen[filter.key]!.contains(o.value)).map((o) => o.label).toList();
            final shown = names.take(6).join(', ');
            return '${filter.label}: $shown${names.length > 6 ? ' +${names.length - 6}' : ''}';
          }(),
    ];
    return parts.join('   |   ');
  }

  Future<void> _export(AppLocalizations l10n, RegisterData data, List<RegisterEntry> shown) async {
    final filterLine = _filterLine(l10n, data);
    final choice = await showModalBottomSheet<(ExportFormat, ExportAction)>(
      context: context,
      builder: (_) => _ExportSheet(title: data.title, rows: shown.length, filterLine: filterLine),
    );
    if (choice == null || !mounted) return;
    final (format, action) = choice;
    final profile = ref.read(profileProvider).value;
    final now = DateTime.now().toUtc().add(dubaiOffset);
    final text = ExportText(
      company: profile?.tradingName ?? profile?.legalName ?? '',
      companyLine: [?profile?.address, ?profile?.phone, ?profile?.email].join('   '),
      title: data.title,
      filterLine: [if (filterLine.isNotEmpty) filterLine, l10n.regAmountsNote].join('   |   '),
      totalLabel: l10n.regTotal,
      madeLabel: l10n.regMade('${showDate(ymd(now))} ${showMinuteOfDay(now.hour * 60 + now.minute)}'),
      pagePattern: l10n.regPage('{page}', '{pages}'),
      rollupSheet: l10n.regSummarySheet,
      footer: profile?.documentFooter,
      note: data.note,
    );
    setState(() => _busy = true);
    try {
      final bytes = await makeExportBytes(
        format,
        text,
        data.columns,
        data.groupsByName ? shown : oldestFirst(shown),
        brandArgb: brand.toARGB32(),
        softArgb: brandSoft.toARGB32(),
        rollups: data.rollupsOf?.call(shown) ?? const [],
        groupHeads: data.groupHeads,
        groupFeet: data.groupFeet,
        sections: data.groupsByName,
      );
      final file = await writeExportFile(exportFileName(data.title, data.dated ? _from : null, data.dated ? _to : null, format), bytes);
      final result = await runExport(action, format, file, bytes);
      if (!mounted) return;
      switch (result) {
        case ExportResult.saved:
          showSavedOnPhone(context, l10n.exportSaved);
        case ExportResult.noWhatsApp:
          showFormError(context, l10n.exportNoWhatsApp);
        case ExportResult.noApp:
          showFormError(context, l10n.exportNoApp);
        case ExportResult.done || ExportResult.cancelled:
          break;
      }
    } catch (_) {
      if (mounted) showFormError(context, l10n.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asked = ref.watch(registerProvider((section: widget.section, from: _from, to: _to, l10n: l10n)));
    final data = asked.value ?? _last;
    if (asked.hasValue) _last = asked.value;
    final shown = data == null ? const <RegisterEntry>[] : filterEntries(data.entries, _chosen);
    final groups = groupEntries(shown);
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(sectionLabel(l10n, widget.section)), bottom: SubTabs(widget.section)),
      bottomNavigationBar: MainActionBar(
        label: _busy ? l10n.exportMaking : l10n.regExport,
        onPressed: _busy || data == null || shown.isEmpty ? null : () => _export(l10n, data, shown),
      ),
      body: data == null
          ? (asked.hasError ? EmptyState(icon: Icons.error_outline, text: l10n.databaseError) : const Center(child: CircularProgressIndicator()))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: groups.length + 1 + (shown.isEmpty ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == 0) return _header(l10n, data, shown);
                if (shown.isEmpty) return EmptyState(icon: Icons.filter_alt_off, text: l10n.regEmpty);
                return _Group(data: data, group: groups[i - 1].group, rows: groups[i - 1].rows);
              },
            ),
    );
  }

  Widget _header(AppLocalizations l10n, RegisterData data, List<RegisterEntry> shown) {
    final today = dubaiToday(DateTime.now());
    final lastMonth = addMonths(_thisMonth, -1);
    final anyFilter = _chosen.values.any((v) => v.isNotEmpty);
    final difference = registerDifference(data, shown);
    final figures = <Widget>[
      for (final c in data.bandColumns)
        Expanded(child: BandFigure(_bandText(data.columns[c], columnFigure(data.columns, shown, c)), data.columns[c].label, size: 16)),
      if (difference != null) Expanded(child: BandFigure(formatAed(difference), l10n.colDifference, size: 16)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBand(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.dated) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(child: _BandButton(icon: Icons.calendar_today, label: _from == null ? l10n.regAllDates : showDate(_from!), onTap: () => _pick(FilterTarget.from))),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 18, color: Colors.white)),
                      Expanded(child: _BandButton(icon: Icons.calendar_today, label: _to == null ? l10n.regAllDates : showDate(_to!), onTap: () => _pick(FilterTarget.to))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _Strip(
                  children: [
                    _BandChip(l10n.tabToday, selected: _from == today && _to == today, onTap: () => _setRange(today, today)),
                    _BandChip(
                      l10n.regThisMonth,
                      selected: _from == monthFirstDay(_thisMonth) && _to == monthLastDay(_thisMonth),
                      onTap: () => _setRange(monthFirstDay(_thisMonth), monthLastDay(_thisMonth)),
                    ),
                    _BandChip(
                      l10n.regLastMonth,
                      selected: _from == monthFirstDay(lastMonth) && _to == monthLastDay(lastMonth),
                      onTap: () => _setRange(monthFirstDay(lastMonth), monthLastDay(lastMonth)),
                    ),
                    _BandChip(l10n.regAll, selected: _from == null && _to == null, onTap: () => _setRange(null, null)),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              _Strip(
                children: [
                  // First, so it stays in view however many filters a register has.
                  if (anyFilter) _BandChip(l10n.regClear, icon: Icons.close, selected: false, onTap: () => setState(_chosen.clear)),
                  for (final filter in data.filters)
                    _BandChip(
                      (_chosen[filter.key]?.length ?? 0) == 0 ? filter.label : '${filter.label} (${_chosen[filter.key]!.length})',
                      icon: Icons.filter_list,
                      selected: _chosen[filter.key]?.isNotEmpty ?? false,
                      onTap: () => _chooseFilter(filter),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < figures.length; i++) ...[if (i > 0) const SizedBox(width: 8), figures[i]],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(l10n.regRows(shown.length), style: const TextStyle(fontSize: 13, color: muted)),
        ),
        if (data.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(data.note!, style: const TextStyle(fontSize: 13, color: muted)),
          ),
      ],
    );
  }
}

enum FilterTarget { from, to }

/// Hours and counts have no currency. Money always says AED on screen (UX-04).
String _bandText(RegisterColumn column, Object? value) => column.kind == CellKind.money ? formatAed(value! as int) : cellText(column, value);

class _Strip extends StatelessWidget {
  const _Strip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final child in children) Padding(padding: const EdgeInsets.only(right: 6), child: child),
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip(this.label, {required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = selected ? brand : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 4)],
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BandButton extends StatelessWidget {
  const _BandButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 16, color: brand),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One date's heading with its totals, and its rows.
class _Group extends StatelessWidget {
  const _Group({required this.data, required this.group, required this.rows});

  final RegisterData data;
  final String group;
  final List<RegisterEntry> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = switch (data.groupKind) {
      CellKind.text => group,
      CellKind.month => showMonth(group),
      _ => group.isEmpty ? '' : '${dayName(l10n, group)}, ${showDate(group)}',
    };
    final head = data.groupHeads[group];
    final foot = data.groupFeet[group];
    final lastBand = data.bandColumns.isEmpty ? null : data.bandColumns.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (group.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: Row(
              children: [
                Expanded(child: Text(heading, style: sectionTitleStyle.copyWith(fontSize: 15))),
                Text(
                  [
                    l10n.regRows(rows.length),
                    // In and out are both on the band, so one of them alone would mislead here.
                    if (lastBand != null && registerDifference(data, rows) == null) _bandText(data.columns[lastBand], columnFigure(data.columns, rows, lastBand)),
                  ].join('   '),
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
        if (head != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(head, style: const TextStyle(fontSize: 13, color: muted)),
          ),
        for (final entry in rows) _EntryCard(data: data, entry: entry),
        if (foot != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(foot, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
          ),
      ],
    );
  }
}

/// Every field of one row in front of the owner, with no need to open it (D-038).
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.data, required this.entry});

  final RegisterData data;
  final RegisterEntry entry;

  @override
  Widget build(BuildContext context) {
    final amountColumn = data.amountColumns.where((c) => entry.cells[c] != null).firstOrNull;
    final amount = amountColumn == null ? null : entry.cells[amountColumn] as int;
    final tone = amountColumn == null ? CellTone.none : data.columns[amountColumn].tone;
    final title = cellText(data.columns[data.titleColumn], entry.cells[data.titleColumn]);
    final details = <(String, String)>[
      for (var c = 0; c < data.columns.length; c++)
        if (c != data.titleColumn && c != amountColumn && data.columns[c].onScreen && !(data.columns[c].kind == data.groupKind && c == 0 && entry.group.isNotEmpty))
          // A cell repeating the row's name says nothing new. A running balance of zero still says where the account stands.
          if ((_worthShowing(entry.cells[c]) || (data.columns[c].closing && entry.cells[c] != null)) && entry.cells[c] != title) (data.columns[c].label, _bandText(data.columns[c], entry.cells[c])),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F17213A), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: sectionTitleStyle.copyWith(fontSize: 15.5))),
                if (amount != null)
                  RowValue(
                    formatAed(amount),
                    style: amountStyle.copyWith(fontSize: 15.5, color: tone == CellTone.plus ? settled : (tone == CellTone.minus ? due : ink)),
                  ),
              ],
            ),
            if (amountColumn != null) Align(alignment: Alignment.centerRight, child: Text(data.columns[amountColumn].label, style: const TextStyle(fontSize: 11.5, color: muted))),
            if (details.isNotEmpty) const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final (label, value) in details)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$label  ', style: const TextStyle(fontSize: 12.5, color: muted)),
                        TextSpan(text: value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Zero amounts and empty cells would only bury the figures that matter. Exports keep every column.
bool _worthShowing(Object? value) => value != null && value != '' && value != 0;

/// Tick one or more names, with a search once the list is long.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.chosen});

  final RegisterFilter filter;
  final Set<String> chosen;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _picked = {...widget.chosen};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = _search.toLowerCase();
    final media = MediaQuery.of(context);
    final options = widget.filter.options.where((o) => o.label.toLowerCase().contains(needle)).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.filter.label, style: sectionTitleStyle)),
                    TextButton(onPressed: () => setState(_picked.clear), child: Text(l10n.regClear)),
                  ],
                ),
              ),
              if (widget.filter.options.length > 6) SearchBox(onChanged: (v) => setState(() => _search = v)),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, i) => CheckboxListTile(
                    tileColor: Colors.transparent,
                    title: Text(options[i].label),
                    value: _picked.contains(options[i].value),
                    onChanged: (on) => setState(() => on == true ? _picked.add(options[i].value) : _picked.remove(options[i].value)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton(onPressed: () => Navigator.of(context).pop(_picked), child: Text(l10n.applyChanges)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says what is about to leave the phone, then lets the owner choose how (DOC-07).
class _ExportSheet extends StatelessWidget {
  const _ExportSheet({required this.title, required this.rows, required this.filterLine});

  final String title;
  final int rows;
  final String filterLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget section(String heading, IconData icon, Color color, ExportFormat format, String viewLabel) {
      Widget action(IconData actionIcon, String label, ExportAction action, {Color? tint}) {
        return Expanded(
          child: Material(
            color: paper,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop((format, action)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    Icon(actionIcon, color: tint ?? brand),
                    const SizedBox(height: 4),
                    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(heading, style: sectionTitleStyle.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  action(Icons.visibility, viewLabel, ExportAction.view),
                  const SizedBox(width: 6),
                  action(Icons.save_alt, l10n.exportSave, ExportAction.save),
                  const SizedBox(width: 6),
                  action(Icons.chat, l10n.exportWhatsApp, ExportAction.whatsapp, tint: const Color(0xFF128C4A)),
                  const SizedBox(width: 6),
                  action(Icons.share, l10n.exportOther, ExportAction.other),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sectionTitleStyle),
                const SizedBox(height: 2),
                Text(l10n.regRows(rows), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
                Text(filterLine, style: const TextStyle(fontSize: 13, color: muted)),
              ],
            ),
          ),
          section('PDF', Icons.picture_as_pdf, const Color(0xFFC62828), ExportFormat.pdf, l10n.exportView),
          section('Excel', Icons.table_chart, const Color(0xFF1D7044), ExportFormat.excel, l10n.exportOpen),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
