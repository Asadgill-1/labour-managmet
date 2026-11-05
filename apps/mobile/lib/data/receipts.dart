import 'package:domain/cash.dart';
import 'package:domain/dates.dart';
import 'package:domain/invoice.dart';
import 'package:drift/drift.dart';

import 'invoices.dart';
import 'masters.dart';
import 'tenant_database.dart';

/// More than an invoice, or the company's balance from before the app, still has left, or more than the receipt holds,
/// or nothing at all (INV-05). Nothing was written.
class ReceiptTooHigh implements Exception {
  const ReceiptTooHigh();
}

/// The money on one issued invoice, all derived from its lines, its credit notes and what settled it (REP-08).
class InvoiceMoney {
  const InvoiceMoney({required this.invoice, required this.totalFils, required this.creditedFils, required this.receivedFils, required this.lostFils});

  final Invoice invoice;
  final int totalFils;
  final int creditedFils;
  final int receivedFils;

  /// What the owner closed as lost (D-048).
  final int lostFils;

  int get leftFils => totalFils - creditedFils - receivedFils - lostFils;

  PayState state(String today) => payState(leftFils: leftFils, receivedFils: receivedFils, lostFils: lostFils, dueDate: invoice.dueDate!, today: today);
}

/// One receipt still standing in the cash book, and what of it is set against nothing yet.
typedef ReceiptLeft = ({CashEntry receipt, int unusedFils});

/// What companies owe and hold, as the stored rows say (INV-05, INV-07).
class Receivables {
  const Receivables({required this.invoices, required this.openingFils, required this.openingLeftFils, required this.receipts, required this.parts});

  /// Every issued invoice by id. Credit notes are counted on the invoice they took back.
  final Map<String, InvoiceMoney> invoices;

  /// Each company's balance from before the app, and what is left of it.
  final Map<String, int> openingFils;
  final Map<String, int> openingLeftFils;

  /// Receipts still standing, by id.
  final Map<String, ReceiptLeft> receipts;

  /// The rows that count: receipts still standing, and what the owner closed.
  final List<InvoiceAllocation> parts;

  /// Received and not yet set against anything. It waits for the next invoice (INV-05).
  int creditOf(String clientId) => receipts.values.where((r) => r.receipt.clientId == clientId).fold(0, (total, r) => total + r.unusedFils);

  /// What a company still owes, oldest first: its balance from before the app, then invoices by due date.
  List<OpenItem> openOf(String clientId) => [
    if ((openingLeftFils[clientId] ?? 0) > 0) (invoiceId: null, number: null, dueDate: null, leftFils: openingLeftFils[clientId]!),
    for (final m in invoices.values.where((m) => m.invoice.clientId == clientId && m.leftFils > 0).toList()
      ..sort((a, b) {
        final due = a.invoice.dueDate!.compareTo(b.invoice.dueDate!);
        return due != 0 ? due : a.invoice.number!.compareTo(b.invoice.number!);
      }))
      (invoiceId: m.invoice.id, number: m.invoice.number, dueDate: m.invoice.dueDate, leftFils: m.leftFils),
  ];
}

/// Something a company still owes: an invoice, or with no id its balance from before the app.
typedef OpenItem = ({String? invoiceId, String? number, String? dueDate, int leftFils});

/// What part of a receipt went on one invoice, or with no number on the balance from before the app.
typedef ReceiptPart = ({String? number, int fils});

extension ReceiptOps on TenantDatabase {
  /// Reads every company, or one. ponytail: adds up all of a company's history each time, which is a few thousand rows
  /// in years. Keep running totals if a phone shows lag.
  Future<Receivables> receivables({String? clientId}) async {
    Expression<bool> mine(GeneratedColumn<String> column) => clientId == null ? const Constant(true) : column.equals(clientId);

    final cash = await (select(cashEntries)..where((c) => c.kind.equals(CashKind.clientReceipt.name) & mine(c.clientId))).get();
    final undone = {for (final c in cash) ?c.reversesEntryId};
    final standing = {for (final c in cash.where((c) => c.reversesEntryId == null && !undone.contains(c.id))) c.id: c};
    final parts = [
      for (final a in await (select(invoiceAllocations)..where((a) => mine(a.clientId))).get())
        if (a.paymentId == null || standing.containsKey(a.paymentId)) a,
    ];

    final issued = await (select(invoices)..where((i) => mine(i.clientId) & i.status.equals(InvoiceStatus.draft.name).not())).get();
    final l = invoiceLines;
    final net = l.netFils.sum();
    final vat = l.vatFils.sum();
    final totals = <String, int>{
      for (final r in await (selectOnly(l)
            ..addColumns([l.invoiceId, net, vat])
            ..where(l.invoiceId.isIn(issued.map((i) => i.id)))
            ..groupBy([l.invoiceId]))
          .get())
        r.read(l.invoiceId)!: (r.read(net) ?? 0) + (r.read(vat) ?? 0),
    };
    final credited = <String, int>{};
    for (final c in issued.where((i) => i.kind == 'credit')) {
      credited[c.creditsInvoiceId!] = (credited[c.creditsInvoiceId!] ?? 0) + (totals[c.id] ?? 0);
    }
    int sum(Iterable<InvoiceAllocation> rows) => rows.fold(0, (total, a) => total + a.amountFils);
    final byInvoice = groupedBy(parts.where((a) => a.invoiceId != null), (a) => a.invoiceId!);

    final openings = await (select(openingBalances)..where((b) => b.kind.equals('client_receivable') & mine(b.clientId))).get();
    final openingFils = {for (final b in openings) b.clientId!: b.amountFils};
    final usedOnOpening = groupedBy(parts.where((a) => a.invoiceId == null), (a) => a.clientId);
    final byReceipt = groupedBy(parts.where((a) => a.paymentId != null), (a) => a.paymentId!);

    return Receivables(
      invoices: {
        for (final i in issued.where((i) => i.kind == 'invoice'))
          i.id: InvoiceMoney(
            invoice: i,
            totalFils: totals[i.id] ?? 0,
            creditedFils: credited[i.id] ?? 0,
            receivedFils: sum((byInvoice[i.id] ?? const []).where((a) => a.paymentId != null)),
            lostFils: sum((byInvoice[i.id] ?? const []).where((a) => a.paymentId == null)),
          ),
      },
      openingFils: openingFils,
      openingLeftFils: {for (final MapEntry(:key, :value) in openingFils.entries) key: value - sum(usedOnOpening[key] ?? const [])},
      receipts: {for (final c in standing.values) c.id: (receipt: c, unusedFils: c.amountFils - sum(byReceipt[c.id] ?? const []))},
      parts: parts,
    );
  }

