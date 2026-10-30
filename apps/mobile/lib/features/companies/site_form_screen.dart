import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

class SiteFormScreen extends ConsumerStatefulWidget {
  const SiteFormScreen({required this.clientId, this.site, super.key});

  final String clientId;
  final Site? site;

  @override
  ConsumerState<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends ConsumerState<SiteFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _name = TextEditingController(text: widget.site?.name);
  late final _location = TextEditingController(text: widget.site?.location);
  late final _contact = TextEditingController(text: widget.site?.contact);
  late final _break = TextEditingController(text: (widget.site?.defaultBreakMinutes ?? 0).toString());
  late String? _from = widget.site?.activeFrom;
  late String? _to = widget.site?.activeTo;
  late int? _start = widget.site?.defaultStartMinute;
  late int? _end = widget.site?.defaultEndMinute;
  late bool _active = widget.site?.active ?? true;

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    await db.saveRow(
      db.sites,
      id: widget.site?.id,
      operationId: _operationId,
      fields: SitesCompanion(
        clientId: Value(widget.clientId),
        name: Value(_name.text.trim()),
        location: optionalText(_location),
        contact: optionalText(_contact),
        activeFrom: Value(_from),
        activeTo: Value(_to),
        defaultStartMinute: Value(_start),
        defaultEndMinute: Value(_end),
        defaultBreakMinutes: Value(int.parse(_break.text.trim())),
        active: Value(_active),
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
      appBar: AppBar(title: Text(widget.site == null ? l10n.addSite : l10n.editSite)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            Field(l10n.siteName, _name, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            fieldGap,
            Field(l10n.siteLocation, _location),
            fieldGap,
            Field(l10n.contactPerson, _contact),
            fieldGap,
            Row(
              children: [
                Expanded(child: TimeField(l10n.defaultStart, value: _start, onChanged: (v) => setState(() => _start = v))),
                const SizedBox(width: 12),
                Expanded(child: TimeField(l10n.defaultEnd, value: _end, onChanged: (v) => setState(() => _end = v))),
              ],
            ),
            fieldGap,
            Field(
              l10n.defaultBreakMinutes,
              _break,
              keyboardType: TextInputType.number,
              validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? l10n.wholeNumberRequired : null,
            ),
            fieldGap,
            DateField(l10n.activeFrom, value: _from, onChanged: (v) => setState(() => _from = v)),
            fieldGap,
            DateField(l10n.activeTo, value: _to, onChanged: (v) => setState(() => _to = v)),
            if (widget.site != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.activeLabel),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
          ],
        ),
      ),
    );
  }
}
