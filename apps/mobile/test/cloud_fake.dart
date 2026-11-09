import 'dart:convert';

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
  final calls = <({String path, Map<String, dynamic> body})>[];
  bool offline = false;
  bool deviceRevoked = false;

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

  /// Carries the request, as a real response does: the REST client reads its method.
  Future<http.Response> _answer(http.Request request) async {
    final r = await _route(request);
    return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
  }

  Future<http.Response> _route(http.Request request) async {
    if (offline) throw http.ClientException('Failed host lookup');
    final path = request.url.path;
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
      case '/auth/v1/token':
        final email = body['email'] as String;
        final user = users[email];
        if (user == null || user.password != body['password']) return _authError(400, 'invalid_credentials', 'Invalid login credentials');
        if (!user.confirmed) return _authError(400, 'email_not_confirmed', 'Email not confirmed');
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
        return _json('00000000-0000-4000-8000-0000000000d1');
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
