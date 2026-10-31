import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

/// "Profit AED 500.00", "Loss AED 500.00" or "Even". In words, so it never relies on colour (UX-04).
String roomResultText(AppLocalizations l10n, int netFils) {
  if (netFils > 0) return l10n.roomProfit(formatAed(netFils));
  if (netFils < 0) return l10n.roomLoss(formatAed(-netFils));
  return l10n.roomEven;
}

/// The month's rent per room: what came in, what went out, and the difference (D-031).
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _month = dubaiToday(DateTime.now()).substring(0, 7);
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = (ref.watch(roomsProvider).value ?? const <Room>[]).where((r) => r.active != _showArchived).toList();
    final entries = ref.watch(cashInMonthProvider(_month)).value ?? const <CashEntry>[];
    final charges = ref.watch(roomChargesInMonthProvider(_month)).value ?? const <PayrollItem>[];
    int deducted(Iterable<PayrollItem> items) => items.fold(0, (total, i) => total + i.amountFils);
    final all = roomResult(entries.map(cashLine), deductedFils: deducted(charges.where((i) => i.roomId != null)));
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: Text(l10n.tabRooms),
        bottom: const SubTabs(Section.rooms),
        actions: [BarButton(_showArchived ? l10n.showActive : l10n.showArchived, onPressed: () => setState(() => _showArchived = !_showArchived))],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.addRoom,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RoomFormScreen())),
      ),
      body: ListView(
        children: [
          TopBand(
            child: Column(
              children: [
                MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BandFigure(formatAed(all.receivedFils), l10n.rentIn, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(all.paidFils), l10n.rentOut, size: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: BandFigure(formatAed(all.netFils.abs()), all.netFils < 0 ? l10n.roomLossLabel : l10n.roomProfitLabel, size: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (rooms.isEmpty) EmptyState(icon: Icons.bed, text: l10n.roomsEmpty),
          for (final room in rooms)
            Builder(
              builder: (context) {
                final result = roomResult(entries.where((e) => e.roomId == room.id).map(cashLine), deductedFils: deducted(charges.where((i) => i.roomId == room.id)));
                return RowCard(
                  child: ListTile(
                    leading: RowTag(initial(room.name)),
                    title: Text(room.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.rentSplit(formatAed(result.receivedFils), formatAed(result.paidFils))),
                        Text(
                          roomResultText(l10n, result.netFils),
                          style: amountStyle.copyWith(fontSize: 16, color: result.netFils < 0 ? due : (result.netFils > 0 ? settled : muted)),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RoomDetailScreen(roomId: room.id, month: _month))),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
