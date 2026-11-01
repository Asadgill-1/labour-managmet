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
      'Optional. Only for a worker with no pay of their own.';

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
    return 'Pay: $name';
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
  String get groupBilling => 'Payroll and billing';

  @override
  String get groupMore => 'More';

  @override
  String get menuPayroll => 'Payroll';

  @override
  String get tabCash => 'Daily money';

  @override
  String get tabRooms => 'Rooms';

  @override
  String get addCash => 'Add entry';

  @override
  String get cashEmpty =>
      'Nothing written for this. Tap Add entry when money comes in or goes out.';

  @override
  String get moneyOut => 'Money given';

  @override
  String get moneyIn => 'Money received';

  @override
  String get cashDifference => 'Difference';

  @override
  String get kindAdvanceGiven => 'Advance';

  @override
  String get kindSalaryPaid => 'Salary';

  @override
  String get kindRoomRentPaid => 'Room rent paid';

  @override
  String get kindExpense => 'Expense';

  @override
  String get kindAdvanceReturned => 'Advance returned';

  @override
  String get kindRoomRentReceived => 'Room rent received';

  @override
  String get kindClientReceipt => 'From a company';

  @override
  String get catTransport => 'Transport';

  @override
  String get catFood => 'Food';

  @override
  String get catVisa => 'Visa and PRO';

  @override
  String get catTools => 'Tools';

  @override
  String get catOffice => 'Office';

  @override
  String get catOther => 'Other';

  @override
  String get expenseCategory => 'Expense type';

  @override
  String get optionalSite => 'Site (optional)';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBank => 'Bank';

  @override
  String get chooseRoom => 'Room';

  @override
  String get advanceTooHigh =>
      'This is more than the advance still to recover.';

  @override
  String get advanceUndoBlocked =>
      'Some of this advance has already come back. Undo that entry first.';

  @override
  String get reverseTitle => 'Undo this entry?';

  @override
  String get reverseHelp =>
      'The original stays on record. A reversing entry cancels it.';

  @override
  String get reverseReason => 'Why it is being undone';

  @override
  String get reverseConfirm => 'Undo entry';

  @override
  String get reversedTag => 'Undone';

  @override
  String get reversalTag => 'Undo of an entry';

  @override
  String get moneyHeading => 'Money';

  @override
  String get advanceOutstanding => 'Advance still to recover';

  @override
  String get salaryPaidTotal => 'Salary paid';

  @override
  String get workerRentTotal => 'Room rent paid by this worker';

  @override
  String get roomsEmpty => 'No rooms yet. Add the rooms you rent for workers.';

  @override
  String get addRoom => 'Add room';

  @override
  String get editRoom => 'Edit room';

  @override
  String get roomName => 'Room name';

  @override
  String get roomNameHelp => 'For example: Sonapur Room 12';

  @override
  String get rentIn => 'Rent received';

  @override
  String get rentOut => 'Rent paid';

  @override
  String get roomProfitLabel => 'Profit';

  @override
  String get roomLossLabel => 'Loss';

  @override
  String get roomEven => 'Even';

  @override
  String get residentsHeading => 'Living here';

  @override
  String get noResidents =>
      'Nobody yet. Choose this room on a worker\'s screen.';

  @override
  String get entriesHeading => 'Entries';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String advanceBalance(String amount) {
    return 'Advance still to recover: $amount';
  }

  @override
  String savedTo(String name) {
    return 'Saved on phone, in $name\'s account';
  }

  @override
  String roomProfit(String amount) {
    return 'Profit $amount';
  }

  @override
  String roomLoss(String amount) {
    return 'Loss $amount';
  }

  @override
  String rentSplit(String received, String paid) {
    return 'Received $received, paid $paid';
  }

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
      'Rows with no worker rate stay out of payroll until a rate is added.';

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
  String get stateDraft => 'No pay rate';

  @override
  String get stateSubmitted => 'Saved';

  @override
  String get stateApproved => 'Final';

  @override
  String get stateLinked => 'In payroll';

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

  @override
  String get payrollEarned => 'This month\'s earnings';

  @override
  String get payrollCut => 'Deductions';

  @override
  String get payrollToPay => 'To pay the worker';

  @override
  String get payrollSalary => 'Monthly salary';

  @override
  String get payrollAdjustment => 'Earlier work';

  @override
  String get payrollNet => 'This month\'s net';

  @override
  String get payrollOpening => 'Previous unpaid';

  @override
  String get payrollPaidAhead => 'Paid ahead';

  @override
  String get payrollPayable => 'Total payable';

  @override
  String get payrollPaid => 'Paid since';

  @override
  String get payrollClosing => 'Still unpaid';

  @override
  String get payrollOverpaid => 'Paid too much';

  @override
  String get payrollEmpty =>
      'Nothing to pay this month. Mark attendance first.';

  @override
  String get payrollEarnedHeading => 'Earnings';

  @override
  String get payrollItemsHeading => 'Allowances and deductions';

  @override
  String get payrollSumHeading => 'Account';

  @override
  String get payrollNoItems => 'None this month.';

  @override
  String get payrollStatePosted => 'Posted';

  @override
  String get payrollStateReady => 'Ready to post';

  @override
  String get payrollStateDraft => 'Not posted';

  @override
  String get payrollPostConfirm => 'Post';

  @override
  String get payrollPayNow => 'Record payment';

  @override
  String get payrollUndo => 'Undo this posting';

  @override
  String get payrollUndoTitle => 'Undo this posting?';

  @override
  String get payrollUndoHelp =>
      'The month goes back to unposted so you can fix it. The record stays, and money already paid stays on the worker\'s account.';

  @override
  String get payrollUndoLater => 'Undo the later month first.';

  @override
  String get payKindAllowance => 'Allowance';

  @override
  String get payKindDeduction => 'Deduction';

  @override
  String get payKindRecovery => 'Advance recovery';

  @override
  String get payItemReason => 'Reason';

  @override
  String get payItemAuthorizedBy => 'Agreement or permission';

  @override
  String get payItemAuthorizedHelp =>
      'Who agreed, and how. For example: signed paper, 01-10-2026';

  @override
  String get payItemDelete => 'Remove';

  @override
  String get issuePartial => 'Choose the part-month method on the contract.';

  @override
  String get issueNegative => 'Deductions are more than earnings.';

  @override
  String get issueRecovery => 'Recovery is more than the advance left.';

  @override
  String get issueLimit => 'Deductions are above your company\'s limit.';

  @override
  String get issueEarlier => 'Post the earlier month first.';

  @override
  String get issueLater =>
      'A later month is posted. This goes into the next payroll.';

  @override
  String get issueNotStarted => 'This month has not started.';

  @override
  String get salaryOwed => 'Salary still owed';

  @override
  String get rentFromPay => 'Taken from salaries';

  @override
  String get deductionLimit => 'Deduction limit (%, optional)';

  @override
  String get deductionLimitHelp =>
      'Share of earnings. Ask your accountant. Empty means no limit.';

  @override
  String get deductionLimitError => 'Write a whole number from 1 to 100.';

  @override
  String payrollPost(int count) {
    return 'Post payroll ($count)';
  }

  @override
  String payrollPostTitle(String month) {
    return 'Post payroll for $month?';
  }

  @override
  String payrollPostBody(int count, String amount) {
    return '$count workers, $amount goes onto their accounts. The figures will not change after this. If something is wrong, undo it on that worker.';
  }

  @override
  String payrollPosted(int count) {
    return 'Payroll posted for $count workers';
  }

  @override
  String payrollSplit(String earned, String cut) {
    return 'Earned $earned, deducted $cut';
  }

  @override
  String get applyRoomCharges => 'Add room charge';

  @override
  String roomChargesApplied(int count) {
    return 'Room charge added for $count workers';
  }

  @override
  String get payKindRoom => 'Room charge';

  @override
  String get mainAttendance => 'Attendance';

  @override
  String get mainVisa => 'Visa';

  @override
  String get mainMoney => 'Money';

  @override
  String get tabVisa => 'Visa money';

  @override
  String get groupSoon => 'Coming soon';

  @override
  String get regAttendance => 'Attendance register';

  @override
  String get regWorkers => 'Worker register';

  @override
  String get regVisa => 'Visa register';

  @override
  String get regCompanies => 'Company register';

  @override
  String get regPayroll => 'Pay register';

  @override
  String get regAdvance => 'Advance register';

  @override
  String get regCash => 'Money register';

  @override
  String get regRooms => 'Room register';

  @override
  String get kindVisaPaid => 'Visa money spent';

  @override
  String get kindVisaReturned => 'Visa money returned';

  @override
  String get visaTooHigh => 'This is more than the visa money left.';

  @override
  String get visaUndoBlocked =>
      'Can\'t undo this: some of this visa money has already come back.';

  @override
  String visaBalance(String amount) {
    return 'Visa money left: $amount';
  }

  @override
  String get visaSpent => 'Spent';

  @override
  String get visaBack => 'Back';

  @override
  String get visaLeft => 'Visa left';

  @override
  String get visaAdd => 'Add visa money';

  @override
  String get visaEmpty =>
      'No visa money yet. Add what the company spent on a worker.';

  @override
  String visaSplit(String spent, String back) {
    return 'Spent $spent, back $back';
  }

  @override
  String get visaInstalment => 'Monthly instalment';

  @override
  String get visaInstalmentOff => 'Off';

  @override
  String get visaInstalmentHelp =>
      'Taken from pay when you press the button in Payroll. Leave empty to turn it off.';

  @override
  String visaInstalmentShort(String amount) {
    return 'Instalment $amount a month';
  }

  @override
  String get visaReturnAdd => 'Add money returned';

  @override
  String get payKindVisa => 'Visa instalment';

  @override
  String get salaryMonthsHeading => 'Which month\'s salary';

  @override
  String salaryMonthLeft(String amount) {
    return '$amount unpaid';
  }

  @override
  String get salaryOldestFirst => 'Oldest first';

  @override
  String get salaryNothingOwed =>
      'No salary is unpaid for this worker. This amount goes on their advance.';

  @override
  String salaryExtraLine(String amount) {
    return '$amount more than is owed. It goes on the advance.';
  }

  @override
  String salaryExtraTitle(String amount) {
    return '$amount more than is owed';
  }

  @override
  String get salaryExtraBody =>
      'This extra is written as an advance to this worker, and comes back through a later salary.';

  @override
  String get salaryExtraConfirm => 'Write as advance';

  @override
  String get salaryExtraNote => 'Paid above salary owed';

  @override
  String get salaryPartsTooMuch => 'The months add up to more than the amount.';

  @override
  String get salaryPartTooHigh => 'Above what is unpaid';

  @override
  String get salaryReference => 'Reference (bank or cheque)';

  @override
  String get salaryReceiver => 'Received by';

  @override
  String get salaryReceiverHelp => 'Leave empty if the worker took it.';

  @override
  String wagesDueBanner(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count workers',
      one: '1 worker',
    );
    return '$_temp0 unpaid: $amount';
  }

  @override
  String wagesDueOldest(String month) {
    return 'Waiting longest: $month';
  }

  @override
  String get wagesDueTitle => 'Unpaid salary';

  @override
  String get wagesDueWorkers => 'Workers';

  @override
  String get wagesDueTotal => 'Unpaid';

  @override
  String wagesDueLate(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String get wagesDueInTime => 'due, not late yet';

  @override
  String get wagesDueNone => 'Every finished month is paid.';

  @override
  String get wagesDueNote =>
      'A reminder only. Recording a late salary does not make it lawful, and this app is not a wage payment or WPS service.';

  @override
  String get wageDueDays => 'Days to pay salary after month end';

  @override
  String get wageDueDaysHelp =>
      'Your own figure, ask your accountant. Empty means late from the day after month end.';

  @override
  String get wageDueDaysError => 'A whole number from 0 to 90.';

  @override
  String applyAdvanceCuts(int count) {
    return 'Cut advance ($count)';
  }

  @override
  String advanceCutsApplied(int count) {
    return 'Advance cut for $count workers';
  }

  @override
  String get tabClosing => 'Close month';

  @override
  String get closingWorkersLeft => 'Left on workers\' accounts';

  @override
  String get closingState => 'This month';

  @override
  String get closingOpen => 'Open';

  @override
  String get closingClosed => 'Closed';

  @override
  String get closingNotOver =>
      'This month has not ended yet, so it cannot be closed.';

  @override
  String get closingIsClosed =>
      'This month is closed. A change now goes into an open month as an allowance, deduction or reversal.';

  @override
  String closingLeft(int count) {
    return '$count things left. The month closes only when all are cleared.';
  }

  @override
  String get closingUnpaidNote =>
      'Unpaid wages do not hold a month up. They carry into the next month.';

  @override
  String closeBlocked(int count) {
    return 'Clear $count things first';
  }

  @override
  String get closingEnterHazri => 'Mark attendance for this date';

  @override
  String get closingDayOff => 'No work for the rest';

  @override
  String get closingDayOffHelp =>
      'Mark attendance for those who worked. Then say the rest had no work, and this date clears.';

  @override
  String get closingDayOffDone => 'Saved. This date is clear.';

  @override
  String get closingPostReady => 'Post pay that is ready';

  @override
  String get closingPostHelp =>
      'Pay that cannot post stays here. Open a name to see why.';

  @override
  String get closingSettle => 'Settle against the oldest months';

  @override
  String get closingSettleHelp =>
      'These figures stay the same. The months are only written down.';

  @override
  String get closingSettled => 'Months written down';

  @override
  String get closingAllClear => 'Nothing to fix. This month can be closed.';

  @override
  String get closingSummary => 'Workers\' accounts this month';

  @override
  String get closingCuts => 'Room, visa and deductions';

  @override
  String get closingExpenses => 'Expenses';

  @override
  String findingNoWorkerRate(int count, String names) {
    return '$count workers have attendance with no pay rate: $names. Add a rate or remove the attendance.';
  }

  @override
  String findingNotPosted(int count, String names) {
    return '$count workers are not posted: $names. Post them in Payroll.';
  }

  @override
  String findingNoCompanyRate(int count, String names) {
    return '$count companies have no rate, so their bill is incomplete: $names.';
  }

  @override
  String findingNoHazri(int count, String names) {
    return '$count workers with no attendance: $names.';
  }

  @override
  String findingOverlap(int count, String names) {
    return '$count workers have shifts that overlap: $names.';
  }

  @override
  String findingNoMonth(int count, String names) {
    return '$count workers have a payment with no month chosen, which settles the oldest month: $names.';
  }

  @override
  String closeButton(String month) {
    return 'Close $month';
  }

  @override
  String closeTitle(String month) {
    return 'Close $month?';
  }

  @override
  String get closeBody =>
      'Attendance, expenses and payroll up to this month will stop changing. A later change goes into an open month as an allowance, deduction or reversal.';

  @override
  String get closeConfirm => 'Close';

  @override
  String closeDone(String month) {
    return '$month is closed';
  }

  @override
  String get closeNotReady =>
      'This month cannot close yet. Fix what is listed first.';

  @override
  String get reopenButton => 'Open this month again';

  @override
  String reopenTitle(String month) {
    return 'Open $month again';
  }

  @override
  String get reopenHelp => 'Why it must change. The reason stays on record.';

  @override
  String get reopenConfirm => 'Open';

  @override
  String reopenDone(String month) {
    return '$month is open again';
  }

  @override
  String get reopenLater => 'Open the later month first.';

  @override
  String get periodLockedError =>
      'This month is closed. Enter the difference in an open month as an allowance or deduction, or open it again from Close month.';

  @override
  String get closedNote => 'This month is closed. Nothing here can change.';

  @override
  String get reverseHelpClosed =>
      'This month is closed, so the reversal is written with today\'s date and the closed month stays as it was.';

  @override
  String get issueClosed => 'This month is closed.';

  @override
  String applyVisaInstalments(int count) {
    return 'Add visa instalments ($count)';
  }

  @override
  String visaInstalmentsApplied(int count) {
    return 'Visa instalment added for $count workers';
  }

  @override
  String get issueVisa => 'This is more than the visa money left.';

  @override
  String regRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get regAllDates => 'All dates';

  @override
  String get regThisMonth => 'This month';

  @override
  String get regLastMonth => 'Last month';

  @override
  String get regAll => 'All';

  @override
  String get regClear => 'Clear';

  @override
  String get regExport => 'PDF, Excel or WhatsApp';

  @override
  String get regEmpty => 'Nothing for these dates and filters.';

  @override
  String get regTotal => 'Total';

  @override
  String regPage(String page, String pages) {
    return 'Page $page of $pages';
  }

  @override
  String regMade(String when) {
    return 'Made on $when';
  }

  @override
  String regFilterDates(String range) {
    return 'Dates: $range';
  }

  @override
  String get regAmountsNote => 'Amounts in AED';

  @override
  String get regCompanyNote =>
      'Wages here are pay marked on attendance. Monthly salaries are not in them.';

  @override
  String get regPayrollNote => 'Posted months only.';

  @override
  String get exportMaking => 'Making the file...';

  @override
  String get exportView => 'View or print';

  @override
  String get exportOpen => 'Open';

  @override
  String get exportSave => 'Save on phone';

  @override
  String get exportWhatsApp => 'WhatsApp';

  @override
  String get exportOther => 'Other apps';

  @override
  String get exportNoWhatsApp => 'WhatsApp not found. Choose another app.';

  @override
  String get exportNoApp =>
      'No app on this phone opens this file. Use Other apps to send it.';

  @override
  String get exportSaved => 'Saved on the phone.';

  @override
  String get exportFailed => 'Could not make the file. Try again.';

  @override
  String get filterStatus => 'Attendance';

  @override
  String get filterState => 'State';

  @override
  String get filterKind => 'Type';

  @override
  String get filterMethod => 'Cash or bank';

  @override
  String get filterTrade => 'Trade';

  @override
  String get filterActive => 'Status';

  @override
  String get filterOwed => 'Balance';

  @override
  String get stateActive => 'Active';

  @override
  String get stateArchived => 'Archived';

  @override
  String get owedYes => 'Still owed';

  @override
  String get owedNo => 'Cleared';

  @override
  String get colDate => 'Date';

  @override
  String get colMonth => 'Month';

  @override
  String get colWorker => 'Worker';

  @override
  String get colCode => 'Code';

  @override
  String get colCompany => 'Company';

  @override
  String get colSite => 'Site';

  @override
  String get colGroup => 'Group';

  @override
  String get colIn => 'In';

  @override
  String get colOut => 'Out';

  @override
  String get colBreak => 'Break';

  @override
  String get colCompanyHours => 'Company hours';

  @override
  String get colWorkerHours => 'Worker hours';

  @override
  String get colOvertime => 'Overtime';

  @override
  String get colCompanyRate => 'Company rate';

  @override
  String get colBill => 'Company bill';

  @override
  String get colWorkerRate => 'Worker rate';

  @override
  String get colPay => 'Worker pay';

  @override
  String get colWhat => 'What';

  @override
  String get colWho => 'Who';

  @override
  String get colGiven => 'Given';

  @override
  String get colBack => 'Back';

  @override
  String get colLeft => 'Left';

  @override
  String get colPhone => 'Phone';

  @override
  String get colJoined => 'Joined';

  @override
  String get colRoom => 'Room';

  @override
  String get colRate => 'Pay rate';

  @override
  String get colWorkers => 'Workers';

  @override
  String get colHours => 'Hours';

  @override
  String get colWages => 'Wages';

  @override
  String get colDifference => 'Difference';

  @override
  String get colPostedOn => 'Posted on';

  @override
  String get settingsColour => 'App colours';

  @override
  String get paletteBlue => 'Blue';

  @override
  String get paletteGreen => 'Green';

  @override
  String get paletteMaroon => 'Maroon';

  @override
  String issueMissingRate(int count) {
    return '$count attendance rows have no worker rate. Add it under Rates.';
  }

  @override
  String get noClientRateNote =>
      'No company rate yet. The worker\'s pay still counts, and the bill appears once the rate is added.';

  @override
  String roomChargeTitle(String month) {
    return 'Room charge, $month';
  }

  @override
  String get roomChargeAll => 'Same amount for all (AED)';

  @override
  String get roomChargeAllHelp =>
      'Used for anyone ticked with no amount of their own.';

  @override
  String roomChargeSave(int count) {
    return 'Add for $count workers';
  }

  @override
  String roomChargeNeedAmount(String name) {
    return 'Write the amount for $name';
  }

  @override
  String get roomChargeNone =>
      'Everyone has this month\'s room charge already, or their month is posted.';

  @override
  String get roomChargeByOwner => 'Added by the owner';

  @override
  String get issueNoRate => 'No rate';

  @override
  String get colEarned => 'Earned';

  @override
  String get colPaid => 'Paid';

  @override
  String get colNoRate => 'No company rate';

  @override
  String get colDays => 'Days';

  @override
  String get regBrought => 'Brought forward';

  @override
  String get regWorkerNote =>
      'Balance = earned - advance - deductions, room and visa cut - paid. A monthly salary shows once its month is posted.';

  @override
  String get regAttendanceNote =>
      'Difference = company bill - worker pay, for rows that have both. Monthly salaries are not in worker pay.';

  @override
  String regOwedToWorker(String amount) {
    return 'Balance $amount: to pay the worker';
  }

  @override
  String regOwedByWorker(String amount) {
    return 'Balance $amount: the worker owes this';
  }

  @override
  String get regSettled => 'Balance AED 0.00: settled';

  @override
  String regOwedSplit(String pay, String advance) {
    return 'Pay $pay, less advance left $advance';
  }

  @override
  String regRecoveryRow(String amount) {
    return '$amount taken from pay. The balance counted it when it was given.';
  }

  @override
  String get regByWorker => 'By worker';

  @override
  String get regBySite => 'By company and site';

  @override
  String get regAllWorkers => 'All workers';

  @override
  String get regSummarySheet => 'Summary';

  @override
  String get colBalance => 'Balance';

  @override
  String rateIn(String name) {
    return 'Pay: $name';
  }

  @override
  String ownRateHelp(String rate) {
    return 'Their own pay is $rate. Leave empty to keep it.';
  }

  @override
  String rateSetHere(String rate) {
    return 'In this group: $rate';
  }

  @override
  String rateOwn(String rate) {
    return 'Own pay: $rate';
  }

  @override
  String rateFromGroup(String rate) {
    return 'Group wage: $rate';
  }

  @override
  String get rateMissing => 'No pay set. Set it here, or add a group wage.';

  @override
  String get rateChange => 'Change';

  @override
  String regVisaRow(String amount) {
    return 'Visa money $amount. It comes off the balance as it is cut from pay.';
  }

  @override
  String regVisaLeft(String amount) {
    return 'Visa left $amount';
  }

  @override
  String get exportSlowPdf =>
      'This PDF is long and can take some minutes. Excel is much quicker.';

  @override
  String get exportTooLong =>
      'Too many rows for one file. Pick fewer dates or add a filter.';

  @override
  String get payrollAdvanceLeft => 'Advance not yet cut';

  @override
  String get payrollAfterAdvance => 'Balance on the slip, after advance';

  @override
  String get slipTitle => 'Salary slip';

  @override
  String get slipSummary => 'Account';

  @override
  String get slipOpening => 'Balance from before';

  @override
  String get slipWork => 'This month\'s work';

  @override
  String get slipAdvance => 'Advance taken';

  @override
  String get slipRoom => 'Room';

  @override
  String get slipVisa => 'Visa';

  @override
  String get slipOther => 'Other deductions';

  @override
  String get slipPaid => 'Paid';

  @override
  String get slipOwedToYou => 'Balance: to be paid to you';

  @override
  String get slipYouOwe => 'Balance: you owe';

  @override
  String get slipSettled => 'Balance';

  @override
  String get slipDays => 'Day by day';

  @override
  String get slipMoney => 'Money taken';

  @override
  String get slipNoWork => 'No work this month.';

  @override
  String get slipNoMoney => 'No money taken this month.';

  @override
  String slipDayCount(int days) {
    return '$days days';
  }

  @override
  String slipVisaLeft(String amount) {
    return 'Visa left $amount: comes out of later pay.';
  }

  @override
  String get slipNote => 'This slip is an account, not proof of payment.';

  @override
  String get ownerSheet => 'Owner\'s sheet';

  @override
  String get sheetTitle => 'Owner\'s salary sheet';

  @override
  String get sheetSummary => 'The month in short';

  @override
  String get sheetBill => 'Company bills';

  @override
  String get sheetWages => 'Wages for that work';

  @override
  String get sheetSalaries => 'Monthly salaries, not split by company';

  @override
  String get sheetAllowances => 'Allowances';

  @override
  String get sheetCuts => 'Other deductions from pay';

  @override
  String get sheetRoomIn => 'Room money in, from pay and cash';

  @override
  String get sheetRoomOut => 'Room rent paid';

  @override
  String get sheetExpenses => 'Other expenses';

  @override
  String get sheetEstimate => 'Estimated profit';

  @override
  String get sheetByCompany => 'By company';

  @override
  String get sheetDetail => 'Company wise';

  @override
  String get sheetWorkers => 'Workers\' accounts';

  @override
  String sheetCompanyHead(int workers, int sites) {
    return '$workers workers, $sites sites';
  }

  @override
  String get sheetNote =>
      'An estimate from attendance, not audited accounts. A company with no rate or a monthly rate shows no bill here, so its profit looks low. Advance and visa money are not expenses, because workers pay them back.';

  @override
  String get colProfit => 'Profit';

  @override
  String get colVisaLeft => 'Visa left';

  @override
  String get mainDocuments => 'Documents';

  @override
  String get docsTab => 'Issued papers';

  @override
  String get docsEmpty =>
      'No papers yet. A salary slip or receipt shows here once made.';

  @override
  String get docCopyOption => 'Mark as COPY';

  @override
  String get docCopyHelp =>
      'The number stays the same. Without COPY you get the same file that was issued.';

  @override
  String get docCopyLabel => 'COPY';

  @override
  String get docPrint => 'Print';

  @override
  String get slipEarnings => 'Earnings';

  @override
  String get slipEarned => 'Total earned';

  @override
  String get slipDeductions => 'Deductions';

  @override
  String get slipDeducted => 'Total deducted';

  @override
  String get slipAccount => 'Account';

  @override
  String get slipNet => 'This month\'s net';

  @override
  String slipWorkBasis(int days, String hours) {
    return 'Work: $days days, $hours hours';
  }

  @override
  String get receiptMake => 'Make a receipt';

  @override
  String get receiptPaymentTitle => 'Salary receipt';

  @override
  String get receiptAdvanceTitle => 'Advance receipt';

  @override
  String get receiptPayment => 'Salary paid';

  @override
  String get receiptAdvance => 'Advance given';

  @override
  String get receiptMethod => 'Method';

  @override
  String get receiptReference => 'Reference';

  @override
  String get receiptReceiver => 'Taken by';

  @override
  String receiptMonth(String month) {
    return 'Salary for $month';
  }

  @override
  String get receiptNote =>
      'This receipt is the company\'s own record. It is not proof of a bank payment.';

  @override
  String get receiptTakenBy => 'Signature of the person receiving';

  @override
  String get receiptFromCompany => 'For the company';

  @override
  String get lhTab => 'Letterhead';

  @override
  String get lhOld =>
      'Papers already issued stay as they are. This applies to new papers only.';

  @override
  String get lhIdentity => 'Company details';

  @override
  String get lhIdentityNote => 'Name, address, phone and TRN come from here.';

  @override
  String get lhPrinted => 'Print the company heading';

  @override
  String get lhPrintedHelp =>
      'Turn off if your paper is already printed. Then name, logo and footer do not print.';

  @override
  String get lhBlankTop => 'Blank at top (mm)';

  @override
  String get lhBlankBottom => 'Blank at foot (mm)';

  @override
  String get lhBlankBad => 'Enter 0 to 120 mm.';

  @override
  String get lhLogo => 'Logo';

  @override
  String get lhHeader => 'Header image';

  @override
  String get lhFooter => 'Footer image';

  @override
  String get lhSignature => 'Signature';

  @override
  String get lhStamp => 'Stamp';

  @override
  String get lhUpload => 'Choose image';

  @override
  String get lhChange => 'Change';

  @override
  String get lhRemove => 'Remove';

  @override
  String get lhSize => 'Width';

  @override
  String get lhLeft => 'Left';

  @override
  String get lhCenter => 'Centre';

  @override
  String get lhRight => 'Right';

  @override
  String get lhCrop => 'Trim edges';

  @override
  String get lhCropTop => 'Top';

  @override
  String get lhCropBottom => 'Bottom';

  @override
  String get lhCropLeft => 'Left';

  @override
  String get lhCropRight => 'Right';

  @override
  String get lhShow => 'Show on papers';

  @override
  String lhResolution(int width, int height) {
    return '$width x $height pixels';
  }

  @override
  String lhLowRes(int dpi) {
    return 'Will look soft in print ($dpi DPI). Use a bigger image or a smaller width.';
  }

  @override
  String get lhBadType => 'Only PNG or JPEG images work.';

  @override
  String get lhTooLarge => 'The image is over 5 MB.';

  @override
  String get lhSample => 'See a sample';

  @override
  String get mainBilling => 'Billing';

  @override
  String get tsTab => 'Timesheets';

  @override
  String get tsTitle => 'Timesheet';

  @override
  String get tsNew => 'New timesheet';

  @override
  String get tsEmpty =>
      'No timesheets yet. Pick a company and dates to make one.';

  @override
  String get tsAllSites => 'All sites';

  @override
  String get tsFrom => 'From';

  @override
  String get tsTo => 'To';

  @override
  String get tsBadDates => 'The end date is before the start date.';

  @override
  String tsWillHold(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows go on it',
      one: '1 row goes on it',
    );
    return '$_temp0';
  }

  @override
  String get tsNothing => 'Nothing in these dates can go on a timesheet.';

  @override
  String tsLeftNoRate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows left out: no company rate. Add it in Rates.',
      one: '1 row left out: no company rate. Add it in Rates.',
    );
    return '$_temp0';
  }

  @override
  String tsLeftNoWage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows left out: no worker rate yet.',
      one: '1 row left out: no worker rate yet.',
    );
    return '$_temp0';
  }

  @override
  String tsLeftOther(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows left out: already on another timesheet.',
      one: '1 row left out: already on another timesheet.',
    );
    return '$_temp0';
  }

  @override
  String get tsCreate => 'Make draft';

  @override
  String get tsDraftNote =>
      'A draft follows the attendance until you approve it.';

  @override
  String get tsStatusDraft => 'Draft';

  @override
  String get tsStatusApproved => 'Approved';

  @override
  String get tsStatusShared => 'Sent to the company';

  @override
  String get tsStatusAccepted => 'Accepted, locked';

  @override
  String get tsStatusDisputed => 'Disputed by the company';

  @override
  String get tsNoteApproved =>
      'Make the paper and send it. Then say you sent it.';

  @override
  String get tsNoteShared =>
      'Waiting for the company. This never holds up a wage.';

  @override
  String get tsNoteDisputed =>
      'Check the hours with the company. Worker pay stays as it is until you correct the attendance.';

  @override
  String tsRevisionLabel(int number) {
    return 'Revision $number';
  }

  @override
  String get tsViewDaily => 'Daily summary';

  @override
  String get tsViewWorkers => 'Worker detail';

  @override
  String get tsPricedLabel => 'with rates';

  @override
  String get tsHoursOnlyLabel => 'hours only';

  @override
  String get tsUniqueWorkers => 'Unique workers';

  @override
  String get tsWorkerDays => 'Worker-days';

  @override
  String get tsShiftsWorked => 'Shifts worked';

  @override
  String get tsHoursBilled => 'Billable hours';

  @override
  String get tsDaysBilled => 'Billable days';

  @override
  String get tsShiftsBilled => 'Billable shifts';

  @override
  String get tsAmount => 'Amount';

  @override
  String get tsTotalAmount => 'Timesheet total';

  @override
  String get colPersons => 'People';

  @override
  String get colShifts => 'Shifts';

  @override
  String get colClock => 'Clock hours';

  @override
  String get colTrade => 'Trade';

  @override
  String get colBillable => 'Billable';

  @override
  String tsHoursValue(String hours) {
    return '$hours h';
  }

  @override
  String tsDaysValue(String days) {
    return '$days days';
  }

  @override
  String tsShiftsValue(String shifts) {
    return '$shifts shifts';
  }

  @override
  String get tsMonthlyRow => 'Monthly';

  @override
  String get tsNotCharged => 'Not charged';

  @override
  String tsMonthlyLine(
    String basis,
    String rate,
    String from,
    String to,
    int count,
  ) {
    return '$basis, $rate: $from to $to, $count people. The fee goes on the invoice once, not from these rows.';
  }

  @override
  String tsMonthlyLinePlain(String basis, String from, String to, int count) {
    return '$basis: $from to $to, $count people.';
  }

  @override
  String get tsAgreedHeading => 'Agreed with the company';

  @override
  String tsRevisedBecause(String reason) {
    return 'Revised: $reason';
  }

  @override
  String get tsNotInvoice => 'This is a timesheet, not an invoice.';

  @override
  String tsClientSign(String client) {
    return 'Acknowledged for $client';
  }

  @override
  String get tsApprove => 'Approve';

  @override
  String get tsApproveBody =>
      'Its attendance freezes and it gets a number. A later change needs a new revision.';

  @override
  String get tsDeleteDraft => 'Throw away draft';

  @override
  String get tsPaper => 'Make the paper';

  @override
  String get tsPaperPriced => 'Show rate and amount';

  @override
  String get tsPaperPricedHelp =>
      'Off, the company sees hours only. A worker\'s wage never prints.';

  @override
  String get tsContinue => 'Continue';

  @override
  String get tsShared => 'Sent to the company';

  @override
  String get tsAccepted => 'Company accepted';

  @override
  String get tsDisputed => 'Company disputes it';

  @override
  String get tsRespondDate => 'On what date';

  @override
  String get tsRespondNote => 'What they said (optional)';

  @override
  String get tsEvidence => 'Add a photo (optional)';

  @override
  String get tsEvidenceAdded => 'Photo added';

  @override
  String get tsEvidenceNote =>
      'A photo of what came back. It is not a verified digital signature.';

  @override
  String get tsNewRevision => 'New revision';

  @override
  String get tsRevisionHelp =>
      'The old one stays exactly as it was. What changed?';

  @override
  String get tsRevisionConfirm => 'Start';

  @override
  String tsChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows of attendance were corrected after this. A new revision takes them in.',
      one: '1 row of attendance was corrected after this. A new revision takes it in.',
    );
    return '$_temp0';
  }

  @override
  String tsBillingChanged(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count rows differ from what an invoice charged, by $amount. The invoice has not changed.',
      one:
          '1 row differs from what an invoice charged, by $amount. The invoice has not changed.',
    );
    return '$_temp0';
  }

  @override
  String get tsRevisionsHeading => 'Revisions';

  @override
  String get tsOldRevisionNote =>
      'This is an older revision, kept exactly as it was.';

  @override
  String get tsAdjustTitle => 'What the company agreed';

  @override
  String get tsAdjustHelp =>
      'This changes the company\'s paper only. Attendance and the worker\'s pay stay as they are.';

  @override
  String get tsAdjustHours => 'Billable hours';

  @override
  String get tsAdjustMinutes => 'Minutes';

  @override
  String get tsAdjustAmount => 'Amount (AED)';

  @override
  String get tsAdjustReason => 'Why';

  @override
  String get tsAdjustClear => 'Back to the attendance figure';

  @override
  String get tsAdjustSave => 'Save';

  @override
  String get tsNotTaken => 'Not charged';

  @override
  String tsAgreedRow(String reason) {
    return 'Agreed: $reason';
  }

  @override
  String get tsWrongStep => 'This has already moved on. Look again.';

  @override
  String get tsBasisOnly => 'A monthly row has no amount of its own.';

  @override
  String tsPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
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
      'Zaroori nahin. Sirf us mazdoor par lagegi jis ki apni tankhwah nahin.';

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
    return 'Tankhwah: $name';
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
  String get groupBilling => 'Tankhwah aur billing';

  @override
  String get groupMore => 'Aur';

  @override
  String get menuPayroll => 'Tankhwah';

  @override
  String get tabCash => 'Rozana hisaab';

  @override
  String get tabRooms => 'Rooms';

  @override
  String get addCash => 'Hisaab likhein';

  @override
  String get cashEmpty =>
      'Yahan koi hisaab nahin. Paisay dene ya milne par Hisaab likhein dabayein.';

  @override
  String get moneyOut => 'Paisay diye';

  @override
  String get moneyIn => 'Paisay mile';

  @override
  String get cashDifference => 'Farq';

  @override
  String get kindAdvanceGiven => 'Advance';

  @override
  String get kindSalaryPaid => 'Tankhwah';

  @override
  String get kindRoomRentPaid => 'Room ka kiraya diya';

  @override
  String get kindExpense => 'Kharcha';

  @override
  String get kindAdvanceReturned => 'Advance wapas mila';

  @override
  String get kindRoomRentReceived => 'Room ka kiraya mila';

  @override
  String get kindClientReceipt => 'Company se mila';

  @override
  String get catTransport => 'Transport';

  @override
  String get catFood => 'Khana';

  @override
  String get catVisa => 'Visa aur PRO';

  @override
  String get catTools => 'Auzaar';

  @override
  String get catOffice => 'Office';

  @override
  String get catOther => 'Doosra';

  @override
  String get expenseCategory => 'Kharche ki qisam';

  @override
  String get optionalSite => 'Site (zaroori nahin)';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBank => 'Bank';

  @override
  String get chooseRoom => 'Room';

  @override
  String get advanceTooHigh => 'Yeh baqi advance se zyada hai.';

  @override
  String get advanceUndoBlocked =>
      'Is advance ka kuch hissa wapas mil chuka hai. Pehle woh entry wapas karein.';

  @override
  String get reverseTitle => 'Yeh entry wapas karein?';

  @override
  String get reverseHelp =>
      'Asal entry mehfooz rahegi. Aik ulti entry isay khatam kar degi.';

  @override
  String get reverseReason => 'Wapas karne ki wajah';

  @override
  String get reverseConfirm => 'Wapas karein';

  @override
  String get reversedTag => 'Wapas ho gayi';

  @override
  String get reversalTag => 'Wapasi ki entry';

  @override
  String get moneyHeading => 'Paisay ka hisaab';

  @override
  String get advanceOutstanding => 'Advance baqi';

  @override
  String get salaryPaidTotal => 'Tankhwah di';

  @override
  String get workerRentTotal => 'Is mazdoor se kiraya mila';

  @override
  String get roomsEmpty =>
      'Abhi koi room nahin. Mazdooron ke liye liye gaye room add karein.';

  @override
  String get addRoom => 'Room add karein';

  @override
  String get editRoom => 'Room badlein';

  @override
  String get roomName => 'Room ka naam';

  @override
  String get roomNameHelp => 'Jaise: Sonapur Room 12';

  @override
  String get rentIn => 'Kiraya mila';

  @override
  String get rentOut => 'Kiraya diya';

  @override
  String get roomProfitLabel => 'Nafa';

  @override
  String get roomLossLabel => 'Nuksan';

  @override
  String get roomEven => 'Barabar';

  @override
  String get residentsHeading => 'Is room mein rehne wale';

  @override
  String get noResidents =>
      'Abhi koi nahin. Mazdoor ki screen par yeh room chunein.';

  @override
  String get entriesHeading => 'Entries';

  @override
  String get previousMonth => 'Pichla mahina';

  @override
  String get nextMonth => 'Agla mahina';

  @override
  String advanceBalance(String amount) {
    return 'Advance baqi: $amount';
  }

  @override
  String savedTo(String name) {
    return 'Mobile par save, $name ke hisaab mein';
  }

  @override
  String roomProfit(String amount) {
    return 'Nafa $amount';
  }

  @override
  String roomLoss(String amount) {
    return 'Nuksan $amount';
  }

  @override
  String rentSplit(String received, String paid) {
    return 'Mila $received, diya $paid';
  }

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
      'Jin rows ka mazdoor rate nahin woh rate milne tak tankhwah mein nahin ginain gi.';

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
  String get stateDraft => 'Rate nahin';

  @override
  String get stateSubmitted => 'Save hai';

  @override
  String get stateApproved => 'Pakki';

  @override
  String get stateLinked => 'Tankhwah mein';

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

  @override
  String get payrollEarned => 'Is mahine ki kamai';

  @override
  String get payrollCut => 'Katoti';

  @override
  String get payrollToPay => 'Mazdoor ko dena hai';

  @override
  String get payrollSalary => 'Mahana tankhwah';

  @override
  String get payrollAdjustment => 'Pichli hazri ka hisaab';

  @override
  String get payrollNet => 'Is mahine ka net';

  @override
  String get payrollOpening => 'Pichla baqaya';

  @override
  String get payrollPaidAhead => 'Pehle se ada kiya';

  @override
  String get payrollPayable => 'Total dena hai';

  @override
  String get payrollPaid => 'Ab ada kiya';

  @override
  String get payrollClosing => 'Abhi baqi';

  @override
  String get payrollOverpaid => 'Zyada ada kiya';

  @override
  String get payrollEmpty => 'Is mahine kuch dena nahin. Pehle hazri lagayein.';

  @override
  String get payrollEarnedHeading => 'Kamai';

  @override
  String get payrollItemsHeading => 'Allowance aur katoti';

  @override
  String get payrollSumHeading => 'Hisaab';

  @override
  String get payrollNoItems => 'Is mahine koi nahin.';

  @override
  String get payrollStatePosted => 'Post ho gayi';

  @override
  String get payrollStateReady => 'Post ke liye tayyar';

  @override
  String get payrollStateDraft => 'Abhi post nahin';

  @override
  String get payrollPostConfirm => 'Post karein';

  @override
  String get payrollPayNow => 'Adaigi likhein';

  @override
  String get payrollUndo => 'Post wapas karein';

  @override
  String get payrollUndoTitle => 'Post wapas karein?';

  @override
  String get payrollUndoHelp =>
      'Mahina phir se khul jayega taake theek ho sake. Record mehfooz rahega, aur diye hue paisay mazdoor ke hisaab mein rahenge.';

  @override
  String get payrollUndoLater => 'Pehle agla mahina wapas karein.';

  @override
  String get payKindAllowance => 'Allowance';

  @override
  String get payKindDeduction => 'Katoti';

  @override
  String get payKindRecovery => 'Advance ki wapsi';

  @override
  String get payItemReason => 'Wajah';

  @override
  String get payItemAuthorizedBy => 'Agreement ya ijazat';

  @override
  String get payItemAuthorizedHelp =>
      'Kis ne maana aur kaise. Jaise: kaghaz par dastakhat, 01-10-2026';

  @override
  String get payItemDelete => 'Hatayein';

  @override
  String get issuePartial => 'Contract mein adhoore mahine ka tareeqa chunein.';

  @override
  String get issueNegative => 'Katoti kamai se zyada hai.';

  @override
  String get issueRecovery => 'Wapsi baqi advance se zyada hai.';

  @override
  String get issueLimit => 'Katoti company ki hadd se zyada hai.';

  @override
  String get issueEarlier => 'Pehle pichla mahina post karein.';

  @override
  String get issueLater =>
      'Agla mahina post ho chuka. Yeh agli tankhwah mein aayega.';

  @override
  String get issueNotStarted => 'Yeh mahina abhi shuru nahin hua.';

  @override
  String get salaryOwed => 'Tankhwah baqi';

  @override
  String get rentFromPay => 'Tankhwah se kata';

  @override
  String get deductionLimit => 'Katoti ki hadd (%, agar ho)';

  @override
  String get deductionLimitHelp =>
      'Kamai ka hissa. Accountant se poochh kar likhein. Khaali ho to koi hadd nahin.';

  @override
  String get deductionLimitError => '1 se 100 tak poora number likhein.';

  @override
  String payrollPost(int count) {
    return 'Tankhwah post karein ($count)';
  }

  @override
  String payrollPostTitle(String month) {
    return '$month ki tankhwah post karein?';
  }

  @override
  String payrollPostBody(int count, String amount) {
    return '$count mazdoor, $amount un ke hisaab mein jayega. Is ke baad rakam nahin badlegi. Galti ho to us mazdoor par wapas karein.';
  }

  @override
  String payrollPosted(int count) {
    return '$count mazdoor ki tankhwah post ho gayi';
  }

  @override
  String payrollSplit(String earned, String cut) {
    return 'Kamai $earned, katoti $cut';
  }

  @override
  String get applyRoomCharges => 'Room charge lagayein';

  @override
  String roomChargesApplied(int count) {
    return '$count mazdoor par room charge lag gaya';
  }

  @override
  String get payKindRoom => 'Room charge';

  @override
  String get mainAttendance => 'Hazri';

  @override
  String get mainVisa => 'Visa';

  @override
  String get mainMoney => 'Hisaab';

  @override
  String get tabVisa => 'Visa ka paisa';

  @override
  String get groupSoon => 'Jald aa raha hai';

  @override
  String get regAttendance => 'Hazri register';

  @override
  String get regWorkers => 'Mazdoor register';

  @override
  String get regVisa => 'Visa register';

  @override
  String get regCompanies => 'Company register';

  @override
  String get regPayroll => 'Tankhwah register';

  @override
  String get regAdvance => 'Advance register';

  @override
  String get regCash => 'Hisaab register';

  @override
  String get regRooms => 'Room register';

  @override
  String get kindVisaPaid => 'Visa ka kharcha';

  @override
  String get kindVisaReturned => 'Visa ka paisa wapas mila';

  @override
  String get visaTooHigh => 'Yeh baqi visa ke paise se zyada hai.';

  @override
  String get visaUndoBlocked =>
      'Yeh wapas nahin ho sakta: is visa ka kuch paisa wapas aa chuka hai.';

  @override
  String visaBalance(String amount) {
    return 'Visa baqi: $amount';
  }

  @override
  String get visaSpent => 'Kharcha';

  @override
  String get visaBack => 'Wapas aaya';

  @override
  String get visaLeft => 'Visa baqi';

  @override
  String get visaAdd => 'Visa kharcha likhein';

  @override
  String get visaEmpty =>
      'Abhi visa ka koi hisaab nahin. Mazdoor par jo kharcha hua woh likhein.';

  @override
  String visaSplit(String spent, String back) {
    return 'Kharcha $spent, wapas $back';
  }

  @override
  String get visaInstalment => 'Har mahine ki qist';

  @override
  String get visaInstalmentOff => 'Band hai';

  @override
  String get visaInstalmentHelp =>
      'Tankhwah mein button dabane par yeh rakam katti hai. Khali chhorein to band.';

  @override
  String visaInstalmentShort(String amount) {
    return 'Qist $amount mahina';
  }

  @override
  String get visaReturnAdd => 'Wapas mila likhein';

  @override
  String get payKindVisa => 'Visa ki qist';

  @override
  String get salaryMonthsHeading => 'Kis mahine ki tankhwah';

  @override
  String salaryMonthLeft(String amount) {
    return '$amount baqi';
  }

  @override
  String get salaryOldestFirst => 'Purana pehle';

  @override
  String get salaryNothingOwed =>
      'Is mazdoor ki koi tankhwah baqi nahin. Yeh raqam advance mein jayegi.';

  @override
  String salaryExtraLine(String amount) {
    return '$amount baqi se zyada hai. Yeh advance mein jayega.';
  }

  @override
  String salaryExtraTitle(String amount) {
    return '$amount baqi se zyada hai';
  }

  @override
  String get salaryExtraBody =>
      'Yeh zyada raqam is mazdoor ke advance mein likhi jayegi, aur baad ki tankhwah se wapas ayegi.';

  @override
  String get salaryExtraConfirm => 'Advance mein likhein';

  @override
  String get salaryExtraNote => 'Tankhwah se zyada diya';

  @override
  String get salaryPartsTooMuch => 'Mahinon ka jor raqam se zyada hai.';

  @override
  String get salaryPartTooHigh => 'Baqi se zyada hai';

  @override
  String get salaryReference => 'Reference (bank ya cheque)';

  @override
  String get salaryReceiver => 'Kis ne liya';

  @override
  String get salaryReceiverHelp => 'Mazdoor ne khud liya ho to khaali rakhein.';

  @override
  String wagesDueBanner(int count, String amount) {
    return '$count mazdoor ki tankhwah baqi: $amount';
  }

  @override
  String wagesDueOldest(String month) {
    return 'Sab se purani: $month';
  }

  @override
  String get wagesDueTitle => 'Baqi tankhwah';

  @override
  String get wagesDueWorkers => 'Mazdoor';

  @override
  String get wagesDueTotal => 'Baqi';

  @override
  String wagesDueLate(int days) {
    return '$days din late';
  }

  @override
  String get wagesDueInTime => 'dena hai, abhi late nahin';

  @override
  String get wagesDueNone => 'Har guzre mahine ki tankhwah ada ho chuki hai.';

  @override
  String get wagesDueNote =>
      'Yeh sirf yaad-dehani hai. Der se di tankhwah likhne se woh qanooni nahin ho jati, aur yeh app tankhwah bhejne ya WPS ki service nahin.';

  @override
  String get wageDueDays => 'Mahine ke baad tankhwah kitne din mein';

  @override
  String get wageDueDaysHelp =>
      'Aap ka apna number, accountant se poochh lein. Khaali ho to mahina khatam hote hi late.';

  @override
  String get wageDueDaysError => '0 se 90 tak poora number likhein.';

  @override
  String applyAdvanceCuts(int count) {
    return 'Advance katein ($count)';
  }

  @override
  String advanceCutsApplied(int count) {
    return '$count mazdoor ka advance kat gaya';
  }

  @override
  String get tabClosing => 'Mahina band';

  @override
  String get closingWorkersLeft => 'Mazdooron ka baqi';

  @override
  String get closingState => 'Yeh mahina';

  @override
  String get closingOpen => 'Khula hai';

  @override
  String get closingClosed => 'Band hai';

  @override
  String get closingNotOver =>
      'Yeh mahina abhi khatam nahin hua, is liye band nahin ho sakta.';

  @override
  String get closingIsClosed =>
      'Yeh mahina band hai. Ab farq khule mahine mein allowance, katoti ya wapsi se likha jata hai.';

  @override
  String closingLeft(int count) {
    return '$count cheezain baqi hain. Sab saaf hone par hi mahina band hoga.';
  }

  @override
  String get closingUnpaidNote =>
      'Baqi tankhwah mahina nahin rokti. Woh agle mahine mein chali jati hai.';

  @override
  String closeBlocked(int count) {
    return 'Pehle $count cheezain saaf karein';
  }

  @override
  String get closingEnterHazri => 'Is tareekh ki hazri lagayein';

  @override
  String get closingDayOff => 'Baqi sab ka kaam nahin tha';

  @override
  String get closingDayOffHelp =>
      'Jin ne kaam kiya un ki hazri lagayein. Phir baqi ke liye yeh button dabayein, aur yeh tareekh saaf ho jayegi.';

  @override
  String get closingDayOffDone => 'Likh diya. Yeh tareekh saaf hai.';

  @override
  String get closingPostReady => 'Jo tayyar hain un ki tankhwah post karein';

  @override
  String get closingPostHelp =>
      'Jo post nahin ho sakti woh yahin rahegi. Naam kholein to wajah dikhegi.';

  @override
  String get closingSettle => 'Sab se purane mahine mein likh dein';

  @override
  String get closingSettleHelp =>
      'Hisaab wahi rahega. Sirf mahine likhe jayenge.';

  @override
  String get closingSettled => 'Mahine likh diye';

  @override
  String get closingAllClear =>
      'Kuch theek karne ko nahin. Yeh mahina band ho sakta hai.';

  @override
  String get closingSummary => 'Is mahine mazdooron ka hisaab';

  @override
  String get closingCuts => 'Room, visa aur katoti';

  @override
  String get closingExpenses => 'Kharche';

  @override
  String findingNoWorkerRate(int count, String names) {
    return '$count mazdoor ki hazri par tankhwah ka rate nahin: $names. Rate likhein ya hazri hatayein.';
  }

  @override
  String findingNotPosted(int count, String names) {
    return '$count mazdoor ki tankhwah post nahin hui: $names. Tankhwah mein post karein.';
  }

  @override
  String findingNoCompanyRate(int count, String names) {
    return '$count company ka rate nahin: $names. Rate likhein.';
  }

  @override
  String findingNoHazri(int count, String names) {
    return '$count mazdoor ki hazri nahin: $names.';
  }

  @override
  String findingOverlap(int count, String names) {
    return '$count mazdoor ki hazri waqt mein takrati hai: $names.';
  }

  @override
  String findingNoMonth(int count, String names) {
    return '$count adaigi mein mahina nahin likha: $names.';
  }

  @override
  String closeButton(String month) {
    return '$month band karein';
  }

  @override
  String closeTitle(String month) {
    return '$month band karein?';
  }

  @override
  String get closeBody =>
      'Is mahine tak ki hazri, kharche aur tankhwah ab nahin badlenge. Baad ka farq khule mahine mein allowance, katoti ya wapsi se likha jayega.';

  @override
  String get closeConfirm => 'Band karein';

  @override
  String closeDone(String month) {
    return '$month band ho gaya';
  }

  @override
  String get closeNotReady =>
      'Yeh mahina abhi band nahin ho sakta. Pehle likhi hui baatein theek karein.';

  @override
  String get reopenButton => 'Yeh mahina dobara kholein';

  @override
  String reopenTitle(String month) {
    return '$month dobara kholein';
  }

  @override
  String get reopenHelp => 'Kyun badalna hai. Yeh wajah record mein rahegi.';

  @override
  String get reopenConfirm => 'Kholein';

  @override
  String reopenDone(String month) {
    return '$month dobara khul gaya';
  }

  @override
  String get reopenLater => 'Pehle baad wala mahina kholein.';

  @override
  String get periodLockedError =>
      'Yeh mahina band hai. Farq khule mahine mein allowance ya katoti se likhein, ya Mahina band se mahina dobara kholein.';

  @override
  String get closedNote => 'Yeh mahina band hai. Yahan kuch nahin badlega.';

  @override
  String get reverseHelpClosed =>
      'Yeh mahina band hai, is liye wapsi aaj ki tareekh par likhi jayegi aur band mahina waisa hi rahega.';

  @override
  String get issueClosed => 'Yeh mahina band hai.';

  @override
  String applyVisaInstalments(int count) {
    return 'Visa qist lagayein ($count)';
  }

  @override
  String visaInstalmentsApplied(int count) {
    return '$count mazdoor par visa qist lag gayi';
  }

  @override
  String get issueVisa => 'Visa ki wapsi baqi rakam se zyada hai.';

  @override
  String regRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get regAllDates => 'Sab tareekhein';

  @override
  String get regThisMonth => 'Is mahine';

  @override
  String get regLastMonth => 'Pichla mahina';

  @override
  String get regAll => 'Sab';

  @override
  String get regClear => 'Saaf karein';

  @override
  String get regExport => 'PDF, Excel ya WhatsApp';

  @override
  String get regEmpty => 'In tareekhon aur filter mein kuch nahin.';

  @override
  String get regTotal => 'Total';

  @override
  String regPage(String page, String pages) {
    return 'Safha $page / $pages';
  }

  @override
  String regMade(String when) {
    return 'Banaya: $when';
  }

  @override
  String regFilterDates(String range) {
    return 'Tareekh: $range';
  }

  @override
  String get regAmountsNote => 'Sab raqam AED mein';

  @override
  String get regCompanyNote =>
      'Yahan mazdoori woh hai jo hazri par bani. Mahana tankhwah is mein shamil nahin.';

  @override
  String get regPayrollNote => 'Sirf post hui tankhwah.';

  @override
  String get exportMaking => 'File ban rahi hai...';

  @override
  String get exportView => 'Dekhein ya print';

  @override
  String get exportOpen => 'Kholein';

  @override
  String get exportSave => 'Phone mein save';

  @override
  String get exportWhatsApp => 'WhatsApp';

  @override
  String get exportOther => 'Aur apps';

  @override
  String get exportNoWhatsApp => 'WhatsApp nahin mila. Koi aur app chunein.';

  @override
  String get exportNoApp =>
      'Is phone par yeh file kholne wali koi app nahin. Aur apps se bhej dein.';

  @override
  String get exportSaved => 'Phone mein save ho gaya.';

  @override
  String get exportFailed => 'File nahin bani. Dobara koshish karein.';

  @override
  String get filterStatus => 'Hazri';

  @override
  String get filterState => 'Haalat';

  @override
  String get filterKind => 'Kis cheez ka';

  @override
  String get filterMethod => 'Cash ya bank';

  @override
  String get filterTrade => 'Kaam';

  @override
  String get filterActive => 'Status';

  @override
  String get filterOwed => 'Baqi';

  @override
  String get stateActive => 'Active';

  @override
  String get stateArchived => 'Archived';

  @override
  String get owedYes => 'Baqi hai';

  @override
  String get owedNo => 'Saaf hai';

  @override
  String get colDate => 'Tareekh';

  @override
  String get colMonth => 'Mahina';

  @override
  String get colWorker => 'Mazdoor';

  @override
  String get colCode => 'Code';

  @override
  String get colCompany => 'Company';

  @override
  String get colSite => 'Site';

  @override
  String get colGroup => 'Group';

  @override
  String get colIn => 'Aaya';

  @override
  String get colOut => 'Gaya';

  @override
  String get colBreak => 'Break';

  @override
  String get colCompanyHours => 'Company ghante';

  @override
  String get colWorkerHours => 'Mazdoor ghante';

  @override
  String get colOvertime => 'Overtime';

  @override
  String get colCompanyRate => 'Company rate';

  @override
  String get colBill => 'Company bill';

  @override
  String get colWorkerRate => 'Mazdoor rate';

  @override
  String get colPay => 'Mazdoor pay';

  @override
  String get colWhat => 'Kya';

  @override
  String get colWho => 'Kis ka';

  @override
  String get colGiven => 'Diya';

  @override
  String get colBack => 'Wapas';

  @override
  String get colLeft => 'Baqi';

  @override
  String get colPhone => 'Phone';

  @override
  String get colJoined => 'Joining';

  @override
  String get colRoom => 'Room';

  @override
  String get colRate => 'Rate';

  @override
  String get colWorkers => 'Mazdoor';

  @override
  String get colHours => 'Ghante';

  @override
  String get colWages => 'Mazdoori';

  @override
  String get colDifference => 'Farq';

  @override
  String get colPostedOn => 'Post ki';

  @override
  String get settingsColour => 'App ke rang';

  @override
  String get paletteBlue => 'Neela';

  @override
  String get paletteGreen => 'Sabz';

  @override
  String get paletteMaroon => 'Maroon';

  @override
  String issueMissingRate(int count) {
    return '$count hazri ka mazdoor rate nahin. Rates mein likhein.';
  }

  @override
  String get noClientRateNote =>
      'Company ka rate abhi nahin. Mazdoor ki tankhwah phir bhi ginti hai, bill rate likhne par banega.';

  @override
  String roomChargeTitle(String month) {
    return 'Room charge, $month';
  }

  @override
  String get roomChargeAll => 'Sab ke liye aik raqam (AED)';

  @override
  String get roomChargeAllHelp =>
      'Jis ki apni raqam khali ho us par yeh lagegi.';

  @override
  String roomChargeSave(int count) {
    return '$count mazdoor par lagayein';
  }

  @override
  String roomChargeNeedAmount(String name) {
    return '$name ki raqam likhein';
  }

  @override
  String get roomChargeNone =>
      'Sab par is mahine ka room charge lag chuka hai, ya un ka mahina post ho chuka hai.';

  @override
  String get roomChargeByOwner => 'Malik ne lagaya';

  @override
  String get issueNoRate => 'Rate nahin';

  @override
  String get colEarned => 'Kamai';

  @override
  String get colPaid => 'Adaigi';

  @override
  String get colNoRate => 'Company rate nahin';

  @override
  String get colDays => 'Din';

  @override
  String get regBrought => 'Pichla baqi';

  @override
  String get regWorkerNote =>
      'Baqi = kamai - advance - katoti, room aur visa ki qist - adaigi. Mahana tankhwah mahina post hone par aati hai.';

  @override
  String get regAttendanceNote =>
      'Farq = company bill - mazdoor pay, jin rows mein dono hon. Mahana tankhwah mazdoor pay mein nahin.';

  @override
  String regOwedToWorker(String amount) {
    return 'Baqi $amount: mazdoor ko dena hai';
  }

  @override
  String regOwedByWorker(String amount) {
    return 'Baqi $amount: mazdoor se lena hai';
  }

  @override
  String get regSettled => 'Baqi AED 0.00: hisaab barabar';

  @override
  String regOwedSplit(String pay, String advance) {
    return 'Tankhwah $pay, is mein se advance baqi $advance';
  }

  @override
  String regRecoveryRow(String amount) {
    return '$amount tankhwah se kata. Baqi mein yeh dete waqt hi ginaa gaya tha.';
  }

  @override
  String get regByWorker => 'Mazdoor ke hisaab se';

  @override
  String get regBySite => 'Company aur site ke hisaab se';

  @override
  String get regAllWorkers => 'Sab mazdoor';

  @override
  String get regSummarySheet => 'Khulasa';

  @override
  String get colBalance => 'Baqi';

  @override
  String rateIn(String name) {
    return 'Tankhwah: $name';
  }

  @override
  String ownRateHelp(String rate) {
    return 'Apni tankhwah $rate hai. Khaali chhorein to yahi lagegi.';
  }

  @override
  String rateSetHere(String rate) {
    return 'Is group mein: $rate';
  }

  @override
  String rateOwn(String rate) {
    return 'Apni tankhwah: $rate';
  }

  @override
  String rateFromGroup(String rate) {
    return 'Group ki dehari: $rate';
  }

  @override
  String get rateMissing =>
      'Tankhwah nahin. Yahan likhein, ya group ki dehari likhein.';

  @override
  String get rateChange => 'Badlein';

  @override
  String regVisaRow(String amount) {
    return 'Visa ke $amount. Baqi se tab kategi jab tankhwah se kategi.';
  }

  @override
  String regVisaLeft(String amount) {
    return 'Visa baqi $amount';
  }

  @override
  String get exportSlowPdf =>
      'Yeh PDF lambi hai, kuch minute lag sakte hain. Excel bohat jaldi banti hai.';

  @override
  String get exportTooLong =>
      'Aik file ke liye rows bohat zyada hain. Kam tareekhein chunein ya filter lagayein.';

  @override
  String get payrollAdvanceLeft => 'Advance jo abhi nahin kata';

  @override
  String get payrollAfterAdvance => 'Slip ka baqi, advance ke baad';

  @override
  String get slipTitle => 'Salary slip';

  @override
  String get slipSummary => 'Hisaab';

  @override
  String get slipOpening => 'Pichla baqi';

  @override
  String get slipWork => 'Is mahine ka kaam';

  @override
  String get slipAdvance => 'Advance liya';

  @override
  String get slipRoom => 'Room';

  @override
  String get slipVisa => 'Visa';

  @override
  String get slipOther => 'Doosri katoti';

  @override
  String get slipPaid => 'Ada kiya';

  @override
  String get slipOwedToYou => 'Baqi: aap ko milna hai';

  @override
  String get slipYouOwe => 'Baqi: aap se lena hai';

  @override
  String get slipSettled => 'Baqi';

  @override
  String get slipDays => 'Din ba din kaam';

  @override
  String get slipMoney => 'Jo paise liye';

  @override
  String get slipNoWork => 'Is mahine koi kaam nahin.';

  @override
  String get slipNoMoney => 'Is mahine koi paise nahin liye.';

  @override
  String slipDayCount(int days) {
    return '$days din';
  }

  @override
  String slipVisaLeft(String amount) {
    return 'Visa baqi $amount: aage tankhwah se katega.';
  }

  @override
  String get slipNote => 'Yeh slip sirf hisaab hai, adaigi ka saboot nahin.';

  @override
  String get ownerSheet => 'Malik ki sheet';

  @override
  String get sheetTitle => 'Malik ki tankhwah sheet';

  @override
  String get sheetSummary => 'Mahine ka khulasa';

  @override
  String get sheetBill => 'Company ka bill';

  @override
  String get sheetWages => 'Us kaam ki mazdoori';

  @override
  String get sheetSalaries => 'Mahana tankhwah, company par nahin bati';

  @override
  String get sheetAllowances => 'Allowance';

  @override
  String get sheetCuts => 'Tankhwah se doosri katoti';

  @override
  String get sheetRoomIn => 'Room se aaya, tankhwah aur cash';

  @override
  String get sheetRoomOut => 'Room ka kiraya diya';

  @override
  String get sheetExpenses => 'Doosre kharche';

  @override
  String get sheetEstimate => 'Andazan nafa';

  @override
  String get sheetByCompany => 'Company ke hisaab se';

  @override
  String get sheetDetail => 'Company wise';

  @override
  String get sheetWorkers => 'Mazdooron ka hisaab';

  @override
  String sheetCompanyHead(int workers, int sites) {
    return '$workers mazdoor, $sites site';
  }

  @override
  String get sheetNote =>
      'Yeh hazri se bana andaza hai, audit shuda hisaab nahin. Jis company ka rate nahin ya mahana hai, us ka bill yahan nahin aata, is liye us ka nafa kam dikhta hai. Advance aur visa kharcha nahin, mazdoor wapas dete hain.';

  @override
  String get colProfit => 'Nafa';

  @override
  String get colVisaLeft => 'Visa baqi';

  @override
  String get mainDocuments => 'Kaghazat';

  @override
  String get docsTab => 'Bane hue kaghaz';

  @override
  String get docsEmpty =>
      'Abhi koi kaghaz nahin bana. Salary slip ya raseed banane par yahan aa jayega.';

  @override
  String get docCopyOption => 'COPY likh kar dein';

  @override
  String get docCopyHelp =>
      'Number wahi rahega. Bina COPY ke woh file milti hai jo pehle di thi.';

  @override
  String get docCopyLabel => 'COPY';

  @override
  String get docPrint => 'Print';

  @override
  String get slipEarnings => 'Kamai';

  @override
  String get slipEarned => 'Kul kamai';

  @override
  String get slipDeductions => 'Katoti';

  @override
  String get slipDeducted => 'Kul katoti';

  @override
  String get slipAccount => 'Hisaab';

  @override
  String get slipNet => 'Is mahine ka net';

  @override
  String slipWorkBasis(int days, String hours) {
    return 'Kaam: $days din, $hours ghante';
  }

  @override
  String get receiptMake => 'Raseed banayein';

  @override
  String get receiptPaymentTitle => 'Tankhwah ki raseed';

  @override
  String get receiptAdvanceTitle => 'Advance ki raseed';

  @override
  String get receiptPayment => 'Tankhwah di';

  @override
  String get receiptAdvance => 'Advance diya';

  @override
  String get receiptMethod => 'Tareeqa';

  @override
  String get receiptReference => 'Reference';

  @override
  String get receiptReceiver => 'Kis ne liya';

  @override
  String receiptMonth(String month) {
    return '$month ki tankhwah';
  }

  @override
  String get receiptNote =>
      'Yeh raseed company ka apna record hai. Yeh bank adaigi ka saboot nahin.';

  @override
  String get receiptTakenBy => 'Lene wale ke dastakhat';

  @override
  String get receiptFromCompany => 'Company ki taraf se';

  @override
  String get lhTab => 'Letterhead';

  @override
  String get lhOld =>
      'Jo kaghaz ban chuke woh nahin badlenge. Yeh sirf naye kaghazon par lagega.';

  @override
  String get lhIdentity => 'Company ki pehchan';

  @override
  String get lhIdentityNote => 'Naam, pata, phone aur TRN yahan se aate hain.';

  @override
  String get lhPrinted => 'Company ka heading print karein';

  @override
  String get lhPrintedHelp =>
      'Band karein agar kaghaz par pehle se heading chhapi hai. Tab naam, logo aur footer print nahin honge.';

  @override
  String get lhBlankTop => 'Upar khali (mm)';

  @override
  String get lhBlankBottom => 'Neeche khali (mm)';

  @override
  String get lhBlankBad => '0 se 120 mm tak likhein.';

  @override
  String get lhLogo => 'Logo';

  @override
  String get lhHeader => 'Header ki tasveer';

  @override
  String get lhFooter => 'Footer ki tasveer';

  @override
  String get lhSignature => 'Dastakhat';

  @override
  String get lhStamp => 'Mohar';

  @override
  String get lhUpload => 'Tasveer chunein';

  @override
  String get lhChange => 'Badlein';

  @override
  String get lhRemove => 'Hatayein';

  @override
  String get lhSize => 'Chaurai';

  @override
  String get lhLeft => 'Baen';

  @override
  String get lhCenter => 'Beech';

  @override
  String get lhRight => 'Dayen';

  @override
  String get lhCrop => 'Kinare kaatein';

  @override
  String get lhCropTop => 'Upar';

  @override
  String get lhCropBottom => 'Neeche';

  @override
  String get lhCropLeft => 'Baen';

  @override
  String get lhCropRight => 'Dayen';

  @override
  String get lhShow => 'Kaghaz par dikhayein';

  @override
  String lhResolution(int width, int height) {
    return '$width x $height pixel';
  }

  @override
  String lhLowRes(int dpi) {
    return 'Print mein dhundli lagegi ($dpi DPI). Bari tasveer lagayein ya chaurai kam karein.';
  }

  @override
  String get lhBadType => 'Sirf PNG ya JPEG tasveer chalegi.';

  @override
  String get lhTooLarge => 'Tasveer 5 MB se bari hai.';

  @override
  String get lhSample => 'Namoona dekhein';

  @override
  String get mainBilling => 'Billing';

  @override
  String get tsTab => 'Timesheet';

  @override
  String get tsTitle => 'Timesheet';

  @override
  String get tsNew => 'Nayi timesheet';

  @override
  String get tsEmpty =>
      'Abhi koi timesheet nahin. Company aur tareekh chun kar banayein.';

  @override
  String get tsAllSites => 'Sab sites';

  @override
  String get tsFrom => 'Kab se';

  @override
  String get tsTo => 'Kab tak';

  @override
  String get tsBadDates => 'Aakhri tareekh pehli se pehle hai.';

  @override
  String tsWillHold(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Is par $count line aayengi',
      one: 'Is par 1 line aayegi',
    );
    return '$_temp0';
  }

  @override
  String get tsNothing => 'In tareekhon mein timesheet ke liye kuch nahin.';

  @override
  String tsLeftNoRate(int count) {
    return '$count line nahin aayin: company ka rate nahin. Rates mein likhein.';
  }

  @override
  String tsLeftNoWage(int count) {
    return '$count line nahin aayin: mazdoor ka rate nahin.';
  }

  @override
  String tsLeftOther(int count) {
    return '$count line nahin aayin: pehle se doosri timesheet par hain.';
  }

  @override
  String get tsCreate => 'Draft banayein';

  @override
  String get tsDraftNote =>
      'Draft hazri ke saath chalta hai, jab tak aap approve na karein.';

  @override
  String get tsStatusDraft => 'Draft';

  @override
  String get tsStatusApproved => 'Approve ho gayi';

  @override
  String get tsStatusShared => 'Company ko bheji';

  @override
  String get tsStatusAccepted => 'Company ne maan li, band';

  @override
  String get tsStatusDisputed => 'Company ko etiraz';

  @override
  String get tsNoteApproved =>
      'Kaghaz bana kar bhejein. Phir yahan batayein ke bhej diya.';

  @override
  String get tsNoteShared =>
      'Company ke jawab ka intezar. Is se tankhwah nahin rukti.';

  @override
  String get tsNoteDisputed =>
      'Company se ghante dekh lein. Mazdoor ki tankhwah wahi rahegi, jab tak aap hazri na badlein.';

  @override
  String tsRevisionLabel(int number) {
    return 'Revision $number';
  }

  @override
  String get tsViewDaily => 'Rozana summary';

  @override
  String get tsViewWorkers => 'Har mazdoor';

  @override
  String get tsPricedLabel => 'rate ke saath';

  @override
  String get tsHoursOnlyLabel => 'sirf ghante';

  @override
  String get tsUniqueWorkers => 'Alag alag mazdoor';

  @override
  String get tsWorkerDays => 'Mazdoor din';

  @override
  String get tsShiftsWorked => 'Kul shifts';

  @override
  String get tsHoursBilled => 'Bill ke ghante';

  @override
  String get tsDaysBilled => 'Bill ke din';

  @override
  String get tsShiftsBilled => 'Bill ki shifts';

  @override
  String get tsAmount => 'Raqam';

  @override
  String get tsTotalAmount => 'Timesheet ka total';

  @override
  String get colPersons => 'Log';

  @override
  String get colShifts => 'Shifts';

  @override
  String get colClock => 'Kul ghante';

  @override
  String get colTrade => 'Kaam';

  @override
  String get colBillable => 'Bill';

  @override
  String tsHoursValue(String hours) {
    return '$hours ghante';
  }

  @override
  String tsDaysValue(String days) {
    return '$days din';
  }

  @override
  String tsShiftsValue(String shifts) {
    return '$shifts shift';
  }

  @override
  String get tsMonthlyRow => 'Mahana';

  @override
  String get tsNotCharged => 'Bill nahin';

  @override
  String tsMonthlyLine(
    String basis,
    String rate,
    String from,
    String to,
    int count,
  ) {
    return '$basis, $rate: $from se $to tak, $count log. Fee invoice par aik dafa lagti hai, in lines se nahin.';
  }

  @override
  String tsMonthlyLinePlain(String basis, String from, String to, int count) {
    return '$basis: $from se $to tak, $count log.';
  }

  @override
  String get tsAgreedHeading => 'Company ke saath tay';

  @override
  String tsRevisedBecause(String reason) {
    return 'Revision ki wajah: $reason';
  }

  @override
  String get tsNotInvoice => 'Yeh timesheet hai, invoice nahin.';

  @override
  String tsClientSign(String client) {
    return '$client ki tasdeeq';
  }

  @override
  String get tsApprove => 'Approve karein';

  @override
  String get tsApproveBody =>
      'Is ki hazri pakki ho jayegi aur number mil jayega. Baad ka farq nayi revision mein aayega.';

  @override
  String get tsDeleteDraft => 'Draft hata dein';

  @override
  String get tsPaper => 'Kaghaz banayein';

  @override
  String get tsPaperPriced => 'Rate aur raqam dikhayein';

  @override
  String get tsPaperPricedHelp =>
      'Band ho to company ko sirf ghante dikhenge. Mazdoor ki tankhwah kabhi nahin chhapti.';

  @override
  String get tsContinue => 'Aage';

  @override
  String get tsShared => 'Company ko bhej diya';

  @override
  String get tsAccepted => 'Company ne maan li';

  @override
  String get tsDisputed => 'Company ko etiraz hai';

  @override
  String get tsRespondDate => 'Kis tareekh';

  @override
  String get tsRespondNote => 'Company ne kya kaha (zaroori nahin)';

  @override
  String get tsEvidence => 'Tasveer lagayein (zaroori nahin)';

  @override
  String get tsEvidenceAdded => 'Tasveer lag gayi';

  @override
  String get tsEvidenceNote =>
      'Company ke jawab ki tasveer. Yeh tasdeeq shuda digital signature nahin.';

  @override
  String get tsNewRevision => 'Nayi revision';

  @override
  String get tsRevisionHelp => 'Purani bilkul waisi rahegi. Kya badla?';

  @override
  String get tsRevisionConfirm => 'Shuru karein';

  @override
  String tsChanged(int count) {
    return 'Is ke baad $count line ki hazri badli. Nayi revision mein aayengi.';
  }

  @override
  String tsBillingChanged(int count, String amount) {
    return '$count line invoice se mukhtalif hain, farq $amount. Invoice khud nahin badla.';
  }

  @override
  String get tsRevisionsHeading => 'Revisions';

  @override
  String get tsOldRevisionNote =>
      'Yeh purani revision hai, bilkul waisi mehfooz.';

  @override
  String get tsAdjustTitle => 'Company se kya tay hua';

  @override
  String get tsAdjustHelp =>
      'Is se sirf company ka kaghaz badlega. Hazri aur mazdoor ki tankhwah wahi rahegi.';

  @override
  String get tsAdjustHours => 'Bill ke ghante';

  @override
  String get tsAdjustMinutes => 'Minute';

  @override
  String get tsAdjustAmount => 'Raqam (AED)';

  @override
  String get tsAdjustReason => 'Wajah';

  @override
  String get tsAdjustClear => 'Hazri wala figure wapas';

  @override
  String get tsAdjustSave => 'Save karein';

  @override
  String get tsNotTaken => 'Bill nahin';

  @override
  String tsAgreedRow(String reason) {
    return 'Tay hua: $reason';
  }

  @override
  String get tsWrongStep => 'Yeh pehle hi aage barh chuka. Dobara dekhein.';

  @override
  String get tsBasisOnly => 'Mahana line ki apni raqam nahin hoti.';

  @override
  String tsPeople(int count) {
    return '$count log';
  }
}
