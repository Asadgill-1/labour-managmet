import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

/// A team that usually works together, with its usual site, daily wage and duty time (D-029).
class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({this.group, super.key});

  final WorkerGroup? group;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _name = TextEditingController(text: widget.group?.name);
  late final _wage = TextEditingController(text: widget.group?.dailyRateFils == null ? '' : plainAmount(widget.group!.dailyRateFils!));
  late final _break = TextEditingController(text: (widget.group?.breakMinutes ?? 0).toString());
  late String? _clientId = widget.group?.clientId;
  late String? _siteId = widget.group?.siteId;
  late int? _start = widget.group?.startMinute;
  late int? _end = widget.group?.endMinute;
  late bool _halfIsHalf = widget.group?.halfDayIsHalf ?? true;
  late bool _active = widget.group?.active ?? true;

  /// Worker ID to their own daily wage. Null means the group's.
  Map<String, int?> _members = {};

  /// Saving before the members load would empty the group.
  late bool _loaded = widget.group == null;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _wage.addListener(() => setState(() {}));
    final group = widget.group;
    if (group == null) return;
    final db = ref.read(dbProvider);
    (db.select(db.workerGroupMembers)..where((m) => m.groupId.equals(group.id))).get().then((rows) {
      if (mounted) {
        setState(() {
          _members = {for (final m in rows) m.workerId: m.dailyRateFils};
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _wage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    if ((_start == null) != (_end == null)) {
      showFormError(context, l10n.timesRequired);
      return;
    }
    final db = ref.read(dbProvider);
    final saved = await saveOrExplain(context, () => db.saveWorkerGroup(
      id: widget.group?.id,
      operationId: _operationId,
      members: _members,
      fields: WorkerGroupsCompanion(
        name: Value(_name.text.trim()),
        clientId: Value(_clientId),
        siteId: Value(_clientId == null ? null : _siteId),
        dailyRateFils: Value(parseAed(_wage.text)),
        halfDayIsHalf: Value(_halfIsHalf),
        startMinute: Value(_start),
        endMinute: Value(_end),
        breakMinutes: Value(int.parse(_break.text.trim())),
        active: Value(_active),
      ),
    ));
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  Future<void> _askOwnWage(Worker worker) async {
    final l10n = AppLocalizations.of(context);
    final result = await askDailyWage(context, title: l10n.wageOf(worker.name), helper: l10n.ownWageHelp, initial: _members[worker.id]);
    if (result != null) setState(() => _members[worker.id] = result.fils);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active || c.id == _clientId).toList();
    final sites = _clientId == null
        ? const <Site>[]
        : (ref.watch(sitesOfClientProvider(_clientId!)).value ?? const <Site>[]).where((s) => s.active || s.id == _siteId).toList();
    final pay = ref.watch(allPayContractsProvider).value ?? const <PayContract>[];
    final today = dubaiToday(DateTime.now());
    final groupWage = parseAed(_wage.text);
    final needle = _search.toLowerCase();
    final workers = (ref.watch(workersProvider).value ?? const <Worker>[])
        .where((w) => (w.active || _members.containsKey(w.id)) && (w.name.toLowerCase().contains(needle) || w.code.toLowerCase().contains(needle)))
        .toList()
      ..sort((a, b) {
        final aIn = _members.containsKey(a.id) ? 0 : 1;
        final bIn = _members.containsKey(b.id) ? 0 : 1;
        return aIn != bIn ? aIn.compareTo(bIn) : a.name.compareTo(b.name);
      });

    String wageLabel(Worker w) {
      final own = _members[w.id];
      if (own != null) return formatAed(own);
      if (onMonthlyPay(pay, w.id, today)) return l10n.monthlyPay;
      return groupWage == null ? l10n.setWage : formatAed(groupWage);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.group == null ? l10n.addGroup : l10n.editGroup)),
      bottomNavigationBar: MainActionBar(label: l10n.saveWithCount(_members.length), onPressed: _loaded ? _save : null),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field(l10n.groupName, _name, helper: l10n.groupNameHelp, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
                    fieldGap,
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: ValueKey('client$_clientId'),
                      initialValue: _clientId,
                      decoration: InputDecoration(labelText: l10n.chooseClient),
                      items: [
                        DropdownMenuItem(child: Text(l10n.noneChoice)),
                        for (final c in clients) DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() {
                        _clientId = v;
                        _siteId = null;
                      }),
                    ),
                    fieldGap,
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: ValueKey('site$_clientId$_siteId'),
                      initialValue: sites.any((s) => s.id == _siteId) ? _siteId : null,
                      decoration: InputDecoration(labelText: l10n.chooseSite),
                      items: [
                        DropdownMenuItem(child: Text(l10n.noneChoice)),
                        for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _siteId = v),
                    ),
                    fieldGap,
                    Field(
                      l10n.dailyWage,
                      _wage,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      helper: l10n.dailyWageHelp,
                      validator: (v) => (v ?? '').trim().isNotEmpty && parseAed(v!) == null ? l10n.amountInvalid : null,
                    ),
                    if (groupWage != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        tileColor: Colors.transparent,
                        title: Text(l10n.halfDayIsHalf),
                        value: _halfIsHalf,
                        onChanged: (v) => setState(() => _halfIsHalf = v),
                      ),
                    fieldGap,
                    Row(
                      children: [
                        Expanded(child: TimeField(l10n.defaultStart, value: _start, onChanged: (v) => setState(() => _start = v))),
                        const SizedBox(width: 12),
                        Expanded(child: TimeField(l10n.defaultEnd, value: _end, onChanged: (v) => setState(() => _end = v))),
                      ],
                    ),
                    fieldGap,
                    Field(
                      l10n.defaultBreakMinutes,
                      _break,
                      keyboardType: TextInputType.number,
                      validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? l10n.wholeNumberRequired : null,
                    ),
                    if (widget.group != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        tileColor: Colors.transparent,
                        title: Text(l10n.activeLabel),
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                      ),
                  ],
                ),
              ),
              SectionHeader(l10n.workersHeading),
              SearchBox(hint: l10n.searchWorker, onChanged: (v) => setState(() => _search = v)),
              const Divider(),
              for (final w in workers) ...[
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(w.name),
                  subtitle: Text([w.code, ?w.trade].join(', ')),
                  value: _members.containsKey(w.id),
                  onChanged: (checked) => setState(() => checked! ? _members[w.id] = null : _members.remove(w.id)),
                  secondary: _members.containsKey(w.id) ? TextButton(onPressed: () => _askOwnWage(w), child: Text(wageLabel(w))) : null,
                ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
