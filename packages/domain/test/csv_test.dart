import 'package:domain/csv.dart';
import 'package:domain/dates.dart';
import 'package:test/test.dart';

/// Records holding lists compare by identity, so each row is flattened first.
List<(int, String)> flat(List<CsvRow> rows) => [for (final r in rows) (r.row, r.fields.join('|'))];

final bom = String.fromCharCode(0xFEFF);

void main() {
  test('reads quoted commas, doubled quotes and line breaks, and counts rows as the spreadsheet does (MASTER-08)', () {
    final text = '${bom}Code,Name,Note\r\nW001,"Khan, Asif","He said ""ok"""\r\n\r\nW002,Imran,"two\nlines"\r\n';
    expect(flat(parseCsv(text)), [(1, 'Code|Name|Note'), (2, 'W001|Khan, Asif|He said "ok"'), (4, 'W002|Imran|two\nlines')]);
  });

  test('a semicolon file and a last row with no line end both read', () {
    expect(flat(parseCsv('Code;Name\nW001;Asif')), [(1, 'Code|Name'), (2, 'W001|Asif')]);
  });

  test('a quote that never closes is refused, naming the row it opened on, instead of swallowing the rest (BUG-011)', () {
    Matcher opensOn(int row) => throwsA(isA<UnclosedQuote>().having((e) => e.row, 'row', row));
    expect(() => parseCsv('Code,Name\nW1,"Ali\nW2,Bilal\nW3,Omar'), opensOn(2));
    expect(() => parseCsv('Code,Note\r\nW1,"two\r\nlines"\r\n\r\nW2,"open\r\nW3,x\r\n'), opensOn(4), reason: 'rows count as the spreadsheet does');
  });

  test('what it writes reads back the same', () {
    final rows = [
      ['Code', 'Name'],
      ['W001', 'Khan, "Asif"'],
    ];
    final text = toCsv(rows);
    expect(text, startsWith(bom));
    expect([for (final r in parseCsv(text)) r.fields], rows);
  });

  test('typed dates read day first, and nothing that is not a real date', () {
    expect(parseDate('5/1/2026'), '2026-01-05');
    expect(parseDate('05-01-2026'), '2026-01-05');
    expect(parseDate('2026-01-05'), '2026-01-05');
    expect(parseDate('31/02/2026'), isNull);
    expect(parseDate('1/13/2026'), isNull, reason: 'month first is not read as a guess');
    expect(parseDate('Jan 5'), isNull);
  });

  test('typed times read as minutes from midnight', () {
    expect(parseClock('8:30'), 510);
    expect(parseClock('20:05'), 1205);
    expect(parseClock('24:00'), isNull);
    expect(parseClock('8.30'), isNull);
  });
}
