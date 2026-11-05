import 'package:domain/invoice.dart';
import 'package:test/test.dart';

void main() {
  group('PRD fixtures (INV-04)', () {
    test('exclusive: 1,100 at 5% is 55 VAT, 1,155 in all', () {
      final t = lineTax(110000, bps: 500, inclusive: false);
      expect((t.netFils, t.vatFils, t.totalFils), (110000, 5500, 115500));
    });

    test('inclusive: 105 at 5% is 100 taxable and 5 VAT', () {
      final t = lineTax(10500, bps: 500, inclusive: true);
      expect((t.netFils, t.vatFils, t.totalFils), (10000, 500, 10500));
    });
  });

  test('VAT rounds half-up on each line', () {
    expect(lineTax(10, bps: 500, inclusive: false).vatFils, 1, reason: '0.5 fils goes up');
    expect(lineTax(9, bps: 500, inclusive: false).vatFils, 0);
  });

  test('inclusive parts always add back to what was charged', () {
    for (final gross in [1, 7, 99, 10001, 123457]) {
      expect(lineTax(gross, bps: 500, inclusive: true).totalFils, gross);
    }
  });

  test('a discount comes off before VAT', () {
    final t = lineTax(110000, discountFils: 10000, bps: 500, inclusive: false);
    expect((t.netFils, t.vatFils), (100000, 5000));
  });

  test('the total is the sum of the lines, not VAT on the total (D-101)', () {
    final lines = [lineTax(10, bps: 500, inclusive: false), lineTax(10, bps: 500, inclusive: false)];
    expect(invoiceTotals(lines).vatFils, 2, reason: 'VAT on 20 fils would be 1');
    expect(invoiceTotals(lines).totalFils, 22);
  });

  test('only standard-rated supply charges VAT', () {
    expect(vatBpsOf(VatCategory.standard), 500);
    for (final c in [VatCategory.zeroRated, VatCategory.exempt, VatCategory.outOfScope]) {
      expect(vatBpsOf(c), 0);
    }
  });

  test('registration counts from its effective date', () {
    expect(vatRegisteredOn('2026-11-04', registered: false), isFalse);
    expect(vatRegisteredOn('2026-11-04', registered: true), isTrue);
    expect(vatRegisteredOn('2026-11-04', registered: true, effectiveFrom: '2026-12-01'), isFalse);
    expect(vatRegisteredOn('2026-12-01', registered: true, effectiveFrom: '2026-12-01'), isTrue);
  });

  test('"Tax Invoice" only from a registered supplier on a taxable supply (INV-02)', () {
    expect(isTaxInvoice(VatCategory.standard, registered: true), isTrue);
    expect(isTaxInvoice(VatCategory.zeroRated, registered: true), isTrue);
    expect(isTaxInvoice(VatCategory.exempt, registered: true), isFalse);
    expect(isTaxInvoice(VatCategory.outOfScope, registered: true), isFalse);
    expect(isTaxInvoice(VatCategory.standard, registered: false), isFalse);
  });

  group('how an issued invoice stands (INV-05, INV-07)', () {
    PayState state(int left, {int received = 0, int lost = 0, String today = '2026-11-10'}) =>
        payState(leftFils: left, receivedFils: received, lostFils: lost, dueDate: '2026-11-10', today: today);

    test('the PRD receipt: 1,155 with 500 received leaves 655, partly paid until it falls due', () {
      expect(115500 - 50000, 65500);
      expect(state(65500, received: 50000), PayState.partlyPaid);
      expect(state(65500, received: 50000, today: '2026-11-11'), PayState.overdue);
    });

    test('nothing received is unpaid, and overdue only the day after its due date', () {
      expect(state(115500), PayState.unpaid);
      expect(state(115500, today: '2026-11-11'), PayState.overdue);
    });

    test('nothing left is paid, or closed once the owner wrote part off (D-048)', () {
      expect(state(0, received: 115500, today: '2027-01-01'), PayState.paid);
      expect(state(0, received: 40000, lost: 60000, today: '2027-01-01'), PayState.closed);
    });
  });
}
