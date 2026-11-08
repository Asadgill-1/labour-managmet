import 'package:domain/calc.dart';
import 'package:domain/csv.dart';
import 'package:domain/dates.dart';
import 'package:domain/money.dart';
import 'package:domain/validation.dart';
import 'package:drift/drift.dart';

import 'masters.dart';
import 'tenant_database.dart';

/// What one file brings in. Only these: anything already posted, invoiced or paid can't be reached (MASTER-08, D-053).
enum ImportKind { workers, companies, sites }

/// A column the file may carry, with the heading the blank file uses and other headings that mean the same.
enum ImportField {
  code('Code', ['workercode', 'mazdoorcode']),
  name('Name', ['workername', 'companyname', 'naam']),
  trade('Trade', ['kaam']),
  phone('Phone', ['mobile', 'whatsapp']),
  joiningDate('Joining date', ['joined', 'joining']),
  payBasis('Pay basis', ['basis']),
  payRate('Pay rate', ['rate', 'wage']),
  rateFrom('Rate from', ['effectivefrom']),
  address('Address', []),
  contactPerson('Contact person', ['contact']),
  email('Email', []),
  vatRegistered('VAT registered', ['vat']),
  trn('TRN', []),
  dueDays('Due days', ['paymentdays']),
  poReference('PO reference', ['po']),
  note('Note', ['notes']),
  company('Company', ['client', 'companyname']),
  site('Site', ['sitename', 'project']),
  location('Location', []),
  siteContact('Contact', ['contactperson']),
  start('Start', ['starttime']),
  end('End', ['endtime']),
  breakMinutes('Break minutes', ['break']);

  const ImportField(this.heading, this.also);

  final String heading;
  final List<String> also;
}

/// Each kind's columns in the blank file's order, and whether a line needs it.
const importFields = <ImportKind, List<(ImportField, bool)>>{
  ImportKind.workers: [
    (ImportField.code, true),
    (ImportField.name, true),
    (ImportField.trade, false),
    (ImportField.phone, false),
    (ImportField.joiningDate, false),
    (ImportField.payBasis, false),
    (ImportField.payRate, false),
    (ImportField.rateFrom, false),
  ],
  ImportKind.companies: [
    (ImportField.name, true),
    (ImportField.address, false),
    (ImportField.contactPerson, false),
    (ImportField.phone, false),
    (ImportField.email, false),
    (ImportField.vatRegistered, false),
    (ImportField.trn, false),
    (ImportField.dueDays, false),
    (ImportField.poReference, false),
    (ImportField.note, false),
  ],
  ImportKind.sites: [
    (ImportField.company, true),
    (ImportField.site, true),
    (ImportField.location, false),
    (ImportField.siteContact, false),
    (ImportField.start, false),
    (ImportField.end, false),
    (ImportField.breakMinutes, false),
  ],
};

/// The blank file: headings only, so no example row gets saved by mistake.
String importTemplate(ImportKind kind) => toCsv([
  [for (final (field, _) in importFields[kind]!) field.heading],
]);

enum ImportProblem {
  missing,
  repeated,
  exists,
  badDate,
  badAmount,
  badNumber,
  badTime,
  badYesNo,
  badTrn,
  badBasis,
  monthlyBasis,
  rateAndBasis,
  rateNeedsDate,
  noCompany,
  twoCompanies,

  /// Warnings, which don't stop the import.
  sameName,
  trnWithoutVat;

  bool get warning => this == sameName || this == trnWithoutVat;
}

typedef ImportIssue = ({ImportProblem problem, ImportField field});

/// One line of the file as it will be saved, or why it can't be.
class ImportLine {
  ImportLine(this.row, this.title, this.issues, this._save, {this.read = const [], this.rate});

  /// The spreadsheet's row number, counting the heading as 1.
  final int row;
  final String title;
  final List<ImportIssue> issues;

  /// The other cells as they will be saved, dates and times already read, so the preview shows what the app understood.
  final List<String> read;

  /// A worker's pay rate as it will be saved.
  final ({RateBasis basis, int fils})? rate;
  final Future<void> Function(TenantDatabase db) _save;

  bool get ok => issues.every((i) => i.problem.warning);
}

