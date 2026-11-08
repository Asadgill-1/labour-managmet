import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/settings.dart';
import '../../app/side_panel.dart';
import '../../app/theme.dart';
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l10n.settingsColour, style: sectionTitleStyle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                for (final palette in AppPalette.values) ...[
                  if (palette != AppPalette.values.first) const SizedBox(width: 8),
                  Expanded(
                    child: _PaletteChoice(palette, selected: settings.palette == palette, onTap: () => controller.setPalette(palette)),
                  ),
                ],
              ],
            ),
          ),
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
            tileColor: Colors.white,
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

/// A small picture of the colours, so the choice is made by eye, with its name in words as well (UX-04).
class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice(this.palette, {required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = switch (palette) {
      AppPalette.blue => l10n.paletteBlue,
      AppPalette.green => l10n.paletteGreen,
      AppPalette.maroon => l10n.paletteMaroon,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? palette.brand : rule, width: selected ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                color: palette.brand,
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(height: 22, child: selected ? const Icon(Icons.check_circle, size: 22, color: Colors.white) : null),
                    ),
                    const Spacer(),
                    Container(
                      height: 16,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: palette.action, borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ink)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
