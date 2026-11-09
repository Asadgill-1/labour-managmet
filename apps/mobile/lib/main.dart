import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/root.dart';
import 'app/settings.dart';
import 'data/account.dart';
import 'data/tenant_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  final account = Account.ofBuild(storage);
  final AppSettings settings;
  final Directory dir;
  TenantDatabase? local;
  ({TenantDatabase db, Binding binding})? opened;
  try {
    settings = await AppSettings.load(storage);
    dir = await getApplicationSupportDirectory();
    if (account == null) {
      local = await openLocalTenant(storage, dir);
    } else {
      // A device someone signed in on opens its company with no network (AUTH-03, ARCH-07).
      final binding = await account.binding();
      if (binding != null) opened = (db: await openTenant(storage, dir, binding.tenantId, actorId: binding.userId), binding: binding);
    }
  } catch (_) {
    // Nothing is created or deleted on this path. The app's data stays as it was.
    runApp(const MaterialApp(home: Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text(startupError))))));
    return;
  }
  if (account == null) {
    runApp(
      ProviderScope(
        overrides: [initialSettingsProvider.overrideWithValue(settings), dbProvider.overrideWithValue(local!)],
        child: const LabourApp(),
      ),
    );
    return;
  }
  runApp(
    AppRoot(
      account: account,
      settings: settings,
      opened: opened,
      openTenant: (tenantId, {required actorId}) => openTenant(storage, dir, tenantId, actorId: actorId),
      loadSettings: () => AppSettings.load(storage),
    ),
  );
}

/// Shown before localization exists, so it carries both languages.
const startupError =
    'App khul nahin saki. Aap ka data delete nahin hua. App band kar ke dobara kholein.\n\n'
    'The app could not start. Your data was not deleted. Close the app and open it again.';
