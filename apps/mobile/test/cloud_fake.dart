import 'dart:convert';
import 'dart:typed_data';

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

  /// The account's deletion goes through, then its answer is lost, as when the connection drops.
  bool deleteAnswerLost = false;

  /// Someone besides the owner still works in the company (T24).
  bool companyHasOthers = false;

  /// The public half of the fake licence function's key, made from a fixed seed so it can be a constant (T21).
  static const licenceKey = '6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw=';

  /// What the licence function answers: the plan's state, name and end, or a refusal such as other_phone.
  String licenceState = 'trial';
  String? licencePlan = 'Trial';

  /// The paid plan's code, when a test names one; else the state stands in for it.
  String? licencePlanCode;
  DateTime licenceEnds = DateTime.now().toUtc().add(const Duration(days: 15));
  String? licenceRefusal;

  /// The plan's numbers of active workers and client companies. Null is unlimited, as in the trial.
  int? licenceWorkers;
  int? licenceClients;

  /// The end of the cloud add-on that covers today, as the licence carries it and the download asks (T20d).
  DateTime? addonUntil;

  /// The platform's hold the licence carries, with the state 'none' (T22b), and the app version the last request sent.
  Map<String, dynamic>? licenceHold;
  String? lastAppVersion;

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

  /// The cloud's backup copies, as `cloud_backups` rows, and the files in the `backups` bucket, by path (T20d).
  final cloudCopies = <Map<String, dynamic>>[];
  final cloudFiles = <String, Uint8List>{};

  /// What the backup function answers a start with instead, such as not_owner or too_many.
  String? backupRefusal;

  /// What it answers a download with instead, such as other_phone.
  String? downloadRefusal;

  /// A copy another phone of the company sent before this one, with its file when [bytes] is given.
  void addCloudCopy(String tenant, String device, {Uint8List? bytes, String at = '2026-11-10T08:00:00.000Z'}) {
    final id = 'copy-${cloudCopies.length + 1}';
    cloudCopies.add({
      'id': id, 'tenant_id': tenant, 'device_id': device, 'file_path': '$tenant/old-$id.zip',
      'operation_id': 'old-$id', 'finished_at_utc': at, 'replace': false, 'size': bytes?.length ?? 2048,
    });
    if (bytes != null) cloudFiles['$tenant/old-$id.zip'] = bytes;
  }

  /// The session's password sign-in is more than ten minutes old, or it has none, as after an emailed code. The cloud
  /// then refuses to turn a phone off, or to turn an owner's phone back on, until the password is typed (D-073).
  bool passwordOld = false;

  /// A password was typed since the last deletion asked, as the server's recent sign-in rule needs (D-066).
  bool _passwordJustNow = false;

  Account account(FlutterSecureStorage storage, {bool emailCodes = true, String recoveryKey = ''}) {
    final client = MockClient(_answer);
    return Account(
      SupabaseClient(
        cloudUrl,
        'sb_publishable_test',
        httpClient: client,
        isolate: YAJsonIsolate(),
        authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false),
      ),
      storage,
      emailCodes: emailCodes,
      licenceKey: licenceKey,
      recoveryKey: recoveryKey,
      downloads: client,
    );
  }

  /// The owner tapped the link in the email.
  void confirmByLink(String email) {
    final user = users[email]!;
    users[email] = (id: user.id, password: user.password, confirmed: true);
  }

  /// A user who signed up and confirmed the email already.
  /// [consented]: the company agreed to send its books, as every company made after the consent page has (D-084).
  void addUser(String email, String password, {String? company, bool consented = true}) {
    final id = '00000000-0000-4000-8000-${(users.length + 1).toString().padLeft(12, '0')}';
    users[email] = (id: id, password: password, confirmed: true);
    if (company != null) companies[id] = company;
    if (company != null && consented) consents[company] = 1;
  }

  /// Each company's yes on the consent page, by the wording's version (T22d).
  final consents = <String, int>{};

  /// The books each company sent, by record type and id, as the cloud keeps them (T22d).
  final books = <String, Map<String, dynamic>>{};

  /// Another phone the user signed in on before (T20c).
  void addPhone(String email, String device, String name, String lastLogin) {
    phones[device] = users[email]!.id;
    phoneNames[device] = name;
    lastLogins[device] = lastLogin;
  }

  /// Carries the request, as a real response does: the REST client reads its method.
  Future<http.Response> _answer(http.Request request) async {
    final r = await _route(request);
    return http.Response.bytes(r.bodyBytes, r.statusCode, headers: r.headers, request: request);
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
    const signed = '/storage/v1/object/upload/sign/backups/';
    if (path.startsWith(signed) && request.method == 'PUT') {
      calls.add((path: path, body: const {}));
      final name = path.substring(signed.length);
      final row = cloudCopies.where((c) => c['file_path'] == name && c['finished_at_utc'] == null);
      if (row.isEmpty || request.url.queryParameters['token'] != 'token-${row.first['id']}') {
        return _json({'statusCode': '400', 'error': 'InvalidSignature', 'message': 'invalid signature'}, status: 400);
      }
      // The file's own bytes and type, from the multipart body the storage client sends.
      final text = latin1.decode(request.bodyBytes);
      final head = text.indexOf('filename=');
      final start = text.indexOf('\r\n\r\n', head) + 4;
      final type = RegExp(r'content-type: (\S+)', caseSensitive: false).firstMatch(text.substring(text.lastIndexOf('--', head), start))![1]!;
      if (type != 'application/zip') return _json({'statusCode': '415', 'error': 'invalid_mime_type'}, status: 400);
      cloudFiles[name] = request.bodyBytes.sublist(start, text.indexOf('\r\n--', start));
      return _json({'Key': 'backups/$name'});
    }
    const fetch = '/storage/v1/object/sign/backups/';
    if (path.startsWith(fetch) && request.method == 'GET') {
      calls.add((path: path, body: const {}));
      final name = path.substring(fetch.length);
      final row = cloudCopies.where((c) => c['file_path'] == name);
      if (row.isEmpty || request.url.queryParameters['token'] != 'get-${row.first['id']}' || !cloudFiles.containsKey(name)) {
        return _json({'statusCode': '400', 'error': 'InvalidSignature', 'message': 'invalid signature'}, status: 400);
      }
      return http.Response.bytes(cloudFiles[name]!, 200, headers: {'content-type': 'application/zip'});
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
        passwordOld = true;
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
        passwordOld = false;
        return _json(_session(email, user.id));
      case '/auth/v1/user' when request.method == 'GET':
        // The token alone is not enough: the server looks the user up, as GoTrue does.
        final user = users.entries.where((e) => e.value.id == caller);
        if (user.isEmpty) return _authError(403, 'user_not_found', 'User from sub claim in JWT does not exist');
        return _json(_user(user.first.key, caller!));
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
        if (offPhones.contains(device) && passwordOld) return _refused('type the password again');
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
        if (passwordOld) return _refused('type the password again');
        phones.remove(device);
        offPhones.add(device);
        return http.Response('', 204);
      case '/rest/v1/rpc/phone_is_off':
        if (phoneCheckFails) return _json({'message': 'internal error'}, status: 500);
        return _json(offPhones.contains(body['p_device_id']));
      case '/functions/v1/licence':
        if (caller == null) return _json({'error': 'sign_in'}, status: 401);
        if (licenceRefusal case final refusal?) return _json({'error': refusal}, status: 403);
        lastAppVersion = body['app_version'] as String?;
        final now = DateTime.now().toUtc();
        final lease = now.add(const Duration(days: 7));
        final none = licenceState == 'none';
        final facts = {
          'v': 1, 'iss': 'labour-app', 'jti': 'jti-${calls.length}', 'iat': now.toIso8601String(),
          'tenant_id': body['tenant_id'], 'device_id': body['device_id'], 'state': licenceState,
          'plan': none ? null : (licencePlanCode ?? licenceState), 'plan_version': none ? null : 1, 'plan_name': none ? null : licencePlan,
          'starts_at': none ? null : now.toIso8601String(), 'ends_at': licenceEnds.toIso8601String(),
          'lease_until': (none || lease.isBefore(licenceEnds) ? lease : licenceEnds).toIso8601String(),
          'addon_until': addonUntil?.toIso8601String(),
          'hold': licenceHold,
          'limits': {'workers': none ? 0 : licenceWorkers, 'clients': none ? 0 : licenceClients, 'managers': none ? 0 : null, 'devices': 1},
        };
        final bytes = utf8.encode(jsonEncode(facts));
        final key = await Ed25519().newKeyPairFromSeed(List.filled(32, 7));
        final signature = await Ed25519().sign(bytes, keyPair: key);
        String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
        return _json({'payload': b64(bytes), 'sig': b64(signature.bytes)});
      case '/functions/v1/backup':
        if (caller == null) return _json({'error': 'sign_in'}, status: 401);
        final tenant = body['tenant_id'] as String;
        if (companies[caller] != tenant) return _json({'error': 'not_owner'}, status: 403);
        if (body['action'] == 'start') {
          if (backupRefusal case final refusal?) return _json({'error': refusal}, status: refusal == 'too_many' ? 429 : 403);
          final done = cloudCopies.where((c) => c['tenant_id'] == tenant && c['finished_at_utc'] != null);
          if (done.isNotEmpty && done.last['device_id'] != body['device_id'] && body['replace'] != true) {
            return _json({'error': 'other_phone_copy'}, status: 403);
          }
          cloudCopies.removeWhere((c) => c['tenant_id'] == tenant && c['finished_at_utc'] == null);
          final id = 'copy-${cloudCopies.length + 1}';
          cloudCopies.add({
            'id': id, 'tenant_id': tenant, 'device_id': body['device_id'], 'file_path': '$tenant/$id.zip', 'operation_id': body['operation_id'],
            'finished_at_utc': null, 'replace': body['replace'], 'size': body['size_bytes'],
          });
          return _json({'path': '$tenant/$id.zip', 'token': 'token-$id'});
        }
        if (body['action'] == 'download') {
          if (downloadRefusal case final refusal?) return _json({'error': refusal}, status: 403);
          final copy = cloudCopies.where((c) => c['id'] == body['backup_id'] && c['tenant_id'] == tenant && c['finished_at_utc'] != null);
          if (copy.isEmpty) return _json({'error': 'no_copy'}, status: 404);
          if (!(addonUntil?.isAfter(DateTime.now().toUtc()) ?? false)) return _json({'error': 'addon_needed'}, status: 403);
          return _json({'url': '$cloudUrl/storage/v1/object/sign/backups/${copy.first['file_path']}?token=get-${copy.first['id']}'});
        }
        final row = cloudCopies.firstWhere((c) => c['operation_id'] == body['operation_id']);
        if (!cloudFiles.containsKey(row['file_path'])) return _json({'error': 'not_arrived'}, status: 409);
        row['finished_at_utc'] = '2026-11-15T06:00:00.000Z';
        // As backup_finish does: with the add-on it is a daily copy the cloud keeps; every other earlier copy goes,
        // whichever phone sent it.
        row['keep'] = addonUntil?.isAfter(DateTime.now().toUtc()) ?? false;
        for (final gone in cloudCopies.where((c) => c['tenant_id'] == tenant && c != row && c['finished_at_utc'] != null && c['keep'] != true).toList()) {
          cloudCopies.remove(gone);
          cloudFiles.remove(gone['file_path']);
        }
        return _json({'finished_at': row['finished_at_utc']});
      case '/rest/v1/cloud_backups':
        // The owner's finished copies, newest first.
        final done = [
          for (final c in cloudCopies)
            if (c['tenant_id'] == companies[caller] && c['finished_at_utc'] != null) c,
        ];
        int byNewest(Map<String, dynamic> a, Map<String, dynamic> b) {
          final at = (b['finished_at_utc'] as String).compareTo(a['finished_at_utc'] as String);
          return at != 0 ? at : cloudCopies.indexOf(b).compareTo(cloudCopies.indexOf(a));
        }
        return _json([
          for (final c in done..sort(byNewest)) {'id': c['id'], 'size_bytes': c['size'], 'finished_at_utc': c['finished_at_utc']},
        ]);
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
        final covers = (body['p_covers'] as String?) ?? 'plan';
        final monthly = switch (covers) {
          'plan' => plan['price_fils'] as int,
          'addon' => plan['addon_price_fils'] as int,
          _ => (plan['price_fils'] as int) + (plan['addon_price_fils'] as int),
        };
        final slip = <String, dynamic>{
          'id': id, 'tenant_id': tenant, 'plan_code': plan['code'], 'plan_version': 1, 'months': body['p_months'], 'covers': covers,
          'expected_fils': monthly * (body['p_months'] as int), 'file_path': '$tenant/$id.${body['p_file_type']}',
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
      case '/rest/v1/rpc/give_data_consent':
        if (companies[caller] != body['p_tenant_id']) return _refused('only the owner gives consent');
        consents[body['p_tenant_id'] as String] = body['p_version'] as int;
        return _json('2026-11-26T09:00:00+00:00');
      case '/rest/v1/rpc/push_book_changes':
        if (companies[caller] != body['p_tenant_id']) return _refused('not a member of this company');
        if (!consents.containsKey(body['p_tenant_id'])) return _refused('give consent first');
        final changes = (body['p_changes'] as List).cast<Map<String, dynamic>>();
        for (final c in changes) {
          books['${c['entity']}/${c['id']}'] = c;
        }
        return _json(changes.length);
      case '/rest/v1/tenants':
        final tenant = request.url.queryParameters['tenant_id']?.replaceFirst('eq.', '');
        return _json([if (tenant != null && companies[caller] == tenant) {'data_consent_version': consents[tenant]}]);
      case '/rest/v1/rpc/delete_account':
        // The server takes only a session signed in with the password just now (D-066).
        if (!_passwordJustNow) return _refused('type the password again');
        _passwordJustNow = false;
        if (companyHasOthers) return _refused('the company has other members');
        users.removeWhere((_, user) => user.id == caller);
        companies.remove(caller);
        phones.removeWhere((_, user) => user == caller);
        if (deleteAnswerLost) throw http.ClientException('Connection closed');
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
