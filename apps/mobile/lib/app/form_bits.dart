import 'package:domain/dates.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

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
          final initial = value == null ? DateTime.now() : DateTime.parse(value!);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(ymd(picked));
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
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
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
