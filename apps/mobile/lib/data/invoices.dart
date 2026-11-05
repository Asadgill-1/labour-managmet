import 'dart:convert';

import 'package:domain/calc.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:domain/money.dart';
import 'package:domain/timesheet.dart';
import 'package:drift/drift.dart';

import 'masters.dart';
import 'receipts.dart';
import 'tenant_database.dart';
import 'timesheets.dart';

/// How far an invoice has gone (INV-07). Paid, partly paid and overdue derive from its receipts (`PayState`).
enum InvoiceStatus { draft, issued, credited }

/// Why an invoice can't be made or issued as it stands. Nothing was written.
enum InvoiceProblem { nothingToBill, noCompanyDetails, noTrn, discountTooBig, wrongStep, creditTooBig }

class InvoiceRefused implements Exception {
  const InvoiceRefused(this.problem);

  final InvoiceProblem problem;
}

/// A line the owner writes on a draft, such as transport, that no timesheet holds (INV-01).
class InvoiceItem {
  const InvoiceItem({required this.key, required this.description, required this.quantity, required this.unitPriceFils});

  factory InvoiceItem.fromJson(Map<String, Object?> j) => InvoiceItem(key: j['key'] as String, description: j['description'] as String, quantity: j['quantity'] as int, unitPriceFils: j['price'] as int);

  final String key;
  final String description;
  final int quantity;
  final int unitPriceFils;

  Map<String, Object?> toJson() => {'key': key, 'description': description, 'quantity': quantity, 'price': unitPriceFils};
}

/// What a draft remembers besides its dates: timesheets the owner left out, each line's discount or monthly fee by line
/// key, and lines the owner wrote. Everything else is read from the timesheets as they stand.
class InvoiceDraft {
  const InvoiceDraft({this.skipped = const {}, this.discounts = const {}, this.fees = const {}, this.items = const []});

  factory InvoiceDraft.fromJson(String json) {
    final j = jsonDecode(json) as Map<String, Object?>;
    return InvoiceDraft(
      skipped: {...(j['skipped'] as List? ?? const []).cast<String>()},
      discounts: (j['discounts'] as Map? ?? const {}).cast<String, int>(),
      fees: (j['fees'] as Map? ?? const {}).cast<String, int>(),
      items: [for (final i in j['items'] as List? ?? const []) InvoiceItem.fromJson((i as Map).cast<String, Object?>())],
    );
  }

  final Set<String> skipped;
  final Map<String, int> discounts;
  final Map<String, int> fees;
  final List<InvoiceItem> items;

  InvoiceDraft copyWith({Set<String>? skipped, Map<String, int>? discounts, Map<String, int>? fees, List<InvoiceItem>? items}) =>
      InvoiceDraft(skipped: skipped ?? this.skipped, discounts: discounts ?? this.discounts, fees: fees ?? this.fees, items: items ?? this.items);

  String toJson() => jsonEncode({'skipped': [...skipped], 'discounts': discounts, 'fees': fees, 'items': [for (final i in items) i.toJson()]});
}

/// How an item line, or a credit for an amount, is stored in place of a `RateBasis`.
const itemBasis = 'item';

/// A stored line's unit, or null for a line the owner wrote or a credit for an amount.
RateBasis? basisOf(String stored) => stored == itemBasis ? null : RateBasis.values.byName(stored);

/// One invoice line: in a draft, worked out from timesheet rows that can still be billed; once issued, as stored.
class InvoiceLineView {
  const InvoiceLineView({
    required this.key,
    required this.timesheetId,
    required this.timesheetNumber,
    required this.siteName,
    required this.trade,
    required this.basis,
    required this.quantity,
    required this.unitPriceFils,
    required this.amountFils,
    required this.discountFils,
    required this.fromDate,
    required this.toDate,
    required this.tax,
    this.description,
    this.sources = const [],
  });

  /// Says which line a discount or fee belongs to. Stable while the draft is open.
  final String key;
  final String? timesheetId;
  final String? timesheetNumber;
  final String? siteName;
  final String? trade;

  /// Null on a line the owner wrote, or a credit for an amount.
  final RateBasis? basis;

  /// Minutes of hours, half days, half shifts, workers on a monthly fee, or items.
  final int quantity;
  final int unitPriceFils;
  final int amountFils;
  final int discountFils;
  final String? fromDate;
  final String? toDate;
  final LineTax tax;

  /// Set once issued, as it was printed, and on a line the owner wrote.
  final String? description;

  /// The timesheet rows a draft line would charge.
  final List<TimesheetLine> sources;

