import 'dart:convert';

import 'package:drift/drift.dart';

import '../documents/document_frame.dart';
import 'masters.dart';
import 'tenant_database.dart';

/// The images a company can put on its papers (DOC-02, DOC-04).
enum AssetKind { logo, header, footer, signature, stamp }

/// An image the app won't take, and why.
class ImageRejected implements Exception {
  const ImageRejected(this.problem);

  final ImageProblem problem;
}

/// Papers that get a number and a stored copy (DOC-05). Registers are reports, so they are made fresh each time.
enum DocKind {
  payslip('SLIP'),
  paymentReceipt('RCPT'),
  advanceReceipt('ADV'),

  // One revision of a timesheet can go out in four ways, each kept as issued under the same number (TS-01, TS-02).
  timesheetDaily('TS'),
  timesheetDailyPriced('TS'),
  timesheetWorkers('TS'),
  timesheetWorkersPriced('TS');

  const DocKind(this.prefix);

  final String prefix;
}

/// A number stays with a paper through its revisions: SLIP-2026-0012, then SLIP-2026-0012 R2.
/// ponytail: counted on this phone. T25 must give each device its own series before two devices issue papers.
String documentNumber(DocKind kind, int year, int seq, int revision) => '${kind.prefix}-$year-${seq.toString().padLeft(4, '0')}${revision > 1 ? ' R$revision' : ''}';

/// One line of the list of papers, without its stored file, so a long list stays light.
class IssuedRow {
  const IssuedRow({required this.id, required this.kind, required this.number, required this.title, required this.summary, required this.issuedAtUtc});

  final String id;
  final DocKind kind;
  final String number;
  final String title;
  final String summary;
  final DateTime issuedAtUtc;
}

extension DocumentOps on TenantDatabase {
  Future<DocumentTemplate?> documentTemplate() => select(documentTemplates).getSingleOrNull();

  /// Saves the template's fields, making the one row if it isn't there yet.
  Future<void> saveDocumentTemplate(DocumentTemplatesCompanion fields, {required String operationId}) async {
    final existing = await documentTemplate();
    await saveRow(documentTemplates, id: existing?.id, fields: fields, operationId: operationId);
  }

  /// Keeps an uploaded image for good and points the template at it. Papers already issued keep the one they used (DOC-04, DOC-05).
  /// The bytes stay out of the audit log and outbox, which only say what was stored.
  Future<String> saveDocumentImage(AssetKind kind, Uint8List bytes, {required String operationId}) => transaction(() async {
    final id = await _keepImage(kind.name, bytes, operationId: operationId);
    await setDocumentImage(kind, id, operationId: newUuid());
    return id;
  });

  /// Keeps a photo of what a company sent back. No paper prints it, and it is never a verified signature (TS-04).
  Future<String> saveEvidenceImage(Uint8List bytes, {required String operationId}) => _keepImage('evidence', bytes, operationId: operationId);

