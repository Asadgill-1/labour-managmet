import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

/// Tables arrive with the generated schema in T06.
class TenantDatabase extends GeneratedDatabase {
  TenantDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
}

/// One encrypted file per tenant (D-005). The tenant ID becomes a file name, so only a UUID passes.
File tenantFile(Directory dir, String tenantId) {
  if (!_uuid.hasMatch(tenantId)) {
    throw ArgumentError.value(tenantId, 'tenantId', 'must be a lowercase UUID');
  }
  return File('${dir.path}/tenant_$tenantId.db');
}

TenantDatabase openTenantDatabase(File file, String hexKey) {
  return TenantDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Not an assert: a build without the cipher must never write payroll data in plaintext.
        if (db.select('PRAGMA cipher;').isEmpty) {
          throw StateError('SQLite build has no encryption support');
        }
        db.execute("PRAGMA hexkey = '$hexKey';");
      },
    ),
  );
}

String newHexKey() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Reads this tenant's key from Android Keystore-backed storage, creating it on first use.
Future<String> tenantKey(FlutterSecureStorage storage, String tenantId) async {
  final name = 'db_key_$tenantId';
  final existing = await storage.read(key: name);
  if (existing != null) return existing;
  final created = newHexKey();
  await storage.write(key: name, value: created);
  return created;
}
