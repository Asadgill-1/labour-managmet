import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../data/tenant_database.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// The trimmed text as a nullable column value, so a cleared field really clears.
Value<String?> optionalText(TextEditingController c) {
  final text = c.text.trim();
  return Value(text.isEmpty ? null : text);
}

/// Gap between form rows, used by every form.
const fieldGap = SizedBox(height: 14);

/// Scrollable form content. Not a ListView: a lazy list drops off-screen fields, and a field that
/// isn't built never gets validated, so a required value could be skipped.
class FormBody extends StatelessWidget {
  const FormBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Validates the form and scrolls to the first bad field, so the error is never out of sight (UX-04).
bool validateAndReveal(GlobalKey<FormState> form) {
  final invalid = form.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  Scrollable.ensureVisible(invalid.first.context, alignment: 0.2, duration: const Duration(milliseconds: 200));
  return false;
}

class Field extends StatelessWidget {
  const Field(this.label, this.controller, {this.validator, this.keyboardType, this.helper, this.lines = 1, super.key});

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final String? helper;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2),
    );
  }
}

/// Opens the calendar on a stored date, or today. Returns a stored date, or null if dismissed.
Future<String?> pickDate(BuildContext context, String? current) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: current == null ? DateTime.now() : DateTime.parse(current),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  return picked == null ? null : ymd(picked);
}

/// Date picked from a calendar, shown DD-MM-YYYY and stored YYYY-MM-DD.
class DateField extends StatelessWidget {
  const DateField(this.label, {required this.value, required this.onChanged, this.required = false, super.key});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormField<String>(
      key: ValueKey('$label$value'),
      initialValue: value,
      validator: (v) => required && v == null ? l10n.fieldRequired : null,
      builder: (state) => InkWell(
        onTap: () async {
          final picked = await pickDate(context, value);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: state.errorText,
            suffixIcon: value != null && !required
                ? IconButton(tooltip: l10n.clearValue, icon: const Icon(Icons.close), onPressed: () => onChanged(null))
                : const Icon(Icons.calendar_today),
          ),
          child: Text(value == null ? '' : showDate(value!)),
        ),
      ),
    );
  }
}

/// Time picked on a clock, held as minutes from midnight.
class TimeField extends StatelessWidget {
  const TimeField(this.label, {required this.value, required this.onChanged, super.key});

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final current = value ?? 8 * 60;
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked.hour * 60 + picked.minute);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule)),
        child: Text(value == null ? '' : showMinuteOfDay(value!)),
      ),
    );
  }
}

/// Section heading in a detail screen, with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: sectionTitleStyle)),
          if (action != null) Flexible(child: action!),
        ],
      ),
    );
  }
}

/// Asks for the reason behind an undo. Null means the owner backed out.
Future<String?> askReason(BuildContext context, {required String title, required String helper, required String confirm}) async {
  final l10n = AppLocalizations.of(context);
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: Field(l10n.reverseReason, reason, helper: helper, validator: (v) => (v ?? '').trim().isEmpty ? l10n.fieldRequired : null),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.of(dialog).pop(true);
          },
          child: Text(confirm),
        ),
      ],
    ),
  );
  return yes == true ? reason.text.trim() : null;
}

/// The month and arrows to change it, on a hi-vis band.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({required this.month, required this.onChanged, super.key});

  /// YYYY-MM.
  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(tooltip: l10n.previousMonth, color: ink, icon: const Icon(Icons.chevron_left), onPressed: () => onChanged(addMonths(month, -1))),
        Text(showMonth(month), style: sectionTitleStyle),
        IconButton(tooltip: l10n.nextMonth, color: ink, icon: const Icon(Icons.chevron_right), onPressed: () => onChanged(addMonths(month, 1))),
      ],
    );
  }
}

/// Search box above a register list.
class SearchBox extends StatelessWidget {
  const SearchBox({required this.onChanged, this.hint, super.key});

  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint ?? AppLocalizations.of(context).search,
          isDense: true,
        ),
      ),
    );
  }
}

/// A row whose text can change after it first shows, because its data arrives a moment later. A tile's white
/// background is painted on the screen behind the list, which otherwise keeps the old height until something scrolls.
class GrowingRow extends StatelessWidget {
  const GrowingRow({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizeChangedLayoutNotifier(child: child);
}

/// A name's first letter, for a [RowTag].
String initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

/// Square mark at the start of a row, like the code column of a paper register.
class RowTag extends StatelessWidget {
  const RowTag(String this.text, {this.fill = paper, this.color = ink, super.key}) : icon = null;
  const RowTag.icon(IconData this.icon, {required this.fill, required this.color, super.key}) : text = null;

  final String? text;
  final IconData? icon;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
      child: icon != null
          ? Icon(icon, color: color)
          : FittedBox(fit: BoxFit.scaleDown, child: Text(text!, style: amountStyle.copyWith(fontSize: 17, color: color))),
    );
  }
}

/// A row's value on the right. Shrinks to fit, so a big amount can't squeeze the row's name or get cut off.
class RowValue extends StatelessWidget {
  const RowValue(this.text, {this.style = amountStyle, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.36),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(text, style: style),
      ),
    );
  }
}

