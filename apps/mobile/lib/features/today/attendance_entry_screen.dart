import 'package:domain/calc.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'attendance_review_screen.dart';

/// Step one of attendance (ATT-01): date, a group or single workers, client, site, one shift, and who worked.
/// Client and site start on the last ones used, so a repeat day is only a few taps (UX-05).
/// Unticking or adding a worker here is for this attendance only. The group itself never changes (D-029).
class AttendanceEntryScreen extends ConsumerStatefulWidget {
  const AttendanceEntryScreen({required this.date, super.key});

  final String date;

  @override
  ConsumerState<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends ConsumerState<AttendanceEntryScreen> {
  late String? _date = widget.date;
  WorkerGroup? _group;

  /// The chosen group's members and their own daily wages.
  Map<String, int?> _members = const {};
  String? _clientId;
  String? _siteId;
  int? _start;
  int? _end;
  final _break = TextEditingController(text: '0');
  final _selected = <String>{};

  /// Daily wages typed here. For this attendance only.
  final _todayWage = <String, int>{};
  String _search = '';
  String _groupSearch = '';

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

  /// Choosing a group ticks its members and fills in whatever it knows. Tapping it again clears it.
  Future<void> _toggleGroup(WorkerGroup group) async {
    if (_group?.id == group.id) {
      setState(() {
        _group = null;
        _members = const {};
        _selected.clear();
        _todayWage.clear();
      });
      return;
    }
    final db = ref.read(dbProvider);
    final members = await (db.select(db.workerGroupMembers)..where((m) => m.groupId.equals(group.id))).get();
    final site = group.siteId == null ? null : await (db.select(db.sites)..where((s) => s.id.equals(group.siteId!))).getSingle();
    if (!mounted) return;
    final active = {for (final w in ref.read(workersProvider).value ?? const <Worker>[]) if (w.active) w.id};
    setState(() {
      _group = group;
      _members = {for (final m in members) m.workerId: m.dailyRateFils};
      _todayWage.clear();
      _selected
        ..clear()
        ..addAll(members.map((m) => m.workerId).where(active.contains));
      if (group.clientId != null) {
        _clientId = group.clientId;
        _siteId = null;
      }
      if (site != null && site.active) _pickSite(site);
      if (group.startMinute != null) {
        _start = group.startMinute;
        _end = group.endMinute;
        _break.text = group.breakMinutes.toString();
      }
    });
  }

  /// False if the owner cancelled.
  Future<bool> _askTodayWage(Worker worker) async {
    final l10n = AppLocalizations.of(context);
    final usual = _members[worker.id] ?? _group?.dailyRateFils;
    final result = await askDailyWage(
      context,
      title: l10n.wageOf(worker.name),
      helper: l10n.todayWageHelp,
      initial: _todayWage[worker.id] ?? usual,
    );
    if (result == null) return false;
    setState(() {
      final fils = result.fils;
      if (fils == null || fils == usual) {
        _todayWage.remove(worker.id);
      } else {
        _todayWage[worker.id] = fils;
      }
    });
    return true;
  }

  /// Someone outside the group is asked about first, starting from the group's daily wage.
  Future<void> _toggleWorker(Worker worker, bool checked) async {
    if (!checked) {
      setState(() {
        _selected.remove(worker.id);
        _todayWage.remove(worker.id);
      });
      return;
    }
    if (_group != null && !_members.containsKey(worker.id) && !await _askTodayWage(worker)) return;
    if (mounted) setState(() => _selected.add(worker.id));
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
                groupId: _group?.id,
                overrideReason: _todayWage.containsKey(workerId) ? l10n.todayWageReason : null,
                shift: ShiftInput(startMinute: _start, endMinute: _end, breakMinutes: breakMinutes, workerOverrideFils: _todayWage[workerId]),
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
    final pay = ref.watch(allPayContractsProvider).value ?? const <PayContract>[];
    final groupNeedle = _groupSearch.toLowerCase();
    final allGroups = (ref.watch(workerGroupsProvider).value ?? const <WorkerGroup>[]).where((g) => g.active).toList();
    final groups = allGroups.where((g) => g.name.toLowerCase().contains(groupNeedle)).toList();
    final needle = _search.toLowerCase();
    final shown = workers.where((w) => w.name.toLowerCase().contains(needle) || w.code.toLowerCase().contains(needle)).toList()
      ..sort((a, b) {
        final aIn = _members.containsKey(a.id) ? 0 : 1;
        final bIn = _members.containsKey(b.id) ? 0 : 1;
        return aIn != bIn ? aIn.compareTo(bIn) : a.name.compareTo(b.name);
      });
    final ready = _clientId != null && _siteId != null && _selected.isNotEmpty;

    String wageLabel(Worker w) {
      final wage = _todayWage[w.id] ?? _members[w.id];
      if (wage != null) return formatAed(wage);
      if (onMonthlyPay(pay, w.id, _date!)) return l10n.monthlyPay;
      return _group!.dailyRateFils == null ? l10n.setWage : formatAed(_group!.dailyRateFils!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.markAttendance)),
      bottomNavigationBar: MainActionBar(label: l10n.nextWithCount(_selected.length), onPressed: ready ? _next : null),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clients.isEmpty || workers.isEmpty) ...[Text(l10n.needSetupFirst), fieldGap],
                DateField(l10n.workDate, value: _date, onChanged: (v) => setState(() => _date = v), required: true),
              ],
            ),
          ),
          if (allGroups.isNotEmpty) ...[
            SectionHeader(l10n.tabGroups),
            SearchBox(hint: l10n.searchGroup, onChanged: (v) => setState(() => _groupSearch = v)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final g in groups) ChoiceChip(label: Text(g.name), selected: _group?.id == g.id, onSelected: (_) => _toggleGroup(g)),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
          ),
          SectionHeader(l10n.workersHeading),
          SearchBox(hint: l10n.searchWorker, onChanged: (v) => setState(() => _search = v)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == workers.length) {
                      _selected.clear();
                      _todayWage.clear();
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
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(w.name),
              subtitle: Text([w.code, ?w.trade].join(', ')),
              value: _selected.contains(w.id),
              onChanged: (checked) => _toggleWorker(w, checked!),
              secondary: _group != null && _selected.contains(w.id) ? TextButton(onPressed: () => _askTodayWage(w), child: Text(wageLabel(w))) : null,
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
