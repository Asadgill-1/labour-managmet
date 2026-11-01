import 'package:domain/dates.dart';
import 'package:domain/money.dart';
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
  const Field(this.label, this.controller, {this.validator, this.keyboardType, this.helper, this.lines = 1, this.onChanged, super.key});

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final String? helper;
  final int lines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
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
/// Says a screen's date or month is closed, so nothing here can change (REP-04).
class ClosedNote extends StatelessWidget {
  const ClosedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return NoteRow(icon: Icons.lock, text: AppLocalizations.of(context).closedNote, color: muted);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ink)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(child: Text(title, style: sectionTitleStyle)),
              if (action != null) Flexible(child: action!),
            ],
          ),
        ),
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

/// The month and arrows to change it, on the coloured band.
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
        IconButton(tooltip: l10n.previousMonth, color: Colors.white, icon: const Icon(Icons.chevron_left), onPressed: () => onChanged(addMonths(month, -1))),
        Text(showMonth(month), style: sectionTitleStyle.copyWith(color: Colors.white)),
        IconButton(tooltip: l10n.nextMonth, color: Colors.white, icon: const Icon(Icons.chevron_right), onPressed: () => onChanged(addMonths(month, 1))),
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

/// One ruled line of a list, as in an account book.
class RowCard extends StatelessWidget {
  const RowCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: rule)),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// A name's first letter, for a [RowTag].
String initial(String name) => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

/// A small mark at the start of a row: a state in its own colours, or a name's first letter.
class RowTag extends StatelessWidget {
  const RowTag(String this.text, {this.fill, this.color, super.key}) : icon = null;
  const RowTag.icon(IconData this.icon, {required Color this.fill, required Color this.color, super.key}) : text = null;

  final String? text;
  final IconData? icon;
  final Color? fill;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? brand;
    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill ?? brandSoft, borderRadius: BorderRadius.circular(10)),
      child: icon != null
          ? Icon(icon, size: 20, color: foreground)
          : FittedBox(fit: BoxFit.scaleDown, child: Text(text!, style: amountStyle.copyWith(fontSize: 15, color: foreground))),
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
      title: Text(label, style: const TextStyle(fontFamily: headingFont, fontSize: 15, fontWeight: FontWeight.w400, color: muted)),
      trailing: RowValue(value),
      onTap: onTap,
    );
  }
}

/// A short line saying how things stand, in words as well as colour (UX-04).
class NoteRow extends StatelessWidget {
  const NoteRow({required this.icon, required this.text, required this.color, super.key});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w500, color: color))),
        ],
      ),
    );
  }
}

/// Something waiting on the owner, full width across the page, that opens where it can be dealt with.
class NoticeRow extends StatelessWidget {
  const NoticeRow({required this.icon, required this.title, required this.onTap, this.subtitle, super.key});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: warnSoft,
      child: ListTile(
        leading: Icon(icon, color: warn),
        title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: warn)),
        subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(color: warn)),
        trailing: const Icon(Icons.chevron_right, color: warn),
        onTap: onTap,
      ),
    );
  }
}

/// The bottom line of a sum, under a double rule as in an account book.
class TotalRow extends StatelessWidget {
  const TotalRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: sectionTitleStyle)),
              RowValue(value),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: ink)),
        const SizedBox(height: 2),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(color: ink)),
      ],
    );
  }
}

/// A double-ringed stamp, slightly off true, for a month that is done with.
class ClosedStamp extends StatelessWidget {
  const ClosedStamp(this.label, this.date, {super.key});

  final String label;
  final String date;

  @override
  Widget build(BuildContext context) {
    final color = brand;
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(10)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(7)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: amountStyle.copyWith(fontSize: 18, color: color)),
              Text(date, style: amountStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: muted),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(height: 1.4, color: muted)),
          ],
        ),
      ),
    );
  }
}

/// One figure with its label on the cover, ruled off from the next like a column in a book.
class BandFigure extends StatelessWidget {
  const BandFigure(this.value, this.label, {this.size = 28, super.key});

  final String value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.35))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, so a long amount that shrinks doesn't lift its label out of line with the others.
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(size * 1.2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: amountStyle.copyWith(fontSize: size, height: 1.15, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.2, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

/// Asks for one worker's daily wage. Null means cancelled. A null `fils` means the field was left empty.
Future<({int? fils})?> askDailyWage(BuildContext context, {required String title, required String helper, int? initial, String? label}) {
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
          label ?? l10n.dailyWage,
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
                final color = offset == 0 ? brand : Colors.white;
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
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: offset == 0 ? Colors.white : null, borderRadius: BorderRadius.circular(10)),
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
                          Text(date.substring(8), style: amountStyle.copyWith(fontSize: 18, color: color)),
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
