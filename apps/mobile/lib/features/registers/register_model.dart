import 'package:domain/dates.dart';
import 'package:domain/money.dart';

enum CellKind { text, date, month, money, minutes, number }

/// Whether a money column is money coming in or going out, so it can be coloured and netted.
enum CellTone { none, plus, minus }

class RegisterColumn {
  const RegisterColumn(
    this.label, {
    this.kind = CellKind.text,
    this.flex = 3,
    this.total = false,
    this.closing = false,
    this.tone = CellTone.none,
    this.inPdf = true,
    this.onScreen = true,
  });

  final String label;
  final CellKind kind;

  /// This column's share of the width of a PDF page.
  final int flex;

  /// Added up on the band, under each date and at the bottom.
  final bool total;

  /// A running balance. Its figure is where each group ended, not a sum of its rows.
  final bool closing;
  final CellTone tone;

  /// A page has room for fewer columns than a sheet. Excel always has them all.
  final bool inPdf;

  /// False when the heading above the rows already says it.
  final bool onScreen;
}

class RegisterEntry {
  const RegisterEntry(this.cells, {this.group = '', this.tags = const {}});

  /// One per column: a String for text, date and month, an int for the rest, null for nothing.
  final List<Object?> cells;

  /// The date, month or name this row sits under. Empty for a register with no groups.
  final String group;

  /// What each filter can match: filter key to the IDs this row belongs to.
  final Map<String, Set<String>> tags;
}

class RegisterFilter {
  const RegisterFilter(this.key, this.label, this.options);

  final String key;
  final String label;
  final List<({String value, String label})> options;
}

/// A small table of sums, printed ahead of a register's rows.
class RegisterRollup {
  const RegisterRollup(this.title, this.columns, this.rows);

  final String title;
  final List<RegisterColumn> columns;
  final List<RegisterEntry> rows;
}

/// One register, ready to show or export. Rows come newest first, unless they group by name.
class RegisterData {
  const RegisterData({
    required this.title,
    required this.columns,
    required this.entries,
    required this.titleColumn,
    this.amountColumns = const [],
    this.bandColumns = const [],
    this.filters = const [],
    this.dated = true,
    this.groupKind = CellKind.date,
    this.note,
    this.netted = true,
    this.groupHeads = const {},
    this.groupFeet = const {},
    this.rollupsOf,
  });

  final String title;
  final List<RegisterColumn> columns;
  final List<RegisterEntry> entries;

  /// The column that names a row.
  final int titleColumn;

  /// Shown large on the row's right: the first of these with a value.
  final List<int> amountColumns;

  /// Totals shown on the coloured band.
  final List<int> bandColumns;
  final List<RegisterFilter> filters;

  /// False for a register with no dates to pick.
  final bool dated;

  /// [CellKind.date], [CellKind.month], or [CellKind.text] for one account per name, oldest row first.
  final CellKind groupKind;

  /// Printed with the register, for what its figures leave out.
  final String? note;

  /// False when its plus and minus columns are only coloured, and a difference between them would mean nothing.
  final bool netted;

  /// Printed above and below a named group's rows.
  final Map<String, String> groupHeads;
  final Map<String, String> groupFeet;

  /// The sums for the rows on show, so they follow the filters.
  final List<RegisterRollup> Function(List<RegisterEntry> shown)? rollupsOf;

  bool get groupsByName => groupKind == CellKind.text;
}

/// 110050 -> "1,100.50". A table says AED once in its heading.
String plainMoney(int fils) => formatAed(fils).replaceFirst('AED ', '');

String cellText(RegisterColumn column, Object? value) {
  if (value == null) return '';
  return switch (column.kind) {
    CellKind.text => value as String,
    CellKind.date => showDate(value as String),
    CellKind.month => showMonth(value as String),
    CellKind.money => plainMoney(value as int),
    CellKind.minutes => showDuration(value as int),
    CellKind.number => '$value',
  };
}

/// Rows matching every filter that has something chosen. Within one filter, any chosen value matches.
List<RegisterEntry> filterEntries(List<RegisterEntry> entries, Map<String, Set<String>> chosen) {
  final active = chosen.entries.where((f) => f.value.isNotEmpty).toList();
  if (active.isEmpty) return entries;
  return entries.where((e) => active.every((f) => (e.tags[f.key] ?? const {}).any(f.value.contains))).toList();
}

int columnTotal(Iterable<RegisterEntry> entries, int column) => entries.fold(0, (total, e) => total + ((e.cells[column] as int?) ?? 0));

/// What a total line shows: the sum, or for a running balance, where each group ended.
int columnFigure(List<RegisterColumn> columns, Iterable<RegisterEntry> entries, int column) {
  if (!columns[column].closing) return columnTotal(entries, column);
  final last = <String, int>{};
  for (final entry in entries) {
    final value = entry.cells[column] as int?;
    if (value != null) last[entry.group] = value;
  }
  return last.values.fold(0, (total, value) => total + value);
}

/// Plus columns less minus columns, or null when a register has no such pair.
int? registerDifference(RegisterData data, Iterable<RegisterEntry> entries) {
  if (!data.netted) return null;
  var plus = false;
  var minus = false;
  var net = 0;
  for (var i = 0; i < data.columns.length; i++) {
    final tone = data.columns[i].tone;
    if (tone == CellTone.plus) {
      plus = true;
      net += columnTotal(entries, i);
    } else if (tone == CellTone.minus) {
      minus = true;
      net -= columnTotal(entries, i);
    }
  }
  return plus && minus ? net : null;
}

/// For a file: oldest date first, like a paper register, with each date's rows in the same order as on screen.
List<RegisterEntry> oldestFirst(List<RegisterEntry> newestFirst) => groupEntries(newestFirst).reversed.expand((g) => g.rows).toList();

/// Consecutive rows under the same date or month. Rows arrive sorted, so one pass is enough.
List<({String group, List<RegisterEntry> rows})> groupEntries(Iterable<RegisterEntry> entries) {
  final groups = <({String group, List<RegisterEntry> rows})>[];
  for (final entry in entries) {
    if (groups.isEmpty || groups.last.group != entry.group) groups.add((group: entry.group, rows: []));
    groups.last.rows.add(entry);
  }
  return groups;
}
