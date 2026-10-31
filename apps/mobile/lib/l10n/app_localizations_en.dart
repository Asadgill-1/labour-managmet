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
  String get tabGroups => 'Worker groups';

  @override
  String get addGroup => 'Make a group';

  @override
  String get editGroup => 'Edit group';

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameHelp => 'For example: Emaar West';

  @override
  String get groupsEmpty =>
      'No groups yet. Make one for workers who usually go together.';

  @override
  String get noneChoice => 'None';

  @override
  String get dailyWage => 'Daily wage (AED)';

  @override
  String get dailyWageHelp =>
      'Optional. It shows beside every worker. To change one worker, tap the amount beside their name.';

  @override
  String get halfDayIsHalf => 'Half day pays half the daily wage';

  @override
  String get ownWageHelp => 'Leave empty to use the group\'s daily wage.';

  @override
  String get todayWageHelp =>
      'For this attendance only. The group does not change.';

  @override
  String get todayWageReason => 'Daily wage typed while marking attendance';

  @override
  String get setWage => 'Set wage';

  @override
  String get monthlyPay => 'Monthly';

  @override
  String get workersHeading => 'Workers';

  @override
  String get searchGroup => 'Search groups';

  @override
  String get searchWorker => 'Search workers';

  @override
  String membersCount(int count) {
    return '$count workers';
  }

  @override
  String saveWithCount(int count) {
    return 'Save ($count workers)';
  }

  @override
  String wageOf(String name) {
    return 'Daily wage: $name';
  }

  @override
  String get tabRates => 'Rates';

  @override
  String get tabSettings => 'Settings';

  @override
  String get menuLabel => 'Menu';

  @override
  String get menuClose => 'Hide menu';

  @override
  String get soon => 'Soon';

  @override
  String get groupDaily => 'Daily';

  @override
  String get groupRegisters => 'Registers';

  @override
  String get groupPayroll => 'Payroll and money';

  @override
  String get groupBilling => 'Billing';

  @override
  String get groupMore => 'More';

  @override
  String get menuPayroll => 'Payroll';

  @override
  String get menuAdvances => 'Advances';

  @override
  String get menuPayments => 'Payments';

  @override
  String get menuExpenses => 'Expenses';

  @override
  String get menuTimesheets => 'Timesheets';

  @override
  String get menuInvoices => 'Invoices';

  @override
  String get menuReceived => 'Money received';

  @override
  String get menuReports => 'Reports';

  @override
  String get menuDocuments => 'Documents';

  @override
  String get menuTeam => 'Team';

  @override
  String get menuBackup => 'Backup';

  @override
  String get menuPlan => 'Plan';

  @override
  String get menuHelp => 'Help';

  @override
  String get countWorkers => 'Workers';

  @override
  String get countShifts => 'Shifts';

  @override
  String get countWorkerDays => 'Worker-days';

  @override
  String get dayNames => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get pickDate => 'Choose date';

  @override
  String get chooseWorker => 'Worker';

  @override
  String get noBillingRates =>
      'No company rates yet. Add one so attendance can be priced.';

  @override
  String get noPayRates =>
      'No pay rates yet. Add one so attendance can be priced.';

  @override
  String get balancesEmpty =>
      'Nothing carried over yet. Add what was already due when you started using this app.';

  @override
  String get addBalance => 'Add carried-over amount';

  @override
  String get balanceKind => 'What kind of amount?';

  @override
  String get todayEmpty =>
      'No attendance on this date. Tap Mark attendance to start.';

  @override
  String get companiesEmpty => 'No client companies yet. Add your first one.';

  @override
  String get labourEmpty => 'No workers yet. Add your first one.';

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

  @override
  String get markAttendance => 'Mark attendance';

  @override
  String get workDate => 'Date';

  @override
  String get chooseClient => 'Company';

  @override
  String get chooseSite => 'Site';

  @override
  String get shiftStart => 'Start';

  @override
  String get shiftEnd => 'End';

  @override
  String get breakMinutes => 'Break in minutes';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get copyLastTeam => 'Last team';

  @override
  String get noLastTeam => 'No earlier team found for this site.';

  @override
  String get needSetupFirst => 'Add a company, a site and a worker first.';

  @override
  String get timesRequired => 'Choose the start and end time.';

  @override
  String get reviewTitle => 'Review attendance';

  @override
  String get totalClient => 'To collect from company';

  @override
  String get totalWorker => 'To pay workers';

  @override
  String get monthlyNotInTotal =>
      'Workers on a monthly rate are not in this total. They are calculated per month.';

  @override
  String get groupRate => 'Change today\'s company rate';

  @override
  String get groupRateAmount => 'Company rate for this group (AED)';

  @override
  String get issueClientRate => 'No company rate found';

  @override
  String get issueWorkerRate => 'No worker rate found';

  @override
  String get issueHalf => 'No half-day amount agreed';

  @override
  String get issueOvertime => 'No overtime rate agreed';

  @override
  String get issueOverlap =>
      'This worker already has attendance at this time. Write a reason.';

  @override
  String get issueBreak => 'Break is longer than the shift';

  @override
  String get issueOverrideReason => 'Write why the rate changed';

  @override
  String get rowsNeedFix => 'Fix the rows marked in red, then save.';

  @override
  String get savesAsDraft =>
      'Rows with a missing rate save as drafts until a rate is added.';

  @override
  String get statusPresent => 'Present';

  @override
  String get statusHalf => 'Half day';

  @override
  String get statusAbsent => 'Absent';

  @override
  String get clientBreakPaid => 'Break paid on company side';

  @override
  String get workerBreakPaid => 'Break paid on worker side';

  @override
  String get overtimeApproved => 'Overtime approved';

  @override
  String get clientOverride => 'Company rate for this row (AED)';

  @override
  String get workerOverride => 'Worker rate for this row (AED)';

  @override
  String get overrideHelp =>
      'Leave empty to use the contract. Changing a rate needs the owner\'s approval and a reason.';

  @override
  String get overrideReason => 'Why the rate changed';

  @override
  String get overlapReason => 'Why two entries overlap';

  @override
  String get correctionReason => 'Why this is being corrected';

  @override
  String get correctionHelp =>
      'The original entry is kept. This creates a corrected entry.';

  @override
  String get deleteRow => 'Remove this entry';

  @override
  String get applyChanges => 'Apply';

  @override
  String get stateDraft => 'Draft';

  @override
  String get stateSubmitted => 'Needs review';

  @override
  String get stateApproved => 'Approved';

  @override
  String get stateLinked => 'In accounts';

  @override
  String get correctedTag => 'Corrected';

  @override
  String get cancel => 'Cancel';

  @override
  String get localOnlyNote => 'This data is only on this phone.';

  @override
  String nextWithCount(int count) {
    return 'Next ($count workers)';
  }

  @override
  String approveAll(int count) {
    return 'Approve all ($count)';
  }

  @override
  String approvedCount(int count) {
    return '$count entries approved';
  }

  @override
  String countsLine(int workers, int shifts, int days) {
    return '$workers workers, $shifts shifts, $days worker-days';
  }

  @override
  String missingWorkers(int count, String names) {
    return '$count workers have no attendance: $names';
  }

  @override
  String hoursPaid(String duration) {
    return '$duration hours';
  }

  @override
  String get saveFailed => 'Could not save. Nothing was changed. Try again.';

  @override
  String rowCollect(String amount) {
    return 'Collect $amount';
  }

  @override
  String rowPay(String amount) {
    return 'pay $amount';
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
  String get tabGroups => 'Mazdoor group';

  @override
  String get addGroup => 'Group banayein';

  @override
  String get editGroup => 'Group badlein';

  @override
  String get groupName => 'Group ka naam';

  @override
  String get groupNameHelp => 'Jaise: Emaar West';

  @override
  String get groupsEmpty =>
      'Abhi koi group nahin. Jo mazdoor aksar saath jate hain un ka group banayein.';

  @override
  String get noneChoice => 'Koi nahin';

  @override
  String get dailyWage => 'Dehari (AED)';

  @override
  String get dailyWageHelp =>
      'Zaroori nahin. Yeh har mazdoor ke saamne aa jayegi. Kisi aik ki badalni ho to us ke naam ke saamne raqam par dabayein.';

  @override
  String get halfDayIsHalf => 'Aadhe din par aadhi dehari';

  @override
  String get ownWageHelp => 'Khaali chhorein to group ki dehari lagegi.';

  @override
  String get todayWageHelp => 'Sirf is hazri ke liye. Group nahin badlega.';

  @override
  String get todayWageReason => 'Hazri lagate waqt dehari likhi';

  @override
  String get setWage => 'Dehari likhein';

  @override
  String get monthlyPay => 'Mahana';

  @override
  String get workersHeading => 'Mazdoor';

  @override
  String get searchGroup => 'Group talash karein';

  @override
  String get searchWorker => 'Mazdoor talash karein';

  @override
  String membersCount(int count) {
    return '$count mazdoor';
  }

  @override
  String saveWithCount(int count) {
    return 'Save karein ($count mazdoor)';
  }

  @override
  String wageOf(String name) {
    return 'Dehari: $name';
  }

  @override
  String get tabRates => 'Rates';

  @override
  String get tabSettings => 'Settings';

  @override
  String get menuLabel => 'Menu';

  @override
  String get menuClose => 'Menu band karein';

  @override
  String get soon => 'Jald';

  @override
  String get groupDaily => 'Rozana';

  @override
  String get groupRegisters => 'Register';

  @override
  String get groupPayroll => 'Tankhwah aur paisa';

  @override
  String get groupBilling => 'Billing';

  @override
  String get groupMore => 'Aur';

  @override
  String get menuPayroll => 'Tankhwah';

  @override
  String get menuAdvances => 'Advance';

  @override
  String get menuPayments => 'Adaigi';

  @override
  String get menuExpenses => 'Kharche';

  @override
  String get menuTimesheets => 'Timesheet';

  @override
  String get menuInvoices => 'Invoice';

  @override
  String get menuReceived => 'Paisay mile';

  @override
  String get menuReports => 'Reports';

  @override
  String get menuDocuments => 'Documents';

  @override
  String get menuTeam => 'Team';

  @override
  String get menuBackup => 'Backup';

  @override
  String get menuPlan => 'Plan';

  @override
  String get menuHelp => 'Madad';

  @override
  String get countWorkers => 'Mazdoor';

  @override
  String get countShifts => 'Shifts';

  @override
  String get countWorkerDays => 'Worker-days';

  @override
  String get dayNames => 'Pir,Mangal,Budh,Jumerat,Juma,Hafta,Itwar';

  @override
  String get pickDate => 'Tareekh chunein';

  @override
  String get chooseWorker => 'Mazdoor';

  @override
  String get noBillingRates =>
      'Abhi koi company rate nahin. Rate add karein taake hazri ka hisaab ban sake.';

  @override
  String get noPayRates =>
      'Abhi koi tankhwah ka rate nahin. Rate add karein taake hazri ka hisaab ban sake.';

  @override
  String get balancesEmpty =>
      'Abhi koi pichla baqaya nahin. Jo raqam app shuru karne se pehle baqi thi woh yahan likhein.';

  @override
  String get addBalance => 'Pichla baqaya add karein';

  @override
  String get balanceKind => 'Kaunsi raqam?';

  @override
  String get todayEmpty =>
      'Is din koi hazri nahin. Shuru karne ke liye Hazri lagayein dabayein.';

  @override
  String get companiesEmpty =>
      'Abhi koi client company nahin. Pehli company add karein.';

  @override
  String get labourEmpty => 'Abhi koi mazdoor nahin. Pehla mazdoor add karein.';

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

  @override
  String get markAttendance => 'Hazri lagayein';

  @override
  String get workDate => 'Tareekh';

  @override
  String get chooseClient => 'Company';

  @override
  String get chooseSite => 'Site';

  @override
  String get shiftStart => 'Shuru';

  @override
  String get shiftEnd => 'Khatam';

  @override
  String get breakMinutes => 'Break, minutes mein';

  @override
  String get selectAll => 'Sab ko select';

  @override
  String get clearSelection => 'Selection hatayein';

  @override
  String get copyLastTeam => 'Pichli team';

  @override
  String get noLastTeam => 'Is site ki pichli team nahin mili.';

  @override
  String get needSetupFirst => 'Pehle company, site aur mazdoor add karein.';

  @override
  String get timesRequired => 'Shuru aur khatam ka waqt chunein.';

  @override
  String get reviewTitle => 'Hazri review karein';

  @override
  String get totalClient => 'Company se lena hai';

  @override
  String get totalWorker => 'Mazdoor ko dena hai';

  @override
  String get monthlyNotInTotal =>
      'Mahana rate wale mazdoor is total mein nahin. Un ka hisaab mahine par hoga.';

  @override
  String get groupRate => 'Aaj ka company rate badlein';

  @override
  String get groupRateAmount => 'Is group ka company rate (AED)';

  @override
  String get issueClientRate => 'Company ka rate nahin mila';

  @override
  String get issueWorkerRate => 'Mazdoor ka rate nahin mila';

  @override
  String get issueHalf => 'Aadhay din ki raqam tay nahin';

  @override
  String get issueOvertime => 'Overtime rate tay nahin';

  @override
  String get issueOverlap =>
      'Is waqt mazdoor ki doosri hazri hai. Wajah likhein.';

  @override
  String get issueBreak => 'Break shift se lamba hai';

  @override
  String get issueOverrideReason => 'Rate badalne ki wajah likhein';

  @override
  String get rowsNeedFix => 'Laal rows theek karein, phir save karein.';

  @override
  String get savesAsDraft =>
      'Jin rows ka rate nahin woh rate milne tak draft rahengi.';

  @override
  String get statusPresent => 'Hazir';

  @override
  String get statusHalf => 'Aadha din';

  @override
  String get statusAbsent => 'Ghair hazir';

  @override
  String get clientBreakPaid => 'Company ke hisaab mein break paid';

  @override
  String get workerBreakPaid => 'Mazdoor ke hisaab mein break paid';

  @override
  String get overtimeApproved => 'Overtime manzoor';

  @override
  String get clientOverride => 'Is row ka company rate (AED)';

  @override
  String get workerOverride => 'Is row ka mazdoor rate (AED)';

  @override
  String get overrideHelp =>
      'Contract ka rate rakhne ke liye khali chhor dein. Rate badalne ke liye maalik ki manzoori aur wajah zaroori hai.';

  @override
  String get overrideReason => 'Rate badalne ki wajah';

  @override
  String get overlapReason => 'Do hazriyan ek waqt mein kyun';

  @override
  String get correctionReason => 'Correction ki wajah';

  @override
  String get correctionHelp =>
      'Asal entry mehfooz rahegi. Yeh nayi corrected entry banayega.';

  @override
  String get deleteRow => 'Yeh entry hatayein';

  @override
  String get applyChanges => 'Theek hai';

  @override
  String get stateDraft => 'Draft';

  @override
  String get stateSubmitted => 'Review baqi';

  @override
  String get stateApproved => 'Manzoor';

  @override
  String get stateLinked => 'Hisaab mein shamil';

  @override
  String get correctedTag => 'Corrected';

  @override
  String get cancel => 'Wapas';

  @override
  String get localOnlyNote => 'Yeh data sirf is mobile par hai.';

  @override
  String nextWithCount(int count) {
    return 'Aage ($count mazdoor)';
  }

  @override
  String approveAll(int count) {
    return 'Sab manzoor karein ($count)';
  }

  @override
  String approvedCount(int count) {
    return '$count entries manzoor';
  }

  @override
  String countsLine(int workers, int shifts, int days) {
    return '$workers mazdoor, $shifts shifts, $days worker-days';
  }

  @override
  String missingWorkers(int count, String names) {
    return '$count mazdoor ki hazri baqi: $names';
  }

  @override
  String hoursPaid(String duration) {
    return '$duration ghante';
  }

  @override
  String get saveFailed =>
      'Save nahin hua. Kuch tabdeel nahin hua. Dobara koshish karein.';

  @override
  String rowCollect(String amount) {
    return 'Lena $amount';
  }

  @override
  String rowPay(String amount) {
    return 'dena $amount';
  }
}
