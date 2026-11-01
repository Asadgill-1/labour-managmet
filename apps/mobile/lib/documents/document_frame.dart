import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The account-book look on paper, kept in step with lib/app/theme.dart.
const docInk = PdfColor.fromInt(0xFF15201B);
const docMuted = PdfColor.fromInt(0xFF5A6259);
const docRule = PdfColor.fromInt(0xFFD3CFC2);

const _mmToPt = 72 / 25.4;

/// Uploads above this are refused, because every copy of every document carries them (DOC-04).
const maxImageBytes = 5 * 1024 * 1024;

/// Below this a printed image looks soft, so the owner is warned (DOC-04).
const lowDpi = 150;

enum ImageProblem { notPngOrJpeg, tooLarge }

class ImageFacts {
  const ImageFacts(this.mime, this.width, this.height);

  final String mime;
  final int width;
  final int height;
}

/// Reads an image's type and size from its own bytes, never from a file name (DOC-04). Null means it is not a readable PNG or JPEG.
ImageFacts? readImageFacts(Uint8List b) {
  final data = ByteData.sublistView(b);
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length > 24 && [for (var i = 0; i < 8; i++) b[i]].join() == png.join()) {
    final (width, height) = (data.getUint32(16), data.getUint32(20));
    return width > 0 && height > 0 ? ImageFacts('image/png', width, height) : null;
  }
  if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      // A start-of-frame marker holds the size. The others just say how far to skip.
      if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
        final (height, width) = (data.getUint16(i + 5), data.getUint16(i + 7));
        return width > 0 && height > 0 ? ImageFacts('image/jpeg', width, height) : null;
      }
      i += 2 + data.getUint16(i + 2);
    }
  }
  return null;
}

/// Why an upload can't be used. Null means it can.
ImageProblem? checkImage(Uint8List bytes) {
  if (bytes.length > maxImageBytes) return ImageProblem.tooLarge;
  return readImageFacts(bytes) == null ? ImageProblem.notPngOrJpeg : null;
}

/// Where and how large an image prints, and how much of each edge is trimmed.
class Placement {
  const Placement({this.scalePct = 100, this.align = 1, this.cropTop = 0, this.cropBottom = 0, this.cropLeft = 0, this.cropRight = 0});

  factory Placement.fromJson(Map<String, Object?>? json) => json == null
      ? const Placement()
      : Placement(
          scalePct: json['scale'] as int? ?? 100,
          align: json['align'] as int? ?? 1,
          cropTop: json['top'] as int? ?? 0,
          cropBottom: json['bottom'] as int? ?? 0,
          cropLeft: json['left'] as int? ?? 0,
          cropRight: json['right'] as int? ?? 0,
        );

  /// Share of the printable width.
  final int scalePct;

  /// 0 left, 1 centre, 2 right.
  final int align;

  /// Percent of the image cut from each edge.
  final int cropTop;
  final int cropBottom;
  final int cropLeft;
  final int cropRight;

  Map<String, int> toJson() => {'scale': scalePct, 'align': align, 'top': cropTop, 'bottom': cropBottom, 'left': cropLeft, 'right': cropRight};

  Placement copyWith({int? scalePct, int? align, int? cropTop, int? cropBottom, int? cropLeft, int? cropRight}) => Placement(
    scalePct: scalePct ?? this.scalePct,
    align: align ?? this.align,
    cropTop: cropTop ?? this.cropTop,
    cropBottom: cropBottom ?? this.cropBottom,
    cropLeft: cropLeft ?? this.cropLeft,
    cropRight: cropRight ?? this.cropRight,
  );
}

class DocumentImage {
  const DocumentImage({required this.assetId, required this.bytes, required this.width, required this.height, this.placement = const Placement()});

  /// Stored once and never changed, so a document can always find the image it was issued with (DOC-05).
  final String assetId;
  final Uint8List bytes;
  final int width;
  final int height;
  final Placement placement;

  /// Dots per inch at this placement on an A4 page's printable width, after trimming.
  int printDpi(double widthPt) {
    final kept = width * (100 - placement.cropLeft - placement.cropRight) / 100;
    final inches = widthPt * placement.scalePct / 100 / 72;
    return (kept / inches).round();
  }
}

