import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class LabourScreen extends StatelessWidget {
  const LabourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabLabour)),
      body: Center(child: Text(l10n.labourEmpty)),
    );
  }
}
