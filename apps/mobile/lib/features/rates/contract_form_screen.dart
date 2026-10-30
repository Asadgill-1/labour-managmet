import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'rate_labels.dart';

/// One form for both sides of a rate (MASTER-06). Set [workerId] for what a worker is paid,
/// or [clientId] for what a client is charged. The two are always separate rows.
class ContractFormScreen extends ConsumerStatefulWidget {
  const ContractFormScreen.pay({
    required String this.workerId,
    this.pay,
    super.key,
  }) : clientId = null,
       billing = null;

  const ContractFormScreen.billing({
    required String this.clientId,
    this.billing,
    super.key,
  }) : workerId = null,
       pay = null;

  final String? workerId;
  final String? clientId;
  final PayContract? pay;
  final BillingContract? billing;

  @override
  ConsumerState<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends ConsumerState<ContractFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();

  bool get _isPay => widget.workerId != null;

  late RateBasis _basis = RateBasis.values.byName(
    widget.pay?.basis ?? widget.billing?.basis ?? 'hour',
  );
  late final _rate = TextEditingController(
    text: _plain(widget.pay?.rateFils ?? widget.billing?.rateFils),
  );
  late final _half = TextEditingController(
    text: _plain(widget.pay?.halfAmountFils ?? widget.billing?.halfAmountFils),
  );
  late final _overtime = TextEditingController(
    text: _plain(
      widget.pay?.overtimeRateFils ?? widget.billing?.overtimeRateFils,
    ),
  );
  late final _included = TextEditingController(
    text: (widget.pay?.includedMinutes ?? widget.billing?.includedMinutes)
        ?.toString(),
  );
  late final _divisor = TextEditingController(
    text: widget.pay?.partialDivisor?.toString(),
  );
  late String? _from =
      widget.pay?.effectiveFrom ??
      widget.billing?.effectiveFrom ??
      dubaiToday(DateTime.now());
  late String? _to = widget.pay?.effectiveTo ?? widget.billing?.effectiveTo;
  late bool _breakPaid =
      widget.pay?.breakPaid ?? widget.billing?.breakPaid ?? false;
  late String? _siteId = widget.pay?.siteId ?? widget.billing?.siteId;
  late String? _scopeWorkerId = widget.billing?.workerId;
  late PartialMethod? _partial = widget.pay?.partialMethod == null
      ? null
      : PartialMethod.values.byName(widget.pay!.partialMethod!);

