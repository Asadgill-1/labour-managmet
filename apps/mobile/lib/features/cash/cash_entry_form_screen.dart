import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/statement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/cash.dart';
import '../../data/changes.dart';
import '../../data/receipts.dart';
import '../../data/statement.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import 'cash_row.dart';

const _outKinds = [CashKind.advanceGiven, CashKind.salaryPaid, CashKind.visaPaid, CashKind.roomRentPaid, CashKind.expense];
const _inKinds = [CashKind.roomRentReceived, CashKind.advanceReturned, CashKind.visaReturned, CashKind.clientReceipt];

/// One money entry. The owner says what the money was for and the line goes where it belongs (D-030).
class CashEntryFormScreen extends ConsumerStatefulWidget {
  const CashEntryFormScreen({this.date, this.kind, this.workerId, this.roomId, this.clientId, this.invoiceId, this.amountFils, this.editing, super.key});

  /// A line being edited: the form starts from it, and saving puts a new line in its place (D-056).
  final CashEntry? editing;

  final String? date;
  final CashKind? kind;
  final String? workerId;
  final String? roomId;
  final String? clientId;

  /// A company's receipt opened from this invoice goes on it first.
  final String? invoiceId;
  final int? amountFils;

  @override
  ConsumerState<CashEntryFormScreen> createState() => _CashEntryFormScreenState();
}

class _CashEntryFormScreenState extends ConsumerState<CashEntryFormScreen> {
  final _form = GlobalKey<FormState>();

  /// Fixed for this screen, so a double tap or a retry can only save once (TEAM-04).
  final _operationId = newUuid();
  late String? _date = widget.editing?.entryDate ?? widget.date ?? dubaiToday(DateTime.now());
  late CashKind _kind = widget.editing == null ? widget.kind ?? CashKind.advanceGiven : CashKind.values.byName(widget.editing!.kind);
  late String? _workerId = widget.editing?.workerId ?? widget.workerId;
  late String? _roomId = widget.editing?.roomId ?? widget.roomId;
  late String? _clientId = widget.editing?.clientId ?? widget.clientId;
  late String? _siteId = widget.editing?.siteId;
  late String _category = widget.editing?.category ?? 'other';
  late String _method = widget.editing?.method ?? 'cash';
  late final _amount = TextEditingController(
    text: switch (widget.editing?.amountFils ?? widget.amountFils) {
      final int fils => plainAmount(fils),
      null => null,
    },
  );
  late final _note = TextEditingController(text: widget.editing?.note);
  late final _reference = TextEditingController(text: widget.editing?.reference);
  late final _receiver = TextEditingController(text: widget.editing?.receiver);

  /// On an advance: what payroll cuts of it each month by itself. Empty means the owner is asked each month (D-057).
  late final _instalment = TextEditingController(text: widget.editing?.instalmentFils == null ? null : plainAmount(widget.editing!.instalmentFils!));

  /// The user's own note on an edit, shown under the new line (D-056).
  final _changeNote = TextEditingController();

  /// What this worker's months still owe, and how much of this payment goes on each (PAY-06).
  Map<String, int> _unpaid = const {};
  final _parts = <String, TextEditingController>{};

  /// Once the owner types a month's share, the amount stops sharing itself out over it.
  bool _partsEdited = false;

  /// What the company still owes, oldest first, and how much of this receipt goes on each (INV-05). The invoice the
  /// screen was opened from comes first.
  List<OpenItem> _owed = const [];
  final _receiptParts = <String?, TextEditingController>{};
  int _companyCredit = 0;

  @override
  void initState() {
    super.initState();
    _loadUnpaid();
  }

  /// Months up to the payment's date, so a late correction to an older month shows here at once.
  Future<void> _loadUnpaid() async {
    if (_kind == CashKind.clientReceipt) return _loadOwed();
    final workerId = _workerId;
    final month = _date?.substring(0, 7);
    if (_kind != CashKind.salaryPaid || workerId == null || month == null) return;
    final db = ref.read(dbProvider);
    final statements = await db.statementsFor(month, workerId: workerId, withWork: false);
    // An edited payment's months are owed again once it is replaced, so it can settle them as before.
    final old = widget.editing;
    final back = old != null && old.kind == CashKind.salaryPaid.name && old.workerId == workerId
        ? await (db.select(db.salaryAllocations)..where((a) => a.paymentId.equals(old.id))).get()
        : const <SalaryAllocation>[];
    if (!mounted || workerId != _workerId || month != _date?.substring(0, 7)) return;
    final unpaid = {...statements.single.unpaid};
    for (final a in back) {
      unpaid[a.month] = (unpaid[a.month] ?? 0) + a.amountFils;
    }
    setState(() {
      _unpaid = {for (final m in unpaid.keys.toList()..sort()) m: unpaid[m]!};
      for (final m in _unpaid.keys) {
        _parts[m] ??= TextEditingController();
      }
      _partsEdited = false;
      _shareOut();
    });
  }

