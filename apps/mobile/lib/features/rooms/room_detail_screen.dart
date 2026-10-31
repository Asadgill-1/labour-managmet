import 'package:domain/cash.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../cash/cash_entry_form_screen.dart';
import '../cash/cash_row.dart';
import 'room_form_screen.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({required this.roomId, required this.month, super.key});

  final String roomId;

  /// YYYY-MM.
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = (ref.watch(roomsProvider).value ?? const <Room>[]).where((r) => r.id == roomId).firstOrNull;
    if (room == null) return Scaffold(appBar: AppBar());
    final rows = (ref.watch(cashInMonthProvider(month)).value ?? const <CashEntry>[]).where((e) => e.roomId == roomId).toList();
    final result = roomResult(rows.map(cashLine));
    final undone = undoneIds(rows);
    final residents = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.roomId == roomId && w.active).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          IconButton(
            tooltip: l10n.editRoom,
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RoomFormScreen(room: room))),
          ),
        ],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.addCash,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CashEntryFormScreen(kind: CashKind.roomRentPaid, roomId: roomId)),
        ),
      ),
      body: ListView(
        children: [
          ColoredBox(
            color: hiVis,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: BandFigure(formatAed(result.receivedFils), l10n.rentIn, size: 19)),
                  const SizedBox(width: 8),
                  Expanded(child: BandFigure(formatAed(result.paidFils), l10n.rentOut, size: 19)),
                  const SizedBox(width: 8),
                  Expanded(child: BandFigure(formatAed(result.netFils.abs()), result.netFils < 0 ? l10n.roomLossLabel : l10n.roomProfitLabel, size: 19)),
                ],
              ),
            ),
          ),
          SectionHeader(l10n.residentsHeading),
          const Divider(),
          if (residents.isEmpty) ListTile(subtitle: Text(l10n.noResidents)),
          for (final w in residents) ...[
            InfoRow(w.name, w.roomChargeFils == null ? l10n.notEntered : formatAed(w.roomChargeFils!)),
            const Divider(),
          ],
          SectionHeader(l10n.entriesHeading),
          const Divider(),
          if (rows.isEmpty) ListTile(subtitle: Text(l10n.cashEmpty)),
          for (final entry in rows) ...[
            CashEntryRow(entry, undone: undone.contains(entry.id), showDate: true),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
