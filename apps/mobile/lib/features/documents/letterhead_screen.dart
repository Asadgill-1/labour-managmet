import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
import '../../data/documents.dart';
import '../../data/tenant_database.dart';
import '../../documents/document_frame.dart';
import '../../l10n/app_localizations.dart';
import '../more/profile_form_screen.dart';
import '../payroll/salary_slip.dart';
import '../registers/register_export.dart';
import 'document_preview_screen.dart';
import 'document_render.dart';

const _files = MethodChannel('labour_app/files');

/// An A4 page's printable width in points, for judging an image's sharpness.
const _printWidth = 539.0;

/// How the company's papers look. Old papers keep the look they went out with (DOC-02 to DOC-05).
class LetterheadScreen extends ConsumerWidget {
  const LetterheadScreen({super.key});

  Future<void> _sample(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final identity = await ref.read(dbProvider).currentIdentity(brandArgb: brand.toARGB32(), softArgb: brandSoft.toARGB32());
      final meta = metaForNow(l10n, title: l10n.slipTitle, subtitle: l10n.lhSample, number: 'SLIP-0000-0000');
      final bytes = await renderIssued(DocKind.payslip, _sampleSlip(l10n).toJson(), identity, meta);
      final file = await writeExportFile('sample.pdf', bytes);
      if (context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocumentPreviewScreen(title: l10n.lhSample, bytes: bytes, file: file)));
      }
    } catch (_) {
      if (context.mounted) showFormError(context, l10n.exportFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final template = ref.watch(documentTemplateProvider).value;
    final profile = ref.watch(profileProvider).value;
    final db = ref.read(dbProvider);
    final printed = template?.printLetterhead ?? true;
    Future<void> save(DocumentTemplatesCompanion fields) => saveOrExplain(context, () => db.saveDocumentTemplate(fields, operationId: newUuid()));

    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.lhTab), bottom: const SubTabs(Section.letterhead)),
      bottomNavigationBar: MainActionBar(label: l10n.lhSample, onPressed: () => _sample(context, ref)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          NoteRow(icon: Icons.history, text: l10n.lhOld, color: muted),
          SectionHeader(l10n.lhIdentity),
          RowCard(
            child: ListTile(
              title: Text(profile?.legalName ?? ''),
              subtitle: Text(l10n.lhIdentityNote),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileFormScreen(profile: profile))),
            ),
          ),
          RowCard(
            child: SwitchListTile(
              title: Text(l10n.lhPrinted),
              subtitle: Text(l10n.lhPrintedHelp),
              value: printed,
              onChanged: (on) => save(DocumentTemplatesCompanion(printLetterhead: Value(on))),
            ),
          ),
          if (!printed)
            _BlankSpace(
              key: ValueKey('blank-${template?.blankTopMm}-${template?.blankBottomMm}'),
              top: template?.blankTopMm ?? 40,
              bottom: template?.blankBottomMm ?? 25,
              onSave: (top, bottom) => save(DocumentTemplatesCompanion(blankTopMm: Value(top), blankBottomMm: Value(bottom))),
            ),
          for (final kind in AssetKind.values)
            if (printed || kind == AssetKind.signature || kind == AssetKind.stamp) _ImageBlock(kind, template: template),
        ],
      ),
    );
  }
}

/// What the sample page shows: long enough to run over a page, so the repeating heading can be seen.
SlipContent _sampleSlip(AppLocalizations l10n) => SlipContent(
  month: l10n.lhSample,
  worker: 'Asif Khan (W100)',
  workerLine: 'Helper',
  earnings: SlipBlock(l10n.slipEarnings, [(l10n.slipWorkBasis(26, '234:00'), '2,340.00')], totalLabel: l10n.slipEarned, total: '2,340.00'),
  deductions: SlipBlock(l10n.slipDeductions, [(l10n.slipAdvance, '-300.00'), (l10n.slipRoom, '-200.00')], totalLabel: l10n.slipDeducted, total: '-500.00'),
  account: SlipBlock(l10n.slipAccount, [(l10n.slipNet, '1,840.00'), (l10n.slipOpening, '-'), (l10n.slipPaid, '-')]),
  closingLabel: l10n.slipOwedToYou,
  closingAmount: 'AED 1,840.00',
  days: SlipTable(
    title: l10n.slipDays,
    emptyText: '',
    headings: [l10n.colDate, l10n.colCompany, l10n.colHours, l10n.regTotal],
    flex: const [3, 6, 2, 3],
    rightFrom: 2,
    rows: [for (var d = 1; d <= 60; d++) ['${(d % 28 + 1).toString().padLeft(2, '0')}-10-2026', 'Emaar Properties', '9:00', '90.00']],
    total: [l10n.regTotal, '', '', '5,400.00'],
  ),
  money: SlipTable(title: l10n.slipMoney, emptyText: l10n.slipNoMoney, headings: const [], flex: const [], rows: const [], total: const []),
  notes: [l10n.slipNote],
);

class _BlankSpace extends StatefulWidget {
  const _BlankSpace({required this.top, required this.bottom, required this.onSave, super.key});

  final int top;
  final int bottom;
  final void Function(int top, int bottom) onSave;

  @override
  State<_BlankSpace> createState() => _BlankSpaceState();
}

class _BlankSpaceState extends State<_BlankSpace> {
  late final _top = TextEditingController(text: '${widget.top}');
  late final _bottom = TextEditingController(text: '${widget.bottom}');

