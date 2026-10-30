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

/// Own company details (MASTER-01). With no profile yet, this is the first onboarding step (UX-02),
/// and only the legal name is needed. Logo upload arrives with the document engine in T14.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({this.profile, super.key});

  final TenantProfile? profile;

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _legal = TextEditingController(text: widget.profile?.legalName);
  late final _trading = TextEditingController(text: widget.profile?.tradingName);
  late final _address = TextEditingController(text: widget.profile?.address);
  late final _phone = TextEditingController(text: widget.profile?.phone);
  late final _email = TextEditingController(text: widget.profile?.email);
  late final _trn = TextEditingController(text: widget.profile?.trn);
  late final _prefix = TextEditingController(text: widget.profile?.invoicePrefix ?? 'INV');
  late final _terms = TextEditingController(text: widget.profile?.paymentTermsDays?.toString());
  late final _bank = TextEditingController(text: widget.profile?.bankDetails);
  late final _footer = TextEditingController(text: widget.profile?.documentFooter);
  late bool _vat = widget.profile?.vatRegistered ?? false;
  late String? _vatFrom = widget.profile?.vatEffectiveFrom;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    await db.saveRow(
      db.tenantProfiles,
      id: widget.profile?.id,
      operationId: _operationId,
      fields: TenantProfilesCompanion(
        legalName: Value(_legal.text.trim()),
        tradingName: optionalText(_trading),
        address: optionalText(_address),
        phone: optionalText(_phone),
        email: optionalText(_email),
        vatRegistered: Value(_vat),
        vatEffectiveFrom: Value(_vat ? _vatFrom : null),
        trn: _vat ? optionalText(_trn) : const Value(null),
        invoicePrefix: Value(_prefix.text.trim().isEmpty ? 'INV' : _prefix.text.trim()),
        paymentTermsDays: Value(int.tryParse(_terms.text.trim())),
        bankDetails: optionalText(_bank),
        documentFooter: optionalText(_footer),
      ),
    );
    if (!mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    if (widget.profile != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstRun = widget.profile == null;
    return Scaffold(
      appBar: AppBar(title: Text(firstRun ? l10n.welcomeTitle : l10n.myCompany)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (firstRun) ...[Text(l10n.welcomeBody), fieldGap],
            Field(l10n.legalName, _legal, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            fieldGap,
            Field(l10n.tradingName, _trading),
            fieldGap,
            Field(l10n.address, _address, lines: 2),
            fieldGap,
            Field(l10n.phone, _phone, keyboardType: TextInputType.phone),
            fieldGap,
            Field(l10n.email, _email, keyboardType: TextInputType.emailAddress),
            fieldGap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.vatRegistered),
              value: _vat,
              onChanged: (v) => setState(() => _vat = v),
            ),
            if (_vat) ...[
              DateField(l10n.vatEffectiveFrom, value: _vatFrom, onChanged: (v) => setState(() => _vatFrom = v), required: true),
              fieldGap,
              Field(
                l10n.trn,
                _trn,
                keyboardType: TextInputType.number,
                helper: l10n.trnFormatOnly,
                validator: (v) => isTrnFormat(v ?? '') ? null : l10n.trnFormatError,
              ),
              fieldGap,
            ],
            Field(l10n.invoicePrefix, _prefix),
            fieldGap,
            Field(l10n.paymentTermsDays, _terms, keyboardType: TextInputType.number),
            fieldGap,
            Field(l10n.bankDetails, _bank, lines: 3),
            fieldGap,
            Field(l10n.documentFooter, _footer, lines: 2),
          ],
        ),
      ),
    );
  }
}
