import 'money.dart';

/// How a supply is treated for VAT (INV-03). Chosen per invoice by a VAT-registered supplier. A customer's TRN never
/// switches VAT on by itself.
enum VatCategory { standard, zeroRated, exempt, outOfScope }

/// The standard rate in basis points (INV-03). A tax reviewer confirms it.
const standardVatBps = 500;

/// Only a standard-rated supply charges VAT.
int vatBpsOf(VatCategory category) => category == VatCategory.standard ? standardVatBps : 0;

/// A supplier charges VAT from the date its registration takes effect (MASTER-01).
bool vatRegisteredOn(String date, {required bool registered, String? effectiveFrom}) => registered && (effectiveFrom == null || effectiveFrom.compareTo(date) <= 0);

/// "Tax Invoice" is printed only by a registered supplier on a taxable supply, standard or zero-rated (INV-02).
bool isTaxInvoice(VatCategory category, {required bool registered}) => registered && (category == VatCategory.standard || category == VatCategory.zeroRated);

/// One line's money once VAT is applied.
class LineTax {
  const LineTax({required this.netFils, required this.vatFils});

  final int netFils;
  final int vatFils;

  int get totalFils => netFils + vatFils;
}

/// VAT on one line, half-up to the fil (D-101). [amountFils] is the line's charge before its discount. When it already
/// holds the VAT, the VAT is what is left once the net is taken out, so the parts always add back to it exactly (INV-04).
LineTax lineTax(int amountFils, {int discountFils = 0, required int bps, required bool inclusive}) {
  final charged = amountFils - discountFils;
  if (!inclusive) return LineTax(netFils: charged, vatFils: divRoundHalfUp(charged * bps, 10000));
  final net = divRoundHalfUp(charged * 10000, 10000 + bps);
  return LineTax(netFils: net, vatFils: charged - net);
}

/// A document's totals are the sum of its lines, never VAT worked out again on the total (D-101).
LineTax invoiceTotals(Iterable<LineTax> lines) => LineTax(
  netFils: lines.fold(0, (total, l) => total + l.netFils),
  vatFils: lines.fold(0, (total, l) => total + l.vatFils),
);