  Future<void> _loadOwed() async {
    final clientId = _clientId;
    if (clientId == null) return;
    final db = ref.read(dbProvider);
    final money = await db.receivables(clientId: clientId);
    // What an edited receipt settled is owed again once it is replaced, so it can settle it as before.
    final old = widget.editing;
    final mine = old != null && old.kind == CashKind.clientReceipt.name && old.clientId == clientId;
    final back = <String?, int>{};
    if (mine) {
      for (final a in await (db.select(db.invoiceAllocations)..where((a) => a.paymentId.equals(old.id))).get()) {
        back[a.invoiceId] = (back[a.invoiceId] ?? 0) + a.amountFils;
      }
    }
    final stillOpen = money.openOf(clientId);
    final settledBefore = <OpenItem>[
      for (final i in await (db.select(db.invoices)..where((i) => i.id.isIn(back.keys.nonNulls))).get())
        if (!stillOpen.any((o) => o.invoiceId == i.id)) (invoiceId: i.id, number: i.number, dueDate: i.dueDate, leftFils: 0),
    ];
    if (!mounted || clientId != _clientId) return;
    final open = <OpenItem>[
      for (final o in [...settledBefore, ...stillOpen])
        if (o.leftFils + (back[o.invoiceId] ?? 0) > 0)
          (invoiceId: o.invoiceId, number: o.number, dueDate: o.dueDate, leftFils: o.leftFils + (back[o.invoiceId] ?? 0)),
    ];
    // The credit an edited receipt left goes with it.
    final oldCredit = mine ? old.amountFils - back.values.fold<int>(0, (total, fils) => total + fils) : 0;
    setState(() {
      _owed = [
        ...open.where((o) => o.invoiceId != null && o.invoiceId == widget.invoiceId),
        ...open.where((o) => o.invoiceId == null || o.invoiceId != widget.invoiceId),
      ];
      for (final o in _owed) {
        _receiptParts[o.invoiceId] ??= TextEditingController();
      }
      _companyCredit = money.creditOf(clientId) - oldCredit;
      _partsEdited = false;
      _shareOut();
    });
  }

  void _shareOut() {
    if (_kind == CashKind.clientReceipt) {
      var left = parseAed(_amount.text) ?? 0;
      for (final o in _owed) {
        final fils = left < o.leftFils ? left : o.leftFils;
        _receiptParts[o.invoiceId]!.text = fils > 0 ? plainAmount(fils) : '';
        left -= fils;
      }
      return;
    }
    final split = splitOldestFirst(_unpaid, parseAed(_amount.text) ?? 0);
    for (final m in _unpaid.keys) {
      _parts[m]!.text = split.parts[m] == null ? '' : plainAmount(split.parts[m]!);
    }
  }

  void _amountChanged() {
    setState(() {
      if (!_partsEdited) _shareOut();
    });
  }

  Map<String, int> get _partsTyped => {
    for (final m in _unpaid.keys)
      if ((parseAed(_parts[m]!.text) ?? 0) > 0) m: parseAed(_parts[m]!.text)!,
  };

  int get _extraFils => (parseAed(_amount.text) ?? 0) - _partsTyped.values.fold(0, (total, fils) => total + fils);

  Map<String?, int> get _receiptTyped => {
    for (final o in _owed)
      if ((parseAed(_receiptParts[o.invoiceId]!.text) ?? 0) > 0) o.invoiceId: parseAed(_receiptParts[o.invoiceId]!.text)!,
  };

  int get _receiptLeftFils => (parseAed(_amount.text) ?? 0) - _receiptTyped.values.fold(0, (total, fils) => total + fils);

