import 'dart:async';
import 'dart:io';

import 'package:domain/dates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/backup.dart';
import '../../data/restore.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screens.dart';
import 'backup_screen.dart';

const _files = MethodChannel('labour_app/files');

/// The data that would come in, opened and brought up to date beside the company's file.
/// [keep] says the data here now is worth setting aside.
typedef _Ready = ({TenantDatabase db, File file, Restored restored, Map<String, int> own, String invoicePrefix, DateTime? at, bool keep});

/// Brings a backup back in place of the company's data on this phone (DATA-05, DATA-06), or, with [kept], the data the
/// last restore set aside (D-070). The file is checked, opened and brought up to date, and the owner sees what it
/// holds, before anything on the phone changes.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({this.kept = false, super.key});

  final bool kept;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _typed = {for (final s in numberSeries) s: TextEditingController()};
  final _operationId = newUuid();
  final _year = int.parse(dubaiToday(DateTime.now()).substring(0, 4));
  Uint8List? _bytes;
  String? _passwordUsed;
  var _askPassword = false;
  String? _problem;
  var _busy = false;
  _Ready? _ready;
  bool? _givenAfter;
  var _mustAnswer = false;
  var _handedOver = false;

  Restorer get _restorer => ref.read(restoreProvider)!;
  TenantDatabase get _live => ref.read(dbProvider);

  @override
  void initState() {
    super.initState();
    if (widget.kept) {
      final kept = keptFile(_restorer.dir, _live.tenantId);
      _run(() => _prepare((into, _) => kept.copy(into.path), at: kept.lastModifiedSync()));
    }
  }

  @override
  void dispose() {
    final ready = _ready;
    if (ready != null && !_handedOver) unawaited(_discard(ready.db, ready.file));
    _password.dispose();
    for (final c in _typed.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _discard(TenantDatabase db, File file) async {
    await db.close();
    if (file.existsSync()) await file.delete();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await work();
    } catch (_) {
      if (mounted) setState(() => _problem = AppLocalizations.of(context).restoreCouldNotOpen);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _say(AppLocalizations l10n, BackupProblem problem) => switch (problem) {
    BackupProblem.notBackup => l10n.restoreNotBackup,
    BackupProblem.damaged => l10n.restoreDamaged,
    BackupProblem.otherCompany => l10n.restoreOtherCompany,
    BackupProblem.newerApp => l10n.restoreNewerApp,
    BackupProblem.wrongPassword => l10n.restoreWrongPassword,
  };

  Future<void> _pick() async {
    final bytes = await _files.invokeMethod<Uint8List>('pickBackup');
    if (bytes == null || !mounted) return;
    _password.clear();
    // A file that is not this company's backup is turned away before any password is asked.
    try {
      readBackupLabel(bytes, tenantId: _live.tenantId, schemaVersion: _live.schemaVersion);
    } on BackupRefused catch (e) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _bytes = null;
        _askPassword = false;
        _problem = _say(l10n, e.problem);
      });
      return;
    }
    _bytes = bytes;
    _askPassword = false;
    // The password this phone keeps is tried first; a backup from before a change, or another phone's, asks.
    final kept = await ref.read(backupStoreProvider).password();
    await _run(() => _open(kept, typed: false));
  }

  Future<void> _typedPassword() async {
    if (!validateAndReveal(_form)) return;
    await _run(() => _open(_password.text, typed: true));
  }

  Future<void> _open(String? password, {required bool typed}) async {
    final l10n = AppLocalizations.of(context);
    if (password == null) {
      setState(() => _askPassword = true);
      return;
    }
    final BackupSummary summary;
    try {
      summary = await checkBackup(_bytes!, password, tenantId: _live.tenantId, schemaVersion: _live.schemaVersion, work: await getTemporaryDirectory());
    } on BackupRefused catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.problem == BackupProblem.wrongPassword) {
          _askPassword = true;
          if (typed) _problem = l10n.restoreWrongPassword;
          return;
        }
        _bytes = null;
        _askPassword = false;
        _problem = _say(l10n, e.problem);
      });
      return;
    }
    _passwordUsed = password;
    await _prepare((into, key) => unlockBackup(_bytes!, password, into, key), at: summary.manifest.createdAtUtc);
  }

  Future<void> _prepare(Future<void> Function(File into, String key) make, {required DateTime? at}) async {
    final key = await _restorer.key();
    final file = restoringFile(_restorer.dir, _live.tenantId);
    await make(file, key);
    final db = openTenantDatabase(file, key, tenantId: _live.tenantId, deviceId: _live.deviceId, actorId: _live.actorId);
    try {
      // The first read brings an older backup up to this app's tables, before anything on the phone changes.
      final own = await db.lastNumbers(_year);
      final restored = await db.restoredSummary();
      final prefix = (await db.select(db.tenantProfiles).getSingleOrNull())?.invoicePrefix ?? 'INV';
      final here = await _live.restoredSummary();
      final keep = here.companyName != null || here.workers > 0 || here.invoices > 0;
      if (!mounted) {
        await _discard(db, file);
        return;
      }
      setState(() => _ready = (db: db, file: file, restored: restored, own: own, invoicePrefix: prefix, at: at, keep: keep));
    } catch (_) {
      await _discard(db, file);
      rethrow;
    }
  }

  Future<void> _restore() async {
    final ready = _ready!;
    final l10n = AppLocalizations.of(context);
    if (!widget.kept && _givenAfter == null) {
      setState(() => _mustAnswer = true);
      return;
    }
    if (!validateAndReveal(_form)) return;
    final owner = <String, int>{
      if (_givenAfter == true)
        for (final s in numberSeries)
          if (_typed[s]!.text.trim().isNotEmpty) s: int.parse(_typed[s]!.text.trim()),
    };
    final restorer = _restorer;
    final store = ref.read(backupStoreProvider);
    final live = _live;
    setState(() => _busy = true);
    try {
      // A new phone keeps the password that opened the backup, so its next backup needs no typing (D-069).
      if (_passwordUsed != null && await store.password() == null) await store.setPassword(_passwordUsed!);
      await ready.db.recordRestore(
        from: widget.kept ? 'kept' : ready.at!.toIso8601String(),
        year: _year,
        phone: await live.lastNumbers(_year),
        owner: owner,
        operationId: _operationId,
      );
      await ready.db.close();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showFormError(context, l10n.restoreCouldNotOpen);
      }
      return;
    }
    _handedOver = true;
    // The root closes this screen with the company, puts the file in its place and opens it again.
    await restorer.swap(ready.restored, keep: ready.keep);
  }

  String _seriesLabel(AppLocalizations l10n, String series) => switch (series) {
    'invoice' => l10n.seriesInvoice,
    'credit' => l10n.seriesCredit,
    'timesheet' => l10n.seriesTimesheet,
    'clientReceipt' => l10n.seriesClientReceipt,
    'payslip' => l10n.seriesPayslip,
    'paymentReceipt' => l10n.seriesPaymentReceipt,
    _ => l10n.seriesAdvanceReceipt,
  };

  Widget _numberField(AppLocalizations l10n, _Ready ready, String series) {
    final prefix = seriesPrefix(series, _year, invoicePrefix: ready.invoicePrefix);
    final own = ready.own[series];
    final last = own == null ? null : '$prefix${own.toString().padLeft(4, '0')}';
    return TextFormField(
      controller: _typed[series],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: _seriesLabel(l10n, series),
        prefixText: prefix,
        helperText: last == null ? l10n.restoreNoneInBackup : l10n.restoreInBackup(last),
        errorMaxLines: 2,
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return null;
        final n = int.tryParse(text);
        if (n == null || n < 1 || n > 99999) return l10n.restoreNumberBad;
        if (n < (own ?? 0)) return l10n.restoreNumberLow(last!);
        return null;
      },
    );
  }

  List<Widget> _preview(AppLocalizations l10n, _Ready ready) => [
    InfoRow(l10n.restoreCompany, ready.restored.companyName ?? '-'),
    InfoRow(widget.kept ? l10n.restoreKeptOn : l10n.restoreMadeOn, ready.at == null ? '-' : shownWhen(ready.at!)),
    InfoRow(l10n.restoreWorkers, '${ready.restored.workers}'),
    InfoRow(l10n.restoreInvoices, '${ready.restored.invoices}'),
    const Divider(height: 1),
    Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.kept)
            MarginNote(l10n.restoreKeptIntro)
          else if (ready.keep) ...[
            MarginNote(l10n.restoreKeeps),
            const SizedBox(height: 24),
          ],
          if (!widget.kept) ...[
            Text(l10n.restoreNumbersQuestion, style: sectionTitleStyle),
            const SizedBox(height: 6),
            Text(l10n.restoreNumbersWhy, style: const TextStyle(color: muted)),
            fieldGap,
            SegmentedButton<bool>(
              segments: [ButtonSegment(value: false, label: Text(l10n.restoreNo)), ButtonSegment(value: true, label: Text(l10n.restoreYes))],
              selected: {?_givenAfter},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _givenAfter = s.firstOrNull;
                _mustAnswer = false;
              }),
            ),
            if (_mustAnswer) ...[
              const SizedBox(height: 8),
              Text(l10n.restoreAnswer, style: const TextStyle(color: due, fontWeight: FontWeight.w600)),
            ],
            if (_givenAfter == true) ...[
              fieldGap,
              Text(l10n.restoreNumbersHelp),
              for (final s in numberSeries) ...[fieldGap, _numberField(l10n, ready, s)],
            ],
          ],
        ],
      ),
    ),
  ];

  List<Widget> _start(AppLocalizations l10n) => [
    Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.kept ? l10n.restoreKeptIntro : l10n.restoreIntro),
          if (_problem != null) ...[
            fieldGap,
            Text(_problem!, style: const TextStyle(color: due, fontWeight: FontWeight.w600)),
          ],
          if (_askPassword) ...[
            fieldGap,
            PasswordField(
              l10n.backupPassword,
              _password,
              autofillHints: const [AutofillHints.password],
              helper: l10n.restorePasswordHelp,
              validator: (v) => (v ?? '').isEmpty ? l10n.fieldRequired : null,
            ),
          ],
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _ready;
    final Widget? action;
    if (ready != null) {
      action = MainActionBar(label: widget.kept ? l10n.restoreBringKept : l10n.restoreBring, onPressed: _busy ? null : _restore);
    } else if (widget.kept) {
      action = null;
    } else {
      action = _askPassword
          ? MainActionBar(label: l10n.restoreOpen, onPressed: _busy ? null : _typedPassword)
          : MainActionBar(label: l10n.restorePick, onPressed: _busy ? null : _pick);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kept ? l10n.restoreKeptTitle : l10n.backupRestore),
        bottom: _busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
      ),
      bottomNavigationBar: action,
      // Not a ListView: a lazy list drops fields it hasn't built, and those never validate.
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: ready == null ? _start(l10n) : _preview(l10n, ready)),
        ),
      ),
    );
  }
}