  bool get isFee => basis != null && isPeriodBasis(basis!);
  bool get isItem => basis == null;
}

/// A timesheet a draft reads from, and what it holds in the draft's dates.
class InvoiceSource {
  const InvoiceSource({required this.timesheet, required this.skipped, required this.ready, required this.disputed, required this.changed});

  final Timesheet timesheet;
  final bool skipped;

  /// Rows that would go on.
  final int ready;

  /// Rows waiting for the company's answer or a new revision.
  final int disputed;
  final int changed;
}

/// One invoice or credit note as the screen and the paper show it. Totals always derive from its lines (REP-08).
class InvoiceView {
  const InvoiceView({
    required this.invoice,
    required this.client,
    required this.siteName,
    required this.lines,
    required this.sources,
    required this.vatRegistered,
    required this.parties,
    this.creditNotes = const [],
    this.credited = const LineTax(netFils: 0, vatFils: 0),
    this.original,
    this.changes = const [],
    this.money,
    this.receipts = const [],
    this.clientCreditFils = 0,
  });

  final Invoice invoice;
  final Client client;
  final String? siteName;
  final List<InvoiceLineView> lines;

  /// Only a draft has any.
  final List<InvoiceSource> sources;

  /// For a draft, whether VAT would be charged if it were issued today.
  final bool vatRegistered;

  /// Both parties as issued, or as they stand today for a draft.
  final InvoiceParties parties;

  /// The credit notes that took this invoice back, in part or whole, oldest first.
  final List<Invoice> creditNotes;

  /// What they took back between them.
  final LineTax credited;

  /// The invoice this credit note took back.
  final Invoice? original;

  /// Work this invoice charged whose timesheet now says another figure. A credit note and a new invoice put it right.
  final List<BillingChange> changes;

  /// What was received on an issued invoice and what is still owed. Null on a draft or a credit note.
  final InvoiceMoney? money;

  /// The receipts that settled it, each with what of it went here, oldest first.
  final List<({CashEntry receipt, int fils})> receipts;

  /// The company's money received and set against nothing yet, which this invoice could use (INV-05).
  final int clientCreditFils;

  InvoiceStatus get status => InvoiceStatus.values.byName(invoice.status);
  bool get isCreditNote => invoice.kind == 'credit';
  VatCategory get category => VatCategory.values.byName(invoice.vatCategory);
  int get bps => status != InvoiceStatus.draft ? invoice.vatBps : (vatRegistered ? vatBpsOf(category) : 0);
  bool get taxInvoice => isTaxInvoice(category, registered: vatRegistered);
  LineTax get totals => invoiceTotals(lines.map((l) => l.tax));

  /// What is left of an invoice once its credit notes are taken off.
  int get leftFils => totals.totalFils - credited.totalFils;
}

/// Who an invoice is from and to, as it stood on the day it issued (INV-02).
class InvoiceParties {
  const InvoiceParties({required this.supplierName, required this.supplierAddress, required this.supplierTrn, required this.customerName, required this.customerAddress, required this.customerTrn, required this.bankDetails});

  factory InvoiceParties.fromJson(String json) {
    final j = (jsonDecode(json) as Map<String, Object?>).cast<String, String?>();
    return InvoiceParties(
      supplierName: j['supplierName'] ?? '',
      supplierAddress: j['supplierAddress'],
      supplierTrn: j['supplierTrn'],
      customerName: j['customerName'] ?? '',
      customerAddress: j['customerAddress'],
      customerTrn: j['customerTrn'],
      bankDetails: j['bankDetails'],
    );
  }

  final String supplierName;
  final String? supplierAddress;
  final String? supplierTrn;
  final String customerName;
  final String? customerAddress;
  final String? customerTrn;
  final String? bankDetails;

  String toJson() => jsonEncode({
    'supplierName': supplierName,
    'supplierAddress': supplierAddress,
    'supplierTrn': supplierTrn,
    'customerName': customerName,
    'customerAddress': customerAddress,
    'customerTrn': customerTrn,
    'bankDetails': bankDetails,
  });
}

/// One line of the list of invoices.
class InvoiceListRow {
  const InvoiceListRow({required this.invoice, required this.clientName, required this.totalFils, this.money});

  final Invoice invoice;
  final String clientName;

  /// Null on a draft, whose lines are not fixed yet.
  final int? totalFils;

  /// What is received and still owed, on an issued invoice.
  final InvoiceMoney? money;
}

