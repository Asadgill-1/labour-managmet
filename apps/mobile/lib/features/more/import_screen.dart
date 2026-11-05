import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/import.dart';
import '../../l10n/app_localizations.dart';
import '../rates/rate_labels.dart';
import '../registers/register_export.dart';

const _files = MethodChannel('labour_app/files');

String importTitle(AppLocalizations l10n, ImportKind kind) => switch (kind) {
  ImportKind.workers => l10n.importWorkersTitle,
  ImportKind.companies => l10n.importCompaniesTitle,
  ImportKind.sites => l10n.importSitesTitle,
};

String? _hint(AppLocalizations l10n, ImportKind kind, ImportField field) => switch (field) {
  ImportField.joiningDate || ImportField.rateFrom => l10n.importHintDate,
  ImportField.payBasis => l10n.importHintBasis,
  ImportField.payRate => l10n.importHintAmount,
  ImportField.vatRegistered => l10n.importHintYesNo,
  ImportField.trn => l10n.importHintTrn,
  ImportField.dueDays || ImportField.breakMinutes => l10n.importHintNumber,
  ImportField.start || ImportField.end => l10n.importHintTime,
  ImportField.company => l10n.importHintCompany,
  _ => null,
};

String importProblemText(AppLocalizations l10n, ImportIssue issue) {
  final column = issue.field.heading;
  return switch (issue.problem) {
    ImportProblem.missing => l10n.problemMissing(column),
    ImportProblem.repeated => l10n.problemRepeated(column),
    ImportProblem.exists => l10n.problemExists(column),
    ImportProblem.badDate => l10n.problemBadDate(column),
    ImportProblem.badAmount => l10n.problemBadAmount(column),
    ImportProblem.badNumber => l10n.problemBadNumber(column),
    ImportProblem.badTime => l10n.problemBadTime(column),
    ImportProblem.badYesNo => l10n.problemBadYesNo(column),
    ImportProblem.badTrn => l10n.problemBadTrn(column),
    ImportProblem.badBasis => l10n.problemBadBasis(column),
    ImportProblem.monthlyBasis => l10n.problemMonthly,
    ImportProblem.rateAndBasis => l10n.problemRateAndBasis,
    ImportProblem.rateNeedsDate => l10n.problemRateDate,
    ImportProblem.noCompany => l10n.problemNoCompany,
    ImportProblem.twoCompanies => l10n.problemTwoCompanies,
    ImportProblem.sameName => l10n.problemSameName,
    ImportProblem.trnWithoutVat => l10n.problemTrnWithoutVat,
  };
}

/// Brings workers, companies or sites in from a CSV file: the owner sees every line and what is wrong with it before
/// anything is saved, and then it is all saved or none of it (MASTER-08).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen(this.kind, {super.key});

  final ImportKind kind;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportPlan? _plan;
  bool _busy = false;

  Future<void> _blankFile() async {
    final l10n = AppLocalizations.of(context);
    final file = await writeExportFile('${widget.kind.name}.csv', utf8.encode(importTemplate(widget.kind)));
    final saved = await _files.invokeMethod<bool>('save', {'path': file.path, 'mime': 'text/csv'});
    if (saved == true && mounted) showSavedOnPhone(context, l10n.exportSaved);
  }

  Future<void> _choose() async {
    final bytes = await _files.invokeMethod<Uint8List>('pickCsv');
    if (bytes == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final plan = await ref.read(dbProvider).planImport(widget.kind, utf8.decode(bytes, allowMalformed: true));
      if (mounted) setState(() => _plan = plan);
    } catch (_) {
      if (mounted) showFormError(context, AppLocalizations.of(context).databaseError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(ImportPlan plan) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final saved = await saveOrExplain(context, () => ref.read(dbProvider).applyImport(plan));
    if (!mounted) return;
    setState(() => _busy = false);
    if (!saved) return;
    showSavedOnPhone(context, l10n.importSaved(plan.lines.length));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = _plan;
    final lines = [...?plan?.lines.where((l) => l.issues.isNotEmpty), ...?plan?.lines.where((l) => l.issues.isEmpty)];
    final bad = plan?.lines.where((l) => !l.ok).length ?? 0;
    final warned = plan?.lines.where((l) => l.ok && l.issues.isNotEmpty).length ?? 0;
    final head = <Widget>[
      if (_busy) const LinearProgressIndicator(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(l10n.importSteps, style: const TextStyle(fontSize: 14.5, height: 1.45, color: ink)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(onPressed: _blankFile, icon: const Icon(Icons.download), label: Text(l10n.importBlankFile)),
        ),
      ),
      NoteRow(icon: Icons.info_outline, text: l10n.importBackupNote, color: warn),
      if (plan == null) ...[
        SectionHeader(l10n.importColumns),
        for (final (field, required) in importFields[widget.kind]!)
          RowCard(
            child: ListTile(
              title: Text(field.heading),
              subtitle: _hint(l10n, widget.kind, field) == null ? null : Text(_hint(l10n, widget.kind, field)!),
              trailing: required ? Text(l10n.importRequired, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: due)) : null,
            ),
          ),
      ] else ...[
        SectionHeader(
          l10n.importSummary(plan.lines.length, bad, warned),
          action: TextButton(onPressed: _busy ? null : _choose, child: Text(l10n.importChooseAgain)),
        ),
        if (plan.missingColumns.isNotEmpty)
          NoteRow(icon: Icons.error_outline, text: l10n.importMissingColumns(plan.missingColumns.map((f) => f.heading).join(', ')), color: due)
        else if (plan.lines.isEmpty)
          NoteRow(icon: Icons.error_outline, text: l10n.importEmpty, color: due)
        else
          NoteRow(
            icon: plan.ready ? Icons.check_circle_outline : Icons.error_outline,
            text: plan.ready ? l10n.importReady : l10n.importFix,
            color: plan.ready ? settled : due,
          ),
        if (plan.ignoredColumns.isNotEmpty) NoteRow(icon: Icons.info_outline, text: l10n.importIgnored(plan.ignoredColumns.join(', ')), color: muted),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(importTitle(l10n, widget.kind))),
      bottomNavigationBar: MainActionBar(
        label: plan?.ready ?? false ? l10n.importSave(plan!.lines.length) : (plan == null ? l10n.importChoose : l10n.importChooseAgain),
        onPressed: _busy ? null : (plan?.ready ?? false ? () => _save(plan!) : _choose),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: head.length + lines.length,
        itemBuilder: (context, i) => i < head.length ? head[i] : _LineCard(lines[i - head.length]),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard(this.line);

  final ImportLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = line.ok ? (line.issues.isEmpty ? settled : warn) : due;
    return RowCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(line.title, style: sectionTitleStyle.copyWith(fontWeight: FontWeight.w500))),
                Text(l10n.importRow(line.row), style: const TextStyle(fontSize: 13, color: muted)),
              ],
            ),
            if (line.read.isNotEmpty || line.rate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [...line.read, if (line.rate case final rate?) rateSummary(l10n, rate.basis.name, rate.fils)].join(', '),
                  style: const TextStyle(fontSize: 13.5, color: muted),
                ),
              ),
            for (final issue in line.issues)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(importProblemText(l10n, issue), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: issue.problem.warning ? warn : color)),
              ),
          ],
        ),
      ),
    );
  }
}
