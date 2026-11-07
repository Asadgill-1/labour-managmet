import 'dart:math';

/// What a line of the daily cash book is. Stored by name. Each kind says where the money belongs (D-030).
enum CashKind { advanceGiven, salaryPaid, roomRentPaid, expense, advanceReturned, roomRentReceived, clientReceipt, visaPaid, visaReturned }

bool isMoneyIn(CashKind kind) => const {CashKind.advanceReturned, CashKind.roomRentReceived, CashKind.clientReceipt, CashKind.visaReturned}.contains(kind);

/// One stored row, for the sums below. A reversal cancels its original exactly (REP-08).
class CashLine {
  const CashLine(this.kind, this.amountFils, {this.reversal = false});

  final CashKind kind;
  final int amountFils;
  final bool reversal;

  int get signedFils => reversal ? -amountFils : amountFils;
}

int _sum(Iterable<CashLine> lines, Set<CashKind> kinds) {
  return lines.where((l) => kinds.contains(l.kind)).fold(0, (total, l) => total + l.signedFils);
}

/// Money in and out across these lines. Money is not revenue or expense here: it is cash flow only (REP-02).
({int inFils, int outFils}) cashTotals(Iterable<CashLine> lines) {
  final moneyIn = lines.where((l) => isMoneyIn(l.kind)).fold(0, (total, l) => total + l.signedFils);
  final moneyOut = lines.where((l) => !isMoneyIn(l.kind)).fold(0, (total, l) => total + l.signedFils);
  return (inFils: moneyIn, outFils: moneyOut);
}

/// outstanding = opening + issued - returned - recovered through posted payroll (PAY-05).
int advanceOutstanding(int openingFils, Iterable<CashLine> lines, {int recoveredFils = 0}) {
  return openingFils + _sum(lines, const {CashKind.advanceGiven}) - _sum(lines, const {CashKind.advanceReturned}) - recoveredFils;
}

/// What payroll cuts by itself this month from a worker's advances, oldest first (D-057). What was handed back or
/// recovered pays off the oldest advance first. An advance with an instalment gives that much, or what is left of it if
/// less. [askFils] is what is left on advances with none, for the owner to say how much of it to cut.
({int instalmentFils, int askFils}) advanceInstalments(Iterable<({int amountFils, int? instalmentFils})> advances, {required int paidBackFils}) {
  var back = paidBackFils;
  var instalment = 0;
  var ask = 0;
  for (final a in advances) {
    final used = min(back, a.amountFils);
    back -= used;
    final left = a.amountFils - used;
    if (left <= 0) continue;
    if (a.instalmentFils case final each?) {
      instalment += min(each, left);
    } else {
      ask += left;
    }
  }
  return (instalmentFils: instalment, askFils: ask);
}

int visaPaidTotal(Iterable<CashLine> lines) => _sum(lines, const {CashKind.visaPaid});

int visaReturnedTotal(Iterable<CashLine> lines) => _sum(lines, const {CashKind.visaReturned});

/// left = paid - handed back - recovered through posted payroll (D-039).
int visaOutstanding(Iterable<CashLine> lines, {int recoveredFils = 0}) => visaPaidTotal(lines) - visaReturnedTotal(lines) - recoveredFils;

int salaryPaidTotal(Iterable<CashLine> lines) => _sum(lines, const {CashKind.salaryPaid});

/// Rent received against rent paid. Both stay separate entries and are only netted here, under this label (REP-07).
/// [deductedFils] is room charge taken through posted payroll, which is rent received without any cash moving (D-031).
({int receivedFils, int paidFils, int netFils}) roomResult(Iterable<CashLine> lines, {int deductedFils = 0}) {
  final received = _sum(lines, const {CashKind.roomRentReceived}) + deductedFils;
  final paid = _sum(lines, const {CashKind.roomRentPaid});
  return (receivedFils: received, paidFils: paid, netFils: received - paid);
}
