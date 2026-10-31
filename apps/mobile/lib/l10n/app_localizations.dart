import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'PK'),
  ];

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabCompanies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get tabCompanies;

  /// No description provided for @tabLabour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get tabLabour;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Worker groups'**
  String get tabGroups;

  /// No description provided for @addGroup.
  ///
  /// In en, this message translates to:
  /// **'Make a group'**
  String get addGroup;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @groupNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example: Emaar West'**
  String get groupNameHelp;

  /// No description provided for @groupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups yet. Make one for workers who usually go together.'**
  String get groupsEmpty;

  /// No description provided for @noneChoice.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneChoice;

  /// No description provided for @dailyWage.
  ///
  /// In en, this message translates to:
  /// **'Daily wage (AED)'**
  String get dailyWage;

  /// No description provided for @dailyWageHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. It shows beside every worker. To change one worker, tap the amount beside their name.'**
  String get dailyWageHelp;

  /// No description provided for @halfDayIsHalf.
  ///
  /// In en, this message translates to:
  /// **'Half day pays half the daily wage'**
  String get halfDayIsHalf;

  /// No description provided for @ownWageHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the group\'s daily wage.'**
  String get ownWageHelp;

  /// No description provided for @todayWageHelp.
  ///
  /// In en, this message translates to:
  /// **'For this attendance only. The group does not change.'**
  String get todayWageHelp;

  /// No description provided for @todayWageReason.
  ///
  /// In en, this message translates to:
  /// **'Daily wage typed while marking attendance'**
  String get todayWageReason;

  /// No description provided for @setWage.
  ///
  /// In en, this message translates to:
  /// **'Set wage'**
  String get setWage;

  /// No description provided for @monthlyPay.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyPay;

  /// No description provided for @workersHeading.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get workersHeading;

  /// No description provided for @searchGroup.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get searchGroup;

  /// No description provided for @searchWorker.
  ///
  /// In en, this message translates to:
  /// **'Search workers'**
  String get searchWorker;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} workers'**
  String membersCount(int count);

  /// No description provided for @saveWithCount.
  ///
  /// In en, this message translates to:
  /// **'Save ({count} workers)'**
  String saveWithCount(int count);

  /// No description provided for @wageOf.
  ///
  /// In en, this message translates to:
  /// **'Daily wage: {name}'**
  String wageOf(String name);

  /// No description provided for @tabRates.
  ///
  /// In en, this message translates to:
  /// **'Rates'**
  String get tabRates;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @menuLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuLabel;

  /// No description provided for @menuClose.
  ///
  /// In en, this message translates to:
  /// **'Hide menu'**
  String get menuClose;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @groupDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get groupDaily;

  /// No description provided for @groupRegisters.
  ///
  /// In en, this message translates to:
  /// **'Registers'**
  String get groupRegisters;

  /// No description provided for @groupPayroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll and money'**
  String get groupPayroll;

  /// No description provided for @groupBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get groupBilling;

  /// No description provided for @groupMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get groupMore;

  /// No description provided for @menuPayroll.
  ///
  /// In en, this message translates to:
  /// **'Payroll'**
  String get menuPayroll;

  /// No description provided for @menuAdvances.
  ///
  /// In en, this message translates to:
  /// **'Advances'**
  String get menuAdvances;

  /// No description provided for @menuPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get menuPayments;

  /// No description provided for @menuExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get menuExpenses;

  /// No description provided for @menuTimesheets.
  ///
  /// In en, this message translates to:
  /// **'Timesheets'**
  String get menuTimesheets;

  /// No description provided for @menuInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get menuInvoices;

  /// No description provided for @menuReceived.
  ///
  /// In en, this message translates to:
  /// **'Money received'**
  String get menuReceived;

  /// No description provided for @menuReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get menuReports;

  /// No description provided for @menuDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get menuDocuments;

  /// No description provided for @menuTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get menuTeam;

  /// No description provided for @menuBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get menuBackup;

  /// No description provided for @menuPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get menuPlan;

  /// No description provided for @menuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// No description provided for @countWorkers.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get countWorkers;

  /// No description provided for @countShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get countShifts;

  /// No description provided for @countWorkerDays.
  ///
  /// In en, this message translates to:
  /// **'Worker-days'**
  String get countWorkerDays;

  /// No description provided for @dayNames.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get dayNames;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get pickDate;

  /// No description provided for @chooseWorker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get chooseWorker;

  /// No description provided for @noBillingRates.
  ///
  /// In en, this message translates to:
  /// **'No company rates yet. Add one so attendance can be priced.'**
  String get noBillingRates;

  /// No description provided for @noPayRates.
  ///
  /// In en, this message translates to:
  /// **'No pay rates yet. Add one so attendance can be priced.'**
  String get noPayRates;

  /// No description provided for @balancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing carried over yet. Add what was already due when you started using this app.'**
  String get balancesEmpty;

  /// No description provided for @addBalance.
  ///
  /// In en, this message translates to:
  /// **'Add carried-over amount'**
  String get addBalance;

  /// No description provided for @balanceKind.
  ///
  /// In en, this message translates to:
  /// **'What kind of amount?'**
  String get balanceKind;

  /// No description provided for @todayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No attendance on this date. Tap Mark attendance to start.'**
  String get todayEmpty;

  /// No description provided for @companiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No client companies yet. Add your first one.'**
  String get companiesEmpty;

  /// No description provided for @labourEmpty.
  ///
  /// In en, this message translates to:
  /// **'No workers yet. Add your first one.'**
  String get labourEmpty;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRomanUrdu.
  ///
  /// In en, this message translates to:
  /// **'Roman Urdu'**
  String get languageRomanUrdu;

  /// No description provided for @settingsLargeText.
  ///
  /// In en, this message translates to:
  /// **'Large text'**
  String get settingsLargeText;

  /// No description provided for @dbCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Data encryption check'**
  String get dbCheckTitle;

  /// No description provided for @dbCheckAllPassed.
  ///
  /// In en, this message translates to:
  /// **'All passed'**
  String get dbCheckAllPassed;

  /// No description provided for @dbCheckSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'Some failed'**
  String get dbCheckSomeFailed;

  /// No description provided for @savedOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Saved on phone'**
  String get savedOnPhone;

  /// No description provided for @databaseError.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be opened. Nothing was deleted. Close the app and open it again. If this repeats, contact support.'**
  String get databaseError;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clearValue.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearValue;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required'**
  String get fieldRequired;

  /// No description provided for @wholeNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get wholeNumberRequired;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount like 1100.50'**
  String get amountInvalid;

  /// No description provided for @showArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get showArchived;

  /// No description provided for @showActive.
  ///
  /// In en, this message translates to:
  /// **'Show active'**
  String get showActive;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @reactivate.
  ///
  /// In en, this message translates to:
  /// **'Make active again'**
  String get reactivate;

  /// No description provided for @archivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archivedLabel;

  /// No description provided for @activeLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeLabel;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your company'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Start with your company\'s name. You can add the rest later.'**
  String get welcomeBody;

  /// No description provided for @myCompany.
  ///
  /// In en, this message translates to:
  /// **'My company'**
  String get myCompany;

  /// No description provided for @legalName.
  ///
  /// In en, this message translates to:
  /// **'Legal company name'**
  String get legalName;

  /// No description provided for @tradingName.
  ///
  /// In en, this message translates to:
  /// **'Trading name'**
  String get tradingName;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone or WhatsApp'**
  String get phone;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @vatRegistered.
  ///
  /// In en, this message translates to:
  /// **'My company is VAT registered'**
  String get vatRegistered;

  /// No description provided for @vatEffectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'VAT registered from'**
  String get vatEffectiveFrom;

  /// No description provided for @trn.
  ///
  /// In en, this message translates to:
  /// **'TRN'**
  String get trn;

  /// No description provided for @trnFormatOnly.
  ///
  /// In en, this message translates to:
  /// **'This only checks the format. It is not verified with the FTA.'**
  String get trnFormatOnly;

  /// No description provided for @trnFormatError.
  ///
  /// In en, this message translates to:
  /// **'A TRN has 15 digits'**
  String get trnFormatError;

  /// No description provided for @invoicePrefix.
  ///
  /// In en, this message translates to:
  /// **'Invoice number prefix'**
  String get invoicePrefix;

  /// No description provided for @paymentTermsDays.
  ///
  /// In en, this message translates to:
  /// **'Payment terms in days'**
  String get paymentTermsDays;

  /// No description provided for @bankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank details'**
  String get bankDetails;

  /// No description provided for @documentFooter.
  ///
  /// In en, this message translates to:
  /// **'Document footer'**
  String get documentFooter;

  /// No description provided for @addClient.
  ///
  /// In en, this message translates to:
  /// **'Add company'**
  String get addClient;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get editClient;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get clientName;

  /// No description provided for @contactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get contactPerson;

  /// No description provided for @clientVatRegistered.
  ///
  /// In en, this message translates to:
  /// **'This company is VAT registered'**
  String get clientVatRegistered;

  /// No description provided for @invoiceAddress.
  ///
  /// In en, this message translates to:
  /// **'Invoice address'**
  String get invoiceAddress;

  /// No description provided for @dueDays.
  ///
  /// In en, this message translates to:
  /// **'Payment due after how many days'**
  String get dueDays;

  /// No description provided for @poReference.
  ///
  /// In en, this message translates to:
  /// **'PO or reference'**
  String get poReference;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @sitesHeading.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get sitesHeading;

  /// No description provided for @sitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sites yet.'**
  String get sitesEmpty;

  /// No description provided for @addSite.
  ///
  /// In en, this message translates to:
  /// **'Add site'**
  String get addSite;

  /// No description provided for @editSite.
  ///
  /// In en, this message translates to:
  /// **'Edit site'**
  String get editSite;

  /// No description provided for @siteName.
  ///
  /// In en, this message translates to:
  /// **'Site or project name'**
  String get siteName;

  /// No description provided for @siteLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get siteLocation;

  /// No description provided for @defaultStart.
  ///
  /// In en, this message translates to:
  /// **'Usual start'**
  String get defaultStart;

  /// No description provided for @defaultEnd.
  ///
  /// In en, this message translates to:
  /// **'Usual end'**
  String get defaultEnd;

  /// No description provided for @defaultBreakMinutes.
  ///
  /// In en, this message translates to:
  /// **'Usual break in minutes'**
  String get defaultBreakMinutes;

  /// No description provided for @activeFrom.
  ///
  /// In en, this message translates to:
  /// **'Active from'**
  String get activeFrom;

  /// No description provided for @activeTo.
  ///
  /// In en, this message translates to:
  /// **'Active until'**
  String get activeTo;

  /// No description provided for @addWorker.
  ///
  /// In en, this message translates to:
  /// **'Add worker'**
  String get addWorker;

  /// No description provided for @editWorker.
  ///
  /// In en, this message translates to:
  /// **'Edit worker'**
  String get editWorker;

  /// No description provided for @workerCode.
  ///
  /// In en, this message translates to:
  /// **'Worker code'**
  String get workerCode;

  /// No description provided for @workerCodeTaken.
  ///
  /// In en, this message translates to:
  /// **'This code is already used by another worker'**
  String get workerCodeTaken;

  /// No description provided for @workerName.
  ///
  /// In en, this message translates to:
  /// **'Worker name'**
  String get workerName;

  /// No description provided for @trade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get trade;

  /// No description provided for @joiningDate.
  ///
  /// In en, this message translates to:
  /// **'Joining date'**
  String get joiningDate;

  /// No description provided for @roomCharge.
  ///
  /// In en, this message translates to:
  /// **'Room charge per month (AED)'**
  String get roomCharge;

  /// No description provided for @roomChargeNote.
  ///
  /// In en, this message translates to:
  /// **'Room charge agreement note'**
  String get roomChargeNote;

  /// No description provided for @addPayContract.
  ///
  /// In en, this message translates to:
  /// **'Add pay rate'**
  String get addPayContract;

  /// No description provided for @editPayContract.
  ///
  /// In en, this message translates to:
  /// **'Edit pay rate'**
  String get editPayContract;

  /// No description provided for @addBillingContract.
  ///
  /// In en, this message translates to:
  /// **'Add client rate'**
  String get addBillingContract;

  /// No description provided for @editBillingContract.
  ///
  /// In en, this message translates to:
  /// **'Edit client rate'**
  String get editBillingContract;

  /// No description provided for @payContractsHeading.
  ///
  /// In en, this message translates to:
  /// **'Pay rates'**
  String get payContractsHeading;

  /// No description provided for @billingContractsHeading.
  ///
  /// In en, this message translates to:
  /// **'Client rates'**
  String get billingContractsHeading;

  /// No description provided for @noPayContract.
  ///
  /// In en, this message translates to:
  /// **'No pay rate yet. Attendance for this worker will stop for review.'**
  String get noPayContract;

  /// No description provided for @noBillingContract.
  ///
  /// In en, this message translates to:
  /// **'No client rate yet. Attendance for this client will stop for review.'**
  String get noBillingContract;

  /// No description provided for @rateBasis.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get rateBasis;

  /// No description provided for @rateAmount.
  ///
  /// In en, this message translates to:
  /// **'Rate (AED)'**
  String get rateAmount;

  /// No description provided for @effectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
  String get effectiveFrom;

  /// No description provided for @effectiveTo.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get effectiveTo;

  /// No description provided for @appliesToSite.
  ///
  /// In en, this message translates to:
  /// **'Applies to site'**
  String get appliesToSite;

  /// No description provided for @allSites.
  ///
  /// In en, this message translates to:
  /// **'All sites'**
  String get allSites;

  /// No description provided for @appliesToWorker.
  ///
  /// In en, this message translates to:
  /// **'Applies to worker'**
  String get appliesToWorker;

  /// No description provided for @allWorkers.
  ///
  /// In en, this message translates to:
  /// **'All workers'**
  String get allWorkers;

  /// No description provided for @breakIsPaid.
  ///
  /// In en, this message translates to:
  /// **'Break is paid'**
  String get breakIsPaid;

  /// No description provided for @halfAmount.
  ///
  /// In en, this message translates to:
  /// **'Half-day amount (AED)'**
  String get halfAmount;

  /// No description provided for @halfAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if there is no agreed half amount. A half day then stops for review.'**
  String get halfAmountHelp;

  /// No description provided for @partialMethod.
  ///
  /// In en, this message translates to:
  /// **'Part-month calculation'**
  String get partialMethod;

  /// No description provided for @partialMethodHelp.
  ///
  /// In en, this message translates to:
  /// **'Used when a worker joins or leaves mid-month. Choose what your contract says.'**
  String get partialMethodHelp;

  /// No description provided for @partialCalendarDays.
  ///
  /// In en, this message translates to:
  /// **'Actual days in the month'**
  String get partialCalendarDays;

  /// No description provided for @partialFixedDivisor.
  ///
  /// In en, this message translates to:
  /// **'Fixed number of days'**
  String get partialFixedDivisor;

  /// No description provided for @partialDivisor.
  ///
  /// In en, this message translates to:
  /// **'Number of days'**
  String get partialDivisor;

  /// No description provided for @includedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes included before overtime'**
  String get includedMinutes;

  /// No description provided for @includedMinutesHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if there is no overtime on this rate.'**
  String get includedMinutesHelp;

  /// No description provided for @overtimeRate.
  ///
  /// In en, this message translates to:
  /// **'Overtime rate per hour (AED)'**
  String get overtimeRate;

  /// No description provided for @overtimeRateHelp.
  ///
  /// In en, this message translates to:
  /// **'Only what your contract states. The app never applies a multiplier by itself.'**
  String get overtimeRateHelp;

  /// No description provided for @basisHour.
  ///
  /// In en, this message translates to:
  /// **'Per hour'**
  String get basisHour;

  /// No description provided for @basisDay.
  ///
  /// In en, this message translates to:
  /// **'Per day'**
  String get basisDay;

  /// No description provided for @basisShift.
  ///
  /// In en, this message translates to:
  /// **'Per shift'**
  String get basisShift;

  /// No description provided for @basisMonth.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get basisMonth;

  /// No description provided for @basisMonthPerWorker.
  ///
  /// In en, this message translates to:
  /// **'Per month, each worker'**
  String get basisMonthPerWorker;

  /// No description provided for @basisMonthFixed.
  ///
  /// In en, this message translates to:
  /// **'Per month, fixed contract'**
  String get basisMonthFixed;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date is before the start date'**
  String get endBeforeStart;

  /// No description provided for @contractOverlap.
  ///
  /// In en, this message translates to:
  /// **'Another rate already covers these dates for the same site and worker. End that rate first.'**
  String get contractOverlap;

  /// No description provided for @openingHeading.
  ///
  /// In en, this message translates to:
  /// **'Carried over from before'**
  String get openingHeading;

  /// No description provided for @openingSalaryOwed.
  ///
  /// In en, this message translates to:
  /// **'Old salary still owed to this worker'**
  String get openingSalaryOwed;

  /// No description provided for @openingAdvance.
  ///
  /// In en, this message translates to:
  /// **'Old advance to recover from this worker'**
  String get openingAdvance;

  /// No description provided for @openingReceivable.
  ///
  /// In en, this message translates to:
  /// **'Old amount this company still owes'**
  String get openingReceivable;

  /// No description provided for @openingHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter what was already due on the date you start using this app. It carries forward as a balance and is not counted as this month\'s expense or income.'**
  String get openingHelp;

  /// No description provided for @amountAed.
  ///
  /// In en, this message translates to:
  /// **'Amount (AED)'**
  String get amountAed;

  /// No description provided for @asOfDate.
  ///
  /// In en, this message translates to:
  /// **'As of date'**
  String get asOfDate;

  /// No description provided for @sourceNote.
  ///
  /// In en, this message translates to:
  /// **'Where this figure comes from'**
  String get sourceNote;

  /// No description provided for @sourceNoteHelp.
  ///
  /// In en, this message translates to:
  /// **'For example: old register, page 12'**
  String get sourceNoteHelp;

  /// No description provided for @openingConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have checked this figure'**
  String get openingConfirm;

  /// No description provided for @confirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you have checked this figure'**
  String get confirmRequired;

  /// No description provided for @notEntered.
  ///
  /// In en, this message translates to:
  /// **'Not entered'**
  String get notEntered;

  /// No description provided for @dateFrom.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String dateFrom(String date);

  /// No description provided for @dateFromTo.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String dateFromTo(String from, String to);

  /// No description provided for @markAttendance.
  ///
  /// In en, this message translates to:
  /// **'Mark attendance'**
  String get markAttendance;

  /// No description provided for @workDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get workDate;

  /// No description provided for @chooseClient.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get chooseClient;

  /// No description provided for @chooseSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get chooseSite;

  /// No description provided for @shiftStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get shiftStart;

  /// No description provided for @shiftEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get shiftEnd;

  /// No description provided for @breakMinutes.
  ///
  /// In en, this message translates to:
  /// **'Break in minutes'**
  String get breakMinutes;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @copyLastTeam.
  ///
  /// In en, this message translates to:
  /// **'Last team'**
  String get copyLastTeam;

  /// No description provided for @noLastTeam.
  ///
  /// In en, this message translates to:
  /// **'No earlier team found for this site.'**
  String get noLastTeam;

  /// No description provided for @needSetupFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a company, a site and a worker first.'**
  String get needSetupFirst;

  /// No description provided for @timesRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the start and end time.'**
  String get timesRequired;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review attendance'**
  String get reviewTitle;

  /// No description provided for @totalClient.
  ///
  /// In en, this message translates to:
  /// **'To collect from company'**
  String get totalClient;

  /// No description provided for @totalWorker.
  ///
  /// In en, this message translates to:
  /// **'To pay workers'**
  String get totalWorker;

  /// No description provided for @monthlyNotInTotal.
  ///
  /// In en, this message translates to:
  /// **'Workers on a monthly rate are not in this total. They are calculated per month.'**
  String get monthlyNotInTotal;

  /// No description provided for @groupRate.
  ///
  /// In en, this message translates to:
  /// **'Change today\'s company rate'**
  String get groupRate;

  /// No description provided for @groupRateAmount.
  ///
  /// In en, this message translates to:
  /// **'Company rate for this group (AED)'**
  String get groupRateAmount;

  /// No description provided for @issueClientRate.
  ///
  /// In en, this message translates to:
  /// **'No company rate found'**
  String get issueClientRate;

  /// No description provided for @issueWorkerRate.
  ///
  /// In en, this message translates to:
  /// **'No worker rate found'**
  String get issueWorkerRate;

  /// No description provided for @issueHalf.
  ///
  /// In en, this message translates to:
  /// **'No half-day amount agreed'**
  String get issueHalf;

  /// No description provided for @issueOvertime.
  ///
  /// In en, this message translates to:
  /// **'No overtime rate agreed'**
  String get issueOvertime;

  /// No description provided for @issueOverlap.
  ///
  /// In en, this message translates to:
  /// **'This worker already has attendance at this time. Write a reason.'**
  String get issueOverlap;

  /// No description provided for @issueBreak.
  ///
  /// In en, this message translates to:
  /// **'Break is longer than the shift'**
  String get issueBreak;

  /// No description provided for @issueOverrideReason.
  ///
  /// In en, this message translates to:
  /// **'Write why the rate changed'**
  String get issueOverrideReason;

  /// No description provided for @rowsNeedFix.
  ///
  /// In en, this message translates to:
  /// **'Fix the rows marked in red, then save.'**
  String get rowsNeedFix;

  /// No description provided for @savesAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Rows with a missing rate save as drafts until a rate is added.'**
  String get savesAsDraft;

  /// No description provided for @statusPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get statusPresent;

  /// No description provided for @statusHalf.
  ///
  /// In en, this message translates to:
  /// **'Half day'**
  String get statusHalf;

  /// No description provided for @statusAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get statusAbsent;

  /// No description provided for @clientBreakPaid.
  ///
  /// In en, this message translates to:
  /// **'Break paid on company side'**
  String get clientBreakPaid;

  /// No description provided for @workerBreakPaid.
  ///
  /// In en, this message translates to:
  /// **'Break paid on worker side'**
  String get workerBreakPaid;

  /// No description provided for @overtimeApproved.
  ///
  /// In en, this message translates to:
  /// **'Overtime approved'**
  String get overtimeApproved;

  /// No description provided for @clientOverride.
  ///
  /// In en, this message translates to:
  /// **'Company rate for this row (AED)'**
  String get clientOverride;

  /// No description provided for @workerOverride.
  ///
  /// In en, this message translates to:
  /// **'Worker rate for this row (AED)'**
  String get workerOverride;

  /// No description provided for @overrideHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the contract. Changing a rate needs the owner\'s approval and a reason.'**
  String get overrideHelp;

  /// No description provided for @overrideReason.
  ///
  /// In en, this message translates to:
  /// **'Why the rate changed'**
  String get overrideReason;

  /// No description provided for @overlapReason.
  ///
  /// In en, this message translates to:
  /// **'Why two entries overlap'**
  String get overlapReason;

  /// No description provided for @correctionReason.
  ///
  /// In en, this message translates to:
  /// **'Why this is being corrected'**
  String get correctionReason;

  /// No description provided for @correctionHelp.
  ///
  /// In en, this message translates to:
  /// **'The original entry is kept. This creates a corrected entry.'**
  String get correctionHelp;

  /// No description provided for @deleteRow.
  ///
  /// In en, this message translates to:
  /// **'Remove this entry'**
  String get deleteRow;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyChanges;

  /// No description provided for @stateDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get stateDraft;

  /// No description provided for @stateSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get stateSubmitted;

  /// No description provided for @stateApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get stateApproved;

  /// No description provided for @stateLinked.
  ///
  /// In en, this message translates to:
  /// **'In accounts'**
  String get stateLinked;

  /// No description provided for @correctedTag.
  ///
  /// In en, this message translates to:
  /// **'Corrected'**
  String get correctedTag;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @localOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'This data is only on this phone.'**
  String get localOnlyNote;

  /// No description provided for @nextWithCount.
  ///
  /// In en, this message translates to:
  /// **'Next ({count} workers)'**
  String nextWithCount(int count);

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve all ({count})'**
  String approveAll(int count);

  /// No description provided for @approvedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries approved'**
  String approvedCount(int count);

  /// No description provided for @countsLine.
  ///
  /// In en, this message translates to:
  /// **'{workers} workers, {shifts} shifts, {days} worker-days'**
  String countsLine(int workers, int shifts, int days);

  /// No description provided for @missingWorkers.
  ///
  /// In en, this message translates to:
  /// **'{count} workers have no attendance: {names}'**
  String missingWorkers(int count, String names);

  /// No description provided for @hoursPaid.
  ///
  /// In en, this message translates to:
  /// **'{duration} hours'**
  String hoursPaid(String duration);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Nothing was changed. Try again.'**
  String get saveFailed;

  /// No description provided for @rowCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount}'**
  String rowCollect(String amount);

  /// No description provided for @rowPay.
  ///
  /// In en, this message translates to:
  /// **'pay {amount}'**
  String rowPay(String amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'PK':
            return AppLocalizationsEnPk();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
