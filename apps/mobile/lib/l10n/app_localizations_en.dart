// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabToday => 'Today';

  @override
  String get tabCompanies => 'Companies';

  @override
  String get tabLabour => 'Labour';

  @override
  String get tabAccounts => 'Accounts';

  @override
  String get tabMore => 'More';

  @override
  String get todayEmpty => 'No attendance recorded today.';

  @override
  String get companiesEmpty => 'No client companies yet.';

  @override
  String get labourEmpty => 'No workers yet.';

  @override
  String get accountsComingLater =>
      'Payroll, invoices, money received, money paid and closing arrive in the next builds.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get settingsLargeText => 'Large text';

  @override
  String get dbCheckTitle => 'Data encryption check';

  @override
  String get dbCheckAllPassed => 'All passed';

  @override
  String get dbCheckSomeFailed => 'Some failed';

  @override
  String get savedOnPhone => 'Saved on phone';
}

/// The translations for English, as used in Pakistan (`en_PK`).
class AppLocalizationsEnPk extends AppLocalizationsEn {
  AppLocalizationsEnPk() : super('en_PK');

  @override
  String get tabToday => 'Aaj';

  @override
  String get tabCompanies => 'Companies';

  @override
  String get tabLabour => 'Labour';

  @override
  String get tabAccounts => 'Hisaab';

  @override
  String get tabMore => 'Aur';

  @override
  String get todayEmpty => 'Aaj koi hazri darj nahin hui.';

  @override
  String get companiesEmpty => 'Abhi koi client company nahin.';

  @override
  String get labourEmpty => 'Abhi koi mazdoor nahin.';

  @override
  String get accountsComingLater =>
      'Tankhwah, invoices, paisay mile, paisay diye aur closing aglay builds mein aayenge.';

  @override
  String get settingsLanguage => 'Zaban';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRomanUrdu => 'Roman Urdu';

  @override
  String get settingsLargeText => 'Bara text';

  @override
  String get dbCheckTitle => 'Data encryption ki jaanch';

  @override
  String get dbCheckAllPassed => 'Sab theek';

  @override
  String get dbCheckSomeFailed => 'Kuch fail';

  @override
  String get savedOnPhone => 'Mobile par save';
}
