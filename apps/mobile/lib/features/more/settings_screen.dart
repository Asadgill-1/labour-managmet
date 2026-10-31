import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings.dart';
import '../../app/side_panel.dart';
import '../../l10n/app_localizations.dart';
import 'db_check_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: Text(l10n.tabSettings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.settingsLanguage),
            trailing: DropdownButton<Locale>(
              value: settings.locale,
              onChanged: (locale) => controller.setLocale(locale!),
              items: [
                DropdownMenuItem(value: romanUrdu, child: Text(l10n.languageRomanUrdu)),
                DropdownMenuItem(value: english, child: Text(l10n.languageEnglish)),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(l10n.settingsLargeText),
            value: settings.largeText,
            onChanged: controller.setLargeText,
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.dbCheckTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DbCheckScreen())),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
