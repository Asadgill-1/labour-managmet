import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import 'licence.dart';
import 'plans.dart';
import 'tenant_database.dart';

/// Why an account step failed, in terms a screen can say plainly (UX-04).
enum AccountProblem { offline, wrongLogin, notConfirmed, exists, weakPassword, badCode, tooMany, deviceRevoked, phoneTaken, phoneData, companyHasMembers, otherPhone, signedOut, slipsWaiting, failed }

class AccountRefused implements Exception {
  const AccountRefused(this.problem, [this.holder]);

  final AccountProblem problem;

  /// With [AccountProblem.phoneTaken]: the masked email of the account that holds this phone, when the server said.
  final String? holder;

  @override
  String toString() => 'AccountRefused($problem)';
}

/// One of the company's phones that is on (T20c). [here] is this phone.
typedef Phone = ({String id, String name, DateTime lastLogin, bool here});

/// The company this device opens without signing in again, and who signed in on it (AUTH-03).
typedef Binding = ({String tenantId, String userId, String email});

const _bindingKey = 'account';
const _sessionKey = 'session';
const _slipBucket = 'payment-slips';

/// Sign-up, sign-in and the company this device opens (T19b). The app holds only the publishable key; the company
/// comes from the signed-in user's membership, never from the app (AUTH-02, AUTH-06).
class Account {
  Account(this._client, this._storage, {required this.emailCodes, this.licenceKey = ''}) {
    // The session is kept on the phone, so the licence renews after a restart without the password (D-062, D-074).
    // Steps the cloud must trust still ask for the password unless it was typed in this run of the app.
    _auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedIn) _typedPassword = true;
        if (state.event == AuthChangeEvent.signedOut) {
          _typedPassword = false;
          unawaited(_storage.delete(key: _sessionKey));
        } else if (state.session case final session?) {
          unawaited(_storage.write(key: _sessionKey, value: jsonEncode(session.toJson())));
        }
      },
      onError: (Object _) {},
    );
  }

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;
  var _typedPassword = false;

  /// The public half of the key the cloud signs licences with, base64, from `.env` (D-074).
  final String licenceKey;

  /// The project's emails carry a code. Supabase's own sender sends its fixed emails, which carry only a link, so
  /// a forgotten password cannot be replaced in the app until the project sends through its own SMTP (T19d, D-062).
  final bool emailCodes;

  /// This build's account service, or null when the build was made without cloud settings (D-062).
  static Account? ofBuild(FlutterSecureStorage storage) {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) return null;
    // Implicit flow: a code typed from the email needs no stored PKCE verifier and no link back into the app.
    return Account(
      SupabaseClient(url, key, authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit)),
      storage,
      emailCodes: const bool.fromEnvironment('EMAIL_CODES'),
      licenceKey: const String.fromEnvironment('LICENCE_KEY'),
    );
  }

  GoTrueClient get _auth => _client.auth;

  Future<Binding?> binding() async {
    final raw = await _storage.read(key: _bindingKey);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (tenantId: m['tenant_id'] as String, userId: m['user_id'] as String, email: m['email'] as String);
  }

  /// The phone holds data made before it had an account.
  Future<bool> hasPhoneData() async => await _storage.read(key: localTenantKey) != null;

  Future<void> signUp(String email, String password) => _run(() async {
    await _phoneFree();
    final response = await _auth.signUp(email: email, password: password);
    // An email that already has an account gets no code and no error, only a user with no identities.
    if (response.user?.identities?.isEmpty ?? false) throw const AccountRefused(AccountProblem.exists);
  });

  Future<void> confirmSignup(String email, String code) => _run(() => _auth.verifyOTP(email: email, token: code, type: OtpType.signup));

  Future<void> resendSignup(String email) => _run(() => _auth.resend(email: email, type: OtpType.signup));

  Future<void> signIn(String email, String password) => _run(() => _auth.signInWithPassword(email: email, password: password));

  Future<void> sendReset(String email) => _run(() => _auth.resetPasswordForEmail(email));

  Future<void> resetPassword(String email, String code, String password) => _run(() async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
    await _auth.updateUser(UserAttributes(password: password));
  });

  /// After a sign-in, puts the user's company on this device. Null means they have none yet.
  Future<String?> openCompany() => _run(() async {
    await _phoneFree();
    final rows = await _client.from('memberships').select('tenant_id').eq('user_id', _auth.currentUser!.id).isFilter('revoked_at_utc', null);
    if (rows.isEmpty) return null;
    // Data made before the phone had an account goes only into a company made here; opening another would hide it.
    if (await hasPhoneData()) throw const AccountRefused(AccountProblem.phoneData);
    // ponytail: the first live membership; a chooser comes with managers who work for more than one company (T24).
    final tenantId = rows.first['tenant_id'] as String;
    await _enrol(tenantId);
    return tenantId;
  });

  /// Makes the signed-in user's company (UX-02). Data the phone made before the account keeps its id, so it stays.
  /// The caller keeps [operationId] across retries, so a lost answer cannot make a second company (MODEL-06).
  Future<String> createCompany(String name, String operationId) => _run(() async {
    final local = await _storage.read(key: localTenantKey);
    final tenantId = await _client.rpc<String>('create_tenant', params: {'p_name': name, 'p_operation_id': operationId, 'p_tenant_id': local});
    await _enrol(tenantId);
    // Handed over once: a later company on this phone gets a new id and a file of its own.
    if (tenantId == local) await _storage.delete(key: localTenantKey);
    return tenantId;
  });

  /// One phone serves one account, so no company's data is left hidden on it under another (D-063).
  Future<void> _phoneFree() async {
    final holder = await _client.rpc<String?>('phone_account', params: {'p_device_id': await thisDeviceId(_storage)});
    if (holder != null) throw AccountRefused(AccountProblem.phoneTaken, holder);
  }

  /// Records this device with the company, which refuses one it turned off, then remembers the company here.
  Future<void> _enrol(String tenantId) async {
    final os = Platform.operatingSystem;
    await _client.rpc<String>(
      'register_device',
      params: {
        'p_tenant_id': tenantId,
        'p_device_id': await thisDeviceId(_storage),
        'p_label': await thisPhoneName(),
        'p_platform': const {'android', 'ios', 'windows'}.contains(os) ? os : 'web',
        'p_operation_id': newUuid(),
      },
    );
    final user = _auth.currentUser!;
    await _storage.write(key: _bindingKey, value: jsonEncode({'tenant_id': tenantId, 'user_id': user.id, 'email': user.email}));
  }

  /// A sign-in with the password from this run of the app is still here, so a step the cloud must trust needs no
  /// password again. A session brought back from the phone does not count.
  bool get signedIn => _typedPassword && _auth.currentSession != null;

  /// Brings back the session kept on this phone. With no network it stays kept for the next try; one the cloud no
  /// longer takes is forgotten, and the password is asked when the cloud is next needed.
  Future<void> resume() async {
    final kept = await _storage.read(key: _sessionKey);
    if (kept == null || _auth.currentSession != null) return;
    try {
      final session = Session.fromJson(jsonDecode(kept) as Map<String, dynamic>);
      if (session?.refreshToken == null) return;
      // An expired one renews with its refresh token, as the client does by itself when it refreshes.
      await (session!.isExpired ? _auth.setSession(session.refreshToken!) : _auth.recoverSession(kept));
    } catch (_) {}
  }

  /// This phone's licence for [tenantId], kept here and renewed from the cloud with the company's counts (D-074).
  Licensing licensing(String tenantId, Future<({int workers, int clients})> Function() counts) => Licensing(
    storage: _storage,
    publicKey: licenceKey,
    tenantId: tenantId,
    deviceId: thisDeviceId(_storage),
    fetch: (deviceId) => _run(() async {
      if (_auth.currentSession == null) throw const AccountRefused(AccountProblem.signedOut);
      if (_auth.currentSession!.isExpired) await _auth.refreshSession();
      final (:workers, :clients) = await counts();
      final response = await _client.functions.invoke(
        'licence',
        body: {'tenant_id': tenantId, 'device_id': deviceId, 'active_workers': workers, 'active_clients': clients},
      );
      final m = response.data as Map<String, dynamic>;
      return (payload: m['payload'] as String, sig: m['sig'] as String);
    }),
  );

  Future<void> signInAgain(String password) => _run(() async {
    await _auth.signInWithPassword(email: (await binding())!.email, password: password);
  });

  /// The company's phones that are on, this one first, then by the last login. The owner sees every one of them.
  Future<List<Phone>> phones() => _run(() async {
    final here = await thisDeviceId(_storage);
    final rows = await _client
        .from('devices')
        .select('id, device_id, label, last_seen_at_utc')
        .eq('tenant_id', (await binding())!.tenantId)
        .isFilter('revoked_at_utc', null)
        .order('last_seen_at_utc');
    final phones = [
      for (final r in rows)
        (id: r['id'] as String, name: r['label'] as String, lastLogin: DateTime.parse(r['last_seen_at_utc'] as String), here: r['device_id'] == here),
    ];
    return [...phones.where((p) => p.here), ...phones.where((p) => !p.here)];
  });

  /// Turns one of the company's phones off. It removes the company from itself the next time it opens online (D-073).
  Future<void> turnPhoneOff(String id) => _run(() => _client.rpc<void>('turn_phone_off', params: {'p_device_row': id, 'p_operation_id': newUuid()}));

  /// True only when the cloud says for certain that the company turned this phone off. No answer is never a yes, so
  /// a network error removes nothing (D-073). Asked before any sign-in, so it needs no session.
  Future<bool> phoneIsOff(String tenantId) async {
    try {
      final off = await _client.rpc<bool?>('phone_is_off', params: {'p_tenant_id': tenantId, 'p_device_id': await thisDeviceId(_storage)});
      return off == true;
    } catch (_) {
      return false;
    }
  }

  /// The plans on sale, in the order the platform set (D-074).
  Future<List<Plan>> plans() => _run(() async {
    final rows = await _client
        .from('plans')
        .select('code, name, price_fils, addon_price_fils, max_workers, max_clients, max_managers')
        .eq('on_sale', true)
        .order('sort_order');
    return [
      for (final r in rows)
        (
          code: r['code'] as String,
          name: r['name'] as String,
          priceFils: r['price_fils'] as int,
          addonFils: r['addon_price_fils'] as int,
          workers: r['max_workers'] as int?,
          clients: r['max_clients'] as int?,
          managers: r['max_managers'] as int?,
        ),
    ];
  });

  /// The bank account to pay into, from the live settings. Blank fields read as not filled in.
  Future<BankDetails> bankDetails() => _run(() async {
    final r = await _client.from('platform_settings').select('bank_name, account_number, iban, account_holder').maybeSingle() ?? const {};
    String? filled(String name) => switch ((r[name] as String?)?.trim()) {
      final text? when text.isNotEmpty => text,
      _ => null,
    };
    return (bankName: filled('bank_name'), accountNumber: filled('account_number'), iban: filled('iban'), holder: filled('account_holder'));
  });

  /// The company's slips, newest first, each saying whether its file reached the cloud.
  Future<List<Slip>> slips() => _run(() async {
    final tenantId = (await binding())!.tenantId;
    final rows = await _client
        .from('payment_slips')
        .select('id, plan_code, months, expected_fils, file_path, state, refuse_reason, submitted_at_utc')
        .eq('tenant_id', tenantId)
        .order('submitted_at_utc', ascending: false);
    final files = {for (final f in await _client.storage.from(_slipBucket).list(path: tenantId)) '$tenantId/${f.name}'};
    return [
      for (final r in rows)
        (
          id: r['id'] as String,
          planCode: r['plan_code'] as String,
          months: r['months'] as int,
          expectedFils: r['expected_fils'] as int,
          state: r['state'] as String,
          refuseReason: r['refuse_reason'] as String?,
          sentAt: DateTime.parse(r['submitted_at_utc'] as String),
          fileArrived: files.contains(r['file_path']),
        ),
    ];
  });

  /// Sends a slip for [months] of a plan: the cloud records it and names the path in the company's own folder, then the
  /// file goes there. The caller keeps [operationId] across retries, so a dropped upload reaches the same slip (MODEL-06).
  Future<void> sendSlip({required String planCode, required int months, required Uint8List bytes, required SlipKind kind, required String operationId}) =>
      _run(() async {
        final path = await _client.rpc<String>(
          'submit_slip',
          params: {'p_tenant_id': (await binding())!.tenantId, 'p_plan_code': planCode, 'p_months': months, 'p_file_type': kind.name, 'p_operation_id': operationId},
        );
        try {
          await _client.storage.from(_slipBucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: kind.mime));
        } on StorageException catch (e) {
          // Already there from a try whose answer was lost.
          if (e.error != 'Duplicate' && e.statusCode != '409') rethrow;
        }
      });

  /// Deletes this account from the cloud, with each company it owns (AUTH-07, D-066). The password is typed again: the
  /// server takes only a session signed in with it in the last minutes, so a phone left open cannot. The company's slip
  /// files go first, as SQL cannot remove a stored file. The caller then removes the company from this phone.
  Future<void> deleteAccount(String password) => _run(() async {
    await _auth.signInWithPassword(email: (await binding())!.email, password: password);
    final paths = await _client.from('payment_slips').select('file_path').eq('tenant_id', (await binding())!.tenantId);
    if (paths.isNotEmpty) await _client.storage.from(_slipBucket).remove([for (final p in paths) p['file_path'] as String]);
    // An empty body, not null, as PostgREST takes for a function with no arguments.
    await _client.rpc<void>('delete_account', params: const <String, dynamic>{});
  });

  /// Ends the account on this device (AUTH-04), without waiting on the network: signing out drops the session here at
  /// once, and the server is told when it answers. Offline it never is, and the session, held only in memory, dies
  /// with the app.
  Future<void> logOut() async {
    await _storage.delete(key: _bindingKey);
    await _storage.delete(key: _sessionKey);
    unawaited(_auth.signOut().then((_) {}, onError: (Object _) {}));
  }

  Future<T> _run<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on AccountRefused {
      rethrow;
    } catch (e) {
      throw AccountRefused(problemOf(e));
    }
  }
}

