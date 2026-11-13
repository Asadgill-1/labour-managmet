import 'dart:async';

import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/account.dart';
import '../../data/licence.dart';
import '../../data/plans.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screens.dart';

const _files = MethodChannel('labour_app/files');

/// A day as the owner reads it, on Dubai's calendar.
String _day(DateTime at) => showDate(dubaiToday(at));

/// Plan lein (T21b, D-074): the plans and prices from the cloud, the bank account to pay into, then the transfer slip,
/// and how each slip sent stands. The session kept on the phone is enough; the password is asked only when the cloud no
/// longer takes it. Not in a Play Store build (BILL-07).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> with CloudStep {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  var _ask = false;
  ({List<Plan> plans, BankDetails bank, List<Slip> slips})? _shop;
  String? _plan;
  var _months = 1;
  ({Uint8List bytes, SlipKind kind})? _slip;

  /// One slip's id across retries, so a dropped upload reaches the same slip (MODEL-06). A new choice is a new slip.
  var _operationId = newUuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
  }

  Future<void> _loadFirst() async {
    try {
      setState(() => busy = true);
      await _load();
    } on AccountRefused catch (e) {
      if (!mounted) return;
      if (e.problem == AccountProblem.signedOut) {
        setState(() => _ask = true);
      } else {
        showFormError(context, accountProblemText(AppLocalizations.of(context), e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _load() async {
    final account = widget.account;
    final plans = await account.plans();
    final bank = await account.bankDetails();
    final slips = await account.slips();
    if (!mounted) return;
    setState(() {
      _shop = (plans: plans, bank: bank, slips: slips);
      // The chosen plan may have left the sale since the last load.
      if (!plans.any((p) => p.code == _plan)) _plan = plans.firstOrNull?.code;
      _ask = false;
    });
  }

  Future<void> _signIn() async {
    if (!validateAndReveal(_form)) return;
    await attempt(() async {
      await widget.account.signInAgain(_password.text);
      _password.clear();
      // The licence waited on the same session.
      unawaited(ref.read(licensingProvider)?.refresh());
      await _load();
    });
  }

  void _choose(void Function() change) => setState(() {
    change();
    _operationId = newUuid();
  });

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    Uint8List? bytes;
    try {
      bytes = await _files.invokeMethod<Uint8List>('pickSlip');
    } catch (_) {
      if (mounted) showFormError(context, l10n.planSlipPickFailed);
      return;
    }
    if (bytes == null || !mounted) return;
    final kind = slipKindOf(bytes);
    if (kind == null) return showFormError(context, l10n.planSlipWrongType);
    if (bytes.length > slipMaxBytes) return showFormError(context, l10n.planSlipTooBig);
    _choose(() => _slip = (bytes: bytes!, kind: kind));
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final slip = _slip;
    if (slip == null) return showFormError(context, l10n.planSendNeedsSlip);
    await attempt(() async {
      await widget.account.sendSlip(planCode: _plan!, months: _months, bytes: slip.bytes, kind: slip.kind, operationId: _operationId);
      if (!mounted) return;
      _choose(() => _slip = null);
      showSavedOnPhone(context, l10n.planSent);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shop = _shop;
    final ready = shop != null && shop.bank.ready;
    return StepScaffold(
      title: l10n.planTake,
      busy: busy,
      action: _ask
          ? MainActionBar(label: l10n.planShowPlans, onPressed: busy ? null : _signIn)
          : ready
          ? MainActionBar(label: l10n.planSend, onPressed: busy ? null : _send)
          : const SizedBox.shrink(),
      child: Form(
        key: _form,
        child: _ask
            ? FormBody(
                children: [
                  MarginNote(l10n.planPasswordBody),
                  fieldGap,
                  PasswordField(
                    l10n.accountPassword,
                    _password,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) => (v ?? '').isEmpty ? l10n.fieldRequired : null,
                  ),
                ],
              )
            : shop == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: MarginNote(l10n.planIntro)),
                  SectionHeader(l10n.planChoose),
                  for (final plan in shop.plans)
                    _PlanChoice(plan, selected: plan.code == _plan, onTap: () => _choose(() => _plan = plan.code)),
                  if (shop.plans.isNotEmpty && shop.bank.ready) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: DropdownButtonFormField<int>(
                        initialValue: _months,
                        decoration: InputDecoration(labelText: l10n.planMonths),
                        items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(l10n.planMonthsCount(m)))],
                        onChanged: (m) => _choose(() => _months = m!),
                      ),
                    ),
                    TotalRow(l10n.planTotal, formatAed(shop.plans.firstWhere((p) => p.code == _plan).priceFils * _months)),
                  ],
                  SectionHeader(l10n.planBankTitle),
                  if (!shop.bank.ready) NoteRow(icon: Icons.info_outline, text: l10n.planBankMissing, color: warn),
                  ?_bankLine(l10n.planBankName, shop.bank.bankName),
                  ?_bankLine(l10n.planAccountNumber, shop.bank.accountNumber, copy: true),
                  ?_bankLine(l10n.planIban, shop.bank.iban, copy: true),
                  ?_bankLine(l10n.planAccountHolder, shop.bank.holder),
                  if (ready) ...[
                    SectionHeader(l10n.planSlipTitle),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l10n.planSlipHint, style: const TextStyle(color: muted)),
                          if (_slip case final slip?) ...[
                            const SizedBox(height: 10),
                            NoteRow(
                              icon: Icons.check_circle_outline,
                              text: l10n.planSlipChosen(slip.kind == SlipKind.pdf ? 'PDF' : l10n.planSlipPhoto, (slip.bytes.length / 1024).ceil()),
                              color: settled,
                            ),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _pick,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_slip == null ? l10n.planSlipPick : l10n.planSlipChange),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (shop.slips.isNotEmpty) ...[
                    SectionHeader(l10n.planSlipsTitle),
                    for (final slip in shop.slips) _SlipRow(slip, planName: shop.plans.where((p) => p.code == slip.planCode).firstOrNull?.name ?? slip.planCode),
                  ],
                ],
              ),
      ),
    );
  }

  /// One line of the bank account, only when it is filled in. The account number and IBAN copy with one tap, so
  /// nobody types them into the bank's app by hand.
  Widget? _bankLine(String label, String? value, {bool copy = false}) {
    if (value == null) return null;
    final l10n = AppLocalizations.of(context);
    return RowCard(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 14, color: muted)),
        subtitle: SelectableText(value, style: amountStyle.copyWith(fontSize: copy ? 18 : 16, letterSpacing: copy ? 0.5 : 0)),
        trailing: copy
            ? IconButton(
                tooltip: l10n.planCopy,
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
                  if (mounted) showSavedOnPhone(context, l10n.planCopied(label));
                },
              )
            : null,
      ),
    );
  }
}

