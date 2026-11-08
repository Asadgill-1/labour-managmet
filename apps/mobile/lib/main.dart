import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'data/tenant_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  final AppSettings settings;
  final TenantDatabase db;
  try {
    settings = await AppSettings.load(storage);
    db = await openLocalTenant(storage, await getApplicationSupportDirectory());
  } catch (_) {
    // Nothing is created or deleted on this path. The app's data stays as it was.
    runApp(const MaterialApp(home: Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Text(startupError))))));
    return;
  }
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings), dbProvider.overrideWithValue(db)],
      child: const LabourApp(),
    ),
  );
}

/// Shown before localization exists, so it carries both languages.
const startupError =
    'App khul nahin saki. Aap ka data delete nahin hua. App band kar ke dobara kholein.\n\n'
    'The app could not start. Your data was not deleted. Close the app and open it again.';