  static String _plain(int? fils) => fils == null ? '' : plainAmount(fils);

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    if (_to != null && _to!.compareTo(_from!) < 0) {
      showFormError(context, l10n.endBeforeStart);
      return;
    }
    final db = ref.read(dbProvider);
    final rate = Value(parseAed(_rate.text)!);
    final half = Value(parseAed(_half.text));
    final overtime = Value(parseAed(_overtime.text));
    final included = Value(int.tryParse(_included.text.trim()));
    final bool overlaps;
    if (_isPay) {
      overlaps = await db.payContractOverlaps(
        workerId: widget.workerId!,
        siteId: _siteId,
        from: _from!,
        to: _to,
        exceptId: widget.pay?.id,
      );
    } else {
      overlaps = await db.billingContractOverlaps(
        clientId: widget.clientId!,
        siteId: _siteId,
        workerId: _scopeWorkerId,
        from: _from!,
        to: _to,
        exceptId: widget.billing?.id,
      );
    }
    if (overlaps) {
      if (mounted) showFormError(context, l10n.contractOverlap);
      return;
    }
    if (!mounted) return;
    final saved = await saveOrExplain(context, () async {
      if (_isPay) {
        final monthly = _basis == RateBasis.month;
        await db.saveRow(
          db.payContracts,
          id: widget.pay?.id,
          operationId: _operationId,
          fields: PayContractsCompanion(
            workerId: Value(widget.workerId!),
            siteId: Value(_siteId),
            basis: Value(_basis.name),
            rateFils: rate,
            effectiveFrom: Value(_from!),
            effectiveTo: Value(_to),
            breakPaid: Value(_breakPaid),
            halfAmountFils: half,
            includedMinutes: included,
            overtimeRateFils: overtime,
            partialMethod: Value(monthly ? _partial?.name : null),
            partialDivisor: Value(
              monthly && _partial == PartialMethod.fixedDivisor
                  ? int.parse(_divisor.text.trim())
                  : null,
            ),
          ),
        );
      } else {
        await db.saveRow(
          db.billingContracts,
          id: widget.billing?.id,
          operationId: _operationId,
          fields: BillingContractsCompanion(
            clientId: Value(widget.clientId!),
            siteId: Value(_siteId),
            workerId: Value(_scopeWorkerId),
            basis: Value(_basis.name),
            rateFils: rate,
            effectiveFrom: Value(_from!),
            effectiveTo: Value(_to),
            breakPaid: Value(_breakPaid),
            halfAmountFils: half,
            includedMinutes: included,
            overtimeRateFils: overtime,
          ),
        );
      }
    });
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  String? _optionalAmount(String? v, AppLocalizations l10n) {
    return (v ?? '').trim().isNotEmpty && parseAed(v!) == null
        ? l10n.amountInvalid
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bases = _isPay
        ? const [
            RateBasis.hour,
            RateBasis.day,
            RateBasis.shift,
            RateBasis.month,
          ]
        : const [
            RateBasis.hour,
            RateBasis.day,
            RateBasis.shift,
            RateBasis.monthPerWorker,
            RateBasis.monthFixed,
          ];
    final sites = _isPay
        ? ref.watch(allSitesProvider).value ?? const <Site>[]
        : ref.watch(sitesOfClientProvider(widget.clientId!)).value ??
              const <Site>[];
    final workers = _isPay
        ? const <Worker>[]
        : ref.watch(workersProvider).value ?? const <Worker>[];
    final editing = widget.pay != null || widget.billing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((_isPay, editing)) {
          (true, false) => l10n.addPayContract,
          (true, true) => l10n.editPayContract,
          (false, false) => l10n.addBillingContract,
          (false, true) => l10n.editBillingContract,
        }),
      ),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            DropdownButtonFormField<RateBasis>(
              isExpanded: true,
              initialValue: _basis,
              decoration: InputDecoration(labelText: l10n.rateBasis),
              items: [
                for (final b in bases)
                  DropdownMenuItem(value: b, child: Text(basisLabel(l10n, b))),
              ],
              onChanged: (b) => setState(() => _basis = b!),
            ),
            fieldGap,
            Field(
              l10n.rateAmount,
              _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  parseAed(v ?? '') == null ? l10n.amountInvalid : null,
            ),
            fieldGap,
            DateField(
              l10n.effectiveFrom,
              value: _from,
              onChanged: (v) => setState(() => _from = v),
              required: true,
            ),
            fieldGap,
            DateField(
              l10n.effectiveTo,
              value: _to,
              onChanged: (v) => setState(() => _to = v),
            ),
            fieldGap,
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _siteId,
              decoration: InputDecoration(labelText: l10n.appliesToSite),
              items: [
                DropdownMenuItem(child: Text(l10n.allSites)),
                for (final s in sites)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _siteId = v),
            ),
            if (!_isPay) ...[
              fieldGap,
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _scopeWorkerId,
                decoration: InputDecoration(labelText: l10n.appliesToWorker),
                items: [
                  DropdownMenuItem(child: Text(l10n.allWorkers)),
                  for (final w in workers)
                    DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} (${w.code})'),
                    ),
                ],
                onChanged: (v) => setState(() => _scopeWorkerId = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.breakIsPaid),
              value: _breakPaid,
              onChanged: (v) => setState(() => _breakPaid = v),
            ),
            if (_basis == RateBasis.day || _basis == RateBasis.shift) ...[
              Field(
                l10n.halfAmount,
                _half,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                helper: l10n.halfAmountHelp,
                validator: (v) => _optionalAmount(v, l10n),
              ),
              fieldGap,
            ],
            if (_basis == RateBasis.month) ...[
              DropdownButtonFormField<PartialMethod>(
                isExpanded: true,
                initialValue: _partial,
                decoration: InputDecoration(
                  labelText: l10n.partialMethod,
                  helperText: l10n.partialMethodHelp,
                  helperMaxLines: 2,
                ),
                validator: (v) => v == null ? l10n.fieldRequired : null,
                items: [
                  DropdownMenuItem(
                    value: PartialMethod.calendarDays,
                    child: Text(l10n.partialCalendarDays),
                  ),
                  DropdownMenuItem(
                    value: PartialMethod.fixedDivisor,
                    child: Text(l10n.partialFixedDivisor),
                  ),
                ],
                onChanged: (v) => setState(() => _partial = v),
              ),
              fieldGap,
              if (_partial == PartialMethod.fixedDivisor) ...[
                Field(
                  l10n.partialDivisor,
                  _divisor,
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) <= 0
                      ? l10n.wholeNumberRequired
                      : null,
                ),
                fieldGap,
              ],
            ],
            Field(
              l10n.includedMinutes,
              _included,
              keyboardType: TextInputType.number,
              helper: l10n.includedMinutesHelp,
              validator: (v) =>
                  (v ?? '').trim().isNotEmpty &&
                      (int.tryParse(v!.trim()) ?? -1) < 0
                  ? l10n.wholeNumberRequired
                  : null,
            ),
            fieldGap,
            Field(
              l10n.overtimeRate,
              _overtime,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              helper: l10n.overtimeRateHelp,
              validator: (v) => _optionalAmount(v, l10n),
            ),
          ],
        ),
      ),
    );
  }
}
