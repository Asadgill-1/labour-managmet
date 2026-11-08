import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/data/tenant_database.dart';
import 'package:labour_app/spike_checks.dart';

void main() {
  test('encrypted per-tenant database checks all pass, and data survives a second run', () async {
    final dir = await Directory.systemTemp.createTemp('tenant_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final keys = <String, String>{};
    Future<String> keyFor(String tenant) async => keys.putIfAbsent(tenant, newHexKey);

    for (var run = 0; run < 2; run++) {
      final checks = await runSpikeChecks(dir, keyFor);
      for (final check in checks) {
        expect(check.pass, isTrue, reason: '${check.name}: ${check.detail}');
      }
    }
  });
}
