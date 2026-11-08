const _bom = 0xFEFF;

/// One record of a CSV file and its row number as a spreadsheet shows it, counting the heading as row 1.
typedef CsvRow = ({int row, List<String> fields});

/// Reads a CSV file the way Excel and Google Sheets save one. A quoted field may hold the separator, a line break, or a
/// quote written twice. A file saved with semicolons, as Excel does in some regions, reads too. Blank rows are dropped
/// but still counted, so a row number points at the same row in the spreadsheet (MASTER-08).
List<CsvRow> parseCsv(String text) {
  if (text.isNotEmpty && text.codeUnitAt(0) == _bom) text = text.substring(1);
  final heading = text.split('\n').first;
  final separator = ';'.allMatches(heading).length > ','.allMatches(heading).length ? ';' : ',';

  final rows = <CsvRow>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var row = 0;
  void endRecord() {
    fields.add(field.toString());
    field.clear();
    row++;
    if (fields.any((f) => f.trim().isNotEmpty)) rows.add((row: row, fields: fields));
    fields = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c != '"') {
        field.write(c);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == separator) {
      fields.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRecord();
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || fields.isNotEmpty) endRecord();
  return rows;
}

/// Rows as a CSV file Excel opens with its letters intact: UTF-8 with a byte-order mark, and CRLF line ends.
String toCsv(List<List<String>> rows) {
  String quote(String f) => f.contains(RegExp('[",\r\n]')) ? '"${f.replaceAll('"', '""')}"' : f;
  return '${String.fromCharCode(_bom)}${rows.map((r) => r.map(quote).join(',')).join('\r\n')}\r\n';
}
