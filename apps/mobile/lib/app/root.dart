import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account.dart';
import '../data/app_lock.dart';
import '../data/masters.dart';
import '../data/tenant_database.dart';
import '../features/account/account_screens.dart';
import '../features/registers/register_export.dart';
import 'app.dart';
import 'providers.dart';
import 'settings.dart';

/// Opens one company's file on this device for the user who signed in.
typedef OpenTenant = Future<TenantDatabase> Function(String tenantId, {required String actorId});

enum _Lock { setPin, locked, open }

/// The account screens until a company is open on this device, then that company's books behind the phone's lock
/// (T19b). Each company opens in a scope of its own, so logging out drops everything the last one held (AUTH-04).
class AppRoot extends StatefulWidget {
  const AppRoot({
    required this.account,
    required this.lock,
    required this.settings,
    required this.openTenant,
    required this.loadSettings,
    this.opened,
    this.pinSet = false,
    super.key,
  });

  final Account account;
  final AppLock lock;
  final AppSettings settings;
  final OpenTenant openTenant;

  /// The language and colours chosen on the account screens carry into the books, and back.
  final Future<AppSettings> Function() loadSettings;

  /// The company main opened, when this device already had one.
  final ({TenantDatabase db, Binding binding})? opened;

  /// [opened] has its PIN already, so it waits behind the lock; without one it opens straight away (D-064).
  final bool pinSet;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late var _settings = widget.settings;
  late var _opened = widget.opened;
  late var _lock = widget.pinSet ? _Lock.locked : _Lock.open;
  var _lockedOut = false;

  Future<void> _open(String tenantId, {String? companyName}) async {
    final binding = (await widget.account.binding())!;
    final db = await widget.openTenant(tenantId, actorId: binding.userId);
    if (companyName != null && await db.select(db.tenantProfiles).getSingleOrNull() == null) {
      await db.saveRow(db.tenantProfiles, id: null, operationId: newUuid(), fields: TenantProfilesCompanion(legalName: Value(companyName)));
    }
    final settings = await widget.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _opened = (db: db, binding: binding);
      _lock = _Lock.setPin;
    });
  }

  void _unlock() => setState(() => _lock = _Lock.open);

  Future<void> _logOut({bool lockedOut = false}) async {
    final db = _opened!.db;
    await widget.account.logOut();
    await widget.lock.clear();
    final settings = await widget.loadSettings();
    setState(() {
      _settings = settings;
      _opened = null;
      _lockedOut = lockedOut;
    });
    // The company's scope goes with this frame, and its streams with it; only then can the file close.
    await WidgetsBinding.instance.endOfFrame;
    await db.close();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await clearExportFiles();
  }

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    if (opened == null) {
      return ProviderScope(
        key: const ValueKey('account'),
        overrides: [initialSettingsProvider.overrideWithValue(_settings)],
        child: AccountApp(home: LoginScreen(account: widget.account, onOpen: _open, lockedOut: _lockedOut)),
      );
    }
    if (_lock != _Lock.open) {
      return ProviderScope(
        key: const ValueKey('lock'),
        overrides: [initialSettingsProvider.overrideWithValue(_settings)],
        child: AccountApp(
          home: _lock == _Lock.setPin
              ? SetPinScreen(lock: widget.lock, onDone: _unlock, onSkip: _unlock)
              : LockScreen(lock: widget.lock, email: opened.binding.email, onUnlock: _unlock, onLogInAgain: _logOut),
        ),
      );
    }
    return ProviderScope(
      key: ObjectKey(opened.db),
      overrides: [
        initialSettingsProvider.overrideWithValue(_settings),
        dbProvider.overrideWithValue(opened.db),
        accountProvider.overrideWithValue((email: opened.binding.email, logOut: _logOut, lock: widget.lock)),
      ],
      child: const LabourApp(),
    );
  }
}
