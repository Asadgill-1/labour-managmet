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
  final settings = await AppSettings.load(storage);
  final db = await openLocalTenant(storage, await getApplicationSupportDirectory());
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings), dbProvider.overrideWithValue(db)],
      child: const LabourApp(),
    ),
  );
}
