import 'package:flutter/material.dart';

import '../../app/side_panel.dart';
import '../../l10n/app_localizations.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen(this.section, {super.key});

  final Section section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(sectionLabel(AppLocalizations.of(context), section)), bottom: SubTabs(section)),
    );
  }
}
