import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/tenant_database.dart';

import 'generated/schema.dart';

void main() {
  test('schema matches the saved snapshot, so a table change without a migration fails', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = TenantDatabase(connection, tenantId: 'tenant', deviceId: 'device');
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });
}
