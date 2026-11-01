import 'dart:typed_data';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/timesheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/documents.dart';
import '../../data/tenant_database.dart';
import '../../data/timesheets.dart';
import '../../l10n/app_localizations.dart';
import '../documents/letterhead_screen.dart';
import '../rates/rate_labels.dart';
import 'timesheet_paper.dart';
import 'timesheets_screen.dart';

/// One revision of a timesheet: what is on it, how far it has gone and what can happen next (TS-01 to TS-06).
class TimesheetScreen extends ConsumerStatefulWidget {
  const TimesheetScreen({required this.timesheetId, this.revision, super.key});

  final String timesheetId;

  /// An older revision to look at. Null means the newest.
  final int? revision;

  @override
  ConsumerState<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends ConsumerState<TimesheetScreen> {
  bool _workers = false;
  bool _busy = false;

  TenantDatabase get _db => ref.read(dbProvider);

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  Future<void> _step(Future<void> Function() work) async {
    final saved = await saveOrExplain(context, work);
    if (saved && mounted) showSavedOnPhone(context, AppLocalizations.of(context).savedOnPhone);
  }

  Future<void> _approve(TimesheetView v) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.tsApprove),
        content: Text(l10n.tsApproveBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.tsApprove)),
        ],
      ),
    );
    if (yes == true && mounted) await _step(() => _db.approveTimesheet(v.revision.id, operationId: newUuid()));
  }

  Future<void> _deleteDraft(TimesheetView v) async {
    final navigator = Navigator.of(context);
    final saved = await saveOrExplain(context, () => _db.deleteTimesheetDraft(v.revision.id, operationId: newUuid()));
    if (saved && mounted && v.revision.revision == 1) navigator.pop();
  }

  Future<void> _paper(TimesheetView v) async {
    final choice = await showModalBottomSheet<(bool, bool)>(context: context, builder: (_) => _PaperSheet(workers: _workers));
    if (choice == null || !mounted) return;
    await shareTimesheet(context, ref, v, workers: choice.$1, priced: choice.$2, onBusy: _setBusy);
  }

  Future<void> _revise(TimesheetView v) async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(context, title: l10n.tsNewRevision, helper: l10n.tsRevisionHelp, confirm: l10n.tsRevisionConfirm);
    if (reason != null && mounted) await _step(() => _db.startTimesheetRevision(v.sheet.id, reason: reason, operationId: newUuid()));
  }

  Future<void> _respond(TimesheetView v, {required bool accepted}) async {
    final answer = await showModalBottomSheet<_Response>(context: context, isScrollControlled: true, builder: (_) => _ResponseSheet(accepted: accepted));
    if (answer == null || !mounted) return;
    await _step(() async {
      final photo = answer.photo == null ? null : await _db.saveEvidenceImage(answer.photo!, operationId: newUuid());
      await _db.recordTimesheetResponse(v.revision.id, accepted: accepted, date: answer.date, note: answer.note, evidenceAssetId: photo, operationId: newUuid());
    });
  }

  Future<void> _adjust(TimesheetView v, TimesheetRow row) async {
    final answer = await showModalBottomSheet<({TsAdjustment? agreed})>(context: context, isScrollControlled: true, builder: (_) => _AdjustSheet(row: row));
    if (answer == null || !mounted) return;
    await _step(() => _db.adjustTimesheetRow(v.revision.id, row.entryId, answer.agreed, operationId: newUuid()));
  }

  void _open(int revision) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TimesheetScreen(timesheetId: widget.timesheetId, revision: revision)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = ref.watch(timesheetProvider((id: widget.timesheetId, revision: widget.revision))).value;
    if (v == null) return Scaffold(appBar: AppBar(title: Text(l10n.tsTitle)));

    final number = v.sheet.number == null ? l10n.tsTitle : '${v.sheet.number}${v.revision.revision > 1 ? ' R${v.revision.revision}' : ''}';
    final current = v.isLatest;
    final (label, press) = switch ((current, v.status)) {
      (true, TsStatus.draft) => (l10n.tsApprove, v.rows.isEmpty ? null : () => _approve(v)),
      (true, TsStatus.disputed) => (l10n.tsNewRevision, () => _revise(v)),
      _ => (l10n.tsPaper, () => _paper(v)),
    };
    final more = !current
        ? const <(String, VoidCallback)>[]
        : switch (v.status) {
            TsStatus.draft => [(l10n.tsDeleteDraft, () => _deleteDraft(v))],
            TsStatus.approved => [(l10n.tsShared, () => _step(() => _db.markTimesheetShared(v.revision.id, dubaiToday(DateTime.now()), operationId: newUuid()))), (l10n.tsNewRevision, () => _revise(v))],
            TsStatus.shared => [(l10n.tsAccepted, () => _respond(v, accepted: true)), (l10n.tsDisputed, () => _respond(v, accepted: false)), (l10n.tsNewRevision, () => _revise(v))],
            TsStatus.disputed => [(l10n.tsAccepted, () => _respond(v, accepted: true)), (l10n.tsPaper, () => _paper(v))],
            TsStatus.accepted => [(l10n.tsNewRevision, () => _revise(v))],
          };

    final head = <Widget>[
      TopBand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.clientName, style: sectionTitleStyle.copyWith(color: Colors.white)),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text('${l10n.dateFromTo(showDate(v.sheet.fromDate), showDate(v.sheet.toDate))}, ${v.siteName ?? l10n.tsAllSites}', style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.85))),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: BandFigure(v.lines.any((l) => l.amountFils != null) || v.monthly.isEmpty ? formatAed(v.totals.amountFils) : l10n.tsMonthlyRow, l10n.tsAmount, size: 20)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: BandFigure('${v.totals.workerDays}', l10n.tsWorkerDays, size: 20)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: BandFigure('${v.totals.uniqueWorkers}', l10n.tsUniqueWorkers, size: 20)),
              ],
            ),
          ],
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (!current) NoteRow(icon: Icons.history, text: l10n.tsOldRevisionNote, color: muted),
      if (v.status == TsStatus.accepted) ...[
        const SizedBox(height: 20),
        Center(child: ClosedStamp(l10n.tsStatusAccepted, showDate(v.revision.respondedOn ?? ''))),
        const SizedBox(height: 12),
      ] else
        NoteRow(
          icon: v.status == TsStatus.disputed ? Icons.error_outline : Icons.info_outline,
          color: v.status == TsStatus.disputed ? due : muted,
          text: switch (v.status) {
            TsStatus.draft => l10n.tsDraftNote,
            TsStatus.approved => '${l10n.tsStatusApproved}. ${l10n.tsNoteApproved}',
            TsStatus.shared => '${l10n.tsStatusShared}. ${l10n.tsNoteShared}',
            TsStatus.disputed => '${l10n.tsStatusDisputed}. ${l10n.tsNoteDisputed}',
            TsStatus.accepted => '',
          },
        ),
      if (v.revision.reason != null) NoteRow(icon: Icons.edit_note, text: l10n.tsRevisedBecause(v.revision.reason!), color: muted),
      if (v.revision.responseNote != null) NoteRow(icon: Icons.chat_bubble_outline, text: v.revision.responseNote!, color: ink),
      if (v.revision.evidenceAssetId != null) _Evidence(assetId: v.revision.evidenceAssetId!),
      if (v.leftOut != null) ...leftOutNotes(l10n, v.leftOut!),
      if (current && v.changedRows > 0) NoteRow(icon: Icons.error_outline, text: l10n.tsChanged(v.changedRows), color: due),
      if (v.billingChanges.isNotEmpty) NoteRow(icon: Icons.error_outline, text: l10n.tsBillingChanged(v.billingChanges.length, formatAed(v.billingChanges.fold(0, (total, c) => total + c.differenceFils))), color: due),
      // Up here, so the next step never sits under a long list of rows.
      for (final (text, onTap) in more)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton(onPressed: _busy ? null : onTap, child: Text(text)),
        ),
      if (v.revisions.length > 1) ...[
        SectionHeader(l10n.tsRevisionsHeading),
        for (final r in v.revisions)
          RowCard(
            child: ListTile(
              title: Text(l10n.tsRevisionLabel(r.revision)),
              subtitle: Text([tsStatusLabel(l10n, TsStatus.values.byName(r.status)), ?r.reason].join(', ')),
              trailing: r.id == v.revision.id ? null : const Icon(Icons.chevron_right),
              onTap: r.id == v.revision.id ? null : () => _open(r.revision),
            ),
          ),
        const SizedBox(height: 8),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [ButtonSegment(value: false, label: Text(l10n.tsViewDaily)), ButtonSegment(value: true, label: Text(l10n.tsViewWorkers))],
          selected: {_workers},
          onSelectionChanged: (s) => setState(() => _workers = s.single),
        ),
      ),
    ];

    final body = <Widget Function()>[];
    String? lastDate;
    void dateHeader(String date) {
      if (date == lastDate) return;
      lastDate = date;
      body.add(() => SectionHeader('${dayName(l10n, date)}, ${showDate(date)}'));
    }

    if (_workers) {
      for (final row in v.rows) {
        dateHeader(row.line.workDate);
        final canAdjust = current && v.status == TsStatus.draft && !isPeriodBasis(row.line.basis);
        body.add(
          () => RowCard(
            child: ListTile(
              title: Text('${row.workerName} (${row.workerCode})'),
              subtitle: Text(
                [
                  [row.siteName, if (row.line.status == AttendanceStatus.absent) l10n.tsNotCharged else billableText(l10n, row.line.basis, unitsOf(row.line))].join(', '),
                  if (row.adjustReason != null) l10n.tsAgreedRow(row.adjustReason!),
                ].join('\n'),
              ),
              trailing: RowValue(row.line.amountFils == null ? '-' : formatAed(row.line.amountFils!)),
              onTap: canAdjust ? () => _adjust(v, row) : null,
            ),
          ),
        );
      }
    } else {
      for (final d in v.daily) {
        dateHeader(d.workDate);
        body.add(
          () => RowCard(
            child: ListTile(
              title: Text([v.siteNames[d.siteId] ?? '', ?d.trade].join(', ')),
              subtitle: Text('${l10n.tsPeople(d.persons)}, ${billableText(l10n, d.basis, d.units)}${isPeriodBasis(d.basis) ? '' : '\n${rateSummary(l10n, d.basis.name, d.rateFils)}'}'),
              trailing: RowValue(d.amountFils == null ? '-' : formatAed(d.amountFils!)),
            ),
          ),
        );
      }
    }

    final foot = <Widget>[
      SectionHeader(l10n.regTotal),
      for (final (name, value) in timesheetFacts(v.totals, l10n)) RowCard(child: InfoRow(name, value)),
      for (final m in v.monthly) NoteRow(icon: Icons.calendar_month, text: l10n.tsMonthlyLine(basisLabel(l10n, m.basis), formatAed(m.rateFils), showDate(m.fromDate), showDate(m.toDate), m.persons), color: ink),
      if (v.lines.any((l) => l.amountFils != null)) TotalRow(l10n.tsTotalAmount, formatAed(v.totals.amountFils)),
      const SizedBox(height: 20),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(number)),
      bottomNavigationBar: MainActionBar(label: label, onPressed: _busy ? null : press),
      body: ListView.builder(
        itemCount: head.length + body.length + foot.length,
        itemBuilder: (_, i) {
          if (i < head.length) return head[i];
          if (i < head.length + body.length) return body[i - head.length]();
          return foot[i - head.length - body.length];
        },
      ),
    );
  }
}