AccountProblem problemOf(Object error) => switch (error) {
  AuthRetryableFetchException() || SocketException() || http.ClientException() || FunctionsFetchException() => AccountProblem.offline,
  AuthSessionMissingException() => AccountProblem.signedOut,
  FunctionException(details: {'error': 'other_phone'}) => AccountProblem.otherPhone,
  FunctionException(details: {'error': 'phone_off'}) => AccountProblem.deviceRevoked,
  FunctionException(details: {'error': 'sign_in'}) => AccountProblem.signedOut,
  AuthException(statusCode: '429') => AccountProblem.tooMany,
  AuthException(code: 'over_email_send_rate_limit' || 'over_request_rate_limit') => AccountProblem.tooMany,
  AuthException(code: 'invalid_credentials') => AccountProblem.wrongLogin,
  AuthException(code: 'email_not_confirmed') => AccountProblem.notConfirmed,
  AuthException(code: 'user_already_exists' || 'email_exists') => AccountProblem.exists,
  AuthException(code: 'weak_password') => AccountProblem.weakPassword,
  AuthException(code: 'otp_expired') => AccountProblem.badCode,
  PostgrestException(:final message) when message.contains('revoked') => AccountProblem.deviceRevoked,
  PostgrestException(:final message) when message.contains('another account') => AccountProblem.phoneTaken,
  PostgrestException(:final message) when message.contains('other members') => AccountProblem.companyHasMembers,
  PostgrestException(:final message) when message.contains('slips are waiting') => AccountProblem.slipsWaiting,
  StorageException(statusCode: 'ClientException' || 'SocketException') => AccountProblem.offline,
  _ => AccountProblem.failed,
};

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmail(String text) => _email.hasMatch(text.trim());

/// Mirrors the project's rule (D-061): 8 or more characters, with letters and digits.
bool isStrongPassword(String text) => text.length >= 8 && RegExp('[A-Za-z]').hasMatch(text) && RegExp(r'\d').hasMatch(text);

/// The project can send 6 to 10 digits.
bool isEmailCode(String text) => RegExp(r'^\d{6,10}$').hasMatch(text.trim());
