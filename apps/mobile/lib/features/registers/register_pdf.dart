import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../documents/document_frame.dart';
import 'register_model.dart';

const _sliceRows = 300;

/// Room for a title, the headings and a row or two.
const _keepWithTable = 70.0;

/// A register on A4 landscape: the company and filters on every page, its sums first, headings repeating over the rows,
/// a line per date with its totals, and page X of Y. With [sections], each name gets its own table under its own heading,
/// and its name stays in the table's heading on every page it runs to. The text stays real text, not a picture (DOC-03, DOC-08).
/// ponytail: Roboto has Latin letters only, so a name typed in Urdu script prints as boxes. Bundle an Arabic-script font if owners type names that way.
Future<Uint8List> registerPdf({
  required DocumentIdentity identity,
  required DocumentMeta meta,
  required List<RegisterColumn> columns,
  required List<RegisterEntry> entries,
  required String totalLabel,
  required Uint8List regularFont,
  required Uint8List boldFont,
  String? note,
  List<RegisterRollup> rollups = const [],
  Map<String, String> groupHeads = const {},
  Map<String, String> groupFeet = const {},
  bool sections = false,
}) async {
  final brand = PdfColor.fromInt(identity.brandArgb);
  final band = PdfColor.fromInt(identity.softArgb);
  final pageWidth = PdfPageFormat.a4.landscape.width - 56;

  List<int> kept(List<RegisterColumn> cols) => [
    for (var i = 0; i < cols.length; i++)
      if (cols[i].inPdf) i,
  ];

  pw.Alignment alignOf(RegisterColumn c) => switch (c.kind) {
    CellKind.money || CellKind.minutes || CellKind.number => pw.Alignment.topRight,
    CellKind.date || CellKind.month => pw.Alignment.topCenter,
    CellKind.text => pw.Alignment.topLeft,
  };

  pw.Widget cell(String text, pw.Alignment align, {bool bold = false, double size = 7.5}) => docCell(text, align: align, bold: bold, size: size, vertical: 2.5);

  /// [name] goes in the first column's heading. A table has no cell spanning columns and clips each cell, so this is
  /// how a long account still says whose it is on its later pages. A column of dates names itself, so the name replaces it.
  pw.TableRow headings(List<RegisterColumn> cols, {String? name}) {
    final shown = kept(cols);
    String first(RegisterColumn c) => name == null ? c.label : (c.kind == CellKind.date ? name : '$name: ${c.label}');
    return pw.TableRow(
      repeat: true,
      decoration: docHeadDecoration,
      verticalAlignment: pw.TableCellVerticalAlignment.bottom,
      children: [for (final i in shown) cell(i == shown.first ? first(cols[i]) : cols[i].label, alignOf(cols[i]), bold: true, size: 7)],
    );
  }

  pw.TableRow line(List<RegisterColumn> cols, RegisterEntry entry, int index) => pw.TableRow(
    // A dash for zero, so the figures that matter stand out on a wide page. A running balance of zero is a real figure.
    children: [for (final i in kept(cols)) cell(entry.cells[i] == 0 && !cols[i].closing ? '-' : cellText(cols[i], entry.cells[i]), alignOf(cols[i]))],
  );

  /// A line of totals: its label sits in the first column, and the totals under their own columns.
  pw.TableRow totals(List<RegisterColumn> cols, String label, Iterable<RegisterEntry> rows, {PdfColor? fill}) {
    final shown = kept(cols);
    return pw.TableRow(
      decoration: fill == null ? docTotalDecoration : pw.BoxDecoration(color: fill),
      children: [
        for (final i in shown)
          i == shown.first
              ? cell(label, pw.Alignment.topLeft, bold: true)
              : cols[i].total || cols[i].closing
              ? cell(cellText(cols[i], columnFigure(cols, rows, i)), pw.Alignment.topRight, bold: true)
              : cell('', pw.Alignment.topLeft),
      ],
    );
  }

  pw.Widget oneTable(List<RegisterColumn> cols, List<pw.TableRow> rows) {
    final shown = kept(cols);
    return pw.Table(
      border: docTableBorder,
      columnWidths: {for (var c = 0; c < shown.length; c++) c: pw.FlexColumnWidth(cols[shown[c]].flex.toDouble())},
      children: rows,
    );
  }

  /// A table walks all its rows again for every page it fills, so its time grows with the square of its length, and a
  /// thousand workers' month would take hours. Slices keep it in step with the rows. Up to [_sliceRows] nothing looks
  /// different, and past that the headings show once more, which they do on every page anyway.
  List<pw.Widget> tables(List<RegisterColumn> cols, List<pw.TableRow> rows, {String? name}) => [
    for (var start = 0; start < rows.length; start += _sliceRows)
      oneTable(cols, [headings(cols, name: name), ...rows.sublist(start, (start + _sliceRows).clamp(0, rows.length))]),
  ];

  List<pw.Widget> rollup(RegisterRollup r) => [
    // So a title never sits alone at the foot of a page with its table on the next.
    pw.NewPage(freeSpace: _keepWithTable),
    pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(r.title, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: brand)),
    ),
    ...tables(r.columns, [
      for (var i = 0; i < r.rows.length; i++) line(r.columns, r.rows[i], i),
      totals(r.columns, r.totalLabel ?? totalLabel, r.rows),
    ]),
    pw.SizedBox(height: 12),
  ];

  /// A name and what else is known about it, across the page.
  pw.Widget nameBand(String name, String? head) => pw.Container(
    width: pageWidth,
    color: band,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(text: name, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: brand)),
          if (head != null && head.isNotEmpty) pw.TextSpan(text: '     $head', style: const pw.TextStyle(fontSize: 8, color: docMuted)),
        ],
      ),
    ),
  );

  final rows = <pw.TableRow>[];
  var index = 0;
  if (!sections) {
    for (final group in groupEntries(entries)) {
      if (group.group.isNotEmpty) rows.add(totals(columns, cellText(columns.first, group.rows.first.cells.first), group.rows, fill: band));
      for (final entry in group.rows) {
        rows.add(line(columns, entry, index++));
      }
    }
    rows.add(totals(columns, totalLabel, entries));
  }

  final doc = pw.Document(title: meta.title, author: identity.legalName, creator: identity.legalName);
  doc.addPage(
    documentPage(
      identity: identity,
      meta: meta,
      format: PdfPageFormat.a4.landscape,
      regularFont: regularFont,
      boldFont: boldFont,
      build: (context) => [
        if (note != null) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text(note, style: const pw.TextStyle(fontSize: 8, color: docMuted))),
        for (final r in rollups.where((r) => !r.afterRows)) ...rollup(r),
        if (sections)
          for (final group in groupEntries(entries)) ...[
            pw.NewPage(freeSpace: _keepWithTable),
            nameBand(group.group, groupHeads[group.group]),
            ...tables(columns, [
              for (var i = 0; i < group.rows.length; i++) line(columns, group.rows[i], i),
              totals(columns, totalLabel, group.rows),
            ], name: group.group),
            if (groupFeet[group.group] != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(groupFeet[group.group]!, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              ),
            pw.SizedBox(height: 12),
          ]
        else
          ...tables(columns, rows),
        for (final r in rollups.where((r) => r.afterRows)) ...rollup(r),
      ],
    ),
  );
  return doc.save();
}
