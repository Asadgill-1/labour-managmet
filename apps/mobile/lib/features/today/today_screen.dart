import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'attendance_entry_screen.dart';
import 'attendance_review_screen.dart';
import 'row_editor_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  String _date = dubaiToday(DateTime.now());

  String _stateLabel(AppLocalizations l10n, AttendanceEntry e) => switch (e.state) {
    'draft' => l10n.stateDraft,
    'submitted' => l10n.stateSubmitted,
    'approved' => l10n.stateApproved,
    _ => l10n.stateLinked,
  };

  Future<void> _approve(List<AttendanceEntry> pending) async {
    final l10n = AppLocalizations.of(context);
    var count = 0;
    final done = await saveOrExplain(context, () async {
      count = await ref.read(dbProvider).approveEntries(pending, operationId: newUuid());
    });
    if (done && mounted) showSavedOnPhone(context, l10n.approvedCount(count));
  }

  /// Unapproved rows change in place. Approved rows get a correction that keeps the original (ATT-08).
  Future<void> _openEntry(AttendanceEntry entry, String title) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final locked = entry.state == 'approved' || entry.state == 'linked';
    final input = entryToInput(entry);
    final preview = await db.previewRow(workDate: entry.workDate, clientId: entry.clientId, siteId: entry.siteId, input: input, exceptId: entry.id);
    if (!mounted) return;
    final edit = await Navigator.of(context).push<RowEdit>(
      MaterialPageRoute(
        builder: (_) => RowEditorScreen(title: title, input: input, overlaps: preview.overlaps, correcting: locked, canDelete: !locked),
      ),
    );
    if (edit == null) return;
    try {
      if (edit.delete) {
        await db.deleteUnapprovedEntry(entry, operationId: newUuid());
      } else if (locked) {
        await db.correctEntry(entry, edit.input!, reason: edit.correctionReason!, operationId: newUuid());
      } else {
        await db.updateUnapprovedEntry(entry, edit.input!, operationId: newUuid());
      }
      if (mounted) showSavedOnPhone(context, l10n.savedOnPhone);
    } on AttendanceInvalid {
      if (mounted) showFormError(context, l10n.rowsNeedFix);
    } catch (_) {
      if (mounted) showFormError(context, l10n.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(entriesOnDateProvider(_date)).value ?? const <AttendanceEntry>[];
    final allWorkers = ref.watch(workersProvider).value ?? const <Worker>[];
    final workers = {for (final w in allWorkers) w.id: w};
    final sites = {for (final s in ref.watch(allSitesProvider).value ?? const <Site>[]) s.id: s};
    final pending = entries.where((e) => e.state == 'draft' || e.state == 'submitted').toList();
    final counts = attendanceCounts(
      entries.map((e) => (workerId: e.workerId, workDate: e.workDate, status: AttendanceStatus.values.byName(e.attendanceStatus))),
    );
    final recorded = entries.map((e) => e.workerId).toSet();
    final missing = allWorkers.where((w) => w.active && !recorded.contains(w.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(showDate(_date)),
        actions: [
          IconButton(
            tooltip: l10n.previousDay,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _date = addDays(_date, -1)),
          ),
          IconButton(
            tooltip: l10n.nextDay,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _date = addDays(_date, 1)),
          ),
        ],
      ),
      bottomNavigationBar: MainActionBar(
        label: l10n.markAttendance,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendanceEntryScreen(date: _date))),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.countsLine(counts.uniqueWorkers, counts.shifts, counts.workerDays), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(l10n.localOnlyNote),
              ],
            ),
          ),
          const Divider(),
          if (missing.isNotEmpty) ...[
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text(l10n.missingWorkers(missing.length, missing.take(5).map((w) => w.name).join(', '))),
            ),
            const Divider(),
          ],
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(onPressed: () => _approve(pending), child: Text(l10n.approveAll(pending.length))),
            ),
          if (entries.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l10n.todayEmpty)),
          for (final entry in entries) ...[
            ListTile(
              title: Text(workers[entry.workerId] == null ? '' : '${workers[entry.workerId]!.name} (${workers[entry.workerId]!.code})'),
              subtitle: Text(
                [
                  ?sites[entry.siteId]?.name,
                  if (entry.startUtc == null)
                    statusLabel(l10n, AttendanceStatus.absent)
                  else
                    '${showMinuteOfDay(dubaiMinuteOfDay(entry.startUtc!))}-${showMinuteOfDay(dubaiMinuteOfDay(entry.endUtc!))}',
                  _stateLabel(l10n, entry),
                  if (entry.state == 'draft' && entry.clientRateFils == null) l10n.issueClientRate,
                  if (entry.state == 'draft' && entry.workerRateFils == null) l10n.issueWorkerRate,
                  if (entry.revisesEntryId != null) l10n.correctedTag,
                ].join(', '),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _openEntry(entry, workers[entry.workerId]?.name ?? ''),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
