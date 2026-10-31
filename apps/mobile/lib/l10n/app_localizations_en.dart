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
      'Optional. Shows beside every worker. Tap an amount there to change it.';

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
  String issueUnapproved(int count) {
    return '$count attendance rows not approved yet.';
  }

  @override
  String applyRoomCharges(int count) {
    return 'Add room charge ($count)';
  }

  @override
  String roomChargesApplied(int count) {
    return 'Room charge added for $count workers';
  }

  @override
  String roomChargesPartly(int added, int left) {
    return 'Room charge added for $added workers. $left left: write the room charge note on their screen.';
  }

  @override
  String get payKindRoom => 'Room charge';

  @override
  String approveMissingRate(int approved, int left) {
    return '$approved approved. $left have no rate: add it under Rates, then approve again.';
  }

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
  String get colPending => 'Not approved';

  @override
  String get colPostedOn => 'Posted on';
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
      'Zaroori nahin. Har mazdoor ke saamne aa jayegi. Badalne ke liye wahan raqam par dabayein.';

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
  String issueUnapproved(int count) {
    return '$count hazri abhi manzoor nahin.';
  }

  @override
  String applyRoomCharges(int count) {
    return 'Room charge lagayein ($count)';
  }

  @override
  String roomChargesApplied(int count) {
    return '$count mazdoor par room charge lag gaya';
  }

  @override
  String roomChargesPartly(int added, int left) {
    return '$added mazdoor par room charge lag gaya. $left reh gaye: un ki screen par room charge ka note likhein.';
  }

  @override
  String get payKindRoom => 'Room charge';

  @override
  String approveMissingRate(int approved, int left) {
    return '$approved manzoor. $left ka rate nahin: Rates mein likh kar dobara manzoor karein.';
  }

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
  String get colPending => 'Manzoor baqi';

  @override
  String get colPostedOn => 'Post ki';
}