/// A label on the left and its value on the right. The value carries the weight, not the label.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {this.onTap, super.key});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w400, color: muted)),
      trailing: RowValue(value),
      onTap: onTap,
    );
  }
}

/// What an empty screen shows: what's missing and what to do about it.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFA9AEB1)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
          ],
        ),
      ),
    );
  }
}

/// One big figure with its label, for the yellow band at the top of a screen.
class BandFigure extends StatelessWidget {
  const BandFigure(this.value, this.label, {this.size = 34, super.key});

  final String value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed height, so a long amount that shrinks doesn't lift its label out of line with the others.
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(size * 1.2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: amountStyle.copyWith(fontSize: size, height: 1.15)),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 13, color: ink)),
      ],
    );
  }
}

/// Asks for one worker's daily wage. Null means cancelled. A null `fils` means the field was left empty.
Future<({int? fils})?> askDailyWage(BuildContext context, {required String title, required String helper, int? initial}) {
  final l10n = AppLocalizations.of(context);
  final amount = TextEditingController(text: initial == null ? '' : plainAmount(initial));
  final form = GlobalKey<FormState>();
  return showDialog<({int? fils})>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: Field(
          l10n.dailyWage,
          amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          helper: helper,
          validator: (v) => (v ?? '').trim().isNotEmpty && parseAed(v!) == null ? l10n.amountInvalid : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.of(dialog).pop((fils: parseAed(amount.text)));
          },
          child: Text(l10n.applyChanges),
        ),
      ],
    ),
  );
}

/// True if this worker has a monthly pay contract on this date. Their pay stays monthly (ATT-03).
bool onMonthlyPay(List<PayContract> contracts, String workerId, String date) {
  return contracts.any(
    (c) => c.workerId == workerId && c.basis == 'month' && c.effectiveFrom.compareTo(date) <= 0 && (c.effectiveTo == null || c.effectiveTo!.compareTo(date) >= 0),
  );
}

/// Bottom sheet to pick one option, with a search once the list is long. Skips the question when there is only one answer.
Future<T?> chooseOne<T>(BuildContext context, String title, List<({T value, String label})> options, {String? emptyText}) async {
  if (options.isEmpty) {
    showFormError(context, emptyText ?? AppLocalizations.of(context).needSetupFirst);
    return null;
  }
  if (options.length == 1) return options.single.value;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChooseSheet<T>(title: title, options: options),
  );
}

class _ChooseSheet<T> extends StatefulWidget {
  const _ChooseSheet({required this.title, required this.options, super.key});

  final String title;
  final List<({T value, String label})> options;

  @override
  State<_ChooseSheet<T>> createState() => _ChooseSheetState<T>();
}

class _ChooseSheetState<T> extends State<_ChooseSheet<T>> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final needle = _search.toLowerCase();
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(widget.title, style: sectionTitleStyle),
              ),
              if (widget.options.length > 6) SearchBox(onChanged: (v) => setState(() => _search = v)),
              for (final option in widget.options.where((o) => o.label.toLowerCase().contains(needle))) ...[
                const Divider(),
                ListTile(
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A required form field that opens [chooseOne], for lists too long to scroll in a dropdown.
class PickField extends StatelessWidget {
  const PickField(this.label, {required this.selected, required this.options, required this.onChanged, this.emptyText, super.key});

  final String label;
  final String? selected;
  final List<({String value, String label})> options;
  final ValueChanged<String> onChanged;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FormField<String>(
      key: ValueKey('$label$selected'),
      initialValue: selected,
      validator: (v) => v == null ? l10n.fieldRequired : null,
      builder: (state) => InkWell(
        onTap: () async {
          final picked = await chooseOne<String>(context, label, options, emptyText: emptyText);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: state.errorText, suffixIcon: const Icon(Icons.search)),
          child: Text(options.where((o) => o.value == selected).map((o) => o.label).firstOrNull ?? ''),
        ),
      ),
    );
  }
}

/// Monday first, as DateTime.weekday counts.
String dayName(AppLocalizations l10n, String date) => l10n.dayNames.split(',')[DateTime.parse(date).weekday - 1];

/// A week around the chosen date, like the date columns of a muster roll. The calendar reaches further.
class DayStrip extends StatelessWidget {
  const DayStrip({required this.selected, required this.onPick, super.key});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        for (var offset = -3; offset <= 3; offset++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = addDays(selected, offset);
                final color = offset == 0 ? Colors.white : ink;
                return Semantics(
                  button: true,
                  selected: offset == 0,
                  label: showDate(date),
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onPick(date),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: offset == 0 ? ink : null, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          // Fixed height, so a long day name that shrinks doesn't lift its number out of line.
                          SizedBox(
                            height: MediaQuery.textScalerOf(context).scale(16),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(dayName(l10n, date), style: TextStyle(fontSize: 12, color: color)),
                            ),
                          ),
                          Text(date.substring(8), style: amountStyle.copyWith(fontSize: 20, color: color)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
