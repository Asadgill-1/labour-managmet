import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'register_model.dart';

// Style numbers in the workbook's style sheet below.
const _title = 1;
const _subtitle = 2;
const _small = 3;
const _head = 4;
const _text = 5;
const _date = 6;
const _money = 7;
const _minutes = 8;
const _number = 9;
const _totalText = 10;
const _totalMoney = 11;
const _totalMinutes = 12;
const _totalNumber = 13;

/// Rows above the column headings: company, register, filters, then a gap.
const _headRow = 5;

String _escape(String text) => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _letter(int column) {
  var text = '';
  for (var n = column + 1; n > 0; n = (n - 1) ~/ 26) {
    text = String.fromCharCode(65 + (n - 1) % 26) + text;
  }
  return text;
}

String _textCell(String ref, String text, int style) => '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_escape(text)}</t></is></c>';

/// Written from whole fils, so no floating point number ever touches an amount (CALC-01).
String _decimal(int fils) => '${fils < 0 ? '-' : ''}${fils.abs() ~/ 100}.${(fils.abs() % 100).toString().padLeft(2, '0')}';

/// Days since Excel's day zero, so the sheet holds a real date it can sort and filter.
int _serial(String date) {
  final parts = date.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]).difference(DateTime.utc(1899, 12, 30)).inDays;
}

/// Excel time is a fraction of a day. Hours are not money, so a decimal is fine here.
String _duration(int minutes) => '${minutes / 1440}';

String _cell(String ref, RegisterColumn column, Object? value) {
  if (value == null) return '<c r="$ref" s="$_text"/>';
  return switch (column.kind) {
    CellKind.text || CellKind.month => _textCell(ref, cellText(column, value), _text),
    CellKind.date => '<c r="$ref" s="$_date"><v>${_serial(value as String)}</v></c>',
    CellKind.money => '<c r="$ref" s="$_money"><v>${_decimal(value as int)}</v></c>',
    CellKind.minutes => '<c r="$ref" s="$_minutes"><v>${_duration(value as int)}</v></c>',
    CellKind.number => '<c r="$ref" s="$_number"><v>$value</v></c>',
  };
}

/// A total that follows the sheet's filter, with its value already worked out for readers that don't calculate.
String _totalCell(String ref, RegisterColumn column, int total, String range) {
  final (style, value) = switch (column.kind) {
    CellKind.money => (_totalMoney, _decimal(total)),
    CellKind.minutes => (_totalMinutes, _duration(total)),
    _ => (_totalNumber, '$total'),
  };
  return '<c r="$ref" s="$style"><f>SUBTOTAL(109,$range)</f><v>$value</v></c>';
}