/// The photo a company sent back, and what it is not (TS-04).
class _Evidence extends ConsumerWidget {
  const _Evidence({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asset = ref.watch(documentAssetProvider(assetId)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asset != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(asset.bytes, height: 160, fit: BoxFit.contain)),
          ),
        NoteRow(icon: Icons.photo, text: l10n.tsEvidenceNote, color: muted),
      ],
    );
  }
}

/// How this paper goes out. Rates stay off until the owner turns them on, so a company only sees what they choose (TS-01).
class _PaperSheet extends StatefulWidget {
  const _PaperSheet({required this.workers});

  final bool workers;

  @override
  State<_PaperSheet> createState() => _PaperSheetState();
}

class _PaperSheetState extends State<_PaperSheet> {
  late bool _workers = widget.workers;
  bool _priced = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.tsPaper, style: sectionTitleStyle),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [ButtonSegment(value: false, label: Text(l10n.tsViewDaily)), ButtonSegment(value: true, label: Text(l10n.tsViewWorkers))],
              selected: {_workers},
              onSelectionChanged: (s) => setState(() => _workers = s.single),
            ),
            SwitchListTile(
              tileColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tsPaperPriced),
              subtitle: Text(l10n.tsPaperPricedHelp),
              value: _priced,
              onChanged: (on) => setState(() => _priced = on),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.of(context).pop((_workers, _priced)), child: Text(l10n.tsContinue)),
          ],
        ),
      ),
    );
  }
}

