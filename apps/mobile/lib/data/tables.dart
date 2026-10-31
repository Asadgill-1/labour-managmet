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
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {tenantId, code},
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

  /// Monthly basis only: 'calendar_days' or 'fixed_divisor'. No default on purpose (D-102).
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

  @override
  List<String> get customConstraints => ['CHECK (break_minutes <= clock_minutes)'];
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
