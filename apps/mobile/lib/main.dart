import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'data/tenant_database.dart';
import 'spike_checks.dart';

void main() {
  runApp(const MaterialApp(home: SpikeScreen()));
}

/// T03 only: shows the encryption proof on a real phone. The five-tab shell replaces this in T05.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  late final Future<List<Check>> _checks = () async {
    const storage = FlutterSecureStorage();
    return runSpikeChecks(await getApplicationSupportDirectory(), (tenant) => tenantKey(storage, tenant));
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted DB check')),
      body: FutureBuilder(
        future: _checks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('FAIL: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final checks = snapshot.data!;
          final allPassed = checks.every((c) => c.pass);
          return ListView(
            children: [
              ListTile(title: Text(allPassed ? 'ALL PASSED' : 'SOME FAILED', style: Theme.of(context).textTheme.titleLarge)),
              for (final check in checks)
                ListTile(
                  leading: Text(check.pass ? 'PASS' : 'FAIL'),
                  title: Text(check.name),
                  subtitle: check.detail.isEmpty ? null : Text(check.detail),
                ),
            ],
          );
        },
      ),
    );
  }
}
