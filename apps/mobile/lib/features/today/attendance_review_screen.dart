import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'row_editor_screen.dart';

/// Every problem a row has, in words. Empty means the row is fine.
List<String> rowProblems(AppLocalizations l10n, RowPreview row) => [
  if (!row.priced.breakValid) l10n.issueBreak,
  if (row.overlaps && (row.input.overlapReason ?? '').isEmpty) l10n.issueOverlap,
  if (row.input.hasOverride && (row.input.overrideReason ?? '').isEmpty) l10n.issueOverrideReason,
  if (row.priced.client.issue == LineIssue.missingRate) l10n.issueClientRate,
  if (row.priced.worker.issue == LineIssue.missingRate) l10n.issueWorkerRate,
  if (row.priced.client.issue == LineIssue.missingHalfAmount || row.priced.worker.issue == LineIssue.missingHalfAmount) l10n.issueHalf,
  if (row.priced.client.issue == LineIssue.missingOvertimeRate || row.priced.worker.issue == LineIssue.missingOvertimeRate) l10n.issueOvertime,
];

String statusLabel(AppLocalizations l10n, AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => l10n.statusPresent,
  AttendanceStatus.half => l10n.statusHalf,
  AttendanceStatus.absent => l10n.statusAbsent,
};

/// Step two (ATT-01): every worker's row, with exceptions and totals, before one atomic save.
class AttendanceReviewScreen extends ConsumerStatefulWidget {
  const AttendanceReviewScreen({required this.date, required this.clientId, required this.siteId, required this.inputs, super.key});

  final String date;
  final String clientId;
  final String siteId;
  final List<EntryInput> inputs;

  @override
  ConsumerState<AttendanceReviewScreen> createState() => _AttendanceReviewScreenState();
}

