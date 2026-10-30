import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class CompaniesScreen extends StatelessWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabCompanies)),
      body: Center(child: Text(l10n.companiesEmpty)),
    );
  }
}
