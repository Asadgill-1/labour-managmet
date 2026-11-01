import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../rates/rate_labels.dart';

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

  /// Worker ID to a rate set for them here. Null means their own contract, or the group's wage if they have none.
  Map<String, MemberRate?> _members = {};

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
          _members = {for (final m in rows) m.workerId: memberRateOf(m)};
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
    final saved = await saveOrExplain(context, () => db.transaction(() async {
      final id = await db.saveWorkerGroup(
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
      );
      // Together with the save, so a crash can't leave the group's open rows on its old wages.
      await db.repriceRows(operationId: newUuid(), groupId: id);
    }));
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  /// Sets what this worker earns in this group, starting from what they earn now. Left empty, it goes back to that.
  Future<void> _askRate(Worker worker, RateTerms? own) async {
    final l10n = AppLocalizations.of(context);
    final current = _members[worker.id];
    final amount = TextEditingController(text: current == null ? '' : plainAmount(current.fils));
    final form = GlobalKey<FormState>();
    var basis = current?.basis ?? (own?.basis == RateBasis.hour ? RateBasis.hour : RateBasis.day);
    final picked = await showDialog<({MemberRate? rate})>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setInner) => AlertDialog(
          title: Text(l10n.rateIn(worker.name)),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Field(
                  l10n.amountAed,
                  amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  helper: own == null ? l10n.ownWageHelp : l10n.ownRateHelp(rateSummary(l10n, own.basis.name, own.rateFils)),
                  validator: (v) => (v ?? '').trim().isNotEmpty && parseAed(v!) == null ? l10n.amountInvalid : null,
                ),
                fieldGap,
                SegmentedButton<RateBasis>(
                  segments: [
                    ButtonSegment(value: RateBasis.hour, label: Text(l10n.basisHour)),
                    ButtonSegment(value: RateBasis.day, label: Text(l10n.basisDay)),
                  ],
                  selected: {basis},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setInner(() => basis = s.single),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                final fils = parseAed(amount.text);
                Navigator.of(dialog).pop((rate: fils == null ? null : (fils: fils, basis: basis)));
              },
              child: Text(l10n.applyChanges),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _members[worker.id] = picked.rate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active || c.id == _clientId).toList();
    final sites = _clientId == null
        ? const <Site>[]
        : (ref.watch(sitesOfClientProvider(_clientId!)).value ?? const <Site>[]).where((s) => s.active || s.id == _siteId).toList();
    final contracts = groupedBy(ref.watch(allPayContractsProvider).value ?? const <PayContract>[], (c) => c.workerId);
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

    RateTerms? ownOf(Worker w) => pickRate((contracts[w.id] ?? const <PayContract>[]).map(payTerms), date: today, siteId: _siteId ?? '', workerId: w.id);

    /// What will be paid, in words, and whether it needs the owner's attention.
    (String, bool) rateLine(Worker w) {
      final own = ownOf(w);
      final set = _members[w.id];
      if (set != null) return (l10n.rateSetHere(rateSummary(l10n, set.basis.name, set.fils)), false);
      if (own != null) return (l10n.rateOwn(rateSummary(l10n, own.basis.name, own.rateFils)), false);
      if (groupWage != null) return (l10n.rateFromGroup(rateSummary(l10n, RateBasis.day.name, groupWage)), false);
      return (l10n.rateMissing, true);
    }

    Widget workerTile(Worker w) {
      final member = _members.containsKey(w.id);
      final line = member ? rateLine(w) : null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(w.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([w.code, ?w.trade].join(', ')),
                if (line != null) Text(line.$1, style: TextStyle(fontWeight: FontWeight.w600, color: line.$2 ? due : brand)),
              ],
            ),
            value: member,
            onChanged: (checked) => setState(() => checked! ? _members[w.id] = null : _members.remove(w.id)),
            secondary: member ? TextButton(onPressed: () => _askRate(w, ownOf(w)), child: Text(l10n.rateChange)) : null,
          ),
          const Divider(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.group == null ? l10n.addGroup : l10n.editGroup)),
      bottomNavigationBar: MainActionBar(label: l10n.saveWithCount(_members.length), onPressed: _loaded ? _save : null),
      body: Form(
        key: _form,
        // The fields stay built so they always validate. The workers build as they scroll, however many there are.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Field(l10n.groupName, _name, helper: l10n.groupNameHelp, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
                    fieldGap,
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      key: ValueKey('client$_clientId'),
                      initialValue: clients.any((c) => c.id == _clientId) ? _clientId : null,
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
            ),
            SliverToBoxAdapter(child: SectionHeader(l10n.workersHeading)),
            SliverToBoxAdapter(child: SearchBox(hint: l10n.searchWorker, onChanged: (v) => setState(() => _search = v))),
            const SliverToBoxAdapter(child: Divider()),
            SliverList.builder(itemCount: workers.length, itemBuilder: (context, i) => workerTile(workers[i])),
          ],
        ),
      ),
    );
  }
}