/// Who a document says it comes from, as plain data so it crosses to a background isolate and is stored with what it
/// issued. Every paper shows the company on it unless the owner chose pre-printed stationery (DOC-02, DOC-03).
class DocumentIdentity {
  const DocumentIdentity({
    required this.legalName,
    this.tradingName,
    this.contactLine = '',
    this.trn,
    this.footerText,
    this.brandArgb = 0xFF0B2648,
    this.softArgb = 0xFFE0EEFF,
    this.printLetterhead = true,
    this.blankTopMm = 40,
    this.blankBottomMm = 25,
    this.logo,
    this.header,
    this.footer,
    this.signature,
    this.stamp,
  });

  /// Back from a stored snapshot, with [assets] holding its images' bytes.
  factory DocumentIdentity.fromJson(Map<String, Object?> json, Map<String, DocumentImage> assets) {
    DocumentImage? image(String key) {
      final saved = json[key] as Map<String, Object?>?;
      final found = saved == null ? null : assets[saved['id']];
      return found == null ? null : DocumentImage(assetId: found.assetId, bytes: found.bytes, width: found.width, height: found.height, placement: Placement.fromJson(saved!['place'] as Map<String, Object?>?));
    }

    return DocumentIdentity(
      legalName: json['legal'] as String,
      tradingName: json['trading'] as String?,
      contactLine: json['contact'] as String? ?? '',
      trn: json['trn'] as String?,
      footerText: json['footer'] as String?,
      brandArgb: json['brand'] as int,
      softArgb: json['soft'] as int,
      printLetterhead: json['print'] as bool,
      blankTopMm: json['blankTop'] as int,
      blankBottomMm: json['blankBottom'] as int,
      logo: image('logo'),
      header: image('header'),
      footer: image('footerImage'),
      signature: image('signature'),
      stamp: image('stamp'),
    );
  }

  final String legalName;
  final String? tradingName;
  final String contactLine;
  final String? trn;
  final String? footerText;
  final int brandArgb;
  final int softArgb;

  /// False means the paper already has its heading, so nothing of the company prints and the space stays clear (DOC-03).
  final bool printLetterhead;
  final int blankTopMm;
  final int blankBottomMm;
  final DocumentImage? logo;
  final DocumentImage? header;
  final DocumentImage? footer;
  final DocumentImage? signature;
  final DocumentImage? stamp;

  String get shownName => tradingName ?? legalName;

  Map<String, Object?> toJson() {
    Map<String, Object?>? image(DocumentImage? i) => i == null ? null : {'id': i.assetId, 'place': i.placement.toJson()};
    return {
      'legal': legalName,
      'trading': tradingName,
      'contact': contactLine,
      'trn': trn,
      'footer': footerText,
      'brand': brandArgb,
      'soft': softArgb,
      'print': printLetterhead,
      'blankTop': blankTopMm,
      'blankBottom': blankBottomMm,
      'logo': image(logo),
      'header': image(header),
      'footerImage': image(footer),
      'signature': image(signature),
      'stamp': image(stamp),
    };
  }
}

/// What one document says about itself on every page (DOC-03).
class DocumentMeta {
  const DocumentMeta({required this.title, required this.pagePattern, required this.madeLabel, this.subtitle = '', this.number, this.dateLabel, this.copyLabel});