typedef _Response = ({String date, String? note, Uint8List? photo});

/// What the company said, when, and a photo if there is one.
class _ResponseSheet extends StatefulWidget {
  const _ResponseSheet({required this.accepted});

  final bool accepted;

  @override
  State<_ResponseSheet> createState() => _ResponseSheetState();
}

class _ResponseSheetState extends State<_ResponseSheet> {
  final _note = TextEditingController();
  String _date = dubaiToday(DateTime.now());
  Uint8List? _photo;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final bytes = await pickCheckedImage(context);
    if (bytes != null && mounted) setState(() => _photo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.accepted ? l10n.tsAccepted : l10n.tsDisputed, style: sectionTitleStyle),
            const SizedBox(height: 12),
            DateField(l10n.tsRespondDate, value: _date, required: true, onChanged: (v) => setState(() => _date = v!)),
            fieldGap,
            Field(l10n.tsRespondNote, _note, lines: 2),
            fieldGap,
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.photo_camera), label: Text(_photo == null ? l10n.tsEvidence : l10n.tsEvidenceAdded)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.tsEvidenceNote, style: const TextStyle(fontSize: 13, color: muted)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final note = _note.text.trim();
                Navigator.of(context).pop((date: _date, note: note.isEmpty ? null : note, photo: _photo));
              },
              child: Text(l10n.tsAdjustSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a company agreed for one row. It starts from the row's own rate and the owner can still type another figure.
/// Attendance and pay are not touched (TS-06).
class _AdjustSheet extends StatefulWidget {
  const _AdjustSheet({required this.row});

  final TimesheetRow row;

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _form = GlobalKey<FormState>();
  late AttendanceStatus _status = widget.row.line.status;
  late final _hours = TextEditingController(text: '${widget.row.line.billableMinutes ~/ 60}');
  late final _minutes = TextEditingController(text: '${widget.row.line.billableMinutes % 60}');
  late final _amount = TextEditingController(text: plainAmount(widget.row.line.amountFils ?? 0));
  late final _reason = TextEditingController(text: widget.row.adjustReason ?? '');

  TsLine get _line => widget.row.line;
  bool get _byHour => _line.basis == RateBasis.hour;
  int get _typedMinutes => (int.tryParse(_hours.text.trim()) ?? 0) * 60 + (int.tryParse(_minutes.text.trim()) ?? 0);

  void _refigure() {
    final amount = adjustedAmount(_line.basis, _line.rateFils, _status, _status == AttendanceStatus.absent ? 0 : _typedMinutes);
    setState(() => _amount.text = plainAmount(amount ?? 0));
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? whole(String? v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? l10n.wholeNumberRequired : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.tsAdjustTitle, style: sectionTitleStyle),
              Text('${widget.row.workerName}, ${showDate(_line.workDate)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(l10n.tsAdjustHelp, style: const TextStyle(fontSize: 13.5, height: 1.35, color: muted)),
              ),
              SegmentedButton<AttendanceStatus>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: AttendanceStatus.present, label: Text(l10n.statusPresent)),
                  ButtonSegment(value: AttendanceStatus.half, label: Text(l10n.statusHalf)),
                  ButtonSegment(value: AttendanceStatus.absent, label: Text(l10n.tsNotTaken)),
                ],
                selected: {_status},
                onSelectionChanged: (s) {
                  _status = s.single;
                  _refigure();
                },
              ),
              fieldGap,
              if (_byHour && _status != AttendanceStatus.absent) ...[
                Row(
                  children: [
                    Expanded(child: Field(l10n.tsAdjustHours, _hours, keyboardType: TextInputType.number, validator: whole, onChanged: (_) => _refigure())),
                    const SizedBox(width: 12),
                    Expanded(child: Field(l10n.tsAdjustMinutes, _minutes, keyboardType: TextInputType.number, validator: whole, onChanged: (_) => _refigure())),
                  ],
                ),
                fieldGap,
              ],
              Field(l10n.tsAdjustAmount, _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => parseAed(v ?? '') == null ? l10n.amountInvalid : null),
              fieldGap,
              Field(l10n.tsAdjustReason, _reason, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (!validateAndReveal(_form)) return;
                  Navigator.of(context).pop((
                    agreed: TsAdjustment(status: _status, minutes: _status == AttendanceStatus.absent ? 0 : (_byHour ? _typedMinutes : _line.billableMinutes), amountFils: parseAed(_amount.text), reason: _reason.text.trim()),
                  ));
                },
                child: Text(l10n.tsAdjustSave),
              ),
              if (widget.row.adjustReason != null) TextButton(onPressed: () => Navigator.of(context).pop((agreed: null)), child: Text(l10n.tsAdjustClear)),
            ],
          ),
        ),
      ),
    );
  }
}
