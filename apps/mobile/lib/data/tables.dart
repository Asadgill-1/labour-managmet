// Drift's check() refers to the column through its own getter.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Columns on every operational table (MODEL-03).
mixin Common on Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  TextColumn get actorId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get sourceOperationId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class TenantProfiles extends Table with Common {
  TextColumn get legalName => text()();
  TextColumn get tradingName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get vatRegistered => boolean().withDefault(const Constant(false))();
  TextColumn get vatEffectiveFrom => text().nullable()();
  TextColumn get trn => text().nullable()();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  IntColumn get paymentTermsDays => integer().nullable()();
  TextColumn get bankDetails => text().nullable()();
  TextColumn get documentFooter => text().nullable()();

  /// The company's own limit on deductions, as a share of earnings. Null means none. Never a built-in legal figure (PAY-07).
  IntColumn get deductionLimitBps => integer().nullable()();
}

class Clients extends Table with Common {
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  BoolColumn get vatRegistered => boolean().withDefault(const Constant(false))();
  TextColumn get trn => text().nullable()();
  TextColumn get invoiceAddress => text().nullable()();
  IntColumn get dueDays => integer().nullable()();
  TextColumn get poReference => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class Sites extends Table with Common {
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  TextColumn get contact => text().nullable()();
  TextColumn get activeFrom => text().nullable()();
  TextColumn get activeTo => text().nullable()();

  /// Default shift as minutes from local midnight. End below start means next day.
  IntColumn get defaultStartMinute => integer().nullable()();
  IntColumn get defaultEndMinute => integer().nullable()();
  IntColumn get defaultBreakMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class Workers extends Table with Common {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get trade => text().nullable()();
  TextColumn get joiningDate => text().nullable()();
  IntColumn get roomChargeFils => integer().nullable()();
  TextColumn get roomChargeNote => text().nullable()();
  TextColumn get roomId => text().nullable().references(Rooms, #id)();

  /// Taken from pay each month while visa money is left. Null means off (D-039).
  IntColumn get visaInstalmentFils => integer().nullable().check(visaInstalmentFils.isBiggerThanValue(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {tenantId, code},
  ];
}

/// A room the company rents for its workers (D-031).
class Rooms extends Table with Common {
  TextColumn get name => text()();
  TextColumn get note => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

/// Every amount in or out, one row each (D-030). Rows never change: a mistake gets a reversal row, so
/// balances always come from the rows themselves (REP-08). Triggers enforce this.
@TableIndex(name: 'idx_cash_date', columns: {#entryDate})
@TableIndex(name: 'idx_cash_worker', columns: {#workerId})
@TableIndex(name: 'idx_cash_room', columns: {#roomId})
class CashEntries extends Table with Common {
  TextColumn get entryDate => text()();

  /// A `CashKind` by name.
  TextColumn get kind => text()();
  IntColumn get amountFils => integer().check(amountFils.isBiggerThanValue(0))();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
  TextColumn get workerId => text().nullable().references(Workers, #id)();
  TextColumn get roomId => text().nullable().references(Rooms, #id)();
  TextColumn get clientId => text().nullable().references(Clients, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();
  TextColumn get category => text().nullable()();

  /// 'cash' or 'bank'.
  TextColumn get method => text().withDefault(const Constant('cash'))();
  TextColumn get note => text().nullable()();

  /// Set on a reversal, which carries the original's figures. Unique, so nothing is reversed twice.
  TextColumn get reversesEntryId => text().nullable().unique().references(CashEntries, #id)();

  @override
  List<String> get customConstraints => [
    "CHECK (kind NOT IN ('advanceGiven', 'salaryPaid', 'advanceReturned') OR worker_id IS NOT NULL)",
    "CHECK (kind NOT IN ('roomRentPaid', 'roomRentReceived') OR room_id IS NOT NULL)",
    "CHECK (kind <> 'clientReceipt' OR client_id IS NOT NULL)",
  ];
}

/// Rate terms shared by both contract tables (MASTER-06). Dates are YYYY-MM-DD.
mixin RateTerms on Table {
  TextColumn get basis => text()();
  IntColumn get rateFils => integer().check(rateFils.isBiggerOrEqualValue(0))();
  TextColumn get effectiveFrom => text()();
  TextColumn get effectiveTo => text().nullable()();
  BoolColumn get breakPaid => boolean().withDefault(const Constant(false))();
  IntColumn get halfAmountFils => integer().nullable()();
  IntColumn get includedMinutes => integer().nullable()();
  IntColumn get overtimeRateFils => integer().nullable()();
}

/// What a worker is paid. A set `siteId` is the assignment-level rate that beats the general one (CALC-06).
class PayContracts extends Table with Common, RateTerms {
  TextColumn get workerId => text().references(Workers, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();

  /// Monthly basis only: a `PartialMethod` by name. No default on purpose (D-102).
  TextColumn get partialMethod => text().nullable()();
  IntColumn get partialDivisor => integer().nullable()();
}

/// What a client is charged. A set `siteId` or `workerId` beats the general rate (CALC-06).
class BillingContracts extends Table with Common, RateTerms {
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();
  TextColumn get workerId => text().nullable().references(Workers, #id)();
}

/// Migration figures with source and owner confirmation (MASTER-05). Never a wage expense.
class OpeningBalances extends Table with Common {
  /// 'worker_salary_owed', 'worker_advance' or 'client_receivable'.
  TextColumn get kind => text()();
  TextColumn get workerId => text().nullable().references(Workers, #id)();
  TextColumn get clientId => text().nullable().references(Clients, #id)();
  IntColumn get amountFils => integer().check(amountFils.isBiggerOrEqualValue(0))();
  TextColumn get asOfDate => text()();
  TextColumn get sourceNote => text()();

  @override
  List<String> get customConstraints => ['CHECK ((worker_id IS NULL) <> (client_id IS NULL))'];

  @override
  List<Set<Column>> get uniqueKeys => [
    {kind, workerId},
    {kind, clientId},
  ];
}

/// A team that usually works together (D-029). Everything but the name is optional.
class WorkerGroups extends Table with Common {
  TextColumn get name => text()();
  TextColumn get clientId => text().nullable().references(Clients, #id)();
  TextColumn get siteId => text().nullable().references(Sites, #id)();

  /// Pay per day for everyone in the group, unless a member has their own.
  IntColumn get dailyRateFils => integer().nullable().check(dailyRateFils.isBiggerOrEqualValue(0))();
  BoolColumn get halfDayIsHalf => boolean().withDefault(const Constant(true))();

  /// Usual duty as minutes from local midnight. End below start means next day.
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();
  IntColumn get breakMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
}

class WorkerGroupMembers extends Table with Common {
  TextColumn get groupId => text().references(WorkerGroups, #id)();
  TextColumn get workerId => text().references(Workers, #id)();

  /// Null means the group's daily wage.
  IntColumn get dailyRateFils => integer().nullable().check(dailyRateFils.isBiggerOrEqualValue(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {groupId, workerId},
  ];
}

@DataClassName('AttendanceBatch')
class AttendanceBatches extends Table with Common {
  TextColumn get workDate => text()();
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get siteId => text().references(Sites, #id)();
  TextColumn get groupId => text().nullable().references(WorkerGroups, #id)();
  TextColumn get note => text().nullable()();
}

@TableIndex(name: 'idx_entries_worker_date', columns: {#workerId, #workDate})
@TableIndex(name: 'idx_entries_date', columns: {#workDate})
class AttendanceEntries extends Table with Common {
  TextColumn get batchId => text().references(AttendanceBatches, #id)();
  TextColumn get workerId => text().references(Workers, #id)();
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get siteId => text().references(Sites, #id)();

  /// Set when marked through a group, so the row can be priced again until it is approved (D-026, D-029).
  TextColumn get groupId => text().nullable().references(WorkerGroups, #id)();
  TextColumn get workDate => text()();

  /// Null for an absent row.
  DateTimeColumn get startUtc => dateTime().nullable()();
  DateTimeColumn get endUtc => dateTime().nullable()();
  IntColumn get clockMinutes => integer().check(clockMinutes.isBiggerOrEqualValue(0))();
  IntColumn get breakMinutes => integer().check(breakMinutes.isBiggerOrEqualValue(0))();
  BoolColumn get breakPaidClient => boolean()();
  BoolColumn get breakPaidWorker => boolean()();
  IntColumn get clientBillableMinutes => integer()();
  IntColumn get workerPayableMinutes => integer()();
  IntColumn get overtimeMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get overtimeApproved => boolean().withDefault(const Constant(false))();

  /// 'present', 'half' or 'absent'.
  TextColumn get attendanceStatus => text()();

  /// 'draft', 'submitted', 'approved' or 'linked' (ATT-07). Client acknowledgement is separate.
  TextColumn get state => text().withDefault(const Constant('draft'))();
  TextColumn get clientAck => text().withDefault(const Constant('none'))();

  /// Rate snapshot. Null means no rate was found: the row cannot be approved (CALC-06).
  TextColumn get clientBasis => text().nullable()();
  IntColumn get clientRateFils => integer().nullable()();
  IntColumn get clientAmountFils => integer().nullable()();
  TextColumn get workerBasis => text().nullable()();
  IntColumn get workerRateFils => integer().nullable()();
  IntColumn get workerAmountFils => integer().nullable()();

  /// Kept apart from the snapshot, so approving a row can re-price it without losing the override.
  IntColumn get clientRateOverrideFils => integer().nullable()();
  IntColumn get workerRateOverrideFils => integer().nullable()();
  TextColumn get overrideReason => text().nullable()();
  TextColumn get overlapReason => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Set on a correction. The original row stays untouched (ATT-08).
  TextColumn get revisesEntryId => text().nullable().references(AttendanceEntries, #id)();
  BoolColumn get superseded => boolean().withDefault(const Constant(false))();

  /// The posted payroll that paid this row (ATT-07, MODEL-07). Null means not paid yet.
  TextColumn get payrollLineId => text().nullable().references(PayrollLines, #id)();

  @override
  List<String> get customConstraints => ['CHECK (break_minutes <= clock_minutes)'];
}

/// One posting: the owner approved these workers' figures for this period (PAY-01).
class PayrollRuns extends Table with Common {
  TextColumn get periodFrom => text()();
  TextColumn get periodTo => text()();
  TextColumn get postingDate => text()();
  TextColumn get currency => text().withDefault(const Constant('AED'))();
}

/// One worker's posted month. Its figures never change. A wrong posting is flagged [reversed], which puts the
/// work and items back to unpaid, and the month can post again (PAY-01, REP-08). Triggers enforce this.
/// Paid and closing are not stored, because they grow with later payments and always derive (REP-08).
@TableIndex(name: 'idx_payroll_lines_worker', columns: {#workerId})
class PayrollLines extends Table with Common {
  TextColumn get runId => text().references(PayrollRuns, #id)();
  TextColumn get workerId => text().references(Workers, #id)();
  TextColumn get periodFrom => text()();

  /// Owed before this month. Below zero means paid in advance of it.
  IntColumn get openingFils => integer()();
  IntColumn get earnedFils => integer()();
  IntColumn get salaryFils => integer()();
  IntColumn get adjustmentFils => integer()();
  IntColumn get allowancesFils => integer()();
  IntColumn get deductionsFils => integer()();
  IntColumn get recoveryFils => integer()();
  IntColumn get visaRecoveryFils => integer().withDefault(const Constant(0))();
  IntColumn get netFils => integer()();
  IntColumn get payableFils => integer()();

  /// All salary paid to this worker before this posting. Payments after it are this line's "paid".
  IntColumn get paidBeforeFils => integer()();
  BoolColumn get reversed => boolean().withDefault(const Constant(false))();
}

/// An allowance or deduction for one worker's month. Free to change until posted (PAY-01).
@TableIndex(name: 'idx_payroll_items_period', columns: {#periodFrom})
class PayrollItems extends Table with Common {
  TextColumn get workerId => text().references(Workers, #id)();
  TextColumn get periodFrom => text()();

  /// A `PayItemKind` by name.
  TextColumn get kind => text()();
  IntColumn get amountFils => integer().check(amountFils.isBiggerThanValue(0))();
  TextColumn get reason => text()();

  /// Who agreed to this deduction, or the paper it rests on (PAY-07).
  TextColumn get authorizedBy => text().nullable()();
  TextColumn get note => text().nullable()();

  /// A room charge counts as rent received for this room once posted (D-031).
  TextColumn get roomId => text().nullable().references(Rooms, #id)();
  TextColumn get lineId => text().nullable().references(PayrollLines, #id)();

  @override
  List<String> get customConstraints => ["CHECK (kind NOT IN ('deduction', 'roomCharge') OR authorized_by IS NOT NULL)"];
}

@DataClassName('AuditEvent')
class AuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  DateTimeColumn get atUtc => dateTime()();
  TextColumn get actorId => text()();
  TextColumn get action => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  IntColumn get recordVersion => integer()();
  TextColumn get operationId => text()();
  TextColumn get reason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per mutation, written with the change itself (TEAM-04). The primary key is the
/// idempotency key, so a retried operation can never apply twice.
@DataClassName('OutboxEntry')
class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get tenantId => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  IntColumn get recordVersion => integer()();
  TextColumn get deviceId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get ackedAtUtc => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}
