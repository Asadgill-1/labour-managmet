import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import 'tenant_database.dart';

/// Why an account step failed, in terms a screen can say plainly (UX-04).
enum AccountProblem { offline, wrongLogin, notConfirmed, exists, weakPassword, badCode, tooMany, deviceRevoked, phoneTaken, phoneData, failed }

class AccountRefused implements Exception {
  const AccountRefused(this.problem, [this.holder]);

  final AccountProblem problem;

  /// With [AccountProblem.phoneTaken]: the masked email of the account that holds this phone, when the server said.
  final String? holder;

  @override
  String toString() => 'AccountRefused($problem)';
}

/// The company this device opens without signing in again, and who signed in on it (AUTH-03).
typedef Binding = ({String tenantId, String userId, String email});

const _bindingKey = 'account';

/// Sign-up, sign-in and the company this device opens (T19b). The app holds only the publishable key; the company
/// comes from the signed-in user's membership, never from the app (AUTH-02, AUTH-06).
class Account {
  Account(this._client, this._storage, {required this.emailCodes});

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;

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
    final host = Platform.localHostname.trim();
    await _client.rpc<String>(
      'register_device',
      params: {
        'p_tenant_id': tenantId,
        'p_device_id': await thisDeviceId(_storage),
        'p_label': host.isEmpty || host == 'localhost' ? os : host,
        'p_platform': const {'android', 'ios', 'windows'}.contains(os) ? os : 'web',
        'p_operation_id': newUuid(),
      },
    );
    final user = _auth.currentUser!;
    await _storage.write(key: _bindingKey, value: jsonEncode({'tenant_id': tenantId, 'user_id': user.id, 'email': user.email}));
  }

  /// Ends the account on this device (AUTH-04), without waiting on the network: signing out drops the session here at
  /// once, and the server is told when it answers. Offline it never is, and the session, held only in memory, dies
  /// with the app.
  Future<void> logOut() async {
    await _storage.delete(key: _bindingKey);
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
  AuthRetryableFetchException() || SocketException() || http.ClientException() => AccountProblem.offline,
  AuthException(statusCode: '429') => AccountProblem.tooMany,
  AuthException(code: 'over_email_send_rate_limit' || 'over_request_rate_limit') => AccountProblem.tooMany,
  AuthException(code: 'invalid_credentials') => AccountProblem.wrongLogin,
  AuthException(code: 'email_not_confirmed') => AccountProblem.notConfirmed,
  AuthException(code: 'user_already_exists' || 'email_exists') => AccountProblem.exists,
  AuthException(code: 'weak_password') => AccountProblem.weakPassword,
  AuthException(code: 'otp_expired') => AccountProblem.badCode,
  PostgrestException(:final message) when message.contains('revoked') => AccountProblem.deviceRevoked,
  PostgrestException(:final message) when message.contains('another account') => AccountProblem.phoneTaken,
  _ => AccountProblem.failed,
};

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmail(String text) => _email.hasMatch(text.trim());

/// Mirrors the project's rule (D-061): 8 or more characters, with letters and digits.
bool isStrongPassword(String text) => text.length >= 8 && RegExp('[A-Za-z]').hasMatch(text) && RegExp(r'\d').hasMatch(text);

/// The project can send 6 to 10 digits.
bool isEmailCode(String text) => RegExp(r'^\d{6,10}$').hasMatch(text.trim());
