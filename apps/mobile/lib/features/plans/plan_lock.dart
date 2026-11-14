import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/licence.dart';
import '../../data/plan_guard.dart';
import '../../data/plans.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screens.dart';
import 'plan_screen.dart';

/// Why the plan would hold back a write from this screen now, or null (T21c). The write path's own rule, read here so
/// a button shows its lock before it is pressed; the write path stays the judge. [entity] and [effect] are as the
/// guard takes them.
PlanRefused? planBlock(WidgetRef ref, {String entity = '', WriteEffect effect = WriteEffect.entry}) {
  final licensing = ref.watch(licensingProvider);
  // A build without accounts has no plans. Until the licence kept here is read, nothing shows a lock.
  if (licensing == null || ref.watch(licenceProvider).value == null) return null;
  final workers = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.active).length;
  final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active).length;
  // The view as of now, since a trial can end while the page is open.
  return planRefusal(licensing.view, entity: entity, effect: effect, workers: workers, clients: clients);
}

/// The reason in words (UX-04). [problem] is why the last check online failed, which says more than "not checked".
/// [workers] and [clients] are the active counts, for a company over its plan.
String planBlockText(AppLocalizations l10n, PlanRefused refused, AccountProblem? problem, {int workers = 0, int clients = 0}) {
  String unchecked(String plain) => problem == null || problem == AccountProblem.offline ? plain : accountProblemText(l10n, AccountRefused(problem));
  return switch (refused.block) {
    PlanBlock.ended => l10n.planEndedNote,
    PlanBlock.clockBack => l10n.planClockBack,
    PlanBlock.noLicence => unchecked(l10n.planNotChecked),
    PlanBlock.leaseOver => unchecked(l10n.planLeaseOver),
    PlanBlock.workerLimit => l10n.planWorkerLimit(refused.limit!),
    PlanBlock.clientLimit => l10n.planClientLimit(refused.limit!),
    PlanBlock.workersOver => l10n.planWorkersOver(refused.limit!, workers),
    PlanBlock.clientsOver => l10n.planClientsOver(refused.limit!, clients),
  };
}

/// The one step that puts a refusal right: a plan, a check online, turning the other phone off, or choosing who stays
/// active. Null when this build has none to offer, as a Play Store build has no Plan lein (BILL-07).
({String label, Future<void> Function() run})? planStep(BuildContext context, PlanRefused refused) {
  final scope = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context);
  final licensing = scope.read(licensingProvider);
  final account = scope.read(accountProvider)?.account;
  if (licensing == null || account == null) return null;
  Future<void> open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  return switch (refused.block) {
    PlanBlock.ended || PlanBlock.workerLimit || PlanBlock.clientLimit => playStoreBuild ? null : (label: l10n.planTake, run: () => open(PlanScreen(account: account))),
    PlanBlock.workersOver => (label: l10n.planKeepOpen, run: () => open(const KeepActiveScreen(clients: false))),
    PlanBlock.clientsOver => (label: l10n.planKeepOpen, run: () => open(const KeepActiveScreen(clients: true))),
    PlanBlock.noLicence || PlanBlock.leaseOver || PlanBlock.clockBack =>
      licensing.view.problem == AccountProblem.otherPhone
          ? (
              label: l10n.phonesMenu,
              run: () async {
                await open(PhonesScreen(account: account));
                // With the old phone off, this one gets its licence.
                await licensing.refresh();
              },
            )
          : (label: l10n.planCheckNow, run: () => checkPlanNow(context, licensing, account)),
  };
}

/// Says why the plan holds a write back, with the step that puts it right (T21c).
Future<void> showPlanBlock(BuildContext context, PlanRefused refused) async {
  final scope = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context);
  final over = refused.block == PlanBlock.workersOver || refused.block == PlanBlock.clientsOver;
  final counts = over ? await activeCounts(scope.read(dbProvider)) : (workers: 0, clients: 0);
  if (!context.mounted) return;
  final step = planStep(context, refused);
  final limit = refused.block == PlanBlock.workerLimit || refused.block == PlanBlock.clientLimit;
  final go = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(limit ? l10n.planTitle : l10n.planLockedTitle),
      content: Text(planBlockText(l10n, refused, scope.read(licensingProvider)?.view.problem, workers: counts.workers, clients: counts.clients)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
        if (step != null) TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(step.label)),
      ],
    ),
  );
  if (go == true && context.mounted) await step!.run();
}

