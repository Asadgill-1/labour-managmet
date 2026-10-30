import 'package:domain/calc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'attendance_review_screen.dart';

/// Step one of attendance (ATT-01): date, client, site, one shift for the group, and who worked.
/// Client and site start on the last ones used, so a repeat day is only a few taps (UX-05).
class AttendanceEntryScreen extends ConsumerStatefulWidget {
  const AttendanceEntryScreen({required this.date, super.key});

  final String date;

  @override
  ConsumerState<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends ConsumerState<AttendanceEntryScreen> {
  late String? _date = widget.date;
  String? _clientId;
  String? _siteId;
  int? _start;
  int? _end;
  final _break = TextEditingController(text: '0');
  final _selected = <String>{};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Starts on the last client and site, unless either has since been archived.
  Future<void> _prefill() async {
    final db = ref.read(dbProvider);
    final last = await db.lastBatch();
    if (last == null) return;
    final client = await (db.select(db.clients)..where((c) => c.id.equals(last.clientId))).getSingle();
    final site = await (db.select(db.sites)..where((s) => s.id.equals(last.siteId))).getSingle();
    if (!mounted || _clientId != null || !client.active || !site.active) return;
    setState(() => _clientId = client.id);
    _pickSite(site);
  }

  void _pickSite(Site site) {
    setState(() {
      _siteId = site.id;
      _start = site.defaultStartMinute;
      _end = site.defaultEndMinute;
      _break.text = site.defaultBreakMinutes.toString();
    });
  }

  Future<void> _copyLastTeam() async {
    final l10n = AppLocalizations.of(context);
    final team = await ref.read(dbProvider).lastTeam(_siteId!, _date!);
    if (!mounted) return;
    if (team.isEmpty) {
      showFormError(context, l10n.noLastTeam);
      return;
    }
    setState(() => _selected.addAll(team));
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    if (_start == null || _end == null) {
      showFormError(context, l10n.timesRequired);
      return;
    }
    final breakMinutes = int.tryParse(_break.text.trim()) ?? -1;
    if (breakMinutes < 0) {
      showFormError(context, l10n.wholeNumberRequired);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceReviewScreen(
          date: _date!,
          clientId: _clientId!,
          siteId: _siteId!,
          inputs: [
            for (final workerId in _selected)
              EntryInput(
                workerId: workerId,
                shift: ShiftInput(startMinute: _start, endMinute: _end, breakMinutes: breakMinutes),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active).toList();
    final workers = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.active).toList();
    final sites = _clientId == null
        ? const <Site>[]
        : (ref.watch(sitesOfClientProvider(_clientId!)).value ?? const <Site>[]).where((s) => s.active).toList();
    final needle = _search.toLowerCase();
    final shown = workers.where((w) => w.name.toLowerCase().contains(needle) || w.code.toLowerCase().contains(needle)).toList();
    final ready = _clientId != null && _siteId != null && _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.markAttendance)),
      bottomNavigationBar: MainActionBar(label: l10n.nextWithCount(_selected.length), onPressed: ready ? _next : null),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clients.isEmpty || workers.isEmpty) ...[Text(l10n.needSetupFirst), fieldGap],
                DateField(l10n.workDate, value: _date, onChanged: (v) => setState(() => _date = v), required: true),
                fieldGap,
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('client$_clientId'),
                  initialValue: _clientId,
                  decoration: InputDecoration(labelText: l10n.chooseClient),
                  items: [for (final c in clients) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() {
                    _clientId = v;
                    _siteId = null;
                  }),
                ),
                fieldGap,
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('site$_clientId$_siteId'),
                  initialValue: sites.any((s) => s.id == _siteId) ? _siteId : null,
                  decoration: InputDecoration(labelText: l10n.chooseSite),
                  items: [for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => _pickSite(sites.firstWhere((s) => s.id == v)),
                ),
                fieldGap,
                Row(
                  children: [
                    Expanded(child: TimeField(l10n.shiftStart, value: _start, onChanged: (v) => setState(() => _start = v))),
                    const SizedBox(width: 12),
                    Expanded(child: TimeField(l10n.shiftEnd, value: _end, onChanged: (v) => setState(() => _end = v))),
                  ],
                ),
                fieldGap,
                Field(l10n.breakMinutes, _break, keyboardType: TextInputType.number),
                fieldGap,
              ],
            ),
          ),
          SearchBox(onChanged: (v) => setState(() => _search = v)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == workers.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(workers.map((w) => w.id));
                    }
                  }),
                  child: Text(_selected.length == workers.length && workers.isNotEmpty ? l10n.clearSelection : l10n.selectAll),
                ),
                TextButton(onPressed: _siteId == null ? null : _copyLastTeam, child: Text(l10n.copyLastTeam)),
              ],
            ),
          ),
          const Divider(),
          for (final w in shown) ...[
            CheckboxListTile(
              title: Text(w.name),
              subtitle: Text([w.code, ?w.trade].join(', ')),
              value: _selected.contains(w.id),
              onChanged: (checked) => setState(() => checked! ? _selected.add(w.id) : _selected.remove(w.id)),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
