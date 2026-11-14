import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account.dart';
import '../data/app_lock.dart';
import '../data/licence.dart';
import '../data/masters.dart';
import '../data/plan_guard.dart';
import '../data/restore.dart';
import '../data/tenant_database.dart';
import '../features/account/account_screens.dart';
import '../features/backup/restore_screen.dart';
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
    required this.deleteTenant,
    this.opened,
    this.pinSet = false,
    this.files,
    super.key,
  });

  final Account account;
  final AppLock lock;
  final AppSettings settings;
  final OpenTenant openTenant;

  /// The language and colours chosen on the account screens carry into the books, and back.
  final Future<AppSettings> Function() loadSettings;

  /// Removes a closed company's file and key from this device, once its account is deleted (AUTH-07).
  final Future<void> Function(String tenantId) deleteTenant;

  /// The company main opened, when this device already had one.
  final ({TenantDatabase db, Binding binding})? opened;

  /// [opened] has its PIN already, so it waits behind the lock; without one it opens straight away (D-064).
  final bool pinSet;

  /// Where a restore finds the company's files (DATA-05). Null leaves restore out.
  final TenantFiles? files;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late var _settings = widget.settings;
  late var _opened = widget.opened;
  late var _lock = widget.pinSet ? _Lock.locked : _Lock.open;
  LoginNote? _note;
  Licensing? _licensing;
  ({SwapStage stage, Restored done, bool kept})? _swapping;

  @override
  void initState() {
    super.initState();
    if (_opened case final opened?) {
      _guard(opened.db);
      unawaited(_closeIfOff(opened.binding.tenantId));
      _startLicence(opened.binding.tenantId, resume: true);
    }
  }

  /// Every write of the open company asks its plan, as the licence on this phone gives it now (T21c).
  void _guard(TenantDatabase db) => db.guard = planGuard(db, () => _licensing?.view);

  /// Reads the licence kept here at once, then renews it from the cloud, with the session kept on the phone when the
  /// app has just started (D-074). Counted from whichever file is open, as a restore swaps it.
  void _startLicence(String tenantId, {required bool resume}) {
    final licensing = _licensing = widget.account.licensing(tenantId, () => activeCounts(_opened!.db));
    unawaited(() async {
      await licensing.load();
      if (resume) await widget.account.resume();
      if (_licensing == licensing) await licensing.refresh();
    }());
  }

  /// A phone the company turned off removes the company from itself as it opens, even behind the lock (D-073).
  Future<void> _closeIfOff(String tenantId) async {
    if (!await widget.account.phoneIsOff(tenantId) || !mounted) return;
    if (_opened?.binding.tenantId == tenantId && _swapping == null) await _leave(LoginNote.phoneOff);
  }

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
      _startLicence(tenantId, resume: false);
      _guard(db);
    });
  }

  void _unlock() => setState(() => _lock = _Lock.open);

  Future<void> _logOut({bool lockedOut = false}) => _leave(lockedOut ? LoginNote.lockedOut : null);

  /// The cloud deletes the account first; only then does the company leave this phone (D-066).
  Future<void> _deleteAccount(String password) async {
    await widget.account.deleteAccount(password);
    await _leave(LoginNote.accountDeleted);
  }

  /// Closes the company, puts the prepared file in its place and opens it again (DATA-05). The prepared file was opened
  /// and checked already, so only the swap itself can fail, and the company's own file is then still whole.
  Future<void> _swap(Restored done, {required bool keep}) async {
    final (:db, :binding) = _opened!;
    // The language and colours chosen in the books carry through the swap and back into them.
    final settings = await widget.loadSettings();
    setState(() {
      _settings = settings;
      _swapping = (stage: SwapStage.working, done: done, kept: keep);
    });
    await WidgetsBinding.instance.endOfFrame;
    await db.close();
    var stage = SwapStage.done;
    try {
      await swapIn(widget.files!.dir, binding.tenantId, keep: keep);
    } catch (_) {
      stage = SwapStage.failed;
    }
    final fresh = await widget.openTenant(binding.tenantId, actorId: binding.userId);
    _guard(fresh);
    // The old data's images must not show for the new.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (!mounted) return;
    setState(() {
      _opened = (db: fresh, binding: binding);
      _swapping = (stage: stage, done: done, kept: keep);
    });
  }

  Future<void> _leave(LoginNote? note) async {
    final (:db, :binding) = _opened!;
    final licensing = _licensing;
    _licensing = null;
    await widget.account.logOut();
    await widget.lock.clear();
    final settings = await widget.loadSettings();
    setState(() {
      _settings = settings;
      _opened = null;
      _note = note;
    });
    // The company's scope goes with this frame, and its streams with it; only then can the file close.
    await WidgetsBinding.instance.endOfFrame;
    await db.close();
    await licensing?.dispose();
    if (note == LoginNote.accountDeleted || note == LoginNote.phoneOff) await widget.deleteTenant(binding.tenantId);
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await clearExportFiles();
  }

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    final files = widget.files;
    if (opened == null) {
      return ProviderScope(
        key: const ValueKey('account'),
        overrides: [initialSettingsProvider.overrideWithValue(_settings)],
        child: AccountApp(home: LoginScreen(account: widget.account, onOpen: _open, note: _note)),
      );
    }
    final swapping = _swapping;
    if (swapping != null) {
      return ProviderScope(
        key: const ValueKey('swap'),
        overrides: [initialSettingsProvider.overrideWithValue(_settings)],
        child: AccountApp(
          home: SwapScreen(stage: swapping.stage, restored: swapping.done, kept: swapping.kept, onDone: () => setState(() => _swapping = null)),
        ),
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
        accountProvider.overrideWithValue((email: opened.binding.email, logOut: _logOut, deleteAccount: _deleteAccount, lock: widget.lock, account: widget.account)),
        restoreProvider.overrideWithValue(files == null ? null : (dir: files.dir, key: () => files.key(opened.binding.tenantId), swap: _swap)),
        licensingProvider.overrideWithValue(_licensing),
      ],
      child: const LabourApp(),
    );
  }
}
