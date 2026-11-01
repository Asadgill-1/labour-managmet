import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../payroll/wages_due_screen.dart';
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

  void _markAttendance() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendanceEntryScreen(date: _date)));
  }

  Future<void> _chooseDate() async {
    final picked = await pickDate(context, _date);
    if (picked != null) setState(() => _date = picked);
  }

  /// Rows change in place until their payroll is posted. After that they get a correction that keeps the original (ATT-08).
  Future<void> _openEntry(AttendanceEntry entry, String title) async {
    final l10n = AppLocalizations.of(context);
    if (isClosed(entry.workDate, ref.read(lockedThroughProvider).value)) {
      showFormError(context, l10n.periodLockedError);
      return;
    }
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
    } catch (e) {
      if (mounted) showFormError(context, saveErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(entriesOnDateProvider(_date)).value ?? const <AttendanceEntry>[];
    final allWorkers = ref.watch(workersProvider).value ?? const <Worker>[];
    final workers = {for (final w in allWorkers) w.id: w};
    final sites = {for (final s in ref.watch(allSitesProvider).value ?? const <Site>[]) s.id: s};
    final counts = attendanceCounts(
      entries.map((e) => (workerId: e.workerId, workDate: e.workDate, status: AttendanceStatus.values.byName(e.attendanceStatus))),
    );
    final recorded = entries.map((e) => e.workerId).toSet();
    final missing = allWorkers.where((w) => w.active && !recorded.contains(w.id)).toList();
    final today = dubaiToday(DateTime.now());
    final closed = isClosed(_date, ref.watch(lockedThroughProvider).value);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        // Shrinks rather than cutting the date off on a narrow phone with large text.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('${_date == today ? l10n.tabToday : dayName(l10n, _date)}, ${showDate(_date)}'),
        ),
        bottom: const SubTabs(Section.today),
        actions: [
          if (_date != today) BarButton(l10n.tabToday, onPressed: () => setState(() => _date = today)),
          IconButton(tooltip: l10n.pickDate, icon: const Icon(Icons.calendar_month), onPressed: _chooseDate),
        ],
      ),
      bottomNavigationBar: MainActionBar(label: l10n.markAttendance, onPressed: closed ? null : _markAttendance),
      body: ListView(
        children: [
          TopBand(
            child: Column(
              children: [
                DayStrip(selected: _date, onPick: (date) => setState(() => _date = date)),
                const SizedBox(height: 12),
                Semantics(
                  label: l10n.countsLine(counts.uniqueWorkers, counts.shifts, counts.workerDays),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Expanded(child: BandFigure('${counts.uniqueWorkers}', l10n.countWorkers)),
                      const SizedBox(width: 8),
                      Expanded(child: BandFigure('${counts.shifts}', l10n.countShifts)),
                      const SizedBox(width: 8),
                      Expanded(child: BandFigure('${counts.workerDays}', l10n.countWorkerDays)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const WagesDueBanner(),
          if (closed) const ClosedNote(),
          if (missing.isNotEmpty && !closed)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Material(
                color: warnSoft,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  tileColor: Colors.transparent,
                  leading: const Icon(Icons.warning_amber, color: warn),
                  title: Text(
                    l10n.missingWorkers(missing.length, missing.take(5).map((w) => w.name).join(', ')),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: warn),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: warn),
                  onTap: _markAttendance,
                ),
              ),
            ),
          if (entries.isEmpty) EmptyState(icon: Icons.assignment_outlined, text: l10n.todayEmpty),
          for (final entry in entries)
            _EntryRow(
              entry: entry,
              worker: workers[entry.workerId],
              site: sites[entry.siteId],
              onTap: () => _openEntry(entry, workers[entry.workerId]?.name ?? ''),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.smartphone, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text(l10n.localOnlyNote, style: const TextStyle(fontSize: 13, color: muted))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.worker, required this.site, required this.onTap});

  final AttendanceEntry entry;
  final Worker? worker;
  final Site? site;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = AttendanceStatus.values.byName(entry.attendanceStatus);
    final problems = [
      if (status != AttendanceStatus.absent && entry.clientRateFils == null) l10n.issueClientRate,
      if (status != AttendanceStatus.absent && entry.workerRateFils == null) l10n.issueWorkerRate,
    ];
    return RowCard(
      child: ListTile(
        leading: switch (status) {
          AttendanceStatus.present => const RowTag.icon(Icons.check, fill: settledSoft, color: settled),
          AttendanceStatus.half => const RowTag('½', fill: warnSoft, color: warn),
          AttendanceStatus.absent => const RowTag.icon(Icons.close, fill: dueSoft, color: due),
        },
        title: Text(worker?.name ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                ?worker?.code,
                ?site?.name,
                if (entry.startUtc == null)
                  statusLabel(l10n, status)
                else
                  '${showMinuteOfDay(dubaiMinuteOfDay(entry.startUtc!))}-${showMinuteOfDay(dubaiMinuteOfDay(entry.endUtc!))}',
                if (entry.revisesEntryId != null) l10n.correctedTag,
              ].join(', '),
            ),
            if (problems.isNotEmpty) Text(problems.join(', '), style: const TextStyle(color: due)),
          ],
        ),
        trailing: _StateLabel(entry.payrollLineId != null ? 'linked' : entry.state),
        onTap: onTap,
      ),
    );
  }
}

/// The row's approval state, in words as well as colour (UX-04).
class _StateLabel extends StatelessWidget {
  const _StateLabel(this.state);

  final String state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, fill, color) = switch (state) {
      'draft' => (l10n.stateDraft, warnSoft, warn),
      'submitted' => (l10n.stateSubmitted, warnSoft, warn),
      'approved' => (l10n.stateApproved, settledSoft, settled),
      _ => (l10n.stateLinked, brandSoft, brand),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
