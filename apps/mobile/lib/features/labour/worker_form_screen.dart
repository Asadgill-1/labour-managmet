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

/// Worker details (MASTER-04). No Emirates ID or passport fields on purpose. Photo arrives in T14.
class WorkerFormScreen extends ConsumerStatefulWidget {
  const WorkerFormScreen({this.worker, super.key});

  final Worker? worker;

  @override
  ConsumerState<WorkerFormScreen> createState() => _WorkerFormScreenState();
}

class _WorkerFormScreenState extends ConsumerState<WorkerFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _code = TextEditingController(text: widget.worker?.code);
  late final _name = TextEditingController(text: widget.worker?.name);
  late final _phone = TextEditingController(text: widget.worker?.phone);
  late final _trade = TextEditingController(text: widget.worker?.trade);
  late final _room = TextEditingController(
    text: widget.worker?.roomChargeFils == null ? '' : plainAmount(widget.worker!.roomChargeFils!),
  );
  late final _roomNote = TextEditingController(text: widget.worker?.roomChargeNote);
  late String? _joined = widget.worker?.joiningDate;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    if (widget.worker == null) {
      ref.read(dbProvider).nextWorkerCode().then((code) {
        if (mounted && _code.text.isEmpty) _code.text = code;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _codeError = null);
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final code = _code.text.trim();
    if (await db.workerCodeTaken(code, exceptId: widget.worker?.id)) {
      setState(() => _codeError = l10n.workerCodeTaken);
      return;
    }
    await db.saveRow(
      db.workers,
      id: widget.worker?.id,
      operationId: _operationId,
      fields: WorkersCompanion(
        code: Value(code),
        name: Value(_name.text.trim()),
        phone: optionalText(_phone),
        trade: optionalText(_trade),
        joiningDate: Value(_joined),
        roomChargeFils: Value(parseAed(_room.text)),
        roomChargeNote: optionalText(_roomNote),
      ),
    );
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.worker == null ? l10n.addWorker : l10n.editWorker)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
              decoration: InputDecoration(labelText: l10n.workerCode, errorText: _codeError),
            ),
            fieldGap,
            Field(l10n.workerName, _name, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            fieldGap,
            Field(l10n.trade, _trade),
            fieldGap,
            Field(l10n.phone, _phone, keyboardType: TextInputType.phone),
            fieldGap,
            DateField(l10n.joiningDate, value: _joined, onChanged: (v) => setState(() => _joined = v)),
            fieldGap,
            Field(
              l10n.roomCharge,
              _room,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v ?? '').trim().isNotEmpty && parseAed(v!) == null ? l10n.amountInvalid : null,
            ),
            fieldGap,
            Field(l10n.roomChargeNote, _roomNote),
          ],
        ),
      ),
    );
  }
}