class _AttendanceReviewScreenState extends ConsumerState<AttendanceReviewScreen> {
  /// Fixed for this screen, so a double tap or a retry can only save once (TEAM-04).
  final _operationId = newUuid();
  late List<EntryInput> _inputs = widget.inputs;
  List<RowPreview>? _rows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = ref.read(dbProvider);
    final rows = await Future.wait(
      _inputs.map((input) => db.previewRow(workDate: widget.date, clientId: widget.clientId, siteId: widget.siteId, input: input)),
    );
    if (mounted) setState(() => _rows = rows);
  }

  Future<void> _editRow(RowPreview row, String title) async {
    final edit = await Navigator.of(context).push<RowEdit>(
      MaterialPageRoute(builder: (_) => RowEditorScreen(title: title, input: row.input, overlaps: row.overlaps)),
    );
    if (edit?.input == null) return;
    _inputs = [for (final i in _inputs) i.workerId == row.input.workerId ? edit!.input! : i];
    await _refresh();
  }

  Future<void> _groupRate() async {
    final l10n = AppLocalizations.of(context);
    final amount = TextEditingController();
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.groupRate),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Field(
                l10n.groupRateAmount,
                amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => parseAed(v ?? '') == null ? l10n.amountInvalid : null,
              ),
              fieldGap,
              Field(l10n.overrideReason, reason, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.of(dialog).pop(true);
            },
            child: Text(l10n.applyChanges),
          ),
        ],
      ),
    );
    if (applied != true) return;
    final rate = parseAed(amount.text)!;
    _inputs = [
      for (final i in _inputs)
        EntryInput(
          workerId: i.workerId,
          groupId: i.groupId,
          overrideReason: reason.text.trim(),
          overlapReason: i.overlapReason,
          notes: i.notes,
          shift: ShiftInput(
            status: i.shift.status,
            startMinute: i.shift.startMinute,
            endMinute: i.shift.endMinute,
            breakMinutes: i.shift.breakMinutes,
            breakPaidClient: i.shift.breakPaidClient,
            breakPaidWorker: i.shift.breakPaidWorker,
            overtimeApproved: i.shift.overtimeApproved,
            clientOverrideFils: rate,
            workerOverrideFils: i.shift.workerOverrideFils,
          ),
        ),
    ];
    await _refresh();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final rows = _rows!;
    if (rows.any((r) => r.blocksSave)) {
      showFormError(context, l10n.rowsNeedFix);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dbProvider).saveAttendanceBatch(
        workDate: widget.date,
        clientId: widget.clientId,
        siteId: widget.siteId,
        inputs: _inputs,
        operationId: _operationId,
      );
    } on AttendanceInvalid {
      // Nothing was written. Show what changed, and let the owner fix it.
      await _refresh();
      if (mounted) {
        setState(() => _saving = false);
        showFormError(context, l10n.rowsNeedFix);
      }
      return;
    } catch (_) {
      // The operation ID is unchanged, so tapping Save again cannot save twice.
      if (mounted) {
        setState(() => _saving = false);
        showFormError(context, l10n.saveFailed);
      }
      return;
    }
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workers = {for (final w in ref.watch(workersProvider).value ?? const <Worker>[]) w.id: w};
    final rows = _rows;
    if (rows == null) return Scaffold(appBar: AppBar(title: Text(l10n.reviewTitle)));
    final clientTotal = rows.fold<int>(0, (sum, r) => sum + (r.priced.client.amountFils ?? 0));
    final workerTotal = rows.fold<int>(0, (sum, r) => sum + (r.priced.worker.amountFils ?? 0));
    final anyPeriod = rows.any((r) {
      final client = r.priced.clientBasis;
      final worker = r.priced.workerBasis;
      return (client != null && isPeriodBasis(client)) || (worker != null && isPeriodBasis(worker));
    });
    final anyDraft = rows.any((r) => r.priced.hasPricingIssue);
    return Scaffold(
      appBar: AppBar(title: Text(showDate(widget.date))),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _saving ? null : _save),
      body: ListView(
        children: [
          TopBand(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: BandFigure(formatAed(clientTotal), l10n.totalClient, size: 22)),
                const SizedBox(width: 8),
                Expanded(child: BandFigure(formatAed(workerTotal), l10n.totalWorker, size: 22)),
              ],
            ),
          ),
          if (anyPeriod) ...[ListTile(subtitle: Text(l10n.monthlyNotInTotal)), const Divider()],
          if (anyDraft) ...[ListTile(subtitle: Text(l10n.savesAsDraft)), const Divider()],
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(onPressed: _groupRate, child: Text(l10n.groupRate)),
            ),
          ),
          const Divider(),
          for (final row in rows) ...[
            _ReviewRow(
              row: row,
              worker: workers[row.input.workerId],
              onTap: () => _editRow(row, workers[row.input.workerId]?.name ?? ''),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.row, required this.worker, required this.onTap});

  final RowPreview row;
  final Worker? worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shift = row.input.shift;
    final problems = rowProblems(l10n, row);
    final times = shift.status == AttendanceStatus.absent
        ? statusLabel(l10n, shift.status)
        : '${showMinuteOfDay(shift.startMinute!)}-${showMinuteOfDay(shift.endMinute!)}, ${l10n.hoursPaid(showDuration(row.priced.workerMinutes))}';
    final amounts = [
      if (row.priced.client.amountFils != null) l10n.rowCollect(formatAed(row.priced.client.amountFils!)),
      if (row.priced.worker.amountFils != null) l10n.rowPay(formatAed(row.priced.worker.amountFils!)),
    ];
    return ListTile(
      title: Text(worker == null ? '' : '${worker!.name} (${worker!.code})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(times),
          if (shift.status == AttendanceStatus.half) Text(statusLabel(l10n, shift.status)),
          if (amounts.isNotEmpty) Text(amounts.join(', ')),
          for (final problem in problems)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 18, color: due),
                const SizedBox(width: 4),
                Expanded(child: Text(problem, style: const TextStyle(color: due))),
              ],
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