  factory DocumentMeta.fromJson(Map<String, Object?> json, {String? copyLabel}) => DocumentMeta(
    title: json['title'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    number: json['number'] as String?,
    dateLabel: json['date'] as String?,
    pagePattern: json['pages'] as String,
    madeLabel: json['made'] as String,
    copyLabel: copyLabel,
  );

  final String title;
  final String subtitle;

  /// An issued document's number. An export of a register has none.
  final String? number;
  final String? dateLabel;

  /// Holds {page} and {pages}.
  final String pagePattern;
  final String madeLabel;

  /// Set on a duplicate, with the same number as the original (DOC-05).
  final String? copyLabel;

  Map<String, Object?> toJson() => {'title': title, 'subtitle': subtitle, 'number': number, 'date': dateLabel, 'pages': pagePattern, 'made': madeLabel};
}

/// Draws an image at its placement. The trim is a clip, so the stored image never changes and the aspect stays true (DOC-04).
pw.Widget placedImage(DocumentImage image, double fullWidth, {double? fixedWidth, double? maxHeight}) {
  final place = image.placement;
  final keptW = (100 - place.cropLeft - place.cropRight) / 100;
  final keptH = (100 - place.cropTop - place.cropBottom) / 100;
  var shownW = fixedWidth ?? fullWidth * place.scalePct / 100;
  // A tall image can't take over the page, or no rows would fit under it. It shrinks whole, so its shape stays true.
  final shownH = shownW / keptW * image.height / image.width * keptH;
  if (maxHeight != null && shownH > maxHeight) shownW *= maxHeight / shownH;
  // The whole image at the size that makes the kept part fill shownW.
  final imageW = shownW / keptW;
  final imageH = imageW * image.height / image.width;
  return pw.Align(
    alignment: fixedWidth != null ? pw.Alignment.centerLeft : const [pw.Alignment.centerLeft, pw.Alignment.center, pw.Alignment.centerRight][place.align],
    child: pw.SizedBox(
      width: shownW,
      height: imageH * keptH,
      child: pw.Stack(
        overflow: pw.Overflow.clip,
        children: [
          pw.Positioned(
            left: -imageW * place.cropLeft / 100,
            top: -imageH * place.cropTop / 100,
            child: pw.Image(pw.MemoryImage(image.bytes), width: imageW, height: imageH, fit: pw.BoxFit.fill),
          ),
        ],
      ),
    ),
  );
}

/// A double-ringed mark, slightly off true, as in the app. It sits in the heading, so it can't cover anything.
pw.Widget _copyMark(String label, PdfColor color) => pw.Transform.rotateBox(
  angle: 0.035,
  child: pw.Container(
    padding: const pw.EdgeInsets.all(1.5),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(3)),
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 0.5), borderRadius: pw.BorderRadius.circular(2)),
      child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
    ),
  ),
);

/// One shared page: the company or its letterhead, the document's title, number and date, and page X of Y on every page.
/// A header and footer take their own height off the page, so no image can ever lie over the content (DOC-01, DOC-03).
pw.MultiPage documentPage({
  required DocumentIdentity identity,
  required DocumentMeta meta,
  required PdfPageFormat format,
  required Uint8List regularFont,
  required Uint8List boldFont,
  required pw.BuildListCallback build,
  int maxPages = 5000,
}) {
  final brand = PdfColor.fromInt(identity.brandArgb);
  const side = 28.0;
  final width = format.width - side * 2;
  final letterhead = identity.printLetterhead;

  pw.Widget companyBlock() => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (identity.logo != null) ...[pw.SizedBox(width: 56, child: placedImage(identity.logo!, 56, fixedWidth: 56, maxHeight: 56)), pw.SizedBox(width: 10)],
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(identity.shownName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: brand)),
            if (identity.tradingName != null) pw.Text(identity.legalName, style: const pw.TextStyle(fontSize: 8, color: docMuted)),
            if (identity.contactLine.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(identity.contactLine, style: const pw.TextStyle(fontSize: 8, color: docMuted))),
            if (identity.trn != null) pw.Text('TRN ${identity.trn}', style: const pw.TextStyle(fontSize: 8, color: docMuted)),
          ],
        ),
      ),
    ],
  );

  pw.Widget titleBlock() => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(meta.title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: docInk)),
            if (meta.subtitle.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 1), child: pw.Text(meta.subtitle, style: const pw.TextStyle(fontSize: 8.5, color: docMuted))),
          ],
        ),
      ),
      if (meta.copyLabel != null) ...[_copyMark(meta.copyLabel!, brand), pw.SizedBox(width: 10)],
      if (meta.number != null || meta.dateLabel != null)
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (meta.number != null) pw.Text(meta.number!, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: docInk)),
            if (meta.dateLabel != null) pw.Text(meta.dateLabel!, style: const pw.TextStyle(fontSize: 8.5, color: docMuted)),
          ],
        ),
    ],
  );

  return pw.MultiPage(
    pageFormat: format,
    // With pre-printed paper the blank space is the owner's to set, so their own heading never gets printed over.
    margin: pw.EdgeInsets.fromLTRB(side, letterhead ? 24 : identity.blankTopMm * _mmToPt, side, letterhead ? 20 : identity.blankBottomMm * _mmToPt),
    maxPages: maxPages,
    theme: pw.ThemeData.withFont(base: pw.Font.ttf(regularFont.buffer.asByteData()), bold: pw.Font.ttf(boldFont.buffer.asByteData())),
    header: (context) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: brand, width: 1.2))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (letterhead) ...[
            if (identity.header != null) placedImage(identity.header!, width, maxHeight: format.height * 0.22) else companyBlock(),
            pw.SizedBox(height: 8),
          ],
          titleBlock(),
        ],
      ),
    ),
    footer: (context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (letterhead && identity.footer != null) ...[placedImage(identity.footer!, width, maxHeight: format.height * 0.14), pw.SizedBox(height: 3)],
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  [
                    // Even under a designed letterhead, the legal name stays in words (DOC-03).
                    if (letterhead && identity.header != null) identity.legalName,
                    if (letterhead && identity.header != null && identity.trn != null) 'TRN ${identity.trn}',
                    if (letterhead) ?identity.footerText,
                    meta.madeLabel,
                  ].join('   '),
                  style: const pw.TextStyle(fontSize: 7.5, color: docMuted),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                [
                  ?meta.number,
                  meta.pagePattern.replaceAll('{page}', '${context.pageNumber}').replaceAll('{pages}', '${context.pagesCount}'),
                ].join('   '),
                style: const pw.TextStyle(fontSize: 7.5, color: docMuted),
              ),
            ],
          ),
        ],
      ),
    ),
    build: build,
  );
}

