import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Payroll and billing arrive in P2 and P3. Until then this says so plainly (AI-07).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabAccounts)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.accountsComingLater),
      ),
    );
  }
}
