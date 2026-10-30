import 'dart:collection';

import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../rates/rate_sections.dart';
import 'worker_form_screen.dart';

class WorkerDetailScreen extends ConsumerWidget {
  const WorkerDetailScreen({required this.workerId, super.key});

  final String workerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final worker = ref.watch(workersProvider).value?.where((w) => w.id == workerId).firstOrNull;
    if (worker == null) return Scaffold(appBar: AppBar());
    return Scaffold(
      appBar: AppBar(
        title: Text(worker.name),
        actions: [
          IconButton(
            tooltip: l10n.editWorker,
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => WorkerFormScreen(worker: worker)),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          if (!worker.active) ListTile(title: Text(l10n.archivedLabel)),
          ListTile(title: Text(l10n.workerCode), trailing: Text(worker.code)),
          const Divider(),
          if (worker.trade != null) ...[ListTile(title: Text(l10n.trade), trailing: Text(worker.trade!)), const Divider()],
          if (worker.phone != null) ...[ListTile(title: Text(l10n.phone), trailing: Text(worker.phone!)), const Divider()],
          if (worker.joiningDate != null) ...[
            ListTile(title: Text(l10n.joiningDate), trailing: Text(showDate(worker.joiningDate!))),
            const Divider(),
          ],
          if (worker.roomChargeFils != null) ...[
            ListTile(title: Text(l10n.roomCharge), trailing: Text(formatAed(worker.roomChargeFils!))),
            const Divider(),
          ],
          WorkerRateSections(workerId: workerId),
          fieldGap,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () {
                final db = ref.read(dbProvider);
                db.saveRow(
                  db.workers,
                  id: workerId,
                  operationId: newUuid(),
                  fields: WorkersCompanion(active: Value(!worker.active)),
                );
              },
              child: Text(worker.active ? l10n.archive : l10n.reactivate),
            ),
          ),
          fieldGap,
        ],
      ),
    );
  }
}