/// One plan as a choice: its price a month, and what it holds. What is not built yet says so (D-074).
class _PlanChoice extends StatelessWidget {
  const _PlanChoice(this.plan, {required this.selected, required this.onTap});

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines = [
      if (plan.workers case final n?) l10n.planWorkers(n) else l10n.planWorkersUnlimited,
      if (plan.clients case final n?) l10n.planClients(n) else l10n.planClientsUnlimited,
    ];
    return Semantics(
      selected: selected,
      button: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        decoration: BoxDecoration(
          color: selected ? brandSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? brand : rule, width: selected ? 2 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? brand : fieldEdge),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name, style: sectionTitleStyle),
                        const SizedBox(height: 4),
                        Text(lines.join(', '), style: const TextStyle(fontSize: 14.5, color: ink)),
                        const SizedBox(height: 2),
                        Text(l10n.planSoon(formatAed(plan.addonFils)), style: const TextStyle(fontSize: 13.5, color: muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RowValue(formatAed(plan.priceFils)),
                      Text(l10n.planPerMonth, style: const TextStyle(fontSize: 13, color: muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slip sent, and how it stands, in words as well as colour (UX-04).
class _SlipRow extends StatelessWidget {
  const _SlipRow(this.slip, {required this.planName});

  final Slip slip;
  final String planName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (tag, text, color) = switch (slip.state) {
      'accepted' => (const RowTag.icon(Icons.check, fill: settledSoft, color: settled), l10n.planSlipAccepted, settled),
      'refused' => (const RowTag.icon(Icons.close, fill: dueSoft, color: due), l10n.planSlipRefused(slip.refuseReason ?? ''), due),
      _ when !slip.fileArrived => (const RowTag.icon(Icons.error_outline, fill: dueSoft, color: due), l10n.planSlipNoFile, due),
      _ => (const RowTag.icon(Icons.schedule, fill: warnSoft, color: warn), l10n.planSlipWaiting(_day(slip.sentAt)), warn),
    };
    return RowCard(
      child: ListTile(
        leading: tag,
        title: Text(l10n.planSlipLine(planName, l10n.planMonthsCount(slip.months))),
        subtitle: Text(text, style: TextStyle(color: color)),
        trailing: RowValue(formatAed(slip.expectedFils)),
      ),
    );
  }
}

/// The plan in Settings: its name, its end, the last check online and when the next is due (BILL-05), and why the
/// last check failed, with the way to put it right.
class PlanStatusSection extends ConsumerStatefulWidget {
  const PlanStatusSection({super.key});

  @override
  ConsumerState<PlanStatusSection> createState() => _PlanStatusSectionState();
}

class _PlanStatusSectionState extends ConsumerState<PlanStatusSection> {
  var _checking = false;

  Future<void> _check(Licensing licensing, Account account) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _checking = true);
    try {
      await licensing.refresh();
      if (licensing.view.problem == AccountProblem.signedOut && mounted) {
        final password = await _askPassword(context);
        if (password == null) return;
        try {
          await account.signInAgain(password);
        } on AccountRefused catch (e) {
          if (mounted) showFormError(context, accountProblemText(l10n, e));
          return;
        }
        await licensing.refresh();
      }
      if (licensing.view.problem == null && mounted) showSavedOnPhone(context, l10n.planChecked);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final licensing = ref.watch(licensingProvider);
    final account = ref.watch(accountProvider)?.account;
    if (licensing == null || account == null) return const SizedBox.shrink();
    final view = ref.watch(licenceProvider).value;
    final licence = view?.licence;
    final now = DateTime.now();
    final ends = licence?.endsAt;
    final lines = [
      if (view == null) l10n.planChecking,
      if (ends != null) now.isBefore(ends) ? l10n.planEnds(_day(ends)) : l10n.planEndedOn(_day(ends)),
      if (licence != null) ...[l10n.planLastCheck(_day(licence.issuedAt)), l10n.planNextCheck(_day(licence.leaseUntil))],
    ];
    final warning = view == null ? null : _warning(l10n, view);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text(l10n.planTitle, style: sectionTitleStyle)),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(licence?.planName ?? l10n.planNone, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
          subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 56),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _checking ? null : () => _check(licensing, account),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.planCheckNow),
            ),
          ),
        ),
        if (warning != null)
          InkWell(
            onTap: view?.problem == AccountProblem.otherPhone
                ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PhonesScreen(account: account)))
                : null,
            child: NoteRow(icon: Icons.warning_amber, text: warning, color: due),
          ),
        if (!playStoreBuild) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: Text(l10n.planTake),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanScreen(account: account))),
          ),
        ],
      ],
    );
  }

  String? _warning(AppLocalizations l10n, LicenceView view) {
    if (view.problem case final problem?) {
      return problem == AccountProblem.offline ? l10n.planCheckOffline : accountProblemText(l10n, AccountRefused(problem));
    }
    return switch (view.status) {
      LicenceStatus.active => null,
      LicenceStatus.none => l10n.planNotChecked,
      LicenceStatus.ended => l10n.planEndedNote,
      LicenceStatus.leaseOver => l10n.planLeaseOver,
      LicenceStatus.clockBack => l10n.planClockBack,
    };
  }
}

Future<String?> _askPassword(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final password = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.planPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.planPasswordBody),
          fieldGap,
          PasswordField(l10n.accountPassword, password, autofillHints: const [AutofillHints.password], validator: (_) => null),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.of(dialog).pop(password.text.isEmpty ? null : password.text), child: Text(l10n.planCheckNow)),
      ],
    ),
  );
}

/// On the day's page from 5 days before the trial ends: the days left, and the way to a plan (D-074).
class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(licenceProvider).value;
    final account = ref.watch(accountProvider)?.account;
    final ends = view?.licence?.endsAt;
    if (playStoreBuild || account == null || view == null || view.licence?.state != 'trial' || ends == null) return const SizedBox.shrink();
    if (view.status != LicenceStatus.active) return const SizedBox.shrink();
    final days = daysBetween(dubaiToday(DateTime.now()), dubaiToday(ends));
    if (days > 5) return const SizedBox.shrink();
    return NoticeRow(
      icon: Icons.hourglass_bottom,
      title: l10n.trialDaysLeft(days),
      subtitle: l10n.trialNoteBody,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanScreen(account: account))),
    );
  }
}