  Future<String> _keepImage(String kind, Uint8List bytes, {required String operationId}) async {
    final problem = checkImage(bytes);
    if (problem != null) throw ImageRejected(problem);
    final facts = readImageFacts(bytes)!;
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'document_assets',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        await into(documentAssets).insert(
          DocumentAssetsCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            kind: kind,
            mime: facts.mime,
            widthPx: facts.width,
            heightPx: facts.height,
            bytes: bytes,
          ),
        );
        return {'kind': kind, 'mime': facts.mime, 'width': facts.width, 'height': facts.height, 'size': bytes.length};
      },
    );
    return id;
  }

  /// Points the template at an image, or at none. The image itself stays, since a paper may still use it.
  Future<void> setDocumentImage(AssetKind kind, String? assetId, {required String operationId}) => saveDocumentTemplate(switch (kind) {
    AssetKind.logo => DocumentTemplatesCompanion(logoAssetId: Value(assetId)),
    AssetKind.header => DocumentTemplatesCompanion(headerAssetId: Value(assetId)),
    AssetKind.footer => DocumentTemplatesCompanion(footerAssetId: Value(assetId)),
    AssetKind.signature => DocumentTemplatesCompanion(signatureAssetId: Value(assetId)),
    AssetKind.stamp => DocumentTemplatesCompanion(stampAssetId: Value(assetId)),
  }, operationId: operationId);

  /// Each image's stored placement, by [AssetKind] name.
  Map<String, Object?> placementsOf(DocumentTemplate? t) => t == null ? const {} : jsonDecode(t.placements) as Map<String, Object?>;

  Future<void> savePlacement(AssetKind kind, Placement placement, {required String operationId}) async {
    final all = {...placementsOf(await documentTemplate()), kind.name: placement.toJson()};
    await saveDocumentTemplate(DocumentTemplatesCompanion(placements: Value(jsonEncode(all))), operationId: operationId);
  }

  Future<Map<String, DocumentImage>> _images(Iterable<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await (select(documentAssets)..where((a) => a.id.isIn(ids))).get();
    return {for (final a in rows) a.id: DocumentImage(assetId: a.id, bytes: a.bytes, width: a.widthPx, height: a.heightPx)};
  }

  /// Who papers made today come from: the company's own details and its current template (DOC-01, DOC-02).
  Future<DocumentIdentity> currentIdentity({required int brandArgb, required int softArgb}) async {
    final p = await select(tenantProfiles).getSingleOrNull();
    final t = await documentTemplate();
    final places = placementsOf(t);
    final images = await _images([?t?.logoAssetId, ?t?.headerAssetId, ?t?.footerAssetId, ?t?.signatureAssetId, ?t?.stampAssetId]);
    DocumentImage? image(AssetKind kind, String? id, {bool on = true}) {
      final found = images[id];
      if (found == null || !on) return null;
      return DocumentImage(assetId: found.assetId, bytes: found.bytes, width: found.width, height: found.height, placement: Placement.fromJson(places[kind.name] as Map<String, Object?>?));
    }

    return DocumentIdentity(
      legalName: p?.legalName ?? '',
      tradingName: p?.tradingName,
      contactLine: [?p?.address, ?p?.phone, ?p?.email].join('   '),
      trn: p?.trn,
      footerText: p?.documentFooter,
      brandArgb: brandArgb,
      softArgb: softArgb,
      printLetterhead: t?.printLetterhead ?? true,
      blankTopMm: t?.blankTopMm ?? 40,
      blankBottomMm: t?.blankBottomMm ?? 25,
      logo: image(AssetKind.logo, t?.logoAssetId),
      header: image(AssetKind.header, t?.headerAssetId),
      footer: image(AssetKind.footer, t?.footerAssetId),
      signature: image(AssetKind.signature, t?.signatureAssetId, on: t?.showSignature ?? false),
      stamp: image(AssetKind.stamp, t?.stampAssetId, on: t?.showStamp ?? false),
    );
  }

  /// The same paper again when nothing on it has changed, or a new revision under the same number when something has.
  /// Each stored file stays exactly as it was issued, whatever changes later (DOC-05). [render] gets the number to print.
  /// A paper with a number of its own passes [fixed]: asking again gives the stored one, since its facts can't change
  /// without a new revision of the thing itself.
  Future<IssuedDocument> issueDocument({
    required DocKind kind,
    required String subjectId,
    required String? period,
    required String title,
    required String summary,
    required Map<String, Object?> data,
    required DocumentIdentity identity,
    required DocumentMeta Function(String number) metaFor,
    required Future<Uint8List> Function(DocumentMeta meta) render,
    required String operationId,
    ({int year, int seq, int revision})? fixed,
  }) async {
    if (fixed != null) {
      final stored = await (select(issuedDocuments)..where((d) => d.kind.equals(kind.name) & d.year.equals(fixed.year) & d.seq.equals(fixed.seq) & d.revision.equals(fixed.revision))).getSingleOrNull();
      if (stored != null) return stored;
    }
    final dataJson = jsonEncode(data);
    final identityJson = jsonEncode(identity.toJson());
    final latest = fixed != null
        ? null
        : await (select(issuedDocuments)
                ..where((d) => d.kind.equals(kind.name) & d.subjectId.equals(subjectId) & (period == null ? d.period.isNull() : d.period.equals(period)))
                ..orderBy([(d) => OrderingTerm.desc(d.revision)])
                ..limit(1))
              .getSingleOrNull();
    // Changing the app's colours alone doesn't make it a different paper.
    String withoutColours(String json) => jsonEncode(jsonDecode(json) as Map<String, Object?>..remove('brand')..remove('soft'));
    if (latest != null && latest.dataJson == dataJson && withoutColours(latest.identityJson) == withoutColours(identityJson)) return latest;

    final year = fixed?.year ?? latest?.year ?? DateTime.now().toUtc().add(const Duration(hours: 4)).year;
    var seq = fixed?.seq ?? latest?.seq;
    if (seq == null) {
      final top = issuedDocuments.seq.max();
      final query = selectOnly(issuedDocuments)
        ..addColumns([top])
        ..where(issuedDocuments.kind.equals(kind.name) & issuedDocuments.year.equals(year));
      seq = ((await query.getSingle()).read(top) ?? 0) + 1;
    }
    final revision = fixed?.revision ?? (latest?.revision ?? 0) + 1;
    final number = documentNumber(kind, year, seq, revision);
    final meta = metaFor(number);
    final pdf = await render(meta);
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'issued_documents',
      recordId: id,
      version: 1,
      action: 'issue',
      change: () async {
        final now = DateTime.now().toUtc();
        await into(issuedDocuments).insert(
          IssuedDocumentsCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            kind: kind.name,
            year: year,
            seq: seq!,
            revision: revision,
            number: number,
            subjectId: subjectId,
            period: Value(period),
            title: title,
            summary: summary,
            dataJson: dataJson,
            identityJson: identityJson,
            metaJson: jsonEncode(meta.toJson()),
            pdfBytes: pdf,
          ),
        );
        return {'number': number, 'kind': kind.name, 'subject': subjectId, 'period': period, 'data': data};
      },
    );
    return (select(issuedDocuments)..where((d) => d.id.equals(id))).getSingle();
  }

  Future<IssuedDocument> issuedDocument(String id) => (select(issuedDocuments)..where((d) => d.id.equals(id))).getSingle();

  /// A stored paper's own company details and images, to draw it again as a copy.
  Future<DocumentIdentity> identityOf(IssuedDocument doc) async {
    final json = jsonDecode(doc.identityJson) as Map<String, Object?>;
    final ids = [
      for (final key in const ['logo', 'header', 'footerImage', 'signature', 'stamp'])
        if (json[key] != null) (json[key] as Map<String, Object?>)['id'] as String,
    ];
    return DocumentIdentity.fromJson(json, await _images(ids));
  }

  /// Every issued paper, newest first.
  Stream<List<IssuedRow>> watchIssued() {
    final d = issuedDocuments;
    final query = selectOnly(d)
      ..addColumns([d.id, d.kind, d.number, d.title, d.summary, d.createdAtUtc])
      ..orderBy([OrderingTerm.desc(d.createdAtUtc)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          IssuedRow(id: r.read(d.id)!, kind: DocKind.values.byName(r.read(d.kind)!), number: r.read(d.number)!, title: r.read(d.title)!, summary: r.read(d.summary)!, issuedAtUtc: r.read(d.createdAtUtc)!),
      ],
    );
  }
}