/// The sums on a sheet of their own, one small table under another.
String _rollupSheetXml(List<RegisterRollup> rollups, String totalLabel) {
  final rows = StringBuffer();
  final longest = <int, int>{};
  var at = 1;
  for (final rollup in rollups) {
    final columns = rollup.columns;
    rows.write('<row r="$at" ht="20" customHeight="1">${_textCell('A$at', rollup.title, _subtitle)}</row>');
    at++;
    rows.write('<row r="$at" ht="32" customHeight="1">');
    for (var c = 0; c < columns.length; c++) {
      rows.write(_textCell('${_letter(c)}$at', columns[c].label, _head));
      longest[c] = _longer(longest[c], columns[c].label.length ~/ 2 + 4);
    }
    rows.write('</row>');
    at++;
    final first = at;
    for (final entry in rollup.rows) {
      rows.write('<row r="$at">');
      for (var c = 0; c < columns.length; c++) {
        rows.write(_cell('${_letter(c)}$at', columns[c], entry.cells[c]));
        longest[c] = _longer(longest[c], cellText(columns[c], entry.cells[c]).length);
      }
      rows.write('</row>');
      at++;
    }
    rows.write('<row r="$at" ht="20" customHeight="1">');
    for (var c = 0; c < columns.length; c++) {
      final ref = '${_letter(c)}$at';
      if (columns[c].total && rollup.rows.isNotEmpty) {
        rows.write(_totalCell(ref, columns[c], columnTotal(rollup.rows, c), '${_letter(c)}$first:${_letter(c)}${at - 1}'));
      } else {
        rows.write(_textCell(ref, c == 0 ? totalLabel : '', _totalText));
      }
    }
    rows.write('</row>');
    at += 2;
  }
  final widths = StringBuffer();
  for (final MapEntry(key: c, value: width) in (longest.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) {
    widths.write('<col min="${c + 1}" max="${c + 1}" width="${(width + 2).clamp(9, 42)}" customWidth="1"/>');
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>'
      '<sheetViews><sheetView showGridLines="0" workbookViewId="0"/></sheetViews>'
      '<sheetFormatPr defaultRowHeight="16"/>'
      '<cols>$widths</cols>'
      '<sheetData>$rows</sheetData>'
      '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.6" header="0.3" footer="0.3"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>'
      '</worksheet>';
}

int _longer(int? a, int b) => a == null || b > a ? b : a;

/// A sheet's name cannot hold these characters or run past 31 letters.
String _sheetName(String title) {
  final clean = title.replaceAll(RegExp(r"[\[\]:*?/\\']"), ' ').trim();
  return clean.length <= 31 ? clean : clean.substring(0, 31);
}

/// A real XLSX: dates, amounts and hours are values, headings stay on screen, every column can be filtered,
/// totals follow the filter, and it prints landscape on A4 with the headings on every page (D-038).
Uint8List registerXlsx({
  required String company,
  required String title,
  required String filterLine,
  required List<RegisterColumn> columns,
  required List<RegisterEntry> entries,
  required String totalLabel,
  required String brandHex,
  String? note,
  List<RegisterRollup> rollups = const [],
  String rollupSheet = '',
}) {
  final lastColumn = _letter(columns.length - 1);
  final firstData = _headRow + 1;
  final lastData = _headRow + entries.length;
  final totalRow = lastData + 1;
  final sheet = _sheetName(title);

  final rows = StringBuffer()
    ..write('<row r="1" ht="24" customHeight="1">${_textCell('A1', company, _title)}</row>')
    ..write('<row r="2" ht="20" customHeight="1">${_textCell('A2', title, _subtitle)}</row>')
    ..write('<row r="3">${_textCell('A3', filterLine, _small)}</row>');
  if (note != null) rows.write('<row r="4">${_textCell('A4', note, _small)}</row>');
  rows.write('<row r="$_headRow" ht="32" customHeight="1">');
  for (var c = 0; c < columns.length; c++) {
    rows.write(_textCell('${_letter(c)}$_headRow', columns[c].label, _head));
  }
  rows.write('</row>');
  for (var r = 0; r < entries.length; r++) {
    final row = firstData + r;
    rows.write('<row r="$row">');
    for (var c = 0; c < columns.length; c++) {
      rows.write(_cell('${_letter(c)}$row', columns[c], entries[r].cells[c]));
    }
    rows.write('</row>');
  }
  rows.write('<row r="$totalRow" ht="20" customHeight="1">');
  for (var c = 0; c < columns.length; c++) {
    final ref = '${_letter(c)}$totalRow';
    if (columns[c].closing && entries.isNotEmpty) {
      // Where each worker ended is not a sum of the rows above, so no formula would be right.
      rows.write('<c r="$ref" s="$_totalMoney"><v>${_decimal(columnFigure(columns, entries, c))}</v></c>');
    } else if (columns[c].total && entries.isNotEmpty) {
      rows.write(_totalCell(ref, columns[c], columnTotal(entries, c), '${_letter(c)}$firstData:${_letter(c)}$lastData'));
    } else {
      rows.write(_textCell(ref, c == 0 ? totalLabel : '', _totalText));
    }
  }
  rows.write('</row>');

  final widths = StringBuffer();
  for (var c = 0; c < columns.length; c++) {
    var longest = columns[c].label.length ~/ 2 + 4;
    for (final e in entries) {
      final length = cellText(columns[c], e.cells[c]).length;
      if (length > longest) longest = length;
    }
    final width = (longest + 2).clamp(9, 42);
    widths.write('<col min="${c + 1}" max="${c + 1}" width="$width" customWidth="1"/>');
  }

  final sheetXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>'
      '<dimension ref="A1:$lastColumn$totalRow"/>'
      '<sheetViews><sheetView showGridLines="0" workbookViewId="0">'
      '<pane ySplit="$_headRow" topLeftCell="A$firstData" activePane="bottomLeft" state="frozen"/>'
      '<selection pane="bottomLeft" activeCell="A$firstData" sqref="A$firstData"/>'
      '</sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="16"/>'
      '<cols>$widths</cols>'
      '<sheetData>$rows</sheetData>'
      '<autoFilter ref="A$_headRow:$lastColumn$lastData"/>'
      '<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.6" header="0.3" footer="0.3"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>'
      '<headerFooter><oddFooter>&amp;C&amp;P / &amp;N</oddFooter></headerFooter>'
      '</worksheet>';

  final quoted = "'${sheet.replaceAll("'", "''")}'";
  final workbookXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="${_escape(sheet)}" sheetId="1" r:id="rId1"/>'
      '${rollups.isEmpty ? '' : '<sheet name="${_escape(_sheetName(rollupSheet))}" sheetId="2" r:id="rId3"/>'}'
      '</sheets>'
      '<definedNames>'
      '<definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">${_escape(quoted)}!\$A\$$_headRow:\$$lastColumn\$$lastData</definedName>'
      '<definedName name="_xlnm.Print_Titles" localSheetId="0">${_escape(quoted)}!\$$_headRow:\$$_headRow</definedName>'
      '</definedNames>'
      '<calcPr fullCalcOnLoad="1"/>'
      '</workbook>';

  final brand = 'FF$brandHex';
  const line = '<left style="thin"><color rgb="FFD5DAE3"/></left><right style="thin"><color rgb="FFD5DAE3"/></right><top style="thin"><color rgb="FFD5DAE3"/></top><bottom style="thin"><color rgb="FFD5DAE3"/></bottom><diagonal/>';
  final stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd\\-mm\\-yyyy"/><numFmt numFmtId="165" formatCode="[h]:mm"/></numFmts>'
      '<fonts count="6">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="16"/><color rgb="$brand"/><name val="Calibri"/></font>'
      '<font><b/><sz val="13"/><name val="Calibri"/></font>'
      '<font><sz val="10"/><color rgb="FF5B667A"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="4">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="$brand"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFEEF1F6"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border>$line</border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="14">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="4" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="top"/></xf>'
      '<xf numFmtId="4" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>'
      '<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment vertical="top"/></xf>'
      '<xf numFmtId="0" fontId="5" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="4" fontId="5" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="165" fontId="5" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf numFmtId="1" fontId="5" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';

  final archive = Archive();
  void add(String path, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '${rollups.isEmpty ? '' : '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'}'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '${rollups.isEmpty ? '' : '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'}'
        '</Relationships>',
  );
  add('xl/workbook.xml', workbookXml);
  add('xl/styles.xml', stylesXml);
  add('xl/worksheets/sheet1.xml', sheetXml);
  if (rollups.isNotEmpty) add('xl/worksheets/sheet2.xml', _rollupSheetXml(rollups, totalLabel));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
