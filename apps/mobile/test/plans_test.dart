import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/plans.dart';

import 'cloud_fake.dart';

const company = '00000000-0000-4000-8000-0000000000c7';

final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 9]);
final pdf = Uint8List.fromList('%PDF-1.7 slip'.codeUnits);

void main() {
  late FakeCloud cloud;
  late FlutterSecureStorage storage;
  late Account account;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    cloud = FakeCloud()..addUser('owner@test.ae', 'pass1234', company: company);
    account = cloud.account(storage);
    await account.signIn('owner@test.ae', 'pass1234');
    await account.openCompany();
  });

  Future<AccountProblem?> problem(Future<void> Function() work) async {
    try {
      await work();
      return null;
    } on AccountRefused catch (e) {
      return e.problem;
    }
  }

  test('the plans on sale come in order, with prices in fils and null as unlimited', () async {
    final plans = await account.plans();
    expect(plans.map((p) => p.code), ['small', 'mid', 'large']);
    expect(plans.first, (code: 'small', name: 'Small Company Plan', priceFils: 19900, addonFils: 2000, workers: 15, clients: 5, managers: 1));
    expect(plans.last.workers, isNull);
    expect(plans.last.clients, isNull);
    final query = cloud.calls.lastWhere((c) => c.path == '/rest/v1/plans');
    expect(query.path, '/rest/v1/plans');
  });

  test('bank details show only the fields filled in', () async {
    cloud.bank = {'bank_name': 'Test Bank', 'account_number': '0123456789001', 'iban': null, 'account_holder': ' '};
    final bank = await account.bankDetails();
    expect(bank.bankName, 'Test Bank');
    expect(bank.accountNumber, '0123456789001');
    expect(bank.iban, isNull);
    expect(bank.holder, isNull, reason: 'blank is not filled');
    expect(bank.ready, isTrue);
    cloud.bank = {'bank_name': null, 'account_number': null, 'iban': null, 'account_holder': null};
    expect((await account.bankDetails()).ready, isFalse, reason: 'nothing to pay into yet');
  });

  test('a slip is told by its bytes: a photo or a PDF, nothing else', () {
    expect(slipKindOf(jpeg), SlipKind.jpg);
    expect(slipKindOf(png), SlipKind.png);
    expect(slipKindOf(pdf), SlipKind.pdf);
    expect(slipKindOf(Uint8List.fromList('PK zip'.codeUnits)), isNull);
    expect(slipKindOf(Uint8List(0)), isNull);
    expect(slipMaxBytes, 5242880);
  });

  test('sending a slip records it, then puts the file at the path the cloud gave', () async {
    await account.sendSlip(planCode: 'mid', months: 3, bytes: pdf, kind: SlipKind.pdf, operationId: 'op-1');
    final submit = cloud.calls.singleWhere((c) => c.path == '/rest/v1/rpc/submit_slip').body;
    expect(submit, {'p_tenant_id': company, 'p_plan_code': 'mid', 'p_months': 3, 'p_file_type': 'pdf', 'p_operation_id': 'op-1'});
    final path = cloud.slips.single['file_path'] as String;
    expect(path, startsWith('$company/'));
    expect(cloud.slipFiles[path], pdf.length);
    expect(cloud.slipTypes[path], 'application/pdf');

    final slips = await account.slips();
    expect(slips.single.planCode, 'mid');
    expect(slips.single.months, 3);
    expect(slips.single.expectedFils, 89700);
    expect(slips.single.state, 'waiting');
    expect(slips.single.fileArrived, isTrue);
  });

  test('a dropped upload is sent again to the same slip, and a file already there counts as sent', () async {
    cloud.uploadFails = true;
    expect(await problem(() => account.sendSlip(planCode: 'small', months: 1, bytes: jpeg, kind: SlipKind.jpg, operationId: 'op-2')), AccountProblem.offline);
    expect((await account.slips()).single.fileArrived, isFalse, reason: 'the slip waits, but its file did not arrive');

    cloud.uploadFails = false;
    await account.sendSlip(planCode: 'small', months: 1, bytes: jpeg, kind: SlipKind.jpg, operationId: 'op-2');
    expect(cloud.slips, hasLength(1), reason: 'the same operation id is the same slip');
    expect((await account.slips()).single.fileArrived, isTrue);

    await account.sendSlip(planCode: 'small', months: 1, bytes: jpeg, kind: SlipKind.jpg, operationId: 'op-2');
    expect(cloud.slips, hasLength(1));
  });

  test('a fourth waiting slip is refused plainly, and a refused slip shows its reason', () async {
    for (final op in ['a', 'b', 'c']) {
      await account.sendSlip(planCode: 'small', months: 1, bytes: png, kind: SlipKind.png, operationId: 'op-$op');
    }
    expect(await problem(() => account.sendSlip(planCode: 'small', months: 1, bytes: png, kind: SlipKind.png, operationId: 'op-d')), AccountProblem.slipsWaiting);
    cloud.slips.first
      ..['state'] = 'refused'
      ..['refuse_reason'] = 'Amount not in the bank';
    final refused = (await account.slips()).singleWhere((s) => s.state == 'refused');
    expect(refused.refuseReason, 'Amount not in the bank');
  });

  test('deleting the account removes the slip files first, as SQL cannot remove a stored file', () async {
    await account.sendSlip(planCode: 'small', months: 2, bytes: pdf, kind: SlipKind.pdf, operationId: 'op-x');
    expect(cloud.slipFiles, hasLength(1));
    await account.deleteAccount('pass1234');
    expect(cloud.slipFiles, isEmpty);
    final paths = cloud.calls.map((c) => c.path).toList();
    expect(paths.indexOf('/storage/v1/object/payment-slips'), lessThan(paths.indexOf('/rest/v1/rpc/delete_account')));
  });
}
