import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:domain/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/form_bits.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/invoices.dart';
import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../documents/document_preview_screen.dart';
import '../rates/rate_labels.dart';
import '../registers/register_export.dart';
import 'invoice_paper.dart';

String vatCategoryLabel(AppLocalizations l10n, VatCategory c) => switch (c) {
  VatCategory.standard => l10n.invCatStandard,
  VatCategory.zeroRated => l10n.invCatZero,
  VatCategory.exempt => l10n.invCatExempt,
  VatCategory.outOfScope => l10n.invCatOut,
};

/// One invoice or credit note: a draft to check and issue, or what was issued and what can happen next (INV-01 to INV-06).
class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _busy = false;

  TenantDatabase get _db => ref.read(dbProvider);

  void _setBusy(bool busy) {
    if (mounted) setState(() => _busy = busy);
  }

  Future<bool> _step(Future<void> Function() work) async {
    final saved = await saveOrExplain(context, work);
    if (saved && mounted) showSavedOnPhone(context, AppLocalizations.of(context).savedOnPhone);
    return saved;
  }

  Future<void> _saveDraft(InvoicesCompanion fields) => _step(() => _db.saveInvoiceDraft(widget.invoiceId, fields, operationId: newUuid()));

  Future<void> _saveChoices(InvoiceView v, InvoiceDraft Function(InvoiceDraft d) change) => _saveDraft(InvoicesCompanion(draft: Value(change(InvoiceDraft.fromJson(v.invoice.draft)).toJson())));

  Future<bool> _confirm(String title, String body, String yes) async {
    final l10n = AppLocalizations.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(yes)),
        ],
      ),
    );
    return answer == true && mounted;
  }

  Future<void> _issue(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.invIssue, l10n.invIssueBody, l10n.invIssue)) return;
    await _step(() => _db.issueInvoice(v.invoice.id, describe: (l) => invoiceLineText(paperWords, l), operationId: newUuid()));
  }

  Future<void> _delete(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (!await _confirm(l10n.invDeleteDraft, l10n.invDeleteDraftBody, l10n.invDeleteDraft)) return;
    final saved = await _step(() => _db.deleteInvoiceDraft(v.invoice.id, operationId: newUuid()));
    if (saved && mounted) navigator.pop();
  }

  Future<void> _preview(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    _setBusy(true);
    try {
      final bytes = await draftPdf(_db, v);
      final file = await writeExportFile(invoiceFileName(v), bytes);
      await navigator.push(MaterialPageRoute<void>(builder: (_) => DocumentPreviewScreen(title: invoiceTitle(paperWords, v), bytes: bytes, file: file)));
    } catch (_) {
      if (mounted) showFormError(context, l10n.exportFailed);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _sendWithTimesheets(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    final whatsapp = await showModalBottomSheet<bool>(context: context, builder: (_) => _SendBothSheet(number: v.invoice.number!));
    if (whatsapp == null || !mounted) return;
    _setBusy(true);
    try {
      final made = await invoiceWithTimesheets(_db, l10n, v);
      final files = [for (final (name, bytes) in made) await writeExportFile(name, bytes)];
      final result = await sendFiles(files, whatsapp: whatsapp);
      if (result == ExportResult.noWhatsApp && mounted) showFormError(context, l10n.exportNoWhatsApp);
    } catch (_) {
      if (mounted) showFormError(context, l10n.exportFailed);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _credit(InvoiceView v) async {
    final answer = await showModalBottomSheet<({int? amount, String reason})>(context: context, isScrollControlled: true, builder: (_) => _CreditSheet(view: v));
    if (answer != null && mounted) await _step(() => _db.creditInvoice(v.invoice.id, reason: answer.reason, amountFils: answer.amount, operationId: newUuid()));
  }

  /// A new draft for the same company and dates, which reads the timesheets as they stand now.
  Future<void> _reissue(InvoiceView v) async {
    final navigator = Navigator.of(context);
    final inv = v.invoice;
    String? id;
    final saved = await saveOrExplain(context, () async => id = await _db.createInvoice(clientId: inv.clientId, siteId: inv.siteId, from: inv.fromDate, to: inv.toDate, operationId: newUuid()));
    if (saved && id != null && mounted) await navigator.push(MaterialPageRoute<void>(builder: (_) => InvoiceScreen(invoiceId: id!)));
  }

  Future<void> _editItem(InvoiceView v, [InvoiceItem? item]) async {
    final answer = await showModalBottomSheet<({InvoiceItem item, bool remove})>(context: context, isScrollControlled: true, builder: (_) => _ItemSheet(item: item));
    if (answer == null || !mounted) return;
    await _saveChoices(v, (d) {
      final others = [for (final i in d.items) if (i.key != answer.item.key) i];
      return d.copyWith(items: answer.remove ? others : [for (final i in d.items) i.key == answer.item.key ? answer.item : i, if (item == null) answer.item]);
    });
  }

  Future<void> _editPo(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    final text = TextEditingController(text: v.invoice.poReference ?? '');
    final answer = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.invPo),
        content: Field(l10n.invPo, text),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialog).pop(text.text.trim()), child: Text(l10n.save)),
        ],
      ),
    );
    text.dispose();
    if (answer != null && mounted) await _saveDraft(InvoicesCompanion(poReference: Value(answer.isEmpty ? null : answer)));
  }

  Future<void> _editDue(InvoiceView v) async {
    final picked = await pickDate(context, v.invoice.dueDate ?? dubaiToday(DateTime.now()));
    if (picked != null && mounted) await _saveDraft(InvoicesCompanion(dueDate: Value(picked)));
  }

  Future<void> _editVat(InvoiceView v) async {
    final l10n = AppLocalizations.of(context);
    final picked = await chooseOne(context, l10n.invVatTreatment, [for (final c in VatCategory.values) (value: c, label: vatCategoryLabel(l10n, c))]);
    if (picked != null && mounted) await _saveDraft(InvoicesCompanion(vatCategory: Value(picked.name)));
  }

  Future<void> _editLine(InvoiceView v, InvoiceLineView line) async {
    if (line.isItem) return _editItem(v, InvoiceDraft.fromJson(v.invoice.draft).items.firstWhere((i) => i.key == line.key));
    final answer = await showModalBottomSheet<({int discount, int? fee})>(context: context, isScrollControlled: true, builder: (_) => _LineSheet(line: line));
    if (answer == null || !mounted) return;
    await _saveChoices(
      v,
      (d) => d.copyWith(
        discounts: {...d.discounts, line.key: answer.discount}..removeWhere((_, fils) => fils == 0),
        fees: {...d.fees, if (answer.fee != null) line.key: answer.fee!},
      ),
    );
  }

  void _open(String id) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InvoiceScreen(invoiceId: id)));

  Future<void> _toggle(InvoiceView v, InvoiceSource s) => _saveChoices(v, (d) => d.copyWith(skipped: s.skipped ? ({...d.skipped}..remove(s.timesheet.id)) : {...d.skipped, s.timesheet.id}));

  String _lineTitle(AppLocalizations l10n, InvoiceLineView l) {
    if (l.description != null) return l.description!;
    if (l.isFee) return basisLabel(l10n, l.basis!);
    return [?l.siteName, ?l.trade, if (l.siteName == null && l.trade == null) l10n.tsAllSites].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = ref.watch(invoiceProvider(widget.invoiceId)).value;
    if (v == null) return Scaffold(appBar: AppBar(title: Text(l10n.invDraftTitle)));

    final inv = v.invoice;
    final isDraft = v.status == InvoiceStatus.draft;
    final profile = ref.watch(profileProvider).value;
    final needsTrn = isDraft && v.vatRegistered && (profile?.trn ?? '').trim().isEmpty;
    final (label, press) = isDraft ? (l10n.invIssue, v.lines.isEmpty || needsTrn ? null : () => _issue(v)) : (l10n.invPaper, () => shareInvoice(context, ref, v, onBusy: _setBusy));
    final more = <(String, VoidCallback)>[
      if (isDraft) ...[(l10n.invPreview, () => _preview(v)), (l10n.invDeleteDraft, () => _delete(v))],
      if (v.status == InvoiceStatus.issued && !v.isCreditNote && v.lines.any((l) => l.timesheetId != null)) (l10n.invShareBoth, () => _sendWithTimesheets(v)),
      if (v.status == InvoiceStatus.issued && !v.isCreditNote && v.leftFils > 0) (l10n.invCredit, () => _credit(v)),
      if (v.status == InvoiceStatus.credited) (l10n.invReissue, () => _reissue(v)),
      for (final note in v.creditNotes) (l10n.invOpenCreditNote(note.number!), () => _open(note.id)),
      if (v.original case final original?) (l10n.invOpenInvoice(original.number!), () => _open(original.id)),
    ];
    final lastNote = v.creditNotes.lastOrNull?.number ?? '';
    final changedBy = v.changes.fold(0, (total, c) => total + c.differenceFils);
    final sign = v.isCreditNote ? -1 : 1;

    final head = <Widget>[
      TopBand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.client.name, style: sectionTitleStyle.copyWith(color: Colors.white)),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text('${l10n.dateFromTo(showDate(inv.fromDate), showDate(inv.toDate))}, ${v.siteName ?? l10n.tsAllSites}', style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.85))),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: BandFigure(formatAed(sign * v.totals.totalFils), l10n.invTotal, size: 20)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: BandFigure(formatAed(sign * v.totals.vatFils), l10n.invVat, size: 20)),
              ],
            ),
          ],
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (v.status == InvoiceStatus.credited) ...[
        const SizedBox(height: 20),
        Center(child: ClosedStamp(l10n.invStatusCredited, lastNote)),
        const SizedBox(height: 12),
      ],
      NoteRow(
        icon: Icons.info_outline,
        color: muted,
        text: switch (v.status) {
          _ when v.isCreditNote => l10n.invNoteCreditNote(v.original?.number ?? '', inv.reason ?? ''),
          InvoiceStatus.draft => l10n.invNoteDraft,
          InvoiceStatus.issued => l10n.invNoteIssued(showDate(inv.issueDate!), showDate(inv.dueDate!)),
          InvoiceStatus.credited => l10n.invNoteCredited(lastNote),
        },
      ),
      if (v.status == InvoiceStatus.issued && v.creditNotes.isNotEmpty)
        NoteRow(icon: Icons.info_outline, text: l10n.invNotePartCredited(formatAed(v.credited.totalFils), formatAed(v.leftFils)), color: muted),
      if (v.changes.isNotEmpty) NoteRow(icon: Icons.error_outline, text: l10n.invChanged(v.changes.length, formatAed(changedBy)), color: due),
      if (isDraft && !v.vatRegistered) NoteRow(icon: Icons.info_outline, text: l10n.invNotRegistered, color: muted),
      if (needsTrn) NoteRow(icon: Icons.error_outline, text: l10n.invNeedsTrn, color: due),
      if (isDraft && v.lines.any((l) => l.discountFils > l.amountFils)) NoteRow(icon: Icons.error_outline, text: l10n.invDiscountTooBig, color: due),
      // Up here, so the next step never sits under a long list of lines.
      for (final (text, onTap) in more)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: OutlinedButton(onPressed: _busy ? null : onTap, child: Text(text)),
        ),
      if (v.sources.isNotEmpty) ...[
        SectionHeader(l10n.invTimesheetsHeading),
        for (final s in v.sources)
          RowCard(
            child: CheckboxListTile(
              value: !s.skipped,
              onChanged: s.ready == 0 ? null : (_) => _toggle(v, s),
              title: Text('${s.timesheet.number}, ${l10n.dateFromTo(showDate(s.timesheet.fromDate), showDate(s.timesheet.toDate))}'),
              subtitle: Text(
                [
                  if (s.ready > 0) l10n.invSourceRows(s.ready),
                  if (s.disputed > 0) l10n.invSourceDisputed(s.disputed),
                  if (s.changed > 0) l10n.invSourceChanged(s.changed),
                ].join('\n'),
              ),
            ),
          ),
      ],
      SectionHeader(l10n.invLinesHeading),
      if (v.lines.isEmpty) NoteRow(icon: Icons.info_outline, text: l10n.invNoLines, color: muted),
    ];

    final body = [
      for (final line in v.lines)
        RowCard(
          child: ListTile(
            title: Text(_lineTitle(l10n, line)),
            subtitle: Text(
              [
                if (line.basis case final basis?) '${quantityLabel(l10n, line)}, ${rateSummary(l10n, basis.name, line.unitPriceFils)}' else quantityLabel(l10n, line),
                if (line.description == null) [if (line.fromDate != null) l10n.dateFromTo(showDate(line.fromDate!), showDate(line.toDate!)), ?line.timesheetNumber].join(', '),
                if (line.isFee && line.description == null) l10n.invFeeHelp,
                if (line.discountFils > 0) l10n.invLessDiscount(formatAed(line.discountFils)),
              ].join('\n'),
            ),
            trailing: RowValue(formatAed(sign * line.tax.netFils)),
            onTap: isDraft ? () => _editLine(v, line) : null,
          ),
        ),
      if (isDraft)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: OutlinedButton.icon(onPressed: _busy ? null : () => _editItem(v), icon: const Icon(Icons.add), label: Text(l10n.invAddLine)),
        ),
    ];

    final foot = <Widget>[
      if (v.lines.isNotEmpty) ...[
        if (v.bps > 0 || v.totals.vatFils != 0) ...[
          RowCard(child: InfoRow(l10n.invNet, formatAed(sign * v.totals.netFils))),
          RowCard(child: InfoRow(l10n.invVatAt(vatPercent(v.bps)), formatAed(sign * v.totals.vatFils))),
        ],
        TotalRow(l10n.invTotal, formatAed(sign * v.totals.totalFils)),
        if (v.creditNotes.isNotEmpty) ...[
          RowCard(child: InfoRow(l10n.invCreditedSoFar(v.creditNotes.length), formatAed(-v.credited.totalFils))),
          TotalRow(l10n.invLeft, formatAed(v.leftFils)),
        ],
      ],
      // Timesheets and lines first, then the tax and terms, in the order INV-01 sets.
      SectionHeader(l10n.invSettingsHeading),
      if (v.vatRegistered)
        RowCard(
          child: ListTile(title: Text(l10n.invVatTreatment), subtitle: Text(vatCategoryLabel(l10n, v.category)), trailing: isDraft ? const Icon(Icons.chevron_right) : null, onTap: isDraft ? () => _editVat(v) : null),
        ),
      if (v.vatRegistered && v.category == VatCategory.standard)
        RowCard(
          child: SwitchListTile(
            title: Text(l10n.invInclusive),
            subtitle: Text(l10n.invInclusiveHelp),
            value: inv.pricesIncludeVat,
            onChanged: isDraft ? (on) => _saveDraft(InvoicesCompanion(pricesIncludeVat: Value(on))) : null,
          ),
        ),
      if (v.vatRegistered && v.category != VatCategory.standard && isDraft) NoteRow(icon: Icons.info_outline, text: l10n.invCatHelp, color: muted),
      RowCard(
        child: ListTile(title: Text(l10n.invPo), subtitle: Text(inv.poReference ?? '-'), trailing: isDraft ? const Icon(Icons.chevron_right) : null, onTap: isDraft ? () => _editPo(v) : null),
      ),
      if (!v.isCreditNote)
        RowCard(
          child: ListTile(
            title: Text(l10n.invDueDate),
            subtitle: Text(inv.dueDate == null ? l10n.invDueAuto : showDate(inv.dueDate!)),
            trailing: isDraft ? const Icon(Icons.chevron_right) : null,
            onTap: isDraft ? () => _editDue(v) : null,
          ),
        ),
      const SizedBox(height: 20),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(inv.number ?? l10n.invDraftTitle)),
      bottomNavigationBar: MainActionBar(label: label, onPressed: _busy ? null : press),
      body: ListView(children: [...head, ...body, ...foot]),
    );
  }
}