  /// Paying beyond what is owed is a clear yes from the owner, never a surprise on the worker's account (PAY-06).
  Future<bool> _confirmExtra(int extra) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.salaryExtraTitle(formatAed(extra))),
        content: Text(l10n.salaryExtraBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.salaryExtraConfirm)),
        ],
      ),
    );
    return yes == true;
  }

  bool get _needsWorker => const {
    CashKind.advanceGiven,
    CashKind.salaryPaid,
    CashKind.advanceReturned,
    CashKind.roomRentReceived,
    CashKind.visaPaid,
    CashKind.visaReturned,
  }.contains(_kind);
  bool get _needsRoom => const {CashKind.roomRentPaid, CashKind.roomRentReceived}.contains(_kind);

  /// Rent from a worker starts on their room and their agreed room charge.
  void _fillRentFromWorker() {
    if (_kind != CashKind.roomRentReceived || _workerId == null) return;
    final worker = (ref.read(workersProvider).value ?? const <Worker>[]).where((w) => w.id == _workerId).firstOrNull;
    if (worker == null) return;
    _roomId ??= worker.roomId;
    if (_amount.text.isEmpty && worker.roomChargeFils != null) _amount.text = plainAmount(worker.roomChargeFils!);
  }

  void _pickKind(CashKind kind) {
    setState(() {
      _kind = kind;
      _fillRentFromWorker();
    });
    _loadUnpaid();
  }

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final workerId = _needsWorker ? _workerId : null;
    final roomId = _needsRoom ? _roomId : null;
    final clientId = _kind == CashKind.clientReceipt ? _clientId : null;
    final isExpense = _kind == CashKind.expense;
    final isSalary = _kind == CashKind.salaryPaid;
    final isReceipt = _kind == CashKind.clientReceipt;
    if (isReceipt && _receiptLeftFils < 0) {
      showFormError(context, l10n.salaryPartsTooMuch);
      return;
    }
    if (isSalary) {
      final extra = _extraFils;
      if (extra < 0) {
        showFormError(context, l10n.salaryPartsTooMuch);
        return;
      }
      if (extra > 0 && !await _confirmExtra(extra)) return;
      if (!mounted) return;
    }
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final reference = _reference.text.trim().isEmpty ? null : _reference.text.trim();
    var opened = const <String>[];
    try {
      Future<void> add() async {
        if (isReceipt) {
          await ref
              .read(dbProvider)
              .addClientReceipt(
                operationId: _operationId,
                date: _date!,
                clientId: clientId!,
                amountFils: parseAed(_amount.text)!,
                parts: _receiptTyped,
                method: _method,
                reference: reference,
                note: note,
              );
        } else if (isSalary) {
          await ref
              .read(dbProvider)
              .addSalaryPayment(
                operationId: _operationId,
                date: _date!,
                workerId: workerId!,
                amountFils: parseAed(_amount.text)!,
                parts: _partsTyped,
                extraNote: l10n.salaryExtraNote,
                method: _method,
                note: note,
                reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
                receiver: _receiver.text.trim().isEmpty ? null : _receiver.text.trim(),
              );
        } else {
          await ref
              .read(dbProvider)
              .addCashEntry(
                operationId: _operationId,
                date: _date!,
                kind: _kind,
                amountFils: parseAed(_amount.text)!,
                workerId: workerId,
                roomId: roomId,
                clientId: clientId,
                siteId: isExpense ? _siteId : null,
                category: isExpense ? _category : null,
                method: _method,
                note: note,
                reference: isExpense && _reference.text.trim().isNotEmpty ? _reference.text.trim() : null,
                instalmentFils: _kind == CashKind.advanceGiven ? parseAed(_instalment.text) : null,
              );
        }
      }

      final old = widget.editing;
      if (old == null) {
        await add();
      } else {
        final changeNote = _changeNote.text.trim();
        opened = await ref
            .read(dbProvider)
            .replaceCash(old, add, note: changeNote.isEmpty ? null : changeNote, newDate: _date!, reopenReason: l10n.reopenByEdit, operationId: _operationId);
      }
    } on ReceiptTooHigh {
      if (mounted) showFormError(context, l10n.receiptPartTooHigh);
      await _loadOwed();
      return;
    } on AllocationTooHigh {
      if (mounted) showFormError(context, l10n.salaryPartTooHigh);
      await _loadUnpaid();
      return;
    } on AdvanceTooHigh {
      if (mounted) showFormError(context, l10n.advanceTooHigh);
      return;
    } on VisaTooHigh {
      if (mounted) showFormError(context, l10n.visaTooHigh);
      return;
    } catch (e) {
      if (mounted) showFormError(context, saveErrorText(l10n, e));
      return;
    }
    if (!mounted) return;
    final worker = (ref.read(workersProvider).value ?? const <Worker>[]).where((w) => w.id == workerId).firstOrNull;
    final room = (ref.read(roomsProvider).value ?? const <Room>[]).where((r) => r.id == roomId).firstOrNull;
    final client = (ref.read(clientsProvider).value ?? const <Client>[]).where((c) => c.id == clientId).firstOrNull;
    final place = worker?.name ?? room?.name ?? client?.name;
    showSavedOnPhone(
      context,
      opened.isNotEmpty ? l10n.monthsOpened(opened.map(showMonth).join(', ')) : (place == null ? l10n.savedOnPhone : l10n.savedTo(place)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final moneyIn = isMoneyIn(_kind);
    final workers = (ref.watch(workersProvider).value ?? const <Worker>[]).where((w) => w.active || w.id == _workerId).toList();
    final rooms = (ref.watch(roomsProvider).value ?? const <Room>[]).where((r) => r.active || r.id == _roomId).toList();
    final clients = (ref.watch(clientsProvider).value ?? const <Client>[]).where((c) => c.active || c.id == _clientId).toList();
    final sites = (ref.watch(allSitesProvider).value ?? const <Site>[]).where((s) => s.active).toList();
    final isSalary = _kind == CashKind.salaryPaid && _workerId != null;
    final showAdvanceLeft = (_kind == CashKind.advanceReturned || isSalary) && _workerId != null;
    final advanceOpening = (ref.watch(openingBalancesProvider).value ?? const <OpeningBalance>[])
        .where((b) => b.kind == 'worker_advance' && b.workerId == _workerId)
        .fold(0, (total, b) => total + b.amountFils);
    final workerLines = showAdvanceLeft ? (ref.watch(cashOfWorkerProvider(_workerId!)).value ?? const <CashEntry>[]) : const <CashEntry>[];
    final recovered = showAdvanceLeft
        ? (ref.watch(linesOfWorkerProvider(_workerId!)).value ?? const <PayrollLine>[]).fold(0, (total, l) => total + l.recoveryFils)
        : 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.editing == null ? l10n.addCash : l10n.cashEdit)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.moneyOut)),
                ButtonSegment(value: true, label: Text(l10n.moneyIn)),
              ],
              selected: {moneyIn},
              onSelectionChanged: (s) => _pickKind(s.single ? _inKinds.first : _outKinds.first),
            ),
            fieldGap,
            Wrap(
              spacing: 8,
              children: [
                for (final kind in moneyIn ? _inKinds : _outKinds)
                  ChoiceChip(label: Text(kindLabel(l10n, kind)), selected: _kind == kind, onSelected: (_) => _pickKind(kind)),
              ],
            ),
            fieldGap,
            if (_needsWorker) ...[
              PickField(
                l10n.chooseWorker,
                selected: _workerId,
                options: [for (final w in workers) (value: w.id, label: '${w.name} (${w.code})')],
                onChanged: (v) {
                  setState(() {
                    _workerId = v;
                    _fillRentFromWorker();
                  });
                  _loadUnpaid();
                },
              ),
              fieldGap,
            ],
            if (showAdvanceLeft) ...[
              Text(
                l10n.advanceBalance(formatAed(advanceOutstanding(advanceOpening, workerLines.map(cashLine), recoveredFils: recovered))),
                style: const TextStyle(color: muted),
              ),
              fieldGap,
            ],
            if (_needsRoom) ...[
              PickField(
                l10n.chooseRoom,
                selected: _roomId,
                emptyText: l10n.roomsEmpty,
                options: [for (final r in rooms) (value: r.id, label: r.name)],
                onChanged: (v) => setState(() => _roomId = v),
              ),
              fieldGap,
            ],
            if (_kind == CashKind.clientReceipt) ...[
              PickField(
                l10n.chooseClient,
                selected: _clientId,
                options: [for (final c in clients) (value: c.id, label: c.name)],
                onChanged: (v) {
                  setState(() {
                    _clientId = v;
                    _owed = const [];
                  });
                  _loadOwed();
                },
              ),
              fieldGap,
            ],
            if (_kind == CashKind.expense) ...[
              Text(l10n.expenseCategory, style: sectionTitleStyle),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final category in expenseCategories)
                    ChoiceChip(
                      label: Text(categoryLabel(l10n, category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              fieldGap,
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _siteId,
                decoration: InputDecoration(labelText: l10n.optionalSite),
                items: [
                  DropdownMenuItem(child: Text(l10n.noneChoice)),
                  for (final s in sites) DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _siteId = v),
              ),
              fieldGap,
            ],
            Field(
              l10n.amountAed,
              _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (parseAed(v ?? '') ?? 0) <= 0 ? l10n.amountInvalid : null,
              onChanged: (_) => _amountChanged(),
            ),
            fieldGap,
            if (_kind == CashKind.advanceGiven) ...[
              Field(
                l10n.cashInstalment,
                _instalment,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                helper: l10n.cashInstalmentHelp,
                validator: (v) => (v ?? '').trim().isNotEmpty && (parseAed(v!) ?? 0) <= 0 ? l10n.amountInvalid : null,
              ),
              fieldGap,
            ],
            if (_kind == CashKind.clientReceipt && _clientId != null) ...[
              Row(
                children: [
                  Expanded(child: Text(l10n.receiptPaysHeading, style: sectionTitleStyle)),
                  if (_partsEdited)
                    TextButton(
                      onPressed: () => setState(() {
                        _partsEdited = false;
                        _shareOut();
                      }),
                      child: Text(l10n.salaryOldestFirst),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (_owed.isEmpty) Text(l10n.receiptNothingOwed, style: const TextStyle(color: muted)),
              for (final o in _owed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.number ?? l10n.receiptOldBalance, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              o.dueDate == null
                                  ? l10n.salaryMonthLeft(formatAed(o.leftFils))
                                  : l10n.receiptInvoiceLeft(formatAed(o.leftFils), showDate(o.dueDate!)),
                              style: const TextStyle(color: muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: Field(
                          l10n.amountAed,
                          _receiptParts[o.invoiceId]!,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() => _partsEdited = true),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return null;
                            final fils = parseAed(v!);
                            if (fils == null || fils < 0) return l10n.amountInvalid;
                            return fils > o.leftFils ? l10n.receiptPartTooHigh : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (_receiptLeftFils > 0) Text(l10n.receiptKeptLine(formatAed(_receiptLeftFils)), style: const TextStyle(color: muted)),
              if (_companyCredit > 0) Text(l10n.receiptCreditAlready(formatAed(_companyCredit)), style: const TextStyle(color: muted)),
              fieldGap,
            ],
            if (isSalary) ...[
              Row(
                children: [
                  Expanded(child: Text(l10n.salaryMonthsHeading, style: sectionTitleStyle)),
                  if (_partsEdited)
                    TextButton(
                      onPressed: () => setState(() {
                        _partsEdited = false;
                        _shareOut();
                      }),
                      child: Text(l10n.salaryOldestFirst),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (_unpaid.isEmpty) Text(l10n.salaryNothingOwed, style: const TextStyle(color: muted)),
              for (final m in _unpaid.keys.toList()..sort())
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(showMonth(m), style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(l10n.salaryMonthLeft(formatAed(_unpaid[m]!)), style: const TextStyle(color: muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: Field(
                          l10n.amountAed,
                          _parts[m]!,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() => _partsEdited = true),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) return null;
                            final fils = parseAed(v!);
                            if (fils == null || fils < 0) return l10n.amountInvalid;
                            return fils > _unpaid[m]! ? l10n.salaryPartTooHigh : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (_extraFils > 0) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.salaryExtraLine(formatAed(_extraFils)),
                  style: const TextStyle(color: warn, fontWeight: FontWeight.w600),
                ),
              ],
              fieldGap,
            ],
            DateField(
              l10n.workDate,
              value: _date,
              onChanged: (v) {
                setState(() => _date = v);
                _loadUnpaid();
              },
              required: true,
            ),
            fieldGap,
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(l10n.methodCash)),
                ButtonSegment(value: 'bank', label: Text(l10n.methodBank)),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.single),
            ),
            fieldGap,
            if (isSalary || _kind == CashKind.expense || _kind == CashKind.clientReceipt) ...[Field(l10n.salaryReference, _reference), fieldGap],
            if (isSalary) ...[Field(l10n.salaryReceiver, _receiver, helper: l10n.salaryReceiverHelp), fieldGap],
            Field(l10n.note, _note),
            if (widget.editing != null) ...[fieldGap, Field(l10n.changeNote, _changeNote, helper: l10n.changeNoteHelp)],
          ],
        ),
      ),
    );
  }
}
