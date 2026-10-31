import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

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

/// Search box above a register list.
class SearchBox extends StatelessWidget {
  const SearchBox({required this.onChanged, super.key});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: AppLocalizations.of(context).search,
          isDense: true,
        ),
      ),
    );
  }
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
  const RowValue(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.42),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(text, style: amountStyle),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: amountStyle.copyWith(fontSize: size, height: 1.15)),
        ),
        Text(label, style: const TextStyle(fontSize: 13, color: ink)),
      ],
    );
  }
}

/// Bottom sheet to pick one option. Skips the question when there is only one answer.
/// ponytail: no search inside the sheet, add one when a long worker list makes this slow.
Future<T?> chooseOne<T>(BuildContext context, String title, List<({T value, String label})> options) async {
  if (options.isEmpty) {
    showFormError(context, AppLocalizations.of(context).needSetupFirst);
    return null;
  }
  if (options.length == 1) return options.single.value;
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: sectionTitleStyle),
          ),
          for (final option in options) ...[
            const Divider(),
            ListTile(
              title: Text(option.label),
              onTap: () => Navigator.of(sheet).pop(option.value),
            ),
          ],
        ],
      ),
    ),
  );
}
