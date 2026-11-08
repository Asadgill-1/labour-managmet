import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'theme.dart';

/// `en_PK` carries Roman Urdu. `ur` would flip the app to RTL and load Urdu-script Material strings (D-010).
const romanUrdu = Locale('en', 'PK');
const english = Locale('en');

class AppSettings {
  const AppSettings({this.locale = romanUrdu, this.largeText = false, this.palette = AppPalette.blue});

  final Locale locale;
  final bool largeText;
  final AppPalette palette;

  static Future<AppSettings> load(FlutterSecureStorage storage) async {
    final language = await storage.read(key: 'setting_language');
    final largeText = await storage.read(key: 'setting_large_text');
    final palette = await storage.read(key: 'setting_palette');
    return AppSettings(
      locale: language == 'en' ? english : romanUrdu,
      largeText: largeText == 'true',
      palette: AppPalette.values.asNameMap()[palette] ?? AppPalette.blue,
    );
  }
}

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final initialSettingsProvider = Provider((ref) => const AppSettings());
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> setLocale(Locale locale) async {
    state = AppSettings(locale: locale, largeText: state.largeText, palette: state.palette);
    await ref.read(secureStorageProvider).write(key: 'setting_language', value: locale == english ? 'en' : 'en_PK');
  }

  Future<void> setLargeText(bool largeText) async {
    state = AppSettings(locale: state.locale, largeText: largeText, palette: state.palette);
    await ref.read(secureStorageProvider).write(key: 'setting_large_text', value: '$largeText');
  }

  Future<void> setPalette(AppPalette palette) async {
    state = AppSettings(locale: state.locale, largeText: state.largeText, palette: palette);
    await ref.read(secureStorageProvider).write(key: 'setting_palette', value: palette.name);
  }
}
