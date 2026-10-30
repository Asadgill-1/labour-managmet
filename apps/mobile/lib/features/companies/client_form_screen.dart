import 'package:domain/validation.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({this.client, super.key});

  final Client? client;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _name = TextEditingController(text: widget.client?.name);
  late final _address = TextEditingController(text: widget.client?.address);
  late final _contact = TextEditingController(text: widget.client?.contactPerson);
  late final _phone = TextEditingController(text: widget.client?.phone);
  late final _email = TextEditingController(text: widget.client?.email);
  late final _trn = TextEditingController(text: widget.client?.trn);
  late final _invoiceAddress = TextEditingController(text: widget.client?.invoiceAddress);
  late final _due = TextEditingController(text: widget.client?.dueDays?.toString());
  late final _po = TextEditingController(text: widget.client?.poReference);
  late final _note = TextEditingController(text: widget.client?.note);
  late bool _vat = widget.client?.vatRegistered ?? false;

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    await db.saveRow(
      db.clients,
      id: widget.client?.id,
      operationId: _operationId,
      fields: ClientsCompanion(
        name: Value(_name.text.trim()),
        address: optionalText(_address),
        contactPerson: optionalText(_contact),
        phone: optionalText(_phone),
        email: optionalText(_email),
        vatRegistered: Value(_vat),
        trn: _vat ? optionalText(_trn) : const Value(null),
        invoiceAddress: optionalText(_invoiceAddress),
        dueDays: Value(int.tryParse(_due.text.trim())),
        poReference: optionalText(_po),
        note: optionalText(_note),
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
      appBar: AppBar(title: Text(widget.client == null ? l10n.addClient : l10n.editClient)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            Field(l10n.clientName, _name, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            fieldGap,
            Field(l10n.contactPerson, _contact),
            fieldGap,
            Field(l10n.phone, _phone, keyboardType: TextInputType.phone),
            fieldGap,
            Field(l10n.email, _email, keyboardType: TextInputType.emailAddress),
            fieldGap,
            Field(l10n.address, _address, lines: 2),
            fieldGap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.clientVatRegistered),
              value: _vat,
              onChanged: (v) => setState(() => _vat = v),
            ),
            if (_vat) ...[
              Field(
                l10n.trn,
                _trn,
                keyboardType: TextInputType.number,
                helper: l10n.trnFormatOnly,
                validator: (v) => isTrnFormat(v ?? '') ? null : l10n.trnFormatError,
              ),
              fieldGap,
            ],
            Field(l10n.invoiceAddress, _invoiceAddress, lines: 2),
            fieldGap,
            Field(l10n.dueDays, _due, keyboardType: TextInputType.number),
            fieldGap,
            Field(l10n.poReference, _po),
            fieldGap,
            Field(l10n.note, _note, lines: 2),
          ],
        ),
      ),
    );
  }
}
