import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/licence.dart';

const tenant = '00000000-0000-4000-8000-0000000000c1';
const device = '00000000-0000-4000-8000-0000000000d9';
final issued = DateTime.utc(2026, 11, 11, 10);

/// The facts as the cloud's `licence_facts` returns them, for a trial issued at [at].
Map<String, dynamic> facts({DateTime? at, String state = 'trial', String t = tenant, String d = device, int v = 1}) {
  final iat = at ?? issued;
  final ends = state == 'none' ? null : iat.add(const Duration(days: 15));
  return {
    'v': v,
    'iss': 'labour-app',
    'jti': '00000000-0000-4000-8000-00000000f001',
    'iat': iat.toIso8601String(),
    'tenant_id': t,
    'device_id': d,
    'state': state,
    'plan': state == 'none' ? null : 'trial',
    'plan_version': state == 'none' ? null : 1,
    'plan_name': state == 'none' ? null : 'Trial',
    'starts_at': state == 'none' ? null : iat.toIso8601String(),
    'ends_at': ends?.toIso8601String(),
    'lease_until': iat.add(const Duration(days: 7)).toIso8601String(),
    'limits': state == 'none'
        ? {'workers': 0, 'clients': 0, 'managers': 0, 'devices': 1}
        : {'workers': null, 'clients': null, 'managers': null, 'devices': 1},
  };
}

String b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Signs as the licence function does: the JSON's exact bytes and the signature, base64url without padding.
Future<SignedLicence> sign(SimpleKeyPair key, Map<String, dynamic> body) async {
  final bytes = utf8.encode(jsonEncode(body));
  final signature = await Ed25519().sign(bytes, keyPair: key);
  return (payload: b64url(bytes), sig: b64url(signature.bytes));
}