class ImportPlan {
  const ImportPlan(this.kind, this.lines, {this.missingColumns = const [], this.ignoredColumns = const []});

  final ImportKind kind;
  final List<ImportLine> lines;
  final List<ImportField> missingColumns;

  /// Headings nothing reads, so the owner sees a misspelt one.
  final List<String> ignoredColumns;

  /// Every line is right, or nothing is saved (MASTER-08).
  bool get ready => missingColumns.isEmpty && lines.isNotEmpty && lines.every((l) => l.ok);
}

String _key(String heading) => heading.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
String _same(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const _yes = {'yes', 'y', 'true', '1', 'haan', 'han', 'ji'};
const _no = {'no', 'n', 'false', '0', 'nahin', 'nahi', ''};

/// "hour", "daily", "din" and the like. Monthly pay needs a part-month rule nobody may default (D-102), so it is set in the app.
RateBasis? _basis(String text) => switch (_key(text)) {
  'hour' || 'hourly' || 'hours' || 'ghanta' => RateBasis.hour,
  'day' || 'daily' || 'days' || 'din' || 'dihari' => RateBasis.day,
  'shift' || 'shifts' => RateBasis.shift,
  'month' || 'monthly' || 'mahana' || 'salary' => RateBasis.month,
  _ => null,
};

extension ImportOps on TenantDatabase {
  /// Reads the file against what the app already holds and says, line by line, what would be saved. Writes nothing.
  Future<ImportPlan> planImport(ImportKind kind, String text) async {
    final rows = parseCsv(text);
    if (rows.isEmpty) return ImportPlan(kind, const []);
    final fields = importFields[kind]!;
    final columns = <ImportField, int>{};
    final ignored = <String>[];
    for (final (i, heading) in rows.first.fields.indexed) {
      final key = _key(heading);
      final match = fields.where((f) => _key(f.$1.heading) == key || f.$1.also.contains(key)).firstOrNull;
      if (match != null && !columns.containsKey(match.$1)) {
        columns[match.$1] = i;
      } else if (key.isNotEmpty) {
        ignored.add(heading.trim());
      }
    }
    final missing = [for (final (f, required) in fields) if (required && !columns.containsKey(f)) f];
    if (missing.isNotEmpty) return ImportPlan(kind, const [], missingColumns: missing, ignoredColumns: ignored);

    final lines = switch (kind) {
      ImportKind.workers => await _workerLines(rows.skip(1), columns),
      ImportKind.companies => await _companyLines(rows.skip(1), columns),
      ImportKind.sites => await _siteLines(rows.skip(1), columns),
    };
    return ImportPlan(kind, lines, ignoredColumns: ignored);
  }

  /// Saves every line in one transaction: if any fails, none is kept (MASTER-08).
  Future<int> applyImport(ImportPlan plan) async {
    if (!plan.ready) throw StateError('the file has lines that cannot be saved');
    await transaction(() async {
      for (final line in plan.lines) {
        await line._save(this);
      }
    });
    return plan.lines.length;
  }

  Future<List<ImportLine>> _workerLines(Iterable<CsvRow> rows, Map<ImportField, int> columns) async {
    final existing = await select(workers).get();
    final codes = {for (final w in existing) _same(w.code)};
    final names = {for (final w in existing) _same(w.name)};
    final seenCodes = <String>{};
    final seenNames = <String>{};
    return [
      for (final r in rows)
        () {
          final cell = _Cells(r, columns);
          final code = cell.text(ImportField.code, required: true);
          final name = cell.text(ImportField.name, required: true);
          if (code != null && (codes.contains(_same(code)))) cell.problem(ImportProblem.exists, ImportField.code);
          if (code != null && !seenCodes.add(_same(code))) cell.problem(ImportProblem.repeated, ImportField.code);
          if (name != null && (names.contains(_same(name)) || !seenNames.add(_same(name)))) cell.problem(ImportProblem.sameName, ImportField.name);
          final trade = cell.text(ImportField.trade);
          final phone = cell.text(ImportField.phone);
          final joined = cell.date(ImportField.joiningDate);
          // Read raw: the preview shows the rate itself, not the word typed for its basis.
          final basisText = cell.raw(ImportField.payBasis).isEmpty ? null : cell.raw(ImportField.payBasis);
          final basis = basisText == null ? null : _basis(basisText);
          if (basisText != null && basis == null) cell.problem(ImportProblem.badBasis, ImportField.payBasis);
          if (basis == RateBasis.month) cell.problem(ImportProblem.monthlyBasis, ImportField.payBasis);
          final rate = cell.amount(ImportField.payRate);
          if ((basisText == null) != (cell.raw(ImportField.payRate).isEmpty)) cell.problem(ImportProblem.rateAndBasis, basisText == null ? ImportField.payBasis : ImportField.payRate);
          final from = cell.date(ImportField.rateFrom) ?? joined;
          if (basisText != null && from == null && cell.raw(ImportField.rateFrom).isEmpty) cell.problem(ImportProblem.rateNeedsDate, ImportField.rateFrom);
          return ImportLine(r.row, [?code, ?name].join('  '), cell.issues, read: cell.read, rate: basis == null || rate == null ? null : (basis: basis, fils: rate), (db) async {
            final id = await db.saveRow(
              db.workers,
              id: null,
              operationId: newUuid(),
              fields: WorkersCompanion(
                code: Value(code!),
                name: Value(name!),
                trade: Value(trade),
                phone: Value(phone),
                joiningDate: Value(joined),
              ),
            );
            if (basis == null) return;
            await db.saveRow(
              db.payContracts,
              id: null,
              operationId: newUuid(),
              fields: PayContractsCompanion(workerId: Value(id), basis: Value(basis.name), rateFils: Value(rate!), effectiveFrom: Value(from!)),
            );
          });
        }(),
    ];
  }

  Future<List<ImportLine>> _companyLines(Iterable<CsvRow> rows, Map<ImportField, int> columns) async {
    final names = {for (final c in await select(clients).get()) _same(c.name)};
    final seen = <String>{};
    return [
      for (final r in rows)
        () {
          final cell = _Cells(r, columns);
          final name = cell.text(ImportField.name, required: true);
          if (name != null && names.contains(_same(name))) cell.problem(ImportProblem.exists, ImportField.name);
          if (name != null && !seen.add(_same(name))) cell.problem(ImportProblem.repeated, ImportField.name);
          final address = cell.text(ImportField.address);
          final contact = cell.text(ImportField.contactPerson);
          final phone = cell.text(ImportField.phone);
          final email = cell.text(ImportField.email);
          final vat = cell.yesNo(ImportField.vatRegistered);
          final trn = cell.raw(ImportField.trn).isEmpty ? null : cell.raw(ImportField.trn);
          // As on the company form: a TRN is kept only for a company registered for VAT, and then it must have one (MASTER-02).
          if (vat == true && (trn == null || !isTrnFormat(trn))) cell.problem(trn == null ? ImportProblem.missing : ImportProblem.badTrn, ImportField.trn);
          if (vat != true && trn != null) cell.problem(ImportProblem.trnWithoutVat, ImportField.trn);
          if (vat == true && trn != null) cell.read.add('TRN $trn');
          final due = cell.number(ImportField.dueDays);
          final po = cell.text(ImportField.poReference);
          final note = cell.text(ImportField.note);
          return ImportLine(r.row, name ?? '', cell.issues, read: cell.read, (db) async {
            await db.saveRow(
              db.clients,
              id: null,
              operationId: newUuid(),
              fields: ClientsCompanion(
                name: Value(name!),
                address: Value(address),
                contactPerson: Value(contact),
                phone: Value(phone),
                email: Value(email),
                vatRegistered: Value(vat == true),
                trn: Value(vat == true ? trn : null),
                dueDays: Value(due),
                poReference: Value(po),
                note: Value(note),
              ),
            );
          });
        }(),
    ];
  }

  Future<List<ImportLine>> _siteLines(Iterable<CsvRow> rows, Map<ImportField, int> columns) async {
    final companies = groupedBy(await select(clients).get(), (c) => _same(c.name));
    final taken = {for (final s in await select(sites).get()) (s.clientId, _same(s.name))};
    final seen = <(String, String)>{};
    return [
      for (final r in rows)
        () {
          final cell = _Cells(r, columns);
          final companyName = cell.text(ImportField.company, required: true);
          final name = cell.text(ImportField.site, required: true);
          final matches = companyName == null ? const <Client>[] : companies[_same(companyName)] ?? const <Client>[];
          if (companyName != null && matches.length != 1) cell.problem(matches.isEmpty ? ImportProblem.noCompany : ImportProblem.twoCompanies, ImportField.company);
          final clientId = matches.length == 1 ? matches.single.id : null;
          if (clientId != null && name != null) {
            if (taken.contains((clientId, _same(name)))) cell.problem(ImportProblem.exists, ImportField.site);
            if (!seen.add((clientId, _same(name)))) cell.problem(ImportProblem.repeated, ImportField.site);
          }
          final location = cell.text(ImportField.location);
          final contact = cell.text(ImportField.siteContact);
          final start = cell.clock(ImportField.start);
          final end = cell.clock(ImportField.end);
          if (cell.raw(ImportField.start).isEmpty != cell.raw(ImportField.end).isEmpty) {
            cell.problem(ImportProblem.missing, cell.raw(ImportField.start).isEmpty ? ImportField.start : ImportField.end);
          }
          final breakMinutes = cell.number(ImportField.breakMinutes);
          return ImportLine(r.row, [?companyName, ?name].join(', '), cell.issues, read: cell.read, (db) async {
            await db.saveRow(
              db.sites,
              id: null,
              operationId: newUuid(),
              fields: SitesCompanion(
                clientId: Value(clientId!),
                name: Value(name!),
                location: Value(location),
                contact: Value(contact),
                defaultStartMinute: Value(start),
                defaultEndMinute: Value(end),
                defaultBreakMinutes: Value(breakMinutes ?? 0),
              ),
            );
          });
        }(),
    ];
  }
}

/// Reads one line's cells and notes what is wrong with them.
class _Cells {
  _Cells(this.row, this.columns);

  final CsvRow row;
  final Map<ImportField, int> columns;
  final issues = <ImportIssue>[];

  /// Each cell read so far, as it will be saved. The ones naming the line are its title instead.
  final read = <String>[];

  void problem(ImportProblem problem, ImportField field) => issues.add((problem: problem, field: field));

  String raw(ImportField field) {
    final i = columns[field];
    return i == null || i >= row.fields.length ? '' : row.fields[i].trim();
  }

  String? text(ImportField field, {bool required = false}) {
    final value = raw(field);
    if (value.isEmpty && required) problem(ImportProblem.missing, field);
    if (value.isNotEmpty && !required) read.add(value);
    return value.isEmpty ? null : value;
  }

  String? date(ImportField field) {
    final value = raw(field);
    final date = parseDate(value);
    if (value.isNotEmpty && date == null) problem(ImportProblem.badDate, field);
    if (date != null) read.add('${field.heading} ${showDate(date)}');
    return date;
  }

  int? amount(ImportField field) {
    final value = raw(field).replaceFirst(RegExp('^aed', caseSensitive: false), '').trim();
    final fils = parseAed(value);
    if (value.isNotEmpty && fils == null) problem(ImportProblem.badAmount, field);
    return fils;
  }

  int? number(ImportField field) {
    final value = raw(field);
    final n = int.tryParse(value);
    if (value.isNotEmpty && (n == null || n < 0)) problem(ImportProblem.badNumber, field);
    if (n != null && n >= 0) read.add('${field.heading} $n');
    return n != null && n >= 0 ? n : null;
  }

  int? clock(ImportField field) {
    final value = raw(field);
    final minute = parseClock(value);
    if (value.isNotEmpty && minute == null) problem(ImportProblem.badTime, field);
    if (minute != null) read.add('${field.heading} ${showMinuteOfDay(minute)}');
    return minute;
  }

  bool? yesNo(ImportField field) {
    final value = raw(field).toLowerCase();
    if (_yes.contains(value)) {
      read.add(field.heading);
      return true;
    }
    if (_no.contains(value)) return false;
    problem(ImportProblem.badYesNo, field);
    return null;
  }
}
