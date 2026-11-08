import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/payroll.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

/// Ticks who pays a room charge this month, and how much. A worker's usual charge starts filled in (D-041).
class RoomChargeScreen extends ConsumerStatefulWidget {
  const RoomChargeScreen({required this.month, super.key});

  /// YYYY-MM.
  final String month;

  @override
  ConsumerState<RoomChargeScreen> createState() => _RoomChargeScreenState();
}

class _RoomChargeScreenState extends ConsumerState<RoomChargeScreen> {
  /// Fixed for this screen, so a double tap or a retry can only add once (TEAM-04).
  final _operationId = newUuid();
  final _common = TextEditingController();
  final _amounts = <String, TextEditingController>{};
  final _ticked = <String>{};

  TextEditingController _amountOf(Worker w) {
    return _amounts.putIfAbsent(w.id, () => TextEditingController(text: w.roomChargeFils == null ? '' : plainAmount(w.roomChargeFils!)));
  }

  Future<void> _save(List<Worker> candidates) async {
    final l10n = AppLocalizations.of(context);
    final charges = <String, int>{};
    for (final w in candidates.where((w) => _ticked.contains(w.id))) {
      final own = _amountOf(w).text.trim();
      final fils = parseAed(own.isEmpty ? _common.text : own) ?? 0;
      if (fils <= 0) {
        showFormError(context, l10n.roomChargeNeedAmount(w.name));
        return;
      }
      charges[w.id] = fils;
    }
    var added = 0;
    final saved = await saveOrExplain(context, () async {
      added = await ref.read(dbProvider).applyRoomCharges(
        widget.month,
        charges: charges,
        reason: l10n.payKindRoom,
        ownerApproved: l10n.roomChargeByOwner,
        operationId: _operationId,
      );
    });
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.roomChargesApplied(added));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payroll = ref.watch(payrollProvider(widget.month)).value ?? const <WorkerPayroll>[];
    final rooms = {for (final r in ref.watch(roomsProvider).value ?? const <Room>[]) r.id: r};
    final taken = payroll.where((p) => !p.canAddRoomCharge).map((p) => p.worker.id).toSet();
    final candidates = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.active && !taken.contains(w.id)).toList();
    final ticked = candidates.where((w) => _ticked.contains(w.id)).length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.roomChargeTitle(showMonth(widget.month)))),
      bottomNavigationBar: MainActionBar(label: l10n.roomChargeSave(ticked), onPressed: ticked == 0 ? null : () => _save(candidates)),
      body: candidates.isEmpty
          ? EmptyState(icon: Icons.bed, text: l10n.roomChargeNone)
          : ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: TextField(
                    controller: _common,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l10n.roomChargeAll, helperText: l10n.roomChargeAllHelp, helperMaxLines: 2),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton(
                      onPressed: () => setState(() => ticked == candidates.length ? _ticked.clear() : _ticked.addAll(candidates.map((w) => w.id))),
                      child: Text(ticked == candidates.length ? l10n.regClear : l10n.selectAll),
                    ),
                  ),
                ),
                for (final w in candidates)
                  RowCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(left: 4, right: 12),
                      leading: Checkbox(
                        value: _ticked.contains(w.id),
                        onChanged: (on) => setState(() => on == true ? _ticked.add(w.id) : _ticked.remove(w.id)),
                      ),
                      title: Text(w.name),
                      subtitle: Text([w.code, ?rooms[w.roomId]?.name].join(', ')),
                      trailing: SizedBox(
                        width: 104,
                        child: TextField(
                          controller: _amountOf(w),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          onChanged: (_) => setState(() => _ticked.add(w.id)),
                          decoration: InputDecoration(isDense: true, hintText: _common.text.trim().isEmpty ? 'AED' : _common.text.trim()),
                        ),
                      ),
                      onTap: () => setState(() => _ticked.contains(w.id) ? _ticked.remove(w.id) : _ticked.add(w.id)),
                    ),
                  ),
              ],
            ),
    );
  }
}