enum SwapStage { working, done, failed }

/// Shown while the root swaps the company's file, then says how it went (DATA-05). [kept] says the data replaced was
/// set aside.
class SwapScreen extends StatelessWidget {
  const SwapScreen({required this.stage, required this.restored, required this.kept, required this.onDone, super.key});

  final SwapStage stage;
  final Restored restored;
  final bool kept;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final done = stage == SwapStage.done;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupRestore), automaticallyImplyLeading: false),
      bottomNavigationBar: stage == SwapStage.working ? null : MainActionBar(label: l10n.accountContinue, onPressed: onDone),
      body: stage == SwapStage.working
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(l10n.restoreWorking, textAlign: TextAlign.center)],
                ),
              ),
            )
          : FormBody(
              children: [
                Text(done ? l10n.restoreDone : l10n.restoreFailed, style: sectionTitleStyle.copyWith(fontSize: 20, color: done ? settled : due)),
                fieldGap,
                if (done) ...[
                  Text(l10n.restoreDoneBody(restored.companyName ?? '-', restored.workers, restored.invoices)),
                  if (kept) ...[fieldGap, MarginNote(l10n.restoreDoneKept)],
                  fieldGap,
                  MarginNote(l10n.restoreDoneBackup),
                ] else
                  Text(l10n.restoreFailedBody),
              ],
            ),
    );
  }
}
