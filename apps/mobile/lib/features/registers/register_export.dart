import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'register_model.dart';
import 'register_pdf.dart';
import 'register_xlsx.dart';

enum ExportFormat { pdf, excel }

enum ExportAction { view, save, whatsapp, other }

const _channel = MethodChannel('labour_app/files');

String _mime(ExportFormat format) => format == ExportFormat.pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// What a file carries besides its rows. Plain strings, so it can cross to a background isolate.
class ExportText {
  const ExportText({
    required this.company,
    required this.companyLine,
    required this.title,
    required this.filterLine,
    required this.totalLabel,
    required this.madeLabel,
    required this.pagePattern,
    this.footer,
    this.note,
  });

  final String company;
  final String companyLine;
  final String title;
  final String filterLine;
  final String totalLabel;
  final String madeLabel;

  /// Holds {page} and {pages}.
  final String pagePattern;
  final String? footer;
  final String? note;
}

/// A file name every app accepts: "Hazri-register_2026-10-01_2026-10-31.pdf".
String exportFileName(String title, String? from, String? to, ExportFormat format) {
  final name = [title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-'), ?from, ?to].join('_');
  return '$name.${format == ExportFormat.pdf ? 'pdf' : 'xlsx'}';
}

/// Makes the file on a background isolate, so a long register doesn't freeze the screen. 
Future<Uint8List> makeExportBytes(ExportFormat format, ExportText text, List<RegisterColumn> columns, List<RegisterEntry> newestFirst, {required int brandArgb}) async {
  final entries = oldestFirst(newestFirst);
  if (format == ExportFormat.excel) {
    final brandHex = (brandArgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return Isolate.run(
      () => registerXlsx(company: text.company, title: text.title, filterLine: text.filterLine, columns: columns, entries: entries, totalLabel: text.totalLabel, brandHex: brandHex, note: text.note),
    );
  }
  final regular = (await rootBundle.load('assets/fonts/Roboto-Regular.ttf')).buffer.asUint8List();
  final bold = (await rootBundle.load('assets/fonts/Roboto-Bold.ttf')).buffer.asUint8List();
  return Isolate.run(
    () => registerPdf(
      company: text.company,
      companyLine: text.companyLine,
      title: text.title,
      filterLine: text.filterLine,
      columns: columns,
      entries: entries,
      totalLabel: text.totalLabel,
      pageLabel: (page, pages) => text.pagePattern.replaceAll('{page}', '$page').replaceAll('{pages}', '$pages'),
      madeLabel: text.madeLabel,
      footer: text.footer,
      note: text.note,
      brandArgb: brandArgb,
      regularFont: regular,
      boldFont: bold,
    ),
  );
}

/// Share files stay in the cache and are gone after a day (DOC-07).
Future<File> writeExportFile(String name, Uint8List bytes) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/exports');
  await dir.create(recursive: true);
  final dayAgo = DateTime.now().subtract(const Duration(days: 1));
  await for (final old in dir.list()) {
    if (old is File && (await old.lastModified()).isBefore(dayAgo)) await old.delete();
  }
  return File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
}

/// What the owner should be told once the action has run. Opening WhatsApp or the share sheet says nothing about delivery (DOC-07).
enum ExportResult { done, saved, cancelled, noWhatsApp, noApp }

Future<ExportResult> runExport(ExportAction action, ExportFormat format, File file, Uint8List bytes) async {
  final path = {'path': file.path, 'mime': _mime(format)};
  switch (action) {
    case ExportAction.view when format == ExportFormat.pdf:
      await Printing.layoutPdf(name: file.uri.pathSegments.last, onLayout: (_) async => bytes);
      return ExportResult.done;
    case ExportAction.view:
      return await _channel.invokeMethod<bool>('open', path) == true ? ExportResult.done : ExportResult.noApp;
    case ExportAction.save:
      return await _channel.invokeMethod<bool>('save', path) == true ? ExportResult.saved : ExportResult.cancelled;
    case ExportAction.whatsapp:
      return await _channel.invokeMethod<bool>('send', {...path, 'whatsapp': true}) == true ? ExportResult.done : ExportResult.noWhatsApp;
    case ExportAction.other:
      await _channel.invokeMethod<bool>('send', {...path, 'whatsapp': false});
      return ExportResult.done;
  }
}
