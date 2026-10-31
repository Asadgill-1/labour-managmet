import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/register_screen.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'worker_detail_screen.dart';
import 'worker_form_screen.dart';

class LabourScreen extends ConsumerWidget {
  const LabourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return RegisterScreen(
      title: l10n.tabLabour,
      emptyIcon: Icons.groups,
      emptyText: l10n.labourEmpty,
      addLabel: l10n.addWorker,
      onAdd: () => open(const WorkerFormScreen()),
      rows: [
        for (final w in ref.watch(workersProvider).value ?? const <Worker>[])
          RegisterRow(
            tag: w.code,
            title: w.name,
            subtitle: w.trade,
            active: w.active,
            onTap: () => open(WorkerDetailScreen(workerId: w.id)),
          ),
      ],
    );
  }
}
