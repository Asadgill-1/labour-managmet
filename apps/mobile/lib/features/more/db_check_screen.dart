import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/tenant_database.dart';
import '../../l10n/app_localizations.dart';
import '../../spike_checks.dart';

/// T03 proof on a real phone. Remove once the owner's phone test passes.
class DbCheckScreen extends StatefulWidget {
  const DbCheckScreen({super.key});

  @override
  State<DbCheckScreen> createState() => _DbCheckScreenState();
}

class _DbCheckScreenState extends State<DbCheckScreen> {
  late final Future<List<Check>> _checks = () async {
    const storage = FlutterSecureStorage();
    return runSpikeChecks(await getApplicationSupportDirectory(), (tenant) => tenantKey(storage, tenant));
  }();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dbCheckTitle)),
      body: FutureBuilder(
        future: _checks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('FAIL: ${snapshot.error}'));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final checks = snapshot.data!;
          final allPassed = checks.every((c) => c.pass);
          return ListView(
            children: [
              ListTile(
                title: Text(allPassed ? l10n.dbCheckAllPassed : l10n.dbCheckSomeFailed, style: Theme.of(context).textTheme.titleLarge),
              ),
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
