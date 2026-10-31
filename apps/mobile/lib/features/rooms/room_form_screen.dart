import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/masters.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';

class RoomFormScreen extends ConsumerStatefulWidget {
  const RoomFormScreen({this.room, super.key});

  final Room? room;

  @override
  ConsumerState<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends ConsumerState<RoomFormScreen> {
  final _form = GlobalKey<FormState>();
  final _operationId = newUuid();
  late final _name = TextEditingController(text: widget.room?.name);
  late final _note = TextEditingController(text: widget.room?.note);
  late bool _active = widget.room?.active ?? true;

  Future<void> _save() async {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final saved = await saveOrExplain(context, () => db.saveRow(
      db.rooms,
      id: widget.room?.id,
      operationId: _operationId,
      fields: RoomsCompanion(name: Value(_name.text.trim()), note: optionalText(_note), active: Value(_active)),
    ));
    if (!saved || !mounted) return;
    showSavedOnPhone(context, l10n.savedOnPhone);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.room == null ? l10n.addRoom : l10n.editRoom)),
      bottomNavigationBar: MainActionBar(label: l10n.save, onPressed: _save),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            Field(l10n.roomName, _name, helper: l10n.roomNameHelp, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
            fieldGap,
            Field(l10n.note, _note),
            if (widget.room != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: Colors.transparent,
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