  void _save() {
    final top = int.tryParse(_top.text.trim());
    final bottom = int.tryParse(_bottom.text.trim());
    if (top == null || bottom == null || top < 0 || bottom < 0 || top > 120 || bottom > 120) {
      showFormError(context, AppLocalizations.of(context).lhBlankBad);
      return;
    }
    widget.onSave(top, bottom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(child: Field(l10n.lhBlankTop, _top, keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: Field(l10n.lhBlankBottom, _bottom, keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

class _ImageBlock extends ConsumerStatefulWidget {
  const _ImageBlock(this.kind, {required this.template});

  final AssetKind kind;
  final DocumentTemplate? template;

  @override
  ConsumerState<_ImageBlock> createState() => _ImageBlockState();
}

class _ImageBlockState extends ConsumerState<_ImageBlock> {
  Placement? _editing;

  String? get _assetId => switch (widget.kind) {
    AssetKind.logo => widget.template?.logoAssetId,
    AssetKind.header => widget.template?.headerAssetId,
    AssetKind.footer => widget.template?.footerAssetId,
    AssetKind.signature => widget.template?.signatureAssetId,
    AssetKind.stamp => widget.template?.stampAssetId,
  };

  bool get _places => widget.kind == AssetKind.header || widget.kind == AssetKind.footer;

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    try {
      final bytes = await _files.invokeMethod<Uint8List>('pickImage');
      if (bytes == null || !mounted) return;
      final problem = checkImage(bytes);
      if (problem != null) {
        showFormError(context, problem == ImageProblem.tooLarge ? l10n.lhTooLarge : l10n.lhBadType);
        return;
      }
      // A file can start like an image and still be broken, so it has to open before it is kept.
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
      } catch (_) {
        if (mounted) showFormError(context, l10n.lhBadType);
        return;
      }
      await db.saveDocumentImage(widget.kind, bytes, operationId: newUuid());
      if (mounted) showSavedOnPhone(context, l10n.savedOnPhone);
    } catch (e) {
      if (mounted) showFormError(context, saveErrorText(l10n, e));
    }
  }

  Future<void> _savePlacement(Placement p) async {
    setState(() => _editing = p);
    await saveOrExplain(context, () => ref.read(dbProvider).savePlacement(widget.kind, p, operationId: newUuid()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(dbProvider);
    final id = _assetId;
    final asset = id == null ? null : ref.watch(documentAssetProvider(id)).value;
    final title = switch (widget.kind) {
      AssetKind.logo => l10n.lhLogo,
      AssetKind.header => l10n.lhHeader,
      AssetKind.footer => l10n.lhFooter,
      AssetKind.signature => l10n.lhSignature,
      AssetKind.stamp => l10n.lhStamp,
    };
    final place = _editing ?? Placement.fromJson(db.placementsOf(widget.template)[widget.kind.name] as Map<String, Object?>?);
    final image = asset == null ? null : DocumentImage(assetId: asset.id, bytes: asset.bytes, width: asset.widthPx, height: asset.heightPx, placement: place);
    final dpi = image?.printDpi(_printWidth);
    final show = switch (widget.kind) {
      AssetKind.signature => widget.template?.showSignature ?? false,
      AssetKind.stamp => widget.template?.showStamp ?? false,
      _ => true,
    };

    Widget slider(String label, int value, double min, double max, Placement Function(int v) change) => Row(
      children: [
        SizedBox(width: 96, child: Text('$label $value%', style: const TextStyle(fontSize: 13.5, color: muted))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: (v) => setState(() => _editing = change(v.round())),
            onChangeEnd: (v) => _savePlacement(change(v.round())),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: _upload, child: Text(id == null ? l10n.lhUpload : l10n.lhChange)),
              if (id != null) TextButton(onPressed: () => saveOrExplain(context, () => db.setDocumentImage(widget.kind, null, operationId: newUuid())), child: Text(l10n.lhRemove)),
            ],
          ),
        ),
        if (image != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.memory(image.bytes, height: 64, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text(
              dpi! < lowDpi && _places ? l10n.lhLowRes(dpi) : l10n.lhResolution(image.width, image.height),
              style: TextStyle(fontSize: 13.5, color: dpi < lowDpi && _places ? due : muted),
            ),
          ),
          if (_places) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  slider(l10n.lhSize, place.scalePct, 30, 100, (v) => place.copyWith(scalePct: v)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 0, label: Text(l10n.lhLeft)),
                        ButtonSegment(value: 1, label: Text(l10n.lhCenter)),
                        ButtonSegment(value: 2, label: Text(l10n.lhRight)),
                      ],
                      selected: {place.align},
                      onSelectionChanged: (s) => _savePlacement(place.copyWith(align: s.first)),
                    ),
                  ),
                ],
              ),
            ),
            ExpansionTile(
              title: Text(l10n.lhCrop, style: const TextStyle(fontSize: 15, color: ink)),
              shape: const Border(),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                slider(l10n.lhCropTop, place.cropTop, 0, 40, (v) => place.copyWith(cropTop: v)),
                slider(l10n.lhCropBottom, place.cropBottom, 0, 40, (v) => place.copyWith(cropBottom: v)),
                slider(l10n.lhCropLeft, place.cropLeft, 0, 40, (v) => place.copyWith(cropLeft: v)),
                slider(l10n.lhCropRight, place.cropRight, 0, 40, (v) => place.copyWith(cropRight: v)),
              ],
            ),
          ],
          if (widget.kind == AssetKind.signature || widget.kind == AssetKind.stamp)
            SwitchListTile(
              title: Text(l10n.lhShow),
              value: show,
              onChanged: (on) => saveOrExplain(
                context,
                () => db.saveDocumentTemplate(
                  widget.kind == AssetKind.signature ? DocumentTemplatesCompanion(showSignature: Value(on)) : DocumentTemplatesCompanion(showStamp: Value(on)),
                  operationId: newUuid(),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
