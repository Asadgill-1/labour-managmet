import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:labour_app/data/account.dart';
import 'package:labour_app/data/app_lock.dart';
import 'package:supabase/supabase.dart';
import 'package:yet_another_json_isolate/yet_another_json_isolate.dart';

const cloudUrl = 'https://test.supabase.co';

/// Stands in for the Supabase project, answering as its auth and REST APIs do, so the app's own calls are what run.
class FakeCloud {
  /// The code every email carries.
  static const code = '12345678';

  final users = <String, ({String id, String password, bool confirmed})>{};

  /// Company id by owner's user id.
  final companies = <String, String>{};
  /// The user each phone serves, by device id, as its live device rows say (D-063).
  final phones = <String, String>{};

  /// Each phone's name and last login, by device id, as its device row holds them (T20c).
  final phoneNames = <String, String>{};
  final lastLogins = <String, String>{};

  /// Phones the company turned off, by device id (T20c).
  final offPhones = <String>{};

  /// The check for a phone turned off answers with a server error.
  bool phoneCheckFails = false;
  final calls = <({String path, Map<String, dynamic> body})>[];
  bool offline = false;
  bool deviceRevoked = false;

  /// Someone besides the owner still works in the company (T24).
  bool companyHasOthers = false;

  /// The public half of the fake licence function's key, made from a fixed seed so it can be a constant (T21).
  static const licenceKey = '6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw=';

  /// What the licence function answers: the plan's state, name and end, or a refusal such as other_phone.
  String licenceState = 'trial';
  String? licencePlan = 'Trial';
  DateTime licenceEnds = DateTime.now().toUtc().add(const Duration(days: 15));
  String? licenceRefusal;

  /// The kept session's refresh token is no longer taken.
  bool refreshRefused = false;

  final plans = <Map<String, dynamic>>[
    {'code': 'small', 'version': 1, 'name': 'Small Company Plan', 'price_fils': 19900, 'addon_price_fils': 2000, 'max_workers': 15, 'max_clients': 5, 'max_managers': 1, 'sort_order': 1},
    {'code': 'mid', 'version': 1, 'name': 'Mid Size Company Plan', 'price_fils': 29900, 'addon_price_fils': 2000, 'max_workers': 35, 'max_clients': 9, 'max_managers': 2, 'sort_order': 2},
    {'code': 'large', 'version': 1, 'name': 'Large Size Company Plan', 'price_fils': 49900, 'addon_price_fils': 4000, 'max_workers': null, 'max_clients': null, 'max_managers': null, 'sort_order': 3},
  ];

  /// The platform's bank details, as typed into the live settings. Test values only.
  Map<String, dynamic> bank = {'bank_name': 'Test Bank', 'account_number': '0123456789001', 'iban': 'AE070000000123456789001', 'account_holder': 'Test Holder'};

  /// The company's slips, as `payment_slips` rows, and the files that reached storage, by path.
  final slips = <Map<String, dynamic>>[];
  final slipFiles = <String, int>{};
  final slipTypes = <String, String>{};

  /// The upload of a slip's file fails as a dropped connection would.
  bool uploadFails = false;

  /// A password was typed since the last deletion asked, as the server's recent sign-in rule needs (D-066).
  bool _passwordJustNow = false;

