import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account.dart';
import 'tenant_database.dart';

/// A licence as the cloud signed it: the payload's exact bytes and the signature over them, both base64url (BILL-03).
typedef SignedLicence = ({String payload, String sig});

/// How far the phone's clock may sit behind the cloud's, or behind itself as network time corrects it, before the plan
/// needs a check online (BILL-06). The tuning knob for phones whose clocks drift.
const clockSlack = Duration(minutes: 10);

/// What the cloud's signed licence says for one company on one phone (T21, D-074).
class Licence {
  const Licence({
    required this.tenantId,
    required this.deviceId,
    required this.state,
    required this.issuedAt,
    required this.leaseUntil,
    this.plan,
    this.planName,
    this.startsAt,
    this.endsAt,
    this.workers,
    this.clients,
    this.managers,
    this.devices,
  });

  final String tenantId;
  final String deviceId;

  /// trial, paid or none.
  final String state;
  final String? plan;
  final String? planName;
  final DateTime issuedAt;

  /// Trusted offline until then, at most 7 days after [issuedAt] and never past the plan's end (BILL-05).
  final DateTime leaseUntil;
  final DateTime? startsAt;

  /// The end of the unbroken run of paid periods, or of the trial.
  final DateTime? endsAt;

  /// Active workers, client companies, managers and phones the plan allows. Null is unlimited.
  final int? workers;
  final int? clients;
  final int? managers;
  final int? devices;
}

enum LicenceStatus {
  active,

  /// No licence on this phone yet.
  none,

  /// The trial or plan ended, or there never was one.
  ended,

  /// Seven days, or the plan's end, passed since the last check online.
  leaseOver,

  /// The phone's clock went back before a time it had already seen.
  clockBack,
}

Uint8List _unBase64Url(String text) => base64Url.decode(base64Url.normalize(text));

/// The licence in [signed], or null unless the key in [publicKey] signed it for this company and this phone.
Future<Licence?> verifyLicence(SignedLicence signed, String publicKey, {required String tenantId, required String deviceId}) async {
  try {
    final bytes = _unBase64Url(signed.payload);
    final key = SimplePublicKey(base64.decode(publicKey), type: KeyPairType.ed25519);
    if (!await Ed25519().verify(bytes, signature: Signature(_unBase64Url(signed.sig), publicKey: key))) return null;
    final m = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (m['v'] != 1 || m['iss'] != 'labour-app') return null;
    if ((m['tenant_id'] as String).toLowerCase() != tenantId.toLowerCase()) return null;
    if ((m['device_id'] as String).toLowerCase() != deviceId.toLowerCase()) return null;
    DateTime? at(String name) => m[name] == null ? null : DateTime.parse(m[name] as String).toUtc();
    final limits = m['limits'] as Map<String, dynamic>;
    return Licence(
      tenantId: tenantId,
      deviceId: deviceId,
      state: m['state'] as String,
      plan: m['plan'] as String?,
      planName: m['plan_name'] as String?,
      issuedAt: at('iat')!,
      leaseUntil: at('lease_until')!,
      startsAt: at('starts_at'),
      endsAt: at('ends_at'),
      workers: limits['workers'] as int?,
      clients: limits['clients'] as int?,
      managers: limits['managers'] as int?,
      devices: limits['devices'] as int?,
    );
  } catch (_) {
    // A licence that does not read is no licence: the phone then asks the cloud again.
    return null;
  }
}

/// Whether [licence] lets the company work at [now], given the latest time this phone has seen (BILL-05, BILL-06).
LicenceStatus licenceStatus(Licence? licence, DateTime now, DateTime latestSeen) {
  if (licence == null) return LicenceStatus.none;
  if (now.isBefore(latestSeen.subtract(clockSlack)) || now.isBefore(licence.issuedAt.subtract(clockSlack))) return LicenceStatus.clockBack;
  if (licence.state == 'none' || (licence.endsAt != null && !now.isBefore(licence.endsAt!))) return LicenceStatus.ended;
  if (!now.isBefore(licence.leaseUntil)) return LicenceStatus.leaseOver;
  return LicenceStatus.active;
}