  /// Sends a fresh reading whenever money or invoices change.
  Stream<Receivables> watchReceivables({String? clientId}) async* {
    yield await receivables(clientId: clientId);
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([invoices, invoiceLines, invoiceAllocations, cashEntries, openingBalances]))) {
      yield await receivables(clientId: clientId);
    }
  }

  Future<void> _allocate({required String operationId, required String clientId, required String? invoiceId, required String? paymentId, required String date, required int fils, String? reason}) {
    final now = DateTime.now().toUtc();
    return into(invoiceAllocations).insert(
      InvoiceAllocationsCompanion.insert(
        id: newUuid(),
        tenantId: tenantId,
        createdAtUtc: now,
        updatedAtUtc: now,
        actorId: actorId,
        sourceOperationId: operationId,
        clientId: clientId,
        invoiceId: Value(invoiceId),
        paymentId: Value(paymentId),
        entryDate: date,
        amountFils: fils,
        reason: Value(reason),
      ),
    );
  }

  /// Records a company's receipt and what it settles, together (INV-05, MODEL-07). [parts] is by invoice id, with null
  /// for the balance from before the app. Whatever they leave stays as the company's credit for later invoices, so the
  /// money is never counted as revenue twice. A retry changes nothing (TEAM-04).
  Future<String> addClientReceipt({
    required String operationId,
    required String date,
    required String clientId,
    required int amountFils,
    required Map<String?, int> parts,
    String method = 'cash',
    String? reference,
    String? note,
  }) async {
    final id = newUuid();
    await applyOperation(
      operationId: operationId,
      entity: 'cash_entries',
      recordId: id,
      version: 1,
      action: 'create',
      change: () async {
        final open = {for (final o in (await receivables(clientId: clientId)).openOf(clientId)) o.invoiceId: o.leftFils};
        final used = parts.values.fold(0, (total, fils) => total + fils);
        if (amountFils <= 0 || used > amountFils || parts.entries.any((p) => p.value <= 0 || p.value > (open[p.key] ?? 0))) throw const ReceiptTooHigh();
        final now = DateTime.now().toUtc();
        final row = await into(cashEntries).insertReturning(
          CashEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            createdAtUtc: now,
            updatedAtUtc: now,
            actorId: actorId,
            sourceOperationId: operationId,
            entryDate: date,
            kind: CashKind.clientReceipt.name,
            amountFils: amountFils,
            clientId: Value(clientId),
            method: Value(method),
            note: Value(note),
            reference: Value(reference),
          ),
        );
        for (final p in parts.entries) {
          await _allocate(operationId: operationId, clientId: clientId, invoiceId: p.key, paymentId: id, date: date, fils: p.value);
        }
        return {'receipt': row.toJson(), 'parts': {for (final p in parts.entries) p.key ?? 'opening': p.value}};
      },
    );
    return id;
  }

  /// Sets the company's unused credit against this invoice, oldest receipt first, up to what it still owes (INV-05).
  Future<void> useClientCredit(String invoiceId, {required String operationId}) async {
    final inv = await (select(invoices)..where((i) => i.id.equals(invoiceId))).getSingle();
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: invoiceId,
      version: inv.version,
      action: 'allocate',
      change: () async {
        final money = await receivables(clientId: inv.clientId);
        var left = money.invoices[invoiceId]?.leftFils ?? 0;
        final today = dubaiToday(DateTime.now());
        final taken = <String, int>{};
        final oldest = money.receipts.values.where((r) => r.receipt.clientId == inv.clientId && r.unusedFils > 0).toList()
          ..sort((a, b) {
            final date = a.receipt.entryDate.compareTo(b.receipt.entryDate);
            return date != 0 ? date : a.receipt.createdAtUtc.compareTo(b.receipt.createdAtUtc);
          });
        for (final r in oldest) {
          if (left <= 0) break;
          final fils = r.unusedFils < left ? r.unusedFils : left;
          await _allocate(operationId: operationId, clientId: inv.clientId, invoiceId: invoiceId, paymentId: r.receipt.id, date: today, fils: fils);
          taken[r.receipt.id] = fils;
          left -= fils;
        }
        if (taken.isEmpty) throw const ReceiptTooHigh();
        return {'invoice': invoiceId, 'parts': taken};
      },
    );
  }

  /// Closes what is left on an invoice as lost, with the owner's reason, so it no longer stops a month (D-048). The
  /// invoice stays as issued. VAT on the loss is for the accountant.
  Future<void> closeInvoiceAsLost(String invoiceId, {required String reason, required String operationId}) => _lost(invoiceId, reason: reason, operationId: operationId, closing: true);

  /// Opens a closing again, when money comes after all (D-048).
  Future<void> undoInvoiceLoss(String invoiceId, {required String reason, required String operationId}) => _lost(invoiceId, reason: reason, operationId: operationId, closing: false);

  Future<void> _lost(String invoiceId, {required String reason, required String operationId, required bool closing}) async {
    final inv = await (select(invoices)..where((i) => i.id.equals(invoiceId))).getSingle();
    await applyOperation(
      operationId: operationId,
      entity: 'invoices',
      recordId: invoiceId,
      version: inv.version,
      action: closing ? 'close' : 'reopen',
      reason: reason,
      change: () async {
        final money = (await receivables(clientId: inv.clientId)).invoices[invoiceId];
        final fils = money == null ? 0 : (closing ? money.leftFils : -money.lostFils);
        if (fils == 0 || (closing && fils < 0)) throw const InvoiceRefused(InvoiceProblem.wrongStep);
        await _allocate(operationId: operationId, clientId: inv.clientId, invoiceId: invoiceId, paymentId: null, date: dubaiToday(DateTime.now()), fils: fils, reason: reason);
        return {'invoice': invoiceId, 'lost': fils};
      },
    );
  }

  /// After a credit note, gives back whatever was settled beyond what the invoice now asks: first what was closed as
  /// lost, then the newest receipts, which become the company's credit (INV-05, INV-06). Runs inside the credit's own
  /// transaction.
  Future<void> releaseOverpaid(Invoice inv, {required String creditNumber, required String operationId}) async {
    final money = await receivables(clientId: inv.clientId);
    var over = -(money.invoices[inv.id]?.leftFils ?? 0);
    if (over <= 0) return;
    final today = dubaiToday(DateTime.now());
    final lost = money.invoices[inv.id]!.lostFils;
    if (lost > 0) {
      final fils = lost < over ? lost : over;
      await _allocate(operationId: operationId, clientId: inv.clientId, invoiceId: inv.id, paymentId: null, date: today, fils: -fils, reason: creditNumber);
      over -= fils;
    }
    final byReceipt = <String, int>{};
    for (final a in money.parts.where((a) => a.invoiceId == inv.id && a.paymentId != null)) {
      byReceipt[a.paymentId!] = (byReceipt[a.paymentId!] ?? 0) + a.amountFils;
    }
    final newest = byReceipt.keys.toList()..sort((a, b) => money.receipts[b]!.receipt.entryDate.compareTo(money.receipts[a]!.receipt.entryDate));
    for (final id in newest) {
      if (over <= 0) break;
      final on = byReceipt[id]!;
      if (on <= 0) continue;
      final fils = on < over ? on : over;
      await _allocate(operationId: operationId, clientId: inv.clientId, invoiceId: inv.id, paymentId: id, date: today, fils: -fils, reason: creditNumber);
      over -= fils;
    }
  }

  /// What a receipt settles now, by invoice number, with a null number for the balance from before the app. What a
  /// credit note gave back is already off. The rest of the receipt is the company's credit.
  Future<List<ReceiptPart>> receiptParts(String paymentId) async {
    final rows = await (select(invoiceAllocations)..where((a) => a.paymentId.equals(paymentId))).get();
    final numbers = {for (final i in await (select(invoices)..where((i) => i.id.isIn(rows.map((a) => a.invoiceId).nonNulls))).get()) i.id: i.number};
    final net = <String?, int>{};
    for (final a in rows) {
      net[a.invoiceId] = (net[a.invoiceId] ?? 0) + a.amountFils;
    }
    return [
      for (final MapEntry(:key, :value) in net.entries)
        if (value != 0) (number: key == null ? null : numbers[key], fils: value),
    ]..sort((a, b) => (a.number ?? '').compareTo(b.number ?? ''));
  }

  Stream<List<ReceiptPart>> watchReceiptParts(String paymentId) async* {
    yield await receiptParts(paymentId);
    await for (final _ in tableUpdates(TableUpdateQuery.onAllTables([invoiceAllocations]))) {
      yield await receiptParts(paymentId);
    }
  }
}