/// One figure-or-word cell of a document's table.
pw.Widget docCell(String text, {pw.Alignment align = pw.Alignment.topLeft, bool bold = false, PdfColor? color, double size = 8.5, double vertical = 2.2}) {
  return pw.Container(
    alignment: align,
    padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: vertical),
    child: pw.Text(
      text,
      textAlign: switch (align) {
        pw.Alignment.topRight => pw.TextAlign.right,
        pw.Alignment.topCenter || pw.Alignment.center => pw.TextAlign.center,
        _ => pw.TextAlign.left,
      },
      style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? docInk),
    ),
  );
}

/// Rules across only, as in an account book: nothing boxes the figures in.
const docTableBorder = pw.TableBorder(horizontalInside: pw.BorderSide(color: docRule, width: 0.4));

/// A heading row: dark words over a dark rule, which also saves ink when it is printed.
const docHeadDecoration = pw.BoxDecoration(
  border: pw.Border(bottom: pw.BorderSide(color: docInk, width: 0.8)),
);

/// A total: a rule above and a heavy one below.
const docTotalDecoration = pw.BoxDecoration(
  border: pw.Border(
    top: pw.BorderSide(color: docInk, width: 0.8),
    bottom: pw.BorderSide(color: docInk, width: 1.6),
  ),
);

/// A section heading on the page.
pw.Widget docHeading(String text, PdfColor brand) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 10, bottom: 3),
  child: pw.Text(text, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: brand)),
);

/// The bottom line of a document, under and over a double rule.
pw.Widget docBottomLine(String label, String amount) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  children: [
    pw.Container(height: 0.8, color: docInk),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: docInk))),
          pw.Text(amount, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: docInk)),
        ],
      ),
    ),
    pw.Container(height: 0.8, color: docInk),
    pw.SizedBox(height: 1.5),
    pw.Container(height: 0.8, color: docInk),
  ],
);

/// Where the company signs and stamps, if the owner keeps these on (DOC-04), and a line for whoever takes the paper.
pw.Widget docSignatures(DocumentIdentity identity, {String? companyLabel, String? receiverLabel}) {
  pw.Widget line(String label) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 0.5, width: 150, color: docInk),
      pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: docMuted))),
    ],
  );
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      if (companyLabel != null)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  if (identity.signature != null) pw.SizedBox(width: 90, child: placedImage(identity.signature!, 90, fixedWidth: 90, maxHeight: 60)) else pw.SizedBox(height: 34),
                  if (identity.stamp != null) ...[pw.SizedBox(width: 8), pw.SizedBox(width: 60, child: placedImage(identity.stamp!, 60, fixedWidth: 60, maxHeight: 60))],
                ],
              ),
              pw.SizedBox(height: 2),
              line(companyLabel),
            ],
          ),
        ),
      if (receiverLabel != null)
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [pw.SizedBox(height: 36), line(receiverLabel)],
          ),
        ),
    ],
  );
}