void main() {
  late SimpleKeyPair key;
  late String publicKey;

  setUpAll(() async {
    key = await Ed25519().newKeyPair();
    publicKey = base64.encode((await key.extractPublicKey()).bytes);
  });

  Future<Licence?> check(SignedLicence signed, {String key = '', String t = tenant, String d = device}) =>
      verifyLicence(signed, key.isEmpty ? publicKey : key, tenantId: t, deviceId: d);

  group('verifyLicence', () {
    test('a good licence reads as the cloud wrote it', () async {
      final licence = (await check(await sign(key, facts())))!;
      expect(licence.state, 'trial');
      expect(licence.planName, 'Trial');
      expect(licence.issuedAt, issued);
      expect(licence.leaseUntil, issued.add(const Duration(days: 7)));
      expect(licence.endsAt, issued.add(const Duration(days: 15)));
      expect(licence.workers, isNull, reason: 'null is unlimited');
      expect(licence.clients, isNull);
    });

    test('Postgres timestamps with an offset and microseconds read', () async {
      final body = facts()
        ..['iat'] = '2026-11-11T10:00:00.123456+00:00'
        ..['lease_until'] = '2026-11-18T14:00:00.123456+04:00';
      final licence = (await check(await sign(key, body)))!;
      expect(licence.issuedAt, DateTime.utc(2026, 11, 11, 10, 0, 0, 123, 456));
      expect(licence.leaseUntil, DateTime.utc(2026, 11, 18, 10, 0, 0, 123, 456));
    });

    test('a changed byte, another key, company, phone or schema is no licence', () async {
      final good = await sign(key, facts());
      final bytes = base64Url.decode(base64Url.normalize(good.payload));
      final tampered = utf8.encode(utf8.decode(bytes).replaceFirst('"trial"', '"paid!"'));
      expect(await check((payload: b64url(tampered), sig: good.sig)), isNull);
      final other = await Ed25519().newKeyPair();
      expect(await check(good, key: base64.encode((await other.extractPublicKey()).bytes)), isNull);
      expect(await check(good, t: '00000000-0000-4000-8000-0000000000c2'), isNull);
      expect(await check(good, d: '00000000-0000-4000-8000-0000000000d2'), isNull);
      expect(await check(await sign(key, facts(v: 2))), isNull);
    });

    test('no key, a bad key or a broken payload is no licence, never a crash', () async {
      final good = await sign(key, facts());
      expect(await verifyLicence(good, '', tenantId: tenant, deviceId: device), isNull);
      expect(await verifyLicence(good, 'not base64!', tenantId: tenant, deviceId: device), isNull);
      expect(await check((payload: 'e30', sig: good.sig)), isNull);
      final unsignedFacts = await sign(key, {'v': 1});
      expect(await check(unsignedFacts), isNull);
    });
  });

  group('licenceStatus', () {
    late Licence trial;

    setUp(() async => trial = (await check(await sign(key, facts())))!);

    test('within the lease the plan works; at its end the phone must check online', () {
      final day3 = issued.add(const Duration(days: 3));
      expect(licenceStatus(trial, day3, day3), LicenceStatus.active);
      final leaseEnd = issued.add(const Duration(days: 7));
      expect(licenceStatus(trial, leaseEnd, leaseEnd), LicenceStatus.leaseOver);
    });

    test('a plan past its end, or none, has ended', () async {
      final ended = issued.add(const Duration(days: 16));
      final late = (await check(await sign(key, facts()..['lease_until'] = ended.add(const Duration(days: 1)).toIso8601String())))!;
      expect(licenceStatus(late, ended, ended), LicenceStatus.ended);
      final none = (await check(await sign(key, facts(state: 'none'))))!;
      expect(licenceStatus(none, issued, issued), LicenceStatus.ended);
      expect(licenceStatus(null, issued, issued), LicenceStatus.none);
    });

    test('a clock moved back before the latest time seen or before the issue needs a check', () {
      final day3 = issued.add(const Duration(days: 3));
      expect(licenceStatus(trial, issued.add(const Duration(days: 1)), day3), LicenceStatus.clockBack);
      expect(licenceStatus(trial, issued.subtract(const Duration(hours: 1)), issued), LicenceStatus.clockBack);
    });

    test('a few minutes of drift, as network time corrects it, is not a clock moved back', () {
      final day3 = issued.add(const Duration(days: 3));
      expect(licenceStatus(trial, day3.subtract(const Duration(minutes: 5)), day3), LicenceStatus.active);
      expect(licenceStatus(trial, issued.subtract(const Duration(minutes: 5)), issued), LicenceStatus.active);
    });
  });

  group('Licensing', () {
    late FlutterSecureStorage storage;
    late DateTime now;
    late List<Object> answers;
    late int fetches;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = const FlutterSecureStorage();
      now = issued;
      answers = [];
      fetches = 0;
    });

    Licensing make() => Licensing(
      storage: storage,
      publicKey: publicKey,
      tenantId: tenant,
      deviceId: Future.value(device),
      clock: () => now,
      fetch: (deviceId) async {
        expect(deviceId, device);
        fetches++;
        final answer = answers.removeAt(0);
        if (answer is SignedLicence) return answer;
        throw answer;
      },
    );

    test('a licence fetched online is kept, and read again with no network after a restart', () async {
      answers.add(await sign(key, facts()));
      final first = make();
      await first.load();
      expect(first.view.status, LicenceStatus.none);
      await first.refresh();
      expect(first.view.status, LicenceStatus.active);
      expect(first.view.licence?.planName, 'Trial');

      now = issued.add(const Duration(days: 2));
      final again = make();
      await again.load();
      expect(fetches, 1);
      expect(again.view.status, LicenceStatus.active);
      expect(again.view.licence?.issuedAt, issued);
    });

    test('a refusal or no network keeps the licence there is, and says why', () async {
      answers
        ..add(await sign(key, facts()))
        ..add(const AccountRefused(AccountProblem.otherPhone))
        ..add(const AccountRefused(AccountProblem.offline));
      final licensing = make();
      await licensing.load();
      await licensing.refresh();
      await licensing.refresh();
      expect(licensing.view.problem, AccountProblem.otherPhone);
      expect(licensing.view.status, LicenceStatus.active, reason: 'the lease still runs');
      await licensing.refresh();
      expect(licensing.view.problem, AccountProblem.offline);
      answers.add(await sign(key, facts(at: issued.add(const Duration(hours: 1)))));
      await licensing.refresh();
      expect(licensing.view.problem, isNull);
    });

    test('an older licence than the one kept is ignored', () async {
      answers
        ..add(await sign(key, facts(at: issued.add(const Duration(days: 1)), state: 'none')))
        ..add(await sign(key, facts()));
      now = issued.add(const Duration(days: 1));
      final licensing = make();
      await licensing.load();
      await licensing.refresh();
      await licensing.refresh();
      expect(licensing.view.licence?.state, 'none');
      expect(licensing.view.licence?.issuedAt, issued.add(const Duration(days: 1)));
    });

    test('a licence signed for another phone or by another key is not kept', () async {
      final other = await Ed25519().newKeyPair();
      answers
        ..add(await sign(key, facts(d: '00000000-0000-4000-8000-0000000000d2')))
        ..add(await sign(other, facts()));
      final licensing = make();
      await licensing.load();
      await licensing.refresh();
      expect(licensing.view.licence, isNull);
      expect(licensing.view.problem, AccountProblem.failed);
      await licensing.refresh();
      expect(licensing.view.licence, isNull);
      expect(await storage.read(key: 'licence'), isNull);
    });

    test('the latest time seen survives a restart, so a clock moved back then needs a check', () async {
      answers.add(await sign(key, facts()));
      final licensing = make();
      await licensing.load();
      await licensing.refresh();
      now = issued.add(const Duration(days: 5));
      await make().load();

      now = issued.add(const Duration(days: 1));
      final turnedBack = make();
      await turnedBack.load();
      expect(turnedBack.view.status, LicenceStatus.clockBack);

      // Online, the cloud's own time sets the latest seen again, so a clock put right works at once.
      answers.add(await sign(key, facts(at: now)));
      await turnedBack.refresh();
      expect(turnedBack.view.status, LicenceStatus.active);
    });

    test('watch gives the view once loaded, then each change', () async {
      answers.add(await sign(key, facts()));
      final licensing = make();
      final seen = <LicenceStatus>[];
      final sub = licensing.watch().listen((v) => seen.add(v.status));
      await licensing.load();
      await licensing.refresh();
      await pumpEventQueue();
      expect(seen, [LicenceStatus.none, LicenceStatus.active]);
      await sub.cancel();
      await licensing.dispose();
      answers.add(await sign(key, facts()));
      await licensing.refresh();
      expect(licensing.view.status, LicenceStatus.active, reason: 'an answer after the company closed changes nothing visible and throws nothing');
    });
  });
}
