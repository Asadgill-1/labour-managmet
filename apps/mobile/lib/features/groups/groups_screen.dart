import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/register_screen.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'group_form_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clients = {for (final c in ref.watch(clientsProvider).value ?? const <Client>[]) c.id: c.name};
    final sites = {for (final s in ref.watch(allSitesProvider).value ?? const <Site>[]) s.id: s.name};
    final members = ref.watch(allGroupMembersProvider).value ?? const <WorkerGroupMember>[];
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return RegisterScreen(
      title: l10n.tabGroups,
      emptyIcon: Icons.diversity_3,
      emptyText: l10n.groupsEmpty,
      addLabel: l10n.addGroup,
      onAdd: () => open(const GroupFormScreen()),
      rows: [
        for (final g in ref.watch(workerGroupsProvider).value ?? const <WorkerGroup>[])
          RegisterRow(
            tag: initial(g.name),
            title: g.name,
            subtitle: [
              ?clients[g.clientId],
              ?sites[g.siteId],
              l10n.membersCount(members.where((m) => m.groupId == g.id).length),
              if (g.dailyRateFils != null) formatAed(g.dailyRateFils!),
            ].join(', '),
            active: g.active,
            onTap: () => open(GroupFormScreen(group: g)),
          ),
      ],
    );
  }
}
