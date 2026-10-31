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
  /// **'Optional. Shows beside every worker. Tap an amount there to change it.'**
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

  /// No description provided for @groupBilling.
  ///
  /// In en, this message translates to:
  /// **'Payroll and billing'**
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

  /// No description provided for @tabCash.
  ///
  /// In en, this message translates to:
  /// **'Daily money'**
  String get tabCash;

  /// No description provided for @tabRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get tabRooms;

  /// No description provided for @addCash.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get addCash;

  /// No description provided for @cashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing written for this. Tap Add entry when money comes in or goes out.'**
  String get cashEmpty;

  /// No description provided for @moneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money given'**
  String get moneyOut;

  /// No description provided for @moneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money received'**
  String get moneyIn;

  /// No description provided for @cashDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get cashDifference;

  /// No description provided for @kindAdvanceGiven.
  ///
  /// In en, this message translates to:
  /// **'Advance'**
  String get kindAdvanceGiven;

  /// No description provided for @kindSalaryPaid.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get kindSalaryPaid;

  /// No description provided for @kindRoomRentPaid.
  ///
  /// In en, this message translates to:
  /// **'Room rent paid'**
  String get kindRoomRentPaid;

  /// No description provided for @kindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get kindExpense;

  /// No description provided for @kindAdvanceReturned.
  ///
  /// In en, this message translates to:
  /// **'Advance returned'**
  String get kindAdvanceReturned;

  /// No description provided for @kindRoomRentReceived.
  ///
  /// In en, this message translates to:
  /// **'Room rent received'**
  String get kindRoomRentReceived;

  /// No description provided for @kindClientReceipt.
  ///
  /// In en, this message translates to:
  /// **'From a company'**
  String get kindClientReceipt;

  /// No description provided for @catTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get catTransport;

  /// No description provided for @catFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catFood;

  /// No description provided for @catVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa and PRO'**
  String get catVisa;

  /// No description provided for @catTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get catTools;

  /// No description provided for @catOffice.
  ///
  /// In en, this message translates to:
  /// **'Office'**
  String get catOffice;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @expenseCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense type'**
  String get expenseCategory;

  /// No description provided for @optionalSite.
  ///
  /// In en, this message translates to:
  /// **'Site (optional)'**
  String get optionalSite;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get methodBank;

  /// No description provided for @chooseRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get chooseRoom;

  /// No description provided for @advanceTooHigh.
  ///
  /// In en, this message translates to:
  /// **'This is more than the advance still to recover.'**
  String get advanceTooHigh;

  /// No description provided for @advanceUndoBlocked.
  ///
  /// In en, this message translates to:
  /// **'Some of this advance has already come back. Undo that entry first.'**
  String get advanceUndoBlocked;

  /// No description provided for @reverseTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this entry?'**
  String get reverseTitle;

  /// No description provided for @reverseHelp.
  ///
  /// In en, this message translates to:
  /// **'The original stays on record. A reversing entry cancels it.'**
  String get reverseHelp;

  /// No description provided for @reverseReason.
  ///
  /// In en, this message translates to:
  /// **'Why it is being undone'**
  String get reverseReason;

  /// No description provided for @reverseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Undo entry'**
  String get reverseConfirm;

  /// No description provided for @reversedTag.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get reversedTag;

  /// No description provided for @reversalTag.
  ///
  /// In en, this message translates to:
  /// **'Undo of an entry'**
  String get reversalTag;

  /// No description provided for @moneyHeading.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get moneyHeading;

  /// No description provided for @advanceOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Advance still to recover'**
  String get advanceOutstanding;

  /// No description provided for @salaryPaidTotal.
  ///
  /// In en, this message translates to:
  /// **'Salary paid'**
  String get salaryPaidTotal;

  /// No description provided for @workerRentTotal.
  ///
  /// In en, this message translates to:
  /// **'Room rent paid by this worker'**
  String get workerRentTotal;

  /// No description provided for @roomsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet. Add the rooms you rent for workers.'**
  String get roomsEmpty;

  /// No description provided for @addRoom.
  ///
  /// In en, this message translates to:
  /// **'Add room'**
  String get addRoom;

  /// No description provided for @editRoom.
  ///
  /// In en, this message translates to:
  /// **'Edit room'**
  String get editRoom;

  /// No description provided for @roomName.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get roomName;

  /// No description provided for @roomNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example: Sonapur Room 12'**
  String get roomNameHelp;

  /// No description provided for @rentIn.
  ///
  /// In en, this message translates to:
  /// **'Rent received'**
  String get rentIn;

  /// No description provided for @rentOut.
  ///
  /// In en, this message translates to:
  /// **'Rent paid'**
  String get rentOut;

  /// No description provided for @roomProfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get roomProfitLabel;

  /// No description provided for @roomLossLabel.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get roomLossLabel;

  /// No description provided for @roomEven.
  ///
  /// In en, this message translates to:
  /// **'Even'**
  String get roomEven;

  /// No description provided for @residentsHeading.
  ///
  /// In en, this message translates to:
  /// **'Living here'**
  String get residentsHeading;

  /// No description provided for @noResidents.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet. Choose this room on a worker\'s screen.'**
  String get noResidents;

  /// No description provided for @entriesHeading.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get entriesHeading;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// No description provided for @advanceBalance.
  ///
  /// In en, this message translates to:
  /// **'Advance still to recover: {amount}'**
  String advanceBalance(String amount);

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved on phone, in {name}\'s account'**
  String savedTo(String name);

  /// No description provided for @roomProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit {amount}'**
  String roomProfit(String amount);

  /// No description provided for @roomLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss {amount}'**
  String roomLoss(String amount);

  /// No description provided for @rentSplit.
  ///
  /// In en, this message translates to:
  /// **'Received {received}, paid {paid}'**
  String rentSplit(String received, String paid);

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

  /// No description provided for @payrollEarned.
  ///
  /// In en, this message translates to:
  /// **'This month\'s earnings'**
  String get payrollEarned;

  /// No description provided for @payrollCut.
  ///
  /// In en, this message translates to:
  /// **'Deductions'**
  String get payrollCut;

  /// No description provided for @payrollToPay.
  ///
  /// In en, this message translates to:
  /// **'To pay the worker'**
  String get payrollToPay;

  /// No description provided for @payrollSalary.
  ///
  /// In en, this message translates to:
  /// **'Monthly salary'**
  String get payrollSalary;

  /// No description provided for @payrollAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Earlier work'**
  String get payrollAdjustment;

  /// No description provided for @payrollNet.
  ///
  /// In en, this message translates to:
  /// **'This month\'s net'**
  String get payrollNet;

  /// No description provided for @payrollOpening.
  ///
  /// In en, this message translates to:
  /// **'Previous unpaid'**
  String get payrollOpening;

  /// No description provided for @payrollPaidAhead.
  ///
  /// In en, this message translates to:
  /// **'Paid ahead'**
  String get payrollPaidAhead;

  /// No description provided for @payrollPayable.
  ///
  /// In en, this message translates to:
  /// **'Total payable'**
  String get payrollPayable;

  /// No description provided for @payrollPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid since'**
  String get payrollPaid;

  /// No description provided for @payrollClosing.
  ///
  /// In en, this message translates to:
  /// **'Still unpaid'**
  String get payrollClosing;

  /// No description provided for @payrollOverpaid.
  ///
  /// In en, this message translates to:
  /// **'Paid too much'**
  String get payrollOverpaid;

  /// No description provided for @payrollEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to pay this month. Mark attendance first.'**
  String get payrollEmpty;

  /// No description provided for @payrollEarnedHeading.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get payrollEarnedHeading;

  /// No description provided for @payrollItemsHeading.
  ///
  /// In en, this message translates to:
  /// **'Allowances and deductions'**
  String get payrollItemsHeading;

  /// No description provided for @payrollSumHeading.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get payrollSumHeading;

  /// No description provided for @payrollNoItems.
  ///
  /// In en, this message translates to:
  /// **'None this month.'**
  String get payrollNoItems;

  /// No description provided for @payrollStatePosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get payrollStatePosted;

  /// No description provided for @payrollStateReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to post'**
  String get payrollStateReady;

  /// No description provided for @payrollStateDraft.
  ///
  /// In en, this message translates to:
  /// **'Not posted'**
  String get payrollStateDraft;

  /// No description provided for @payrollPostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get payrollPostConfirm;

  /// No description provided for @payrollPayNow.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get payrollPayNow;

  /// No description provided for @payrollUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo this posting'**
  String get payrollUndo;

  /// No description provided for @payrollUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this posting?'**
  String get payrollUndoTitle;

  /// No description provided for @payrollUndoHelp.
  ///
  /// In en, this message translates to:
  /// **'The month goes back to unposted so you can fix it. The record stays, and money already paid stays on the worker\'s account.'**
  String get payrollUndoHelp;

  /// No description provided for @payrollUndoLater.
  ///
  /// In en, this message translates to:
  /// **'Undo the later month first.'**
  String get payrollUndoLater;

  /// No description provided for @payKindAllowance.
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get payKindAllowance;

  /// No description provided for @payKindDeduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction'**
  String get payKindDeduction;

  /// No description provided for @payKindRecovery.
  ///
  /// In en, this message translates to:
  /// **'Advance recovery'**
  String get payKindRecovery;

  /// No description provided for @payItemReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get payItemReason;

  /// No description provided for @payItemAuthorizedBy.
  ///
  /// In en, this message translates to:
  /// **'Agreement or permission'**
  String get payItemAuthorizedBy;

  /// No description provided for @payItemAuthorizedHelp.
  ///
  /// In en, this message translates to:
  /// **'Who agreed, and how. For example: signed paper, 01-10-2026'**
  String get payItemAuthorizedHelp;

  /// No description provided for @payItemDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get payItemDelete;

  /// No description provided for @issuePartial.
  ///
  /// In en, this message translates to:
  /// **'Choose the part-month method on the contract.'**
  String get issuePartial;

  /// No description provided for @issueNegative.
  ///
  /// In en, this message translates to:
  /// **'Deductions are more than earnings.'**
  String get issueNegative;

  /// No description provided for @issueRecovery.
  ///
  /// In en, this message translates to:
  /// **'Recovery is more than the advance left.'**
  String get issueRecovery;

  /// No description provided for @issueLimit.
  ///
  /// In en, this message translates to:
  /// **'Deductions are above your company\'s limit.'**
  String get issueLimit;

  /// No description provided for @issueEarlier.
  ///
  /// In en, this message translates to:
  /// **'Post the earlier month first.'**
  String get issueEarlier;

  /// No description provided for @issueLater.
  ///
  /// In en, this message translates to:
  /// **'A later month is posted. This goes into the next payroll.'**
  String get issueLater;

  /// No description provided for @issueNotStarted.
  ///
  /// In en, this message translates to:
  /// **'This month has not started.'**
  String get issueNotStarted;

  /// No description provided for @salaryOwed.
  ///
  /// In en, this message translates to:
  /// **'Salary still owed'**
  String get salaryOwed;

  /// No description provided for @rentFromPay.
  ///
  /// In en, this message translates to:
  /// **'Taken from salaries'**
  String get rentFromPay;

  /// No description provided for @deductionLimit.
  ///
  /// In en, this message translates to:
  /// **'Deduction limit (%, optional)'**
  String get deductionLimit;

  /// No description provided for @deductionLimitHelp.
  ///
  /// In en, this message translates to:
  /// **'Share of earnings. Ask your accountant. Empty means no limit.'**
  String get deductionLimitHelp;

  /// No description provided for @deductionLimitError.
  ///
  /// In en, this message translates to:
  /// **'Write a whole number from 1 to 100.'**
  String get deductionLimitError;

  /// No description provided for @payrollPost.
  ///
  /// In en, this message translates to:
  /// **'Post payroll ({count})'**
  String payrollPost(int count);

  /// No description provided for @payrollPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post payroll for {month}?'**
  String payrollPostTitle(String month);

  /// No description provided for @payrollPostBody.
  ///
  /// In en, this message translates to:
  /// **'{count} workers, {amount} goes onto their accounts. The figures will not change after this. If something is wrong, undo it on that worker.'**
  String payrollPostBody(int count, String amount);

  /// No description provided for @payrollPosted.
  ///
  /// In en, this message translates to:
  /// **'Payroll posted for {count} workers'**
  String payrollPosted(int count);

  /// No description provided for @payrollSplit.
  ///
  /// In en, this message translates to:
  /// **'Earned {earned}, deducted {cut}'**
  String payrollSplit(String earned, String cut);

  /// No description provided for @issueUnapproved.
  ///
  /// In en, this message translates to:
  /// **'{count} attendance rows not approved yet.'**
  String issueUnapproved(int count);

  /// No description provided for @applyRoomCharges.
  ///
  /// In en, this message translates to:
  /// **'Add room charge ({count})'**
  String applyRoomCharges(int count);

  /// No description provided for @roomChargesApplied.
  ///
  /// In en, this message translates to:
  /// **'Room charge added for {count} workers'**
  String roomChargesApplied(int count);

  /// No description provided for @roomChargesPartly.
  ///
  /// In en, this message translates to:
  /// **'Room charge added for {added} workers. {left} left: write the room charge note on their screen.'**
  String roomChargesPartly(int added, int left);

  /// No description provided for @payKindRoom.
  ///
  /// In en, this message translates to:
  /// **'Room charge'**
  String get payKindRoom;

  /// No description provided for @approveMissingRate.
  ///
  /// In en, this message translates to:
  /// **'{approved} approved. {left} have no rate: add it under Rates, then approve again.'**
  String approveMissingRate(int approved, int left);

  /// No description provided for @mainAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get mainAttendance;

  /// No description provided for @mainVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa'**
  String get mainVisa;

  /// No description provided for @mainMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get mainMoney;

  /// No description provided for @tabVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa money'**
  String get tabVisa;

  /// No description provided for @groupSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get groupSoon;

  /// No description provided for @regAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance register'**
  String get regAttendance;

  /// No description provided for @regWorkers.
  ///
  /// In en, this message translates to:
  /// **'Worker register'**
  String get regWorkers;

  /// No description provided for @regVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa register'**
  String get regVisa;

  /// No description provided for @regCompanies.
  ///
  /// In en, this message translates to:
  /// **'Company register'**
  String get regCompanies;

  /// No description provided for @regPayroll.
  ///
  /// In en, this message translates to:
  /// **'Pay register'**
  String get regPayroll;

  /// No description provided for @regAdvance.
  ///
  /// In en, this message translates to:
  /// **'Advance register'**
  String get regAdvance;

  /// No description provided for @regCash.
  ///
  /// In en, this message translates to:
  /// **'Money register'**
  String get regCash;

  /// No description provided for @regRooms.
  ///
  /// In en, this message translates to:
  /// **'Room register'**
  String get regRooms;

  /// No description provided for @kindVisaPaid.
  ///
  /// In en, this message translates to:
  /// **'Visa money spent'**
  String get kindVisaPaid;

  /// No description provided for @kindVisaReturned.
  ///
  /// In en, this message translates to:
  /// **'Visa money returned'**
  String get kindVisaReturned;

  /// No description provided for @visaTooHigh.
  ///
  /// In en, this message translates to:
  /// **'This is more than the visa money left.'**
  String get visaTooHigh;

  /// No description provided for @visaUndoBlocked.
  ///
  /// In en, this message translates to:
  /// **'Can\'t undo this: some of this visa money has already come back.'**
  String get visaUndoBlocked;

  /// No description provided for @visaBalance.
  ///
  /// In en, this message translates to:
  /// **'Visa money left: {amount}'**
  String visaBalance(String amount);

  /// No description provided for @visaSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get visaSpent;

  /// No description provided for @visaBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get visaBack;

  /// No description provided for @visaLeft.
  ///
  /// In en, this message translates to:
  /// **'Visa left'**
  String get visaLeft;

  /// No description provided for @visaAdd.
  ///
  /// In en, this message translates to:
  /// **'Add visa money'**
  String get visaAdd;

  /// No description provided for @visaEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visa money yet. Add what the company spent on a worker.'**
  String get visaEmpty;

  /// No description provided for @visaSplit.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent}, back {back}'**
  String visaSplit(String spent, String back);

  /// No description provided for @visaInstalment.
  ///
  /// In en, this message translates to:
  /// **'Monthly instalment'**
  String get visaInstalment;

  /// No description provided for @visaInstalmentOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get visaInstalmentOff;

  /// No description provided for @visaInstalmentHelp.
  ///
  /// In en, this message translates to:
  /// **'Taken from pay when you press the button in Payroll. Leave empty to turn it off.'**
  String get visaInstalmentHelp;

  /// No description provided for @visaInstalmentShort.
  ///
  /// In en, this message translates to:
  /// **'Instalment {amount} a month'**
  String visaInstalmentShort(String amount);

  /// No description provided for @visaReturnAdd.
  ///
  /// In en, this message translates to:
  /// **'Add money returned'**
  String get visaReturnAdd;

  /// No description provided for @payKindVisa.
  ///
  /// In en, this message translates to:
  /// **'Visa instalment'**
  String get payKindVisa;

  /// No description provided for @applyVisaInstalments.
  ///
  /// In en, this message translates to:
  /// **'Add visa instalments ({count})'**
  String applyVisaInstalments(int count);

  /// No description provided for @visaInstalmentsApplied.
  ///
  /// In en, this message translates to:
  /// **'Visa instalment added for {count} workers'**
  String visaInstalmentsApplied(int count);

  /// No description provided for @issueVisa.
  ///
  /// In en, this message translates to:
  /// **'This is more than the visa money left.'**
  String get issueVisa;

  /// No description provided for @regRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String regRows(int count);

  /// No description provided for @regAllDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get regAllDates;

  /// No description provided for @regThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get regThisMonth;

  /// No description provided for @regLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get regLastMonth;

  /// No description provided for @regAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get regAll;

  /// No description provided for @regClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get regClear;

  /// No description provided for @regExport.
  ///
  /// In en, this message translates to:
  /// **'PDF, Excel or WhatsApp'**
  String get regExport;

  /// No description provided for @regEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing for these dates and filters.'**
  String get regEmpty;

  /// No description provided for @regTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get regTotal;

  /// No description provided for @regPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String regPage(String page, String pages);

  /// No description provided for @regMade.
  ///
  /// In en, this message translates to:
  /// **'Made on {when}'**
  String regMade(String when);

  /// No description provided for @regFilterDates.
  ///
  /// In en, this message translates to:
  /// **'Dates: {range}'**
  String regFilterDates(String range);

  /// No description provided for @regAmountsNote.
  ///
  /// In en, this message translates to:
  /// **'Amounts in AED'**
  String get regAmountsNote;

  /// No description provided for @regCompanyNote.
  ///
  /// In en, this message translates to:
  /// **'Wages here are pay marked on attendance. Monthly salaries are not in them.'**
  String get regCompanyNote;

  /// No description provided for @regPayrollNote.
  ///
  /// In en, this message translates to:
  /// **'Posted months only.'**
  String get regPayrollNote;

  /// No description provided for @exportMaking.
  ///
  /// In en, this message translates to:
  /// **'Making the file...'**
  String get exportMaking;

  /// No description provided for @exportView.
  ///
  /// In en, this message translates to:
  /// **'View or print'**
  String get exportView;

  /// No description provided for @exportOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get exportOpen;

  /// No description provided for @exportSave.
  ///
  /// In en, this message translates to:
  /// **'Save on phone'**
  String get exportSave;

  /// No description provided for @exportWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get exportWhatsApp;

  /// No description provided for @exportOther.
  ///
  /// In en, this message translates to:
  /// **'Other apps'**
  String get exportOther;

  /// No description provided for @exportNoWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp not found. Choose another app.'**
  String get exportNoWhatsApp;

  /// No description provided for @exportNoApp.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone opens this file. Use Other apps to send it.'**
  String get exportNoApp;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved on the phone.'**
  String get exportSaved;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not make the file. Try again.'**
  String get exportFailed;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get filterStatus;

  /// No description provided for @filterState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get filterState;

  /// No description provided for @filterKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filterKind;

  /// No description provided for @filterMethod.
  ///
  /// In en, this message translates to:
  /// **'Cash or bank'**
  String get filterMethod;

  /// No description provided for @filterTrade.
  ///
  /// In en, this message translates to:
  /// **'Trade'**
  String get filterTrade;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterActive;

  /// No description provided for @filterOwed.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get filterOwed;

  /// No description provided for @stateActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get stateActive;

  /// No description provided for @stateArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get stateArchived;

  /// No description provided for @owedYes.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get owedYes;

  /// No description provided for @owedNo.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get owedNo;

  /// No description provided for @colDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get colDate;

  /// No description provided for @colMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get colMonth;

  /// No description provided for @colWorker.
  ///
  /// In en, this message translates to:
  /// **'Worker'**
  String get colWorker;

  /// No description provided for @colCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get colCode;

  /// No description provided for @colCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get colCompany;

  /// No description provided for @colSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get colSite;

  /// No description provided for @colGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get colGroup;

  /// No description provided for @colIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get colIn;

  /// No description provided for @colOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get colOut;

  /// No description provided for @colBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get colBreak;

  /// No description provided for @colCompanyHours.
  ///
  /// In en, this message translates to:
  /// **'Company hours'**
  String get colCompanyHours;

  /// No description provided for @colWorkerHours.
  ///
  /// In en, this message translates to:
  /// **'Worker hours'**
  String get colWorkerHours;

  /// No description provided for @colOvertime.
  ///
  /// In en, this message translates to:
  /// **'Overtime'**
  String get colOvertime;

  /// No description provided for @colCompanyRate.
  ///
  /// In en, this message translates to:
  /// **'Company rate'**
  String get colCompanyRate;

  /// No description provided for @colBill.
  ///
  /// In en, this message translates to:
  /// **'Company bill'**
  String get colBill;

  /// No description provided for @colWorkerRate.
  ///
  /// In en, this message translates to:
  /// **'Worker rate'**
  String get colWorkerRate;

  /// No description provided for @colPay.
  ///
  /// In en, this message translates to:
  /// **'Worker pay'**
  String get colPay;

  /// No description provided for @colWhat.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get colWhat;

  /// No description provided for @colWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get colWho;

  /// No description provided for @colGiven.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get colGiven;

  /// No description provided for @colBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get colBack;

  /// No description provided for @colLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get colLeft;

  /// No description provided for @colPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get colPhone;

  /// No description provided for @colJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get colJoined;

  /// No description provided for @colRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get colRoom;

  /// No description provided for @colRate.
  ///
  /// In en, this message translates to:
  /// **'Pay rate'**
  String get colRate;

  /// No description provided for @colWorkers.
  ///
  /// In en, this message translates to:
  /// **'Workers'**
  String get colWorkers;

  /// No description provided for @colHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get colHours;

  /// No description provided for @colWages.
  ///
  /// In en, this message translates to:
  /// **'Wages'**
  String get colWages;

  /// No description provided for @colDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get colDifference;

  /// No description provided for @colPending.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get colPending;

  /// No description provided for @colPostedOn.
  ///
  /// In en, this message translates to:
  /// **'Posted on'**
  String get colPostedOn;
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
