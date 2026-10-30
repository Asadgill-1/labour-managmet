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
  String get companiesEmpty => 'No client companies yet. Add your first one.';

  @override
  String get labourEmpty => 'No workers yet. Add your first one.';

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

  @override
  String get databaseError =>
      'Your data could not be opened. Nothing was deleted. Close the app and open it again. If this repeats, contact support.';

  @override
  String get save => 'Save';

  @override
  String get search => 'Search';

  @override
  String get clearValue => 'Clear';

  @override
  String get fieldRequired => 'This is required';

  @override
  String get wholeNumberRequired => 'Enter a whole number';

  @override
  String get amountInvalid => 'Enter an amount like 1100.50';

  @override
  String get showArchived => 'Show archived';

  @override
  String get showActive => 'Show active';

  @override
  String get archive => 'Archive';

  @override
  String get reactivate => 'Make active again';

  @override
  String get archivedLabel => 'Archived';

  @override
  String get activeLabel => 'Active';

  @override
  String get welcomeTitle => 'Your company';

  @override
  String get welcomeBody =>
      'Start with your company\'s name. You can add the rest later.';

  @override
  String get myCompany => 'My company';

  @override
  String get legalName => 'Legal company name';

  @override
  String get tradingName => 'Trading name';

  @override
  String get address => 'Address';

  @override
  String get phone => 'Phone or WhatsApp';

  @override
  String get email => 'Email';

  @override
  String get vatRegistered => 'My company is VAT registered';

  @override
  String get vatEffectiveFrom => 'VAT registered from';

  @override
  String get trn => 'TRN';

  @override
  String get trnFormatOnly =>
      'This only checks the format. It is not verified with the FTA.';

  @override
  String get trnFormatError => 'A TRN has 15 digits';

  @override
  String get invoicePrefix => 'Invoice number prefix';

  @override
  String get paymentTermsDays => 'Payment terms in days';

  @override
  String get bankDetails => 'Bank details';

  @override
  String get documentFooter => 'Document footer';

  @override
  String get addClient => 'Add company';

  @override
  String get editClient => 'Edit company';

  @override
  String get clientName => 'Company name';

  @override
  String get contactPerson => 'Contact person';

  @override
  String get clientVatRegistered => 'This company is VAT registered';

  @override
  String get invoiceAddress => 'Invoice address';

  @override
  String get dueDays => 'Payment due after how many days';

  @override
  String get poReference => 'PO or reference';

  @override
  String get note => 'Note';

  @override
  String get sitesHeading => 'Sites';

  @override
  String get sitesEmpty => 'No sites yet.';

  @override
  String get addSite => 'Add site';

  @override
  String get editSite => 'Edit site';

  @override
  String get siteName => 'Site or project name';

  @override
  String get siteLocation => 'Location';

  @override
  String get defaultStart => 'Usual start';

  @override
  String get defaultEnd => 'Usual end';

  @override
  String get defaultBreakMinutes => 'Usual break in minutes';

  @override
  String get activeFrom => 'Active from';

  @override
  String get activeTo => 'Active until';

  @override
  String get addWorker => 'Add worker';

  @override
  String get editWorker => 'Edit worker';

  @override
  String get workerCode => 'Worker code';

  @override
  String get workerCodeTaken => 'This code is already used by another worker';

  @override
  String get workerName => 'Worker name';

  @override
  String get trade => 'Trade';

  @override
  String get joiningDate => 'Joining date';

  @override
  String get roomCharge => 'Room charge per month (AED)';

  @override
  String get roomChargeNote => 'Room charge agreement note';

  @override
  String get addPayContract => 'Add pay rate';

  @override
  String get editPayContract => 'Edit pay rate';

  @override
  String get addBillingContract => 'Add client rate';

  @override
  String get editBillingContract => 'Edit client rate';

  @override
  String get payContractsHeading => 'Pay rates';

  @override
  String get billingContractsHeading => 'Client rates';

  @override
  String get noPayContract =>
      'No pay rate yet. Attendance for this worker will stop for review.';

  @override
  String get noBillingContract =>
      'No client rate yet. Attendance for this client will stop for review.';

  @override
  String get rateBasis => 'Paid by';

  @override
  String get rateAmount => 'Rate (AED)';

  @override
  String get effectiveFrom => 'Starts on';

  @override
  String get effectiveTo => 'Ends on';

  @override
  String get appliesToSite => 'Applies to site';

  @override
  String get allSites => 'All sites';

  @override
  String get appliesToWorker => 'Applies to worker';

  @override
  String get allWorkers => 'All workers';

  @override
  String get breakIsPaid => 'Break is paid';

  @override
  String get halfAmount => 'Half-day amount (AED)';

  @override
  String get halfAmountHelp =>
      'Leave empty if there is no agreed half amount. A half day then stops for review.';

  @override
  String get partialMethod => 'Part-month calculation';

  @override
  String get partialMethodHelp =>
      'Used when a worker joins or leaves mid-month. Choose what your contract says.';

  @override
  String get partialCalendarDays => 'Actual days in the month';

  @override
  String get partialFixedDivisor => 'Fixed number of days';

  @override
  String get partialDivisor => 'Number of days';

  @override
  String get includedMinutes => 'Minutes included before overtime';

  @override
  String get includedMinutesHelp =>
      'Leave empty if there is no overtime on this rate.';

  @override
  String get overtimeRate => 'Overtime rate per hour (AED)';

  @override
  String get overtimeRateHelp =>
      'Only what your contract states. The app never applies a multiplier by itself.';

  @override
  String get basisHour => 'Per hour';

  @override
  String get basisDay => 'Per day';

  @override
  String get basisShift => 'Per shift';

  @override
  String get basisMonth => 'Per month';

  @override
  String get basisMonthPerWorker => 'Per month, each worker';

  @override
  String get basisMonthFixed => 'Per month, fixed contract';

  @override
  String get endBeforeStart => 'The end date is before the start date';

  @override
  String get contractOverlap =>
      'Another rate already covers these dates for the same site and worker. End that rate first.';

  @override
  String get openingHeading => 'Carried over from before';

  @override
  String get openingSalaryOwed => 'Old salary still owed to this worker';

  @override
  String get openingAdvance => 'Old advance to recover from this worker';

  @override
  String get openingReceivable => 'Old amount this company still owes';

  @override
  String get openingHelp =>
      'Enter what was already due on the date you start using this app. It carries forward as a balance and is not counted as this month\'s expense or income.';

  @override
  String get amountAed => 'Amount (AED)';

  @override
  String get asOfDate => 'As of date';

  @override
  String get sourceNote => 'Where this figure comes from';

  @override
  String get sourceNoteHelp => 'For example: old register, page 12';

  @override
  String get openingConfirm => 'I have checked this figure';

  @override
  String get confirmRequired => 'Please confirm you have checked this figure';

  @override
  String get notEntered => 'Not entered';

  @override
  String dateFrom(String date) {
    return 'From $date';
  }

  @override
  String dateFromTo(String from, String to) {
    return '$from to $to';
  }
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
  String get companiesEmpty =>
      'Abhi koi client company nahin. Pehli company add karein.';

  @override
  String get labourEmpty => 'Abhi koi mazdoor nahin. Pehla mazdoor add karein.';

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

  @override
  String get databaseError =>
      'Aap ka data khul nahin saka. Kuch delete nahin hua. App band kar ke dobara kholein. Masla rahe to support se rabta karein.';

  @override
  String get save => 'Save karein';

  @override
  String get search => 'Talash karein';

  @override
  String get clearValue => 'Hatayein';

  @override
  String get fieldRequired => 'Yeh zaroori hai';

  @override
  String get wholeNumberRequired => 'Poora number likhein';

  @override
  String get amountInvalid => 'Raqam is tarah likhein: 1100.50';

  @override
  String get showArchived => 'Archived dikhayein';

  @override
  String get showActive => 'Active dikhayein';

  @override
  String get archive => 'Archive karein';

  @override
  String get reactivate => 'Dobara active karein';

  @override
  String get archivedLabel => 'Archived';

  @override
  String get activeLabel => 'Active';

  @override
  String get welcomeTitle => 'Apni company';

  @override
  String get welcomeBody =>
      'Apni company ke naam se shuru karein. Baqi baad mein bhi add kar sakte hain.';

  @override
  String get myCompany => 'Apni company';

  @override
  String get legalName => 'Company ka qanooni naam';

  @override
  String get tradingName => 'Trading naam';

  @override
  String get address => 'Pata';

  @override
  String get phone => 'Phone ya WhatsApp';

  @override
  String get email => 'Email';

  @override
  String get vatRegistered => 'Meri company VAT registered hai';

  @override
  String get vatEffectiveFrom => 'VAT kis tareekh se';

  @override
  String get trn => 'TRN';

  @override
  String get trnFormatOnly =>
      'Yeh sirf format check karta hai. FTA se tasdeeq nahin hai.';

  @override
  String get trnFormatError => 'TRN mein 15 hindsay hote hain';

  @override
  String get invoicePrefix => 'Invoice number ka shuru';

  @override
  String get paymentTermsDays => 'Payment ke din';

  @override
  String get bankDetails => 'Bank ki tafseel';

  @override
  String get documentFooter => 'Document ka footer';

  @override
  String get addClient => 'Company add karein';

  @override
  String get editClient => 'Company tabdeel karein';

  @override
  String get clientName => 'Company ka naam';

  @override
  String get contactPerson => 'Rabta shakhs';

  @override
  String get clientVatRegistered => 'Yeh company VAT registered hai';

  @override
  String get invoiceAddress => 'Invoice ka pata';

  @override
  String get dueDays => 'Kitne din baad payment';

  @override
  String get poReference => 'PO ya reference';

  @override
  String get note => 'Note';

  @override
  String get sitesHeading => 'Sites';

  @override
  String get sitesEmpty => 'Abhi koi site nahin.';

  @override
  String get addSite => 'Site add karein';

  @override
  String get editSite => 'Site tabdeel karein';

  @override
  String get siteName => 'Site ya project ka naam';

  @override
  String get siteLocation => 'Jagah';

  @override
  String get defaultStart => 'Aam shuru waqt';

  @override
  String get defaultEnd => 'Aam khatam waqt';

  @override
  String get defaultBreakMinutes => 'Aam break, minutes mein';

  @override
  String get activeFrom => 'Kab se active';

  @override
  String get activeTo => 'Kab tak active';

  @override
  String get addWorker => 'Mazdoor add karein';

  @override
  String get editWorker => 'Mazdoor tabdeel karein';

  @override
  String get workerCode => 'Mazdoor ka code';

  @override
  String get workerCodeTaken => 'Yeh code kisi aur mazdoor ka hai';

  @override
  String get workerName => 'Mazdoor ka naam';

  @override
  String get trade => 'Kaam ki qisam';

  @override
  String get joiningDate => 'Shamil hone ki tareekh';

  @override
  String get roomCharge => 'Kamray ka mahana charge (AED)';

  @override
  String get roomChargeNote => 'Kamray ke charge ka note';

  @override
  String get addPayContract => 'Tankhwah ka rate add karein';

  @override
  String get editPayContract => 'Tankhwah ka rate tabdeel karein';

  @override
  String get addBillingContract => 'Company ka rate add karein';

  @override
  String get editBillingContract => 'Company ka rate tabdeel karein';

  @override
  String get payContractsHeading => 'Tankhwah ke rate';

  @override
  String get billingContractsHeading => 'Company ke rate';

  @override
  String get noPayContract =>
      'Abhi koi rate nahin. Is mazdoor ki hazri review ke liye rukegi.';

  @override
  String get noBillingContract =>
      'Abhi koi rate nahin. Is company ki hazri review ke liye rukegi.';

  @override
  String get rateBasis => 'Kis hisaab se';

  @override
  String get rateAmount => 'Rate (AED)';

  @override
  String get effectiveFrom => 'Kab se shuru';

  @override
  String get effectiveTo => 'Kab khatam';

  @override
  String get appliesToSite => 'Kis site par';

  @override
  String get allSites => 'Tamam sites';

  @override
  String get appliesToWorker => 'Kis mazdoor par';

  @override
  String get allWorkers => 'Tamam mazdoor';

  @override
  String get breakIsPaid => 'Break ke paisay milte hain';

  @override
  String get halfAmount => 'Aadhay din ki raqam (AED)';

  @override
  String get halfAmountHelp =>
      'Agar aadhay din ki raqam tay nahin to khali chhor dein. Phir half-day review ke liye rukega.';

  @override
  String get partialMethod => 'Adhooray mahine ka hisaab';

  @override
  String get partialMethodHelp =>
      'Jab mazdoor mahine ke beech aaye ya jaye. Jo contract mein hai woh chunein.';

  @override
  String get partialCalendarDays => 'Mahine ke asal din';

  @override
  String get partialFixedDivisor => 'Din ki tay tadaad';

  @override
  String get partialDivisor => 'Dinon ki tadaad';

  @override
  String get includedMinutes => 'Overtime se pehle kitne minute shamil';

  @override
  String get includedMinutesHelp =>
      'Agar is rate par overtime nahin to khali chhor dein.';

  @override
  String get overtimeRate => 'Overtime rate fi ghanta (AED)';

  @override
  String get overtimeRateHelp =>
      'Sirf jo contract mein likha ho. App khud koi multiplier nahin lagati.';

  @override
  String get basisHour => 'Fi ghanta';

  @override
  String get basisDay => 'Fi din';

  @override
  String get basisShift => 'Fi shift';

  @override
  String get basisMonth => 'Mahana';

  @override
  String get basisMonthPerWorker => 'Mahana, har mazdoor';

  @override
  String get basisMonthFixed => 'Mahana, fixed contract';

  @override
  String get endBeforeStart => 'Khatam ki tareekh shuru se pehle hai';

  @override
  String get contractOverlap =>
      'In tareekhon ke liye isi site aur mazdoor ka doosra rate pehle se hai. Pehle us rate ko khatam karein.';

  @override
  String get openingHeading => 'Pichla baqaya';

  @override
  String get openingSalaryOwed => 'Mazdoor ko purani salary deni hai';

  @override
  String get openingAdvance => 'Mazdoor se purana advance wapas lena hai';

  @override
  String get openingReceivable => 'Company se purana lena hai';

  @override
  String get openingHelp =>
      'Jis tareekh se app istemal karna shuru kar rahe hain, us din jo baqaya tha woh likhein. Yeh baqaya ke tor par aage chalega. Is mahine ka kharcha ya aamdani nahin ginega.';

  @override
  String get amountAed => 'Raqam (AED)';

  @override
  String get asOfDate => 'Kis tareekh tak';

  @override
  String get sourceNote => 'Yeh raqam kahan se aayi';

  @override
  String get sourceNoteHelp => 'Maslan: purana register, safha 12';

  @override
  String get openingConfirm => 'Maine yeh raqam check kar li hai';

  @override
  String get confirmRequired => 'Raqam check kar ke tasdeeq karein';

  @override
  String get notEntered => 'Darj nahin';

  @override
  String dateFrom(String date) {
    return '$date se';
  }

  @override
  String dateFromTo(String from, String to) {
    return '$from se $to tak';
  }
}