/// On the day's page while the plan holds new entries back: why, and the step that puts it right (T21c).
class PlanBanner extends ConsumerWidget {
  const PlanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = planBlock(ref);
    if (block == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final workers = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.active).length;
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active).length;
    return NoticeRow(
      icon: Icons.lock_outline,
      title: switch (block.block) {
        PlanBlock.workersOver => l10n.planKeepWorkers(block.limit!),
        PlanBlock.clientsOver => l10n.planKeepClients(block.limit!),
        _ => l10n.planLockedTitle,
      },
      subtitle: planBlockText(l10n, block, ref.watch(licensingProvider)?.view.problem, workers: workers, clients: clients),
      onTap: () => planStep(context, block)?.run(),
    );
  }
}

/// A company over its plan chooses which workers, or client companies, stay active. The rest are archived with their
/// history and balances as they are, and nothing is hidden or deleted (PLAN-04).
class KeepActiveScreen extends ConsumerStatefulWidget {
  const KeepActiveScreen({required this.clients, super.key});

  /// Client companies rather than workers.
  final bool clients;

  @override
  ConsumerState<KeepActiveScreen> createState() => _KeepActiveScreenState();
}

class _KeepActiveScreenState extends ConsumerState<KeepActiveScreen> {
  final _keep = <String>{};
  var _search = '';
  var _busy = false;

  void _toggle(String id, int most) {
    if (_keep.contains(id)) {
      setState(() => _keep.remove(id));
    } else if (_keep.length >= most) {
      showFormError(context, AppLocalizations.of(context).planKeepTooMany(most));
    } else {
      setState(() => _keep.add(id));
    }
  }

  Future<void> _archive(String question, int rest) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(question),
        content: Text(l10n.planKeepConfirm(rest)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.archive)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    final db = ref.read(dbProvider);
    final done = await saveOrExplain(
      context,
      () => widget.clients
          ? db.archiveAllBut(db.clients, const ClientsCompanion(active: Value(false)), _keep, reason: l10n.planKeepReason)
          : db.archiveAllBut(db.workers, const WorkersCompanion(active: Value(false)), _keep, reason: l10n.planKeepReason),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return;
    showSavedOnPhone(context, l10n.planKeepDone(rest));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(licenceProvider);
    final licence = ref.watch(licensingProvider)?.view.licence;
    final rows = widget.clients
        ? [
            for (final c in ref.watch(clientsProvider).value ?? const <Client>[])
              if (c.active) (id: c.id, title: c.name, subtitle: c.contactPerson),
          ]
        : [
            for (final w in ref.watch(workersProvider).value ?? const <Worker>[])
              if (w.active) (id: w.id, title: w.name, subtitle: [w.code, ?w.trade].join(', ')),
          ];
    // An unlimited plan, should one arrive while this page is open, leaves nothing to choose.
    final most = (widget.clients ? licence?.clients : licence?.workers) ?? rows.length;
    _keep.retainAll({for (final r in rows) r.id});
    final rest = rows.length - _keep.length;
    final question = widget.clients ? l10n.planKeepClients(most) : l10n.planKeepWorkers(most);
    final needle = _search.toLowerCase();
    final shown = [
      for (final r in rows)
        if ('${r.title} ${r.subtitle ?? ''}'.toLowerCase().contains(needle)) r,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(question)),
      bottomNavigationBar: MainActionBar(
        free: true,
        label: l10n.planKeepGo(rest),
        onPressed: _busy || _keep.isEmpty || _keep.length > most || rest == 0 ? null : () => _archive(question, rest),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TopBand(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchBox(onChanged: (v) => setState(() => _search = v)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    l10n.planKeepChosen(_keep.length, most),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: shown.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: MarginNote(l10n.planKeepBody));
                final row = shown[i - 1];
                return RowCard(
                  child: CheckboxListTile(
                    value: _keep.contains(row.id),
                    onChanged: _busy ? null : (_) => _toggle(row.id, most),
                    title: Text(row.title),
                    subtitle: (row.subtitle ?? '').isEmpty ? null : Text(row.subtitle!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