/// How the invoice and its timesheets go out together (TS-07). The owner picks the recipient there (DOC-07).
class _SendBothSheet extends StatelessWidget {
  const _SendBothSheet({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.invShareBoth, style: sectionTitleStyle),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(l10n.invShareBothBody(number), style: const TextStyle(fontSize: 13.5, height: 1.35, color: muted)),
            ),
            FilledButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.chat), label: Text(l10n.exportWhatsApp)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.share), label: Text(l10n.exportOther)),
          ],
        ),
      ),
    );
  }
}

/// A line's discount, and a monthly fee for part of a month. What the timesheet charged stays as it is (TS-06).
class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.line});

  final InvoiceLineView line;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  final _form = GlobalKey<FormState>();
  late final _discount = TextEditingController(text: plainAmount(widget.line.discountFils));
  late final _fee = TextEditingController(text: plainAmount(widget.line.amountFils));

  @override
  void dispose() {
    _discount.dispose();
    _fee.dispose();
    super.dispose();
  }

  int get _charge => widget.line.isFee ? parseAed(_fee.text) ?? 0 : widget.line.amountFils;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.invLineSheetTitle, style: sectionTitleStyle),
              const SizedBox(height: 12),
              if (widget.line.isFee) ...[
                Field(l10n.invFee, _fee, helper: l10n.invFeeHelp, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => parseAed(v ?? '') == null ? l10n.amountInvalid : null),
                fieldGap,
              ],
              Field(
                l10n.invDiscount,
                _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final fils = parseAed(v ?? '');
                  if (fils == null) return l10n.amountInvalid;
                  return fils > _charge ? l10n.invDiscountTooBig : null;
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (!validateAndReveal(_form)) return;
                  Navigator.of(context).pop((discount: parseAed(_discount.text)!, fee: widget.line.isFee ? parseAed(_fee.text) : null));
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A credit note for the whole invoice, or what is left of it, or for an amount (INV-06).
class _CreditSheet extends StatefulWidget {
  const _CreditSheet({required this.view});

  final InvoiceView view;

  @override
  State<_CreditSheet> createState() => _CreditSheetState();
}

class _CreditSheetState extends State<_CreditSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late bool _whole = widget.view.creditNotes.isEmpty || widget.view.changes.isNotEmpty;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = widget.view;
    final inv = v.invoice;
    final left = formatAed(v.leftFils);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.invCreditTitle, style: sectionTitleStyle),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [ButtonSegment(value: true, label: Text(l10n.invCreditWhole)), ButtonSegment(value: false, label: Text(l10n.invCreditPart))],
                selected: {_whole},
                onSelectionChanged: (picked) => setState(() => _whole = picked.single),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  _whole ? (v.creditNotes.isEmpty ? l10n.invCreditHelp : l10n.invCreditRestHelp(left)) : l10n.invCreditPartHelp(left),
                  style: const TextStyle(fontSize: 13.5, height: 1.35, color: muted),
                ),
              ),
              if (!_whole) ...[
                Field(
                  inv.vatBps == 0 ? l10n.invCreditAmount : (inv.pricesIncludeVat ? l10n.invCreditAmountWithVat : l10n.invCreditAmountBeforeVat),
                  _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (text) {
                    final fils = parseAed(text ?? '');
                    if (fils == null || fils <= 0) return l10n.amountInvalid;
                    return lineTax(fils, bps: inv.vatBps, inclusive: inv.pricesIncludeVat).totalFils > v.leftFils ? l10n.invCreditTooBig(left) : null;
                  },
                ),
                fieldGap,
              ],
              Field(l10n.invCreditReason, _reason, validator: (text) => (text ?? '').trim().isEmpty ? l10n.fieldRequired : null),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (!validateAndReveal(_form)) return;
                  Navigator.of(context).pop((amount: _whole ? null : parseAed(_amount.text), reason: _reason.text.trim()));
                },
                child: Text(l10n.invCreditConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line the owner writes, such as transport. VAT goes on it at the invoice's rate (INV-01).
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({this.item});

  final InvoiceItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  final _form = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.item?.description ?? '');
  late final _quantity = TextEditingController(text: '${widget.item?.quantity ?? 1}');
  late final _price = TextEditingController(text: widget.item == null ? '' : plainAmount(widget.item!.unitPriceFils));

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  InvoiceItem get _item => InvoiceItem(key: widget.item?.key ?? 'item|${newUuid()}', description: _description.text.trim(), quantity: int.parse(_quantity.text.trim()), unitPriceFils: parseAed(_price.text)!);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.item == null ? l10n.invAddLine : l10n.invItemTitle, style: sectionTitleStyle),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(l10n.invItemHelp, style: const TextStyle(fontSize: 13.5, height: 1.35, color: muted)),
              ),
              Field(l10n.invItemDescription, _description, validator: (text) => (text ?? '').trim().isEmpty ? l10n.fieldRequired : null),
              fieldGap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Field(
                      l10n.invItemCount,
                      _quantity,
                      keyboardType: TextInputType.number,
                      validator: (text) => (int.tryParse((text ?? '').trim()) ?? 0) < 1 ? l10n.invItemCountInvalid : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Field(
                      l10n.invItemPrice,
                      _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (text) => (parseAed(text ?? '') ?? 0) <= 0 ? l10n.amountInvalid : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (!validateAndReveal(_form)) return;
                  Navigator.of(context).pop((item: _item, remove: false));
                },
                child: Text(l10n.save),
              ),
              if (widget.item != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => Navigator.of(context).pop((item: widget.item!, remove: true)), child: Text(l10n.invItemRemove)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