/// INV-2026-0012, or CN-2026-0003 for a credit note. Counted by year on this phone (INV-08).
/// ponytail: T25 must give Team tenants server-issued numbers before a second device can issue.
String invoiceNumber(String prefix, int year, int seq) => '$prefix-$year-${seq.toString().padLeft(4, '0')}';

const creditNotePrefix = 'CN';

extension InvoiceOps on TenantDatabase {
  Future<Invoice> _invoice(String id) => (select(invoices)..where((i) => i.id.equals(id))).getSingle();

  /// The timesheets of this company that cover some of these dates and have a number, so were approved once.
  Future<List<Timesheet>> _timesheetsFor(Invoice inv) => (select(timesheets)
        ..where(
          (t) =>
              t.clientId.equals(inv.clientId) &
              t.number.isNotNull() &
              t.fromDate.isSmallerOrEqualValue(inv.toDate) &
              t.toDate.isBiggerOrEqualValue(inv.fromDate) &
              (inv.siteId == null ? const Constant(true) : (t.siteId.isNull() | t.siteId.equals(inv.siteId!))),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.fromDate), (t) => OrderingTerm.asc(t.seq)]))
      .get();

  /// What a draft would hold if issued now (TS-05, TS-08). One line per timesheet, site, trade, unit and rate, charging
  /// the sum of its rows, each rounded on its own (D-101). A monthly contract is one line a month at its fee, which the
  /// owner can change; its rows go on record at 0 so the fee can't be charged twice.
  Future<(List<InvoiceLineView>, List<InvoiceSource>)> _draftLines(Invoice inv, {required int bps}) async {
    final draft = InvoiceDraft.fromJson(inv.draft);
    final sheets = await _timesheetsFor(inv);
    final all = sheets.isEmpty ? const <BillableLine>[] : await billableLines(sheets.map((t) => t.id), from: inv.fromDate, to: inv.toDate, siteId: inv.siteId);
    final byKey = <String, List<TimesheetLine>>{};
    final sources = <InvoiceSource>[];
    for (final t in sheets) {
      final mine = all.where((b) => b.line.timesheetId == t.id).toList();
      final ready = mine.where((b) => b.hold == null).toList();
      int count(BillHold h) => mine.where((b) => b.hold == h).length;
      if (ready.isEmpty && count(BillHold.disputed) == 0 && count(BillHold.changed) == 0) continue;
      final skipped = draft.skipped.contains(t.id);
      sources.add(InvoiceSource(timesheet: t, skipped: skipped, ready: ready.length, disputed: count(BillHold.disputed), changed: count(BillHold.changed)));
      if (skipped) continue;
      for (final b in ready) {
        final l = b.line;
        // One fee a month, whichever timesheets hold its work (TS-08).
        final key = l.amountFils == null ? 'fee|${l.basis}|${l.rateFils}|${l.workDate.substring(0, 7)}' : 'ts|${t.id}|${l.siteId}|${l.trade ?? ''}|${l.basis}|${l.rateFils}';
        (byKey[key] ??= []).add(l);
      }
    }
    final numbers = {for (final t in sheets) t.id: t.number};
    final lines = [
      for (final MapEntry(:key, value: rows) in byKey.entries)
        () {
          final first = rows.first;
          final basis = RateBasis.values.byName(first.basis);
          final dates = rows.map((l) => l.workDate).toList()..sort();
          final sites = rows.map((l) => l.siteName).toSet();
          final persons = rows.map((l) => l.workerId).toSet().length;
          final units = rows.fold(const TsUnits(), (total, l) => total + unitsOf(_tsLine(l)));
          final amount = isPeriodBasis(basis) ? draft.fees[key] ?? clientMonthlyCharge(basis, rateFils: first.rateFils, workerCount: persons) : rows.fold(0, (total, l) => total + l.amountFils!);
          final discount = draft.discounts[key] ?? 0;
          return InvoiceLineView(
            key: key,
            timesheetId: first.timesheetId,
            timesheetNumber: numbers[first.timesheetId],
            siteName: sites.length == 1 ? sites.single : null,
            trade: first.trade,
            basis: basis,
            quantity: switch (basis) {
              RateBasis.hour => units.minutes,
              RateBasis.day => units.dayHalves,
              RateBasis.shift => units.shiftHalves,
              RateBasis.monthFixed => 1,
              RateBasis.month || RateBasis.monthPerWorker => persons,
            },
            unitPriceFils: first.rateFils,
            amountFils: amount,
            discountFils: discount,
            fromDate: dates.first,
            toDate: dates.last,
            tax: lineTax(amount, discountFils: discount.clamp(0, amount), bps: bps, inclusive: inv.pricesIncludeVat),
            sources: rows,
          );
        }(),
    ];
    // By timesheet, work before its monthly fee, then by site and trade, as the owner reads them.
    int order(InvoiceLineView a, InvoiceLineView b) {
      for (final (x, y) in [(a.timesheetNumber ?? '', b.timesheetNumber ?? ''), (a.isFee ? '1' : '0', b.isFee ? '1' : '0'), (a.siteName ?? '', b.siteName ?? ''), (a.trade ?? '', b.trade ?? ''), (a.key, b.key)]) {
        final c = x.compareTo(y);
        if (c != 0) return c;
      }
      return 0;
    }

    final items = [
      for (final item in draft.items)
        InvoiceLineView(
          key: item.key,
          timesheetId: null,
          timesheetNumber: null,
          siteName: null,
          trade: null,
          basis: null,
          quantity: item.quantity,
          unitPriceFils: item.unitPriceFils,
          amountFils: item.quantity * item.unitPriceFils,
          discountFils: 0,
          fromDate: null,
          toDate: null,
          tax: lineTax(item.quantity * item.unitPriceFils, bps: bps, inclusive: inv.pricesIncludeVat),
          description: item.description,
        ),
    ];
    // Lines the owner wrote come last, in the order written.
    return ([...lines..sort(order), ...items], sources);
  }

  TsLine _tsLine(TimesheetLine l) => TsLine(
    workDate: l.workDate,
    siteId: l.siteId,
    workerId: l.workerId,
    trade: l.trade,
    status: AttendanceStatus.values.byName(l.attendanceStatus),
    clockMinutes: l.clockMinutes,
    breakMinutes: l.breakMinutes,
    billableMinutes: l.billableMinutes,
    basis: RateBasis.values.byName(l.basis),
    rateFils: l.rateFils,
    amountFils: l.amountFils,
  );

  /// Whether the company charges VAT today, and both parties as they stand.
  Future<(bool, InvoiceParties)> _partiesToday(Client client) async {
    final p = await select(tenantProfiles).getSingleOrNull();
    final registered = vatRegisteredOn(dubaiToday(DateTime.now()), registered: p?.vatRegistered ?? false, effectiveFrom: p?.vatEffectiveFrom);
    return (
      registered,
      InvoiceParties(
        supplierName: p?.legalName ?? '',
        supplierAddress: p?.address,
        supplierTrn: p?.trn,
        customerName: client.name,
        customerAddress: client.invoiceAddress ?? client.address,
        customerTrn: client.trn,
        bankDetails: p?.bankDetails,
      ),
    );
  }

  Future<InvoiceView> invoiceView(String id) async {
    final inv = await _invoice(id);
    final client = await (select(clients)..where((c) => c.id.equals(inv.clientId))).getSingle();
    final site = inv.siteId == null ? null : await (select(sites)..where((s) => s.id.equals(inv.siteId!))).getSingle();
    final original = inv.creditsInvoiceId == null ? null : await _invoice(inv.creditsInvoiceId!);

    if (inv.status == InvoiceStatus.draft.name) {
      final (registered, parties) = await _partiesToday(client);
      final (lines, sources) = await _draftLines(inv, bps: registered ? vatBpsOf(VatCategory.values.byName(inv.vatCategory)) : 0);
      return InvoiceView(invoice: inv, client: client, siteName: site?.name, lines: lines, sources: sources, vatRegistered: registered, parties: parties);
    }
    final stored = await (select(invoiceLines)
          ..where((l) => l.invoiceId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.position)]))
        .get();
    final numbers = {for (final t in await (select(timesheets)..where((t) => t.id.isIn(stored.map((l) => l.timesheetId).nonNulls))).get()) t.id: t.number};
    final notes = await (select(invoices)
          ..where((i) => i.creditsInvoiceId.equals(id))
          ..orderBy([(i) => OrderingTerm.asc(i.year), (i) => OrderingTerm.asc(i.seq)]))
        .get();
    final money = inv.kind == 'invoice' ? await receivables(clientId: inv.clientId) : null;
    final paid = <String, int>{};
    for (final a in money?.parts ?? const <InvoiceAllocation>[]) {
      if (a.invoiceId == id && a.paymentId != null) paid[a.paymentId!] = (paid[a.paymentId!] ?? 0) + a.amountFils;
    }
    return InvoiceView(
      invoice: inv,
      client: client,
      siteName: site?.name,
      lines: [
        for (final l in stored)
          InvoiceLineView(
            key: l.id,
            timesheetId: l.timesheetId,
            timesheetNumber: numbers[l.timesheetId],
            siteName: null,
            trade: null,
            basis: basisOf(l.basis),
            quantity: l.quantity,
            unitPriceFils: l.unitPriceFils,
            amountFils: l.amountFils,
            discountFils: l.discountFils,
            fromDate: null,
            toDate: null,
            tax: LineTax(netFils: l.netFils, vatFils: l.vatFils),
            description: l.description,
          ),
      ],
      sources: const [],
      vatRegistered: inv.vatRegistered,
      parties: InvoiceParties.fromJson(inv.parties!),
      creditNotes: notes,
      credited: await _creditedBy(notes),
      original: original,
      changes: inv.kind == 'invoice' ? await billingChanges(invoiceId: id) : const [],
      money: money?.invoices[id],
      receipts: [
        for (final MapEntry(:key, :value) in paid.entries)
          if (value > 0) (receipt: money!.receipts[key]!.receipt, fils: value),
      ]..sort((a, b) => a.receipt.entryDate.compareTo(b.receipt.entryDate)),
      clientCreditFils: money?.creditOf(inv.clientId) ?? 0,
    );
  }

  /// What these credit notes took back between them.
  Future<LineTax> _creditedBy(List<Invoice> notes) async {
    if (notes.isEmpty) return const LineTax(netFils: 0, vatFils: 0);
    final lines = await (select(invoiceLines)..where((l) => l.invoiceId.isIn(notes.map((n) => n.id)))).get();
    return invoiceTotals(lines.map((l) => LineTax(netFils: l.netFils, vatFils: l.vatFils)));
  }

  /// Sends a fresh copy whenever anything behind it changes.
  Stream<InvoiceView> watchInvoice(String id) async* {
    yield await invoiceView(id);
    final changes = tableUpdates(
      TableUpdateQuery.onAllTables([invoices, invoiceLines, billedAllocations, timesheets, timesheetRevisions, timesheetLines, attendanceEntries, tenantProfiles, clients, invoiceAllocations, cashEntries]),
    );
    await for (final _ in changes) {
      // A draft thrown away goes while the screen is closing.
      if (await (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull() == null) return;
      yield await invoiceView(id);
    }
  }

  /// Every invoice and credit note, newest first.
  Stream<List<InvoiceListRow>> watchInvoices() async* {
    Future<List<InvoiceListRow>> read() async {
      final names = {for (final c in await select(clients).get()) c.id: c.name};
      final l = invoiceLines;
      final net = l.netFils.sum();
      final vat = l.vatFils.sum();
      final totals = <String, int>{
        for (final r in await (selectOnly(l)
              ..addColumns([l.invoiceId, net, vat])
              ..groupBy([l.invoiceId]))
            .get())
          r.read(l.invoiceId)!: (r.read(net) ?? 0) + (r.read(vat) ?? 0),
      };
      final rows = await (select(invoices)..orderBy([(i) => OrderingTerm.desc(i.createdAtUtc)])).get();
      final money = (await receivables()).invoices;
      return [for (final i in rows) InvoiceListRow(invoice: i, clientName: names[i.clientId] ?? '', totalFils: totals[i.id], money: money[i.id])];
    }

    yield await read();
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([invoices, invoiceLines, clients, invoiceAllocations, cashEntries]))) {
      yield await read();
    }
  }

  /// Starts a draft, if anything in these dates can still be billed. The company's own PO reference fills in.
  Future<String> createInvoice({required String clientId, String? siteId, required String from, required String to, required String operationId}) async {
    final client = await (select(clients)..where((c) => c.id.equals(clientId))).getSingle();
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        final now = DateTime.now().toUtc();
        await into(invoices).insert(
          InvoicesCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            clientId: clientId,
            siteId: Value(siteId),
            fromDate: from,
            toDate: to,
            poReference: Value(client.poReference),
          ),
        );
        final (lines, _) = await _draftLines(await _invoice(id), bps: 0);
        if (lines.isEmpty) throw const InvoiceRefused(InvoiceProblem.nothingToBill);
        return (await _invoice(id)).toJson();
      },
    );
    return id;
  }

  /// Saves a draft's choices. An issued invoice never changes (INV-06).
  Future<void> saveInvoiceDraft(String id, InvoicesCompanion fields, {required String operationId}) async {
    if ((await _invoice(id)).status != InvoiceStatus.draft.name) throw const InvoiceRefused(InvoiceProblem.wrongStep);
    await saveRow(invoices, id: id, fields: fields, operationId: operationId);
  }

  Future<void> deleteInvoiceDraft(String id, {required String operationId}) async {
    final inv = await (select(invoices)..where((i) => i.id.equals(id))).getSingleOrNull();
    if (inv == null) return;
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: id,
      version: inv.version + 1,
      action: 'delete',
      change: () async {
        if (inv.status != InvoiceStatus.draft.name) throw const InvoiceRefused(InvoiceProblem.wrongStep);
        await (delete(invoices)..where((i) => i.id.equals(id))).go();
        return {'id': id, 'deleted': true};
      },
    );
  }

  Future<int> _nextSeq(String kind, int year) async {
    final top = invoices.seq.max();
    final query = selectOnly(invoices)
      ..addColumns([top])
      ..where(invoices.kind.equals(kind) & invoices.year.equals(year));
    return ((await query.getSingle()).read(top) ?? 0) + 1;
  }

  /// Issues a draft: its number, its lines and both parties as they stand, and the work it charges, all in one
  /// transaction (INV-01, MODEL-07). It is dated today. [describe] words each line as it will print.
  Future<void> issueInvoice(String id, {required String Function(InvoiceLineView line) describe, required String operationId}) async {
    final before = await _invoice(id);
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: id,
      version: before.version + 1,
      action: 'issue',
      change: () async {
        final inv = await _invoice(id);
        if (inv.status != InvoiceStatus.draft.name) throw const InvoiceRefused(InvoiceProblem.wrongStep);
        final view = await invoiceView(id);
        if (view.lines.any((l) => l.discountFils > l.amountFils)) throw const InvoiceRefused(InvoiceProblem.discountTooBig);
        if (view.lines.isEmpty || view.totals.totalFils <= 0) throw const InvoiceRefused(InvoiceProblem.nothingToBill);
        final profile = await select(tenantProfiles).getSingleOrNull();
        if (profile == null || profile.legalName.trim().isEmpty) throw const InvoiceRefused(InvoiceProblem.noCompanyDetails);
        if (view.vatRegistered && (profile.trn ?? '').trim().isEmpty) throw const InvoiceRefused(InvoiceProblem.noTrn);

        final now = DateTime.now().toUtc();
        final today = dubaiToday(now);
        final year = int.parse(today.substring(0, 4));
        final seq = await _nextSeq('invoice', year);
        final dueDays = view.client.dueDays ?? profile.paymentTermsDays ?? 0;
        await _storeLines(id, view.lines, describe: describe, operationId: operationId);
        await (update(invoices)..where((i) => i.id.equals(id))).write(
          InvoicesCompanion(
            status: Value(InvoiceStatus.issued.name),
            issueDate: Value(today),
            // A due date picked in the draft can't fall before the day it issues.
            dueDate: Value(inv.dueDate == null || inv.dueDate!.compareTo(today) < 0 ? addDays(today, dueDays) : inv.dueDate),
            year: Value(year),
            seq: Value(seq),
            number: Value(invoiceNumber(profile.invoicePrefix, year, seq)),
            vatRegistered: Value(view.vatRegistered),
            vatBps: Value(view.bps),
            parties: Value(view.parties.toJson()),
            version: Value(inv.version + 1),
            updatedAtUtc: Value(now),
            sourceOperationId: Value(operationId),
          ),
        );
        await allocateBilling(id, [for (final l in view.lines) ...l.sources], operationId: newUuid());
        return {'invoice': (await _invoice(id)).toJson(), 'lines': [for (final l in await (select(invoiceLines)..where((l) => l.invoiceId.equals(id))).get()) l.toJson()]};
      },
    );
  }

  Future<void> _storeLines(String invoiceId, List<InvoiceLineView> lines, {required String Function(InvoiceLineView line) describe, required String operationId}) {
    final now = DateTime.now().toUtc();
    return batch((b) {
      b.insertAll(invoiceLines, [
        for (final (i, l) in lines.indexed)
          InvoiceLinesCompanion.insert(
            id: newUuid(),
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            invoiceId: invoiceId,
            position: i + 1,
            timesheetId: Value(l.timesheetId),
            description: l.description ?? describe(l),
            basis: l.basis?.name ?? itemBasis,
            quantity: l.quantity,
            unitPriceFils: l.unitPriceFils,
            amountFils: l.amountFils,
            discountFils: Value(l.discountFils),
            netFils: l.tax.netFils,
            vatFils: l.tax.vatFils,
          ),
      ]);
    });
  }

  /// Takes back an issued invoice with a credit note dated today, CN-2026-0003 (INV-06). Whole, it carries the same
  /// lines and VAT, or one line for what earlier credit notes left, and the work it charged can go on a new invoice.
  /// For [amountFils], before VAT unless the invoice's prices include it, it is one line worded as [reason], and the
  /// work stays charged. The invoice itself stays as issued.
  Future<String> creditInvoice(String id, {required String reason, int? amountFils, required String operationId}) async {
    final creditId = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: creditId,
      version: 1,
      action: 'credit',
      reason: reason,
      change: () async {
        final inv = await _invoice(id);
        if (inv.status != InvoiceStatus.issued.name || inv.kind != 'invoice') throw const InvoiceRefused(InvoiceProblem.wrongStep);
        final view = await invoiceView(id);
        InvoiceLineView single(LineTax tax) => InvoiceLineView(
          key: '',
          timesheetId: null,
          timesheetNumber: null,
          siteName: null,
          trade: null,
          basis: null,
          quantity: 1,
          unitPriceFils: inv.pricesIncludeVat ? tax.totalFils : tax.netFils,
          amountFils: inv.pricesIncludeVat ? tax.totalFils : tax.netFils,
          discountFils: 0,
          fromDate: null,
          toDate: null,
          tax: tax,
          description: reason,
        );
        final left = LineTax(netFils: view.totals.netFils - view.credited.netFils, vatFils: view.totals.vatFils - view.credited.vatFils);
        final whole = amountFils == null;
        final lines = switch (amountFils) {
          null when view.creditNotes.isEmpty => view.lines,
          null => [single(left)],
          final int fils => [single(lineTax(fils, bps: inv.vatBps, inclusive: inv.pricesIncludeVat))],
        };
        final taken = invoiceTotals(lines.map((l) => l.tax)).totalFils;
        if (taken <= 0 || taken > left.totalFils) throw const InvoiceRefused(InvoiceProblem.creditTooBig);

        final now = DateTime.now().toUtc();
        final today = dubaiToday(now);
        final year = int.parse(today.substring(0, 4));
        final seq = await _nextSeq('credit', year);
        await into(invoices).insert(
          InvoicesCompanion.insert(
            id: creditId,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            clientId: inv.clientId,
            kind: const Value('credit'),
            status: Value(InvoiceStatus.issued.name),
            creditsInvoiceId: Value(id),
            siteId: Value(inv.siteId),
            fromDate: inv.fromDate,
            toDate: inv.toDate,
            poReference: Value(inv.poReference),
            vatCategory: Value(inv.vatCategory),
            vatBps: Value(inv.vatBps),
            pricesIncludeVat: Value(inv.pricesIncludeVat),
            vatRegistered: Value(inv.vatRegistered),
            issueDate: Value(today),
            year: Value(year),
            seq: Value(seq),
            number: Value(invoiceNumber(creditNotePrefix, year, seq)),
            parties: Value(inv.parties),
            reason: Value(reason),
          ),
        );
        await _storeLines(creditId, lines, describe: (l) => l.description!, operationId: operationId);
        await releaseOverpaid(inv, creditNumber: invoiceNumber(creditNotePrefix, year, seq), operationId: operationId);
        if (whole) {
          // The issued row itself is the one other write: the status trigger lets nothing else through.
          await (update(invoices)..where((i) => i.id.equals(id))).write(
            InvoicesCompanion(status: Value(InvoiceStatus.credited.name), version: Value(inv.version + 1), updatedAtUtc: Value(now)),
          );
          await releaseBilling(id, reason: reason, operationId: newUuid());
        }
        return (await _invoice(creditId)).toJson();
      },
    );
    return creditId;
  }

  /// The timesheet revisions an invoice charged, to send with it (TS-07).
  Future<List<TimesheetRevision>> billedRevisions(String invoiceId) async {
    final b = billedAllocations;
    final l = timesheetLines;
    final query = selectOnly(b, distinct: true).join([innerJoin(l, l.id.equalsExp(b.lineId))])
      ..addColumns([l.revisionId])
      ..where(b.invoiceId.equals(invoiceId));
    final ids = [for (final r in await query.get()) r.read(l.revisionId)!];
    return (select(timesheetRevisions)..where((r) => r.id.isIn(ids))).get();
  }

  /// Companies with work up to [to], after [after], that no invoice charges yet, each with the month it falls in (D-048).
  Future<Set<(String, String)>> uninvoicedWork({required String to, String? after}) async => {
    for (final w in await workCharges(to: to, after: after))
      if (w.rated && !w.settled) (w.clientId, w.workDate.substring(0, 7)),
  };

  /// Every live row of work from [from] to [to], or after [after], and the invoice that charges it (REP-01, D-048).
  /// A row agreed or rated at nothing has nothing to charge, so it counts as settled. A row with no company rate can't be
  /// charged yet, and says so.
  Future<List<WorkCharge>> workCharges({String? from, String? to, String? after}) async {
    final e = attendanceEntries;
    Expression<bool> limit(Expression<bool> Function(String) test, String? value) => value == null ? const Constant(true) : test(value);
    final rows = await (selectOnly(e)
          ..addColumns([e.id, e.revisesEntryId, e.clientId, e.siteId, e.workerId, e.workDate, e.clientBillableMinutes, e.clientAmountFils, e.clientRateFils, e.clientBasis])
          ..where(
            e.superseded.equals(false) &
                limit(e.workDate.isBiggerOrEqualValue, from) &
                limit(e.workDate.isSmallerOrEqualValue, to) &
                limit(e.workDate.isBiggerThanValue, after) &
                e.attendanceStatus.equals(AttendanceStatus.absent.name).not(),
          ))
        .get();
    if (rows.isEmpty) return const [];

    // A corrected row is still the same work, so it is known by the first row of its chain (TS-05).
    final parent = {for (final r in rows) r.read(e.id)!: r.read(e.revisesEntryId)};
    var missing = parent.values.nonNulls.where((p) => !parent.containsKey(p)).toSet();
    while (missing.isNotEmpty) {
      final found = await (selectOnly(e)
            ..addColumns([e.id, e.revisesEntryId])
            ..where(e.id.isIn(missing)))
          .get();
      for (final r in found) {
        parent[r.read(e.id)!] = r.read(e.revisesEntryId);
      }
      missing = {for (final r in found) ?r.read(e.revisesEntryId)}.difference(parent.keys.toSet());
    }
    String keyOf(String id) {
      var at = id;
      while (parent[at] != null) {
        at = parent[at]!;
      }
      return at;
    }

    final b = billedAllocations;
    final l = timesheetLines;
    final charged = {
      for (final r in await (selectOnly(b)
            ..addColumns([b.workKey, b.invoiceId])
            ..where(b.released.equals(false)))
          .get())
        r.read(b.workKey)!: r.read(b.invoiceId)!,
    };
    final agreedAtNothing = {
      for (final r in await (selectOnly(l)
            ..addColumns([l.workKey])
            ..where(l.live.equals(true) & l.amountFils.equals(0)))
          .get())
        r.read(l.workKey)!,
    };
    final periodBases = [for (final b in RateBasis.values) if (isPeriodBasis(b)) b.name];
    final fees = await feesCharged();
    return [
      for (final r in rows)
        () {
          final key = keyOf(r.read(e.id)!);
          final amount = r.read(e.clientAmountFils) ?? 0;
          final rated = r.read(e.clientRateFils) != null;
          final basis = r.read(e.clientBasis);
          final monthly = basis != null && periodBases.contains(basis);
          final chargeable = rated && (amount > 0 || monthly);
          final feeCharged = monthly && fees.contains(feeCover(r.read(e.clientId)!, basis, r.read(e.workDate)!, r.read(e.workerId)!));
          return (
            clientId: r.read(e.clientId)!,
            siteId: r.read(e.siteId)!,
            workDate: r.read(e.workDate)!,
            minutes: r.read(e.clientBillableMinutes) ?? 0,
            amountFils: amount,
            rated: rated,
            invoiceId: charged[key],
            settled: charged.containsKey(key) || feeCharged || agreedAtNothing.contains(key) || (rated && !chargeable),
          );
        }(),
    ];
  }
}

/// One row of work as billing sees it: [rated] when the company has a rate for it, [invoiceId] when an invoice charges it,
/// [settled] when nothing more is to be charged.
typedef WorkCharge = ({String clientId, String siteId, String workDate, int minutes, int amountFils, bool rated, String? invoiceId, bool settled});

/// How many of a line's unit it bills, as printed: 525.50 hours, 12.5 days, 3 workers.
String quantityText(RateBasis? basis, int quantity) => switch (basis) {
  null => '$quantity',
  RateBasis.hour => '${quantity ~/ 60}.${divRoundHalfUp(quantity % 60 * 100, 60).toString().padLeft(2, '0')}',
  RateBasis.day || RateBasis.shift => showHalves(quantity),
  RateBasis.month || RateBasis.monthPerWorker || RateBasis.monthFixed => '$quantity',
};
