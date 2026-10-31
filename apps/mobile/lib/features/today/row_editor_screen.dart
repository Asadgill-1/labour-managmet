import 'package:domain/calc.dart';
import 'package:domain/money.dart';
import 'package:flutter/material.dart';

import '../../app/form_bits.dart';
import '../../app/theme.dart';
import '../../data/attendance.dart';
import '../../l10n/app_localizations.dart';

/// What the editor hands back. [delete] means remove the entry.
typedef RowEdit = ({EntryInput? input, String? correctionReason, bool delete});

/// Changes one worker's row: late, half day, absent, overtime or a different rate (ATT-04).
/// With [correcting], the row is already approved, so a reason is required and the original is kept (ATT-08).
class RowEditorScreen extends StatefulWidget {
  const RowEditorScreen({
    required this.title,
    required this.input,
    this.overlaps = false,
    this.correcting = false,
    this.canDelete = false,
    super.key,
  });

  final String title;
  final EntryInput input;
  final bool overlaps;
  final bool correcting;
  final bool canDelete;

  @override
  State<RowEditorScreen> createState() => _RowEditorScreenState();
}

class _RowEditorScreenState extends State<RowEditorScreen> {
  final _form = GlobalKey<FormState>();
  late AttendanceStatus _status = widget.input.shift.status;
  late int? _start = widget.input.shift.startMinute;
  late int? _end = widget.input.shift.endMinute;
  late final _break = TextEditingController(text: widget.input.shift.breakMinutes.toString());
  late bool? _paidClient = widget.input.shift.breakPaidClient;
  late bool? _paidWorker = widget.input.shift.breakPaidWorker;
  late bool _overtime = widget.input.shift.overtimeApproved;
  late final _clientRate = TextEditingController(text: _plain(widget.input.shift.clientOverrideFils));
  late final _workerRate = TextEditingController(text: _plain(widget.input.shift.workerOverrideFils));
  late final _reason = TextEditingController(text: widget.input.overrideReason);
  late final _overlapReason = TextEditingController(text: widget.input.overlapReason);
  late final _notes = TextEditingController(text: widget.input.notes);
  final _correction = TextEditingController();

  static String _plain(int? fils) => fils == null ? '' : plainAmount(fils);
  static String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  void _apply() {
    if (!validateAndReveal(_form)) return;
    final l10n = AppLocalizations.of(context);
    if (_status != AttendanceStatus.absent && (_start == null || _end == null)) {
      showFormError(context, l10n.timesRequired);
      return;
    }
    Navigator.of(context).pop<RowEdit>((
      delete: false,
      correctionReason: _text(_correction),
      input: EntryInput(
        workerId: widget.input.workerId,
        groupId: widget.input.groupId,
        overrideReason: _text(_reason),
        overlapReason: _text(_overlapReason),
        notes: _text(_notes),
        shift: ShiftInput(
          status: _status,
          startMinute: _start,
          endMinute: _end,
          breakMinutes: int.parse(_break.text.trim()),
          breakPaidClient: _paidClient,
          breakPaidWorker: _paidWorker,
          overtimeApproved: _overtime,
          clientOverrideFils: parseAed(_clientRate.text),
          workerOverrideFils: parseAed(_workerRate.text),
        ),
      ),
    ));
  }

  String? _optionalAmount(String? v, AppLocalizations l10n) {
    return (v ?? '').trim().isNotEmpty && parseAed(v!) == null ? l10n.amountInvalid : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final worked = _status != AttendanceStatus.absent;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      bottomNavigationBar: MainActionBar(label: l10n.applyChanges, onPressed: _apply),
      body: Form(
        key: _form,
        child: FormBody(
          children: [
            SegmentedButton<AttendanceStatus>(
              segments: [
                ButtonSegment(value: AttendanceStatus.present, label: Text(l10n.statusPresent)),
                ButtonSegment(value: AttendanceStatus.half, label: Text(l10n.statusHalf)),
                ButtonSegment(value: AttendanceStatus.absent, label: Text(l10n.statusAbsent)),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.single),
            ),
            fieldGap,
            if (worked) ...[
              Row(
                children: [
                  Expanded(child: TimeField(l10n.shiftStart, value: _start, onChanged: (v) => setState(() => _start = v))),
                  const SizedBox(width: 12),
                  Expanded(child: TimeField(l10n.shiftEnd, value: _end, onChanged: (v) => setState(() => _end = v))),
                ],
              ),
              fieldGap,
              Field(
                l10n.breakMinutes,
                _break,
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse((v ?? '').trim()) ?? -1) < 0 ? l10n.wholeNumberRequired : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.clientBreakPaid),
                value: _paidClient ?? false,
                onChanged: (v) => setState(() => _paidClient = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.workerBreakPaid),
                value: _paidWorker ?? false,
                onChanged: (v) => setState(() => _paidWorker = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.overtimeApproved),
                value: _overtime,
                onChanged: (v) => setState(() => _overtime = v),
              ),
              Field(
                l10n.clientOverride,
                _clientRate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                helper: l10n.overrideHelp,
                validator: (v) => _optionalAmount(v, l10n),
              ),
              fieldGap,
              Field(
                l10n.workerOverride,
                _workerRate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => _optionalAmount(v, l10n),
              ),
              fieldGap,
              Field(
                l10n.overrideReason,
                _reason,
                validator: (v) {
                  final overridden = _clientRate.text.trim().isNotEmpty || _workerRate.text.trim().isNotEmpty;
                  return overridden && (v ?? '').trim().isEmpty ? l10n.fieldRequired : null;
                },
              ),
              fieldGap,
            ],
            if (widget.overlaps) ...[
              Field(l10n.overlapReason, _overlapReason, validator: (v) => worked && (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
              fieldGap,
            ],
            Field(l10n.note, _notes),
            if (widget.correcting) ...[
              fieldGap,
              Field(
                l10n.correctionReason,
                _correction,
                helper: l10n.correctionHelp,
                validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
              ),
            ],
            if (widget.canDelete) ...[
              fieldGap,
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop<RowEdit>((delete: true, correctionReason: null, input: null)),
                child: Text(l10n.deleteRow),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
