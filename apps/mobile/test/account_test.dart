import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'cloud_fake.dart';

const phoneTenant = '00000000-0000-4000-8000-0000000000aa';

void main() {
  late FakeCloud cloud;
  late FlutterSecureStorage storage;
  late Account account;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    cloud = FakeCloud();
    account = cloud.account(storage);
  });

  Future<AccountProblem?> problem(Future<void> Function() work) async {
    try {
      await work();
      return null;
    } on AccountRefused catch (e) {
      return e.problem;
    }
  }

  test('sign-up, the email code and the company name put the company on this device, keeping the phone data', () async {
    await storage.write(key: localTenantKey, value: phoneTenant);
    expect(await account.hasPhoneData(), isTrue);

    await account.signUp('owner@test.ae', 'pass1234');
    expect(await problem(() => account.confirmSignup('owner@test.ae', '00000000')), AccountProblem.badCode);
    await account.confirmSignup('owner@test.ae', FakeCloud.code);
    expect(await account.openCompany(), isNull, reason: 'no company yet');

    final operation = newUuid();
    final tenant = await account.createCompany('Al Noor Labour', operation);
    expect(tenant, phoneTenant, reason: 'the data already on the phone stays with the new company');
    final create = cloud.calls.singleWhere((c) => c.path == '/rest/v1/rpc/create_tenant').body;
    expect(create, {'p_name': 'Al Noor Labour', 'p_operation_id': operation, 'p_tenant_id': phoneTenant});
    final device = cloud.calls.singleWhere((c) => c.path == '/rest/v1/rpc/register_device').body;
    expect(device['p_tenant_id'], phoneTenant);
    expect(device['p_device_id'], await storage.read(key: 'device_id'));
    expect(['android', 'ios', 'windows', 'web'], contains(device['p_platform']));

    final bound = await account.binding();
    expect(bound?.tenantId, phoneTenant);
    expect(bound?.email, 'owner@test.ae');
    expect(await account.hasPhoneData(), isFalse, reason: 'handed over once');
  });

  test('a fresh phone lets the server make the company id', () async {
    await account.signUp('new@test.ae', 'pass1234');
    await account.confirmSignup('new@test.ae', FakeCloud.code);
    await account.createCompany('Fresh LLC', newUuid());
    expect(cloud.calls.singleWhere((c) => c.path == '/rest/v1/rpc/create_tenant').body['p_tenant_id'], isNull);
  });

  test('logging in finds the company from the membership', () async {
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    expect(await problem(() => account.signIn('owner@test.ae', 'wrong123')), AccountProblem.wrongLogin);
    await account.signIn('owner@test.ae', 'pass1234');
    expect(await account.openCompany(), '00000000-0000-4000-8000-0000000000c9');
    expect((await account.binding())?.tenantId, '00000000-0000-4000-8000-0000000000c9');
  });

  test('a device the company turned off is refused and not remembered', () async {
    cloud
      ..addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9')
      ..deviceRevoked = true;
    await account.signIn('owner@test.ae', 'pass1234');
    expect(await problem(account.openCompany), AccountProblem.deviceRevoked);
    expect(await account.binding(), isNull);
  });

  test('an email with an account already, or not confirmed yet, says so', () async {
    cloud.addUser('owner@test.ae', 'pass1234');
    expect(await problem(() => account.signUp('owner@test.ae', 'other123')), AccountProblem.exists);

    await account.signUp('late@test.ae', 'pass1234');
    expect(await problem(() => account.signIn('late@test.ae', 'pass1234')), AccountProblem.notConfirmed);
  });

  test('a forgotten password is replaced with the email code', () async {
    cloud.addUser('owner@test.ae', 'pass1234');
    await account.sendReset('owner@test.ae');
    await account.resetPassword('owner@test.ae', FakeCloud.code, 'newpass99');
    expect(cloud.users['owner@test.ae']?.password, 'newpass99');
  });

  test('no internet says so, and logging out still works offline', () async {
    cloud.addUser('owner@test.ae', 'pass1234', company: '00000000-0000-4000-8000-0000000000c9');
    await account.signIn('owner@test.ae', 'pass1234');
    await account.openCompany();
    cloud.offline = true;
    expect(await problem(() => account.signIn('owner@test.ae', 'pass1234')), AccountProblem.offline);
    expect(await problem(account.openCompany), AccountProblem.offline);

    await account.logOut();
    expect(await account.binding(), isNull);
  });

  test('the form checks match the project rules', () {
    expect(isEmail(' owner@test.ae '), isTrue);
    expect(isEmail('owner@test'), isFalse);
    expect(isStrongPassword('pass1234'), isTrue);
    expect(isStrongPassword('pass123'), isFalse, reason: '7 characters');
    expect(isStrongPassword('password'), isFalse, reason: 'no digit');
    expect(isStrongPassword('12345678'), isFalse, reason: 'no letter');
    expect(isEmailCode('12345678'), isTrue);
    expect(isEmailCode('1234 5678'), isFalse);
  });
}
