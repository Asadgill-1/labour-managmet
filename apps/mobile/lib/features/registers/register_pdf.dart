import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'register_model.dart';

/// A register on A4 landscape: the company and filters on every page, headings repeating over the rows,
/// a line per date with its totals, and page X of Y. The text stays real text, not a picture (DOC-03, DOC-08).
/// ponytail: Roboto has Latin letters only, so a name typed in Urdu script prints as boxes. Bundle an Arabic-script font if owners type names that way.
Future<Uint8List> registerPdf({
  required String company,
  required String companyLine,
  required String title,
  required String filterLine,
  required List<RegisterColumn> columns,
  required List<RegisterEntry> entries,
  required String totalLabel,
  required String Function(int page, int pages) pageLabel,
  required String madeLabel,
  required int brandArgb,
  required Uint8List regularFont,
  required Uint8List boldFont,
  String? footer,
  String? note,
}) async {
  final brand = PdfColor.fromInt(brandArgb);
  const rule = PdfColor.fromInt(0xFFD5DAE3);
  const grey = PdfColor.fromInt(0xFF5B667A);
  const band = PdfColor.fromInt(0xFFE7EDFA);
  const zebra = PdfColor.fromInt(0xFFF7F8FB);
  const totalFill = PdfColor.fromInt(0xFFD9E1F2);

  final kept = [
    for (var i = 0; i < columns.length; i++)
      if (columns[i].inPdf) i,
  ];

  pw.Alignment alignOf(RegisterColumn c) => switch (c.kind) {
    CellKind.money || CellKind.minutes || CellKind.number => pw.Alignment.topRight,
    CellKind.date || CellKind.month => pw.Alignment.topCenter,
    CellKind.text => pw.Alignment.topLeft,
  };

  pw.Widget cell(String text, pw.Alignment align, {bool bold = false, PdfColor? color, double size = 7.5}) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
      child: pw.Text(
        text,
        textAlign: switch (align) {
          pw.Alignment.topRight => pw.TextAlign.right,
          pw.Alignment.topCenter || pw.Alignment.center => pw.TextAlign.center,
          _ => pw.TextAlign.left,
        },
        style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
      ),
    );
  }

  /// A line of totals: its label sits in the first column, and the totals under their own columns.
  pw.TableRow totals(String label, Iterable<RegisterEntry> rows, PdfColor fill) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: fill),
      children: [
        for (final i in kept)
          i == kept.first
              ? cell(label, pw.Alignment.topLeft, bold: true)
              : columns[i].total
              ? cell(cellText(columns[i], columnTotal(rows, i)), pw.Alignment.topRight, bold: true)
              : cell('', pw.Alignment.topLeft),
      ],
    );
  }

  final rows = <pw.TableRow>[
    pw.TableRow(
      repeat: true,
      decoration: pw.BoxDecoration(color: brand),
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [for (final i in kept) cell(columns[i].label, pw.Alignment.center, bold: true, color: PdfColors.white, size: 7)],
    ),
  ];
  var line = 0;
  for (final group in groupEntries(entries)) {
    if (group.group.isNotEmpty) rows.add(totals(cellText(columns.first, group.rows.first.cells.first), group.rows, band));
    for (final entry in group.rows) {
      rows.add(
        pw.TableRow(
          decoration: line.isOdd ? const pw.BoxDecoration(color: zebra) : null,
          // A dash for zero, so the figures that matter stand out on a wide page.
          children: [for (final i in kept) cell(entry.cells[i] == 0 ? '-' : cellText(columns[i], entry.cells[i]), alignOf(columns[i]))],
        ),
      );
      line++;
    }
  }
  rows.add(totals(totalLabel, entries, totalFill));

  final doc = pw.Document(title: title, author: company, creator: company);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
      maxPages: 5000,
      theme: pw.ThemeData.withFont(base: pw.Font.ttf(regularFont.buffer.asByteData()), bold: pw.Font.ttf(boldFont.buffer.asByteData())),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: brand, width: 1.4))),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(company, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand)),
                  if (companyLine.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(companyLine, style: const pw.TextStyle(fontSize: 8, color: grey))),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text(filterLine, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8, color: grey)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text([?footer, madeLabel].join('   '), style: const pw.TextStyle(fontSize: 7.5, color: grey))),
            pw.Text(pageLabel(context.pageNumber, context.pagesCount), style: const pw.TextStyle(fontSize: 7.5, color: grey)),
          ],
        ),
      ),
      build: (context) => [
        if (note != null) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text(note, style: const pw.TextStyle(fontSize: 8, color: grey))),
        pw.Table(
          border: const pw.TableBorder(
            left: pw.BorderSide(color: rule, width: 0.4),
            right: pw.BorderSide(color: rule, width: 0.4),
            top: pw.BorderSide(color: rule, width: 0.4),
            bottom: pw.BorderSide(color: rule, width: 0.4),
            horizontalInside: pw.BorderSide(color: rule, width: 0.4),
            verticalInside: pw.BorderSide(color: rule, width: 0.4),
          ),
          columnWidths: {for (var c = 0; c < kept.length; c++) c: pw.FlexColumnWidth(columns[kept[c]].flex.toDouble())},
          children: rows,
        ),
      ],
    ),
  );
  return doc.save();
}