  Account account(FlutterSecureStorage storage, {bool emailCodes = true}) => Account(
    SupabaseClient(
      cloudUrl,
      'sb_publishable_test',
      httpClient: MockClient(_answer),
      isolate: YAJsonIsolate(),
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false),
    ),
    storage,
    emailCodes: emailCodes,
    licenceKey: licenceKey,
  );

  /// The owner tapped the link in the email.
  void confirmByLink(String email) {
    final user = users[email]!;
    users[email] = (id: user.id, password: user.password, confirmed: true);
  }

  /// A user who signed up and confirmed the email already.
  void addUser(String email, String password, {String? company}) {
    final id = '00000000-0000-4000-8000-${(users.length + 1).toString().padLeft(12, '0')}';
    users[email] = (id: id, password: password, confirmed: true);
    if (company != null) companies[id] = company;
  }

  /// Another phone the user signed in on before (T20c).
  void addPhone(String email, String device, String name, String lastLogin) {
    phones[device] = users[email]!.id;
    phoneNames[device] = name;
    lastLogins[device] = lastLogin;
  }

  /// Carries the request, as a real response does: the REST client reads its method.
  Future<http.Response> _answer(http.Request request) async {
    final r = await _route(request);
    return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
  }

  Future<http.Response> _route(http.Request request) async {
    if (offline) throw http.ClientException('Failed host lookup');
    final path = request.url.path;
    const upload = '/storage/v1/object/payment-slips/';
    if (path.startsWith(upload) && request.method == 'POST') {
      calls.add((path: path, body: const {}));
      if (uploadFails) throw http.ClientException('Connection closed');
      final name = path.substring(upload.length);
      if (!slips.any((s) => s['file_path'] == name && s['state'] == 'waiting')) {
        return _json({'statusCode': '403', 'error': 'Unauthorized', 'message': 'new row violates row-level security policy'}, status: 400);
      }
      if (slipFiles.containsKey(name)) return _json({'statusCode': '409', 'error': 'Duplicate', 'message': 'The resource already exists'}, status: 400);
      // The file's own bytes and type, from the multipart body the storage client sends.
      final text = latin1.decode(request.bodyBytes);
      final head = text.indexOf('filename=');
      final start = text.indexOf('\r\n\r\n', head) + 4;
      slipFiles[name] = text.indexOf('\r\n--', start) - start;
      slipTypes[name] = RegExp(r'content-type: (\S+)', caseSensitive: false).firstMatch(text.substring(text.lastIndexOf('--', head), start))![1]!;
      return _json({'Key': 'payment-slips/$name'});
    }
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
    calls.add((path: path, body: body));
    final caller = _caller(request);
    switch (path) {
      case '/auth/v1/signup':
        final email = body['email'] as String;
        final existing = users[email];
        if (existing != null && existing.confirmed) return _json({..._user(email, existing.id), 'identities': []});
        final id = existing?.id ?? '00000000-0000-4000-8000-${(users.length + 1).toString().padLeft(12, '0')}';
        users[email] = (id: id, password: body['password'] as String, confirmed: false);
        return _json(_user(email, id));
      case '/auth/v1/resend' || '/auth/v1/recover':
        return _json({});
      case '/auth/v1/verify':
        final email = body['email'] as String;
        final user = users[email];
        if (user == null || body['token'] != code) return _authError(403, 'otp_expired', 'Token has expired or is invalid');
        users[email] = (id: user.id, password: user.password, confirmed: true);
        return _json(_session(email, user.id));
      case '/auth/v1/token' when request.url.queryParameters['grant_type'] == 'refresh_token':
        final id = (body['refresh_token'] as String).replaceFirst('refresh-', '');
        if (refreshRefused) return _authError(400, 'refresh_token_not_found', 'Invalid Refresh Token: Refresh Token Not Found');
        return _json(_session(users.entries.firstWhere((e) => e.value.id == id).key, id));
      case '/auth/v1/token':
        final email = body['email'] as String;
        final user = users[email];
        if (user == null || user.password != body['password']) return _authError(400, 'invalid_credentials', 'Invalid login credentials');
        if (!user.confirmed) return _authError(400, 'email_not_confirmed', 'Email not confirmed');
        _passwordJustNow = true;
        return _json(_session(email, user.id));
      case '/auth/v1/user':
        final email = users.entries.firstWhere((e) => e.value.id == caller).key;
        final user = users[email]!;
        users[email] = (id: user.id, password: body['password'] as String, confirmed: true);
        return _json(_user(email, user.id));
      case '/auth/v1/logout':
        return http.Response('', 204);
      case '/rest/v1/memberships':
        final company = companies[caller];
        return _json([if (company != null) {'tenant_id': company}]);
      case '/rest/v1/rpc/create_tenant':
        final id = companies[caller!] ??= (body['p_tenant_id'] as String?) ?? '00000000-0000-4000-8000-0000000000c1';
        return _json(id);
      case '/rest/v1/rpc/phone_account':
        final holder = phones[body['p_device_id']];
        if (holder == null || holder == caller) return _json(null);
        final email = users.entries.firstWhere((e) => e.value.id == holder).key;
        return _json(email.replaceFirstMapped(RegExp(r'^(.{1,2})[^@]*(@.*)$'), (m) => '${m[1]}***${m[2]}'));
      case '/rest/v1/rpc/register_device':
        if (deviceRevoked) return _refused('this device was revoked');
        final device = body['p_device_id'] as String;
        if ((phones[device] ?? caller) != caller) return _refused('this phone belongs to another account');
        phones[device] = caller!;
        phoneNames[device] = body['p_label'] as String;
        lastLogins[device] = '2026-11-11T05:00:00Z';
        // The owner signing in again turns a phone the company turned off back on (D-073).
        offPhones.remove(device);
        return _json('00000000-0000-4000-8000-0000000000d1');
      case '/rest/v1/devices':
        return _json([
          for (final MapEntry(key: device, value: user) in phones.entries)
            if (user == caller) {'id': 'row-$device', 'device_id': device, 'label': phoneNames[device], 'last_seen_at_utc': lastLogins[device]},
        ]);
      case '/rest/v1/rpc/turn_phone_off':
        final device = (body['p_device_row'] as String).replaceFirst('row-', '');
        if (phones[device] != caller) return _refused('not a phone of yours');
        phones.remove(device);
        offPhones.add(device);
        return http.Response('', 204);
      case '/rest/v1/rpc/phone_is_off':
        if (phoneCheckFails) return _json({'message': 'internal error'}, status: 500);
        return _json(offPhones.contains(body['p_device_id']));
      case '/functions/v1/licence':
        if (caller == null) return _json({'error': 'sign_in'}, status: 401);
        if (licenceRefusal case final refusal?) return _json({'error': refusal}, status: 403);
        final now = DateTime.now().toUtc();
        final lease = now.add(const Duration(days: 7));
        final none = licenceState == 'none';
        final facts = {
          'v': 1, 'iss': 'labour-app', 'jti': 'jti-${calls.length}', 'iat': now.toIso8601String(),
          'tenant_id': body['tenant_id'], 'device_id': body['device_id'], 'state': licenceState,
          'plan': none ? null : licenceState, 'plan_version': none ? null : 1, 'plan_name': none ? null : licencePlan,
          'starts_at': none ? null : now.toIso8601String(), 'ends_at': licenceEnds.toIso8601String(),
          'lease_until': (none || lease.isBefore(licenceEnds) ? lease : licenceEnds).toIso8601String(),
          'limits': {'workers': none ? 0 : null, 'clients': none ? 0 : null, 'managers': none ? 0 : null, 'devices': 1},
        };
        final bytes = utf8.encode(jsonEncode(facts));
        final key = await Ed25519().newKeyPairFromSeed(List.filled(32, 7));
        final signature = await Ed25519().sign(bytes, keyPair: key);
        String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
        return _json({'payload': b64(bytes), 'sig': b64(signature.bytes)});
      case '/rest/v1/plans':
        return _json(plans);
      case '/rest/v1/platform_settings':
        return _json(bank);
      case '/rest/v1/payment_slips':
        return _json([for (final slip in slips.reversed) if (slip['tenant_id'] == companies[caller]) slip]);
      case '/rest/v1/rpc/submit_slip':
        final tenant = body['p_tenant_id'] as String;
        if (companies[caller] != tenant) return _refused("only the company's owner sends a slip");
        final same = slips.where((s) => s['source_operation_id'] == body['p_operation_id']);
        if (same.isNotEmpty) return _json(same.first['file_path']);
        if (slips.where((s) => s['tenant_id'] == tenant && s['state'] == 'waiting').length >= 3) {
          return _json({'code': '22023', 'details': null, 'hint': null, 'message': 'three slips are waiting already'}, status: 400);
        }
        final plan = plans.firstWhere((p) => p['code'] == body['p_plan_code']);
        final id = '00000000-0000-4000-8000-${(slips.length + 1).toString().padLeft(12, '0')}';
        final slip = <String, dynamic>{
          'id': id, 'tenant_id': tenant, 'plan_code': plan['code'], 'plan_version': 1, 'months': body['p_months'],
          'expected_fils': (plan['price_fils'] as int) * (body['p_months'] as int), 'file_path': '$tenant/$id.${body['p_file_type']}',
          'state': 'waiting', 'refuse_reason': null, 'submitted_at_utc': '2026-11-11T08:00:00+00:00', 'source_operation_id': body['p_operation_id'],
        };
        slips.add(slip);
        return _json(slip['file_path']);
      case '/storage/v1/object/list/payment-slips':
        final prefix = body['prefix'] as String;
        return _json([
          for (final name in slipFiles.keys)
            if (name.startsWith('$prefix/')) {'name': name.substring(prefix.length + 1), 'id': name},
        ]);
      case '/storage/v1/object/payment-slips':
        final removed = [
          for (final name in (body['prefixes'] as List).cast<String>())
            if (slipFiles.remove(name) != null) {'name': name},
        ];
        return _json(removed);
      case '/rest/v1/rpc/delete_account':
        // The server takes only a session signed in with the password just now (D-066).
        if (!_passwordJustNow) return _refused('type the password again');
        _passwordJustNow = false;
        if (companyHasOthers) return _refused('the company has other members');
        users.removeWhere((_, user) => user.id == caller);
        companies.remove(caller);
        phones.removeWhere((_, user) => user == caller);
        return http.Response('', 204);
    }
    return _json({'message': 'no route $path'}, status: 404);
  }

  /// The user id inside the bearer token, as the server reads it.
  String? _caller(http.Request request) {
    final token = request.headers['Authorization']?.replaceFirst('Bearer ', '').split('.');
    if (token == null || token.length != 3) return null;
    final claims = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token[1])))) as Map<String, dynamic>;
    return claims['sub'] as String?;
  }

  Map<String, dynamic> _user(String email, String id) => {
    'id': id,
    'aud': 'authenticated',
    'email': email,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-11-09T00:00:00Z',
    'identities': [
      {'id': id, 'user_id': id, 'identity_id': id, 'provider': 'email', 'identity_data': <String, dynamic>{}},
    ],
  };

  Map<String, dynamic> _session(String email, String id) {
    String part(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
    final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    return {
      'access_token': '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': id, 'exp': expires, 'role': 'authenticated'})}.c2ln',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expires,
      'refresh_token': 'refresh-$id',
      'user': _user(email, id),
    };
  }

  http.Response _refused(String message) => _json({'code': '42501', 'details': null, 'hint': null, 'message': message}, status: 403);

  http.Response _authError(int status, String code, String message) => _json({'code': status, 'error_code': code, 'msg': message}, status: status);

  http.Response _json(Object? body, {int status = 200}) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});
}

/// The phone's lock with a stand-in for the phone's fingerprint reader.
class FakeLock extends AppLock {
  FakeLock(super.storage, {this.hasFingerprint = false});

  final bool hasFingerprint;
  var fingerprintWorks = true;
  var prompts = 0;

  @override
  Future<bool> canUseFingerprint() async => hasFingerprint;

  @override
  Future<bool> unlockWithFingerprint(String reason) async {
    prompts++;
    return fingerprintWorks;
  }
}