/// The licence on this phone, what it allows now, and why the last check online failed, if it did.
typedef LicenceView = ({Licence? licence, LicenceStatus status, AccountProblem? problem});

const _licenceKey = 'licence';
const _seenKey = 'licence_seen';

/// The open company's licence on this phone: kept in secure storage, checked against the cloud's public key on every
/// read, and renewed online at start and after login (BILL-05). The phone keeps the latest time it has seen, so a clock
/// moved back needs a check online (BILL-06).
class Licensing {
  Licensing({
    required this._storage,
    required this._publicKey,
    required this.tenantId,
    required Future<String> deviceId,
    required this._fetch,
    this._clock = DateTime.now,
  }) : _deviceIdFuture = deviceId;

  final FlutterSecureStorage _storage;
  final String _publicKey;
  final String tenantId;
  final Future<String> _deviceIdFuture;
  final Future<SignedLicence> Function(String deviceId) _fetch;
  final DateTime Function() _clock;
  final _loaded = Completer<void>();
  final _changes = StreamController<LicenceView>.broadcast();
  late String _deviceId;
  Licence? _licence;
  DateTime _latestSeen = DateTime.utc(2000);
  AccountProblem? _problem;

  LicenceView get view => (licence: _licence, status: licenceStatus(_licence, _clock().toUtc(), _latestSeen), problem: _problem);

  /// The view once the kept licence is read, then each change.
  Stream<LicenceView> watch() async* {
    await _loaded.future;
    yield view;
    yield* _changes.stream;
  }

  /// Reads the kept licence, with no network.
  Future<void> load() async {
    _deviceId = await _deviceIdFuture;
    final kept = await _storage.read(key: _licenceKey);
    if (kept != null) {
      final m = jsonDecode(kept) as Map<String, dynamic>;
      _licence = await _verify((payload: m['payload'] as String, sig: m['sig'] as String));
    }
    final seen = await _storage.read(key: _seenKey);
    if (seen != null) _latestSeen = DateTime.parse(seen);
    await _see(_clock().toUtc());
    if (!_loaded.isCompleted) _loaded.complete();
  }

  /// Asks the cloud for a fresh licence. A refusal or no network keeps the licence there is, until its lease runs out.
  Future<void> refresh() async {
    try {
      final signed = await _fetch(_deviceId);
      final fresh = await _verify(signed);
      if (fresh == null) throw const AccountRefused(AccountProblem.failed);
      // A licence older than the one kept is a replay, and changes nothing.
      if (_licence == null || !fresh.issuedAt.isBefore(_licence!.issuedAt)) {
        await _storage.write(key: _licenceKey, value: jsonEncode({'payload': signed.payload, 'sig': signed.sig}));
        _licence = fresh;
        // The cloud's own time, so a clock that once ran ahead and was put right works again at once.
        _latestSeen = fresh.issuedAt;
        await _see(_clock().toUtc());
      }
      _problem = null;
    } on AccountRefused catch (e) {
      _problem = e.problem;
    } catch (_) {
      _problem = AccountProblem.failed;
    }
    // The company may have closed while the cloud answered.
    if (!_changes.isClosed) _changes.add(view);
  }

  Future<void> dispose() => _changes.close();

  Future<Licence?> _verify(SignedLicence signed) => verifyLicence(signed, _publicKey, tenantId: tenantId, deviceId: _deviceId);

  Future<void> _see(DateTime now) async {
    if (now.isAfter(_latestSeen)) _latestSeen = now;
    await _storage.write(key: _seenKey, value: _latestSeen.toIso8601String());
  }
}

/// What a licence check reports: the company's active workers and client companies on this phone (D-074).
Future<({int workers, int clients})> activeCounts(TenantDatabase db) async {
  final workers = db.workers.id.count(filter: db.workers.active.equals(true));
  final clients = db.clients.id.count(filter: db.clients.active.equals(true));
  final w = await (db.selectOnly(db.workers)..addColumns([workers])).getSingle();
  final c = await (db.selectOnly(db.clients)..addColumns([clients])).getSingle();
  return (workers: w.read(workers)!, clients: c.read(clients)!);
}
