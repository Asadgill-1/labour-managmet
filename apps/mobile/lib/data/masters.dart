import 'package:domain/calc.dart';
import 'package:drift/drift.dart';

import 'changes.dart';
import 'receipts.dart';
import 'tenant_database.dart';

/// A second fixed monthly amount for a company over the same dates. One fee a month covers a company, so the second
/// would never be billed (D-080 (1)). Nothing was written.
class SecondFixedAmount implements Exception {
  const SecondFixedAmount();
}

/// What a worker earns in one group, set by hand there, per day or per hour (D-042).
typedef MemberRate = ({int fils, RateBasis basis});

MemberRate? memberRateOf(WorkerGroupMember m) => m.rateFils == null ? null : (fils: m.rateFils!, basis: RateBasis.values.byName(m.rateBasis));

/// Rows by a key, keeping their order. With a thousand workers, scanning every row for each worker takes minutes.
Map<K, List<T>> groupedBy<K, T>(Iterable<T> rows, K Function(T row) key) {
  final groups = <K, List<T>>{};
  for (final row in rows) {
    (groups[key(row)] ??= []).add(row);
  }
  return groups;
}

/// Adds the common columns to a form's fields without each table repeating them.
class _Stamped<D> implements Insertable<D> {
  _Stamped(this.fields, this.common);

  final Insertable<D> fields;
  final Map<String, Expression> common;

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) => {...fields.toColumns(nullToAbsent), ...common};
}

extension Masters on TenantDatabase {
  /// Creates the row when [id] is null, otherwise updates it and bumps its version.
  /// The operation ID comes from the form, so a double tap or retry applies once.
  /// An update of a record the owner reads keeps what changed, from and to, beside [reason], the user's note (D-056).
  Future<String> saveRow<T extends Table, D extends DataClass>(
    TableInfo<T, D> table, {
    required String? id,
    required Insertable<D> fields,
    required String operationId,
    String? reason,
  }) async {
    final rowId = id ?? newUuid();
    final idColumn = table.columnsByName['id']! as Expression<String>;
    SimpleSelectStatement<T, D> byId() => select(table)..where((_) => idColumn.equals(rowId));

    var version = 1;
    Facts? before;
    Map<String, dynamic>? existing;
    // What the plan asks of this write (T21c): a row only set aside, a row made active, or any other entry.
    final written = fields.toColumns(true);
    final active = switch (written['active']) {
      Variable<bool>(:final value) => value,
      _ => null,
    };
    var effect = table.columnsByName.containsKey('active') && active != false ? WriteEffect.activates : WriteEffect.entry;
    if (id != null) {
      existing = (await byId().getSingle()).toJson();
      version = (existing['version'] as int) + 1;
      before = await recordFacts(table.actualTableName, existing);
      effect = switch (active) {
        false when written.length == 1 => WriteEffect.archives,
        true when existing['active'] == false => WriteEffect.activates,
        _ => WriteEffect.entry,
      };
    }
    return applyOperation(
      operationId: operationId,
      entity: table.actualTableName,
      recordId: rowId,
      version: version,
      action: id == null ? 'create' : 'update',
      reason: reason,
      effect: effect,
      detail: before == null
          ? null
          : () async => {'from': factsJson(before!), 'to': factsJson((await recordFacts(table.actualTableName, (await byId().getSingle()).toJson()))!)},
      change: () async {
        final now = Variable<DateTime>(DateTime.now().toUtc());
        final shared = <String, Expression>{
          'updated_at_utc': now,
          'actor_id': Variable<String>(actorId),
          'version': Variable<int>(version),
          'source_operation_id': Variable<String>(operationId),
        };
        if (id == null) {
          final common = {...shared, 'id': Variable<String>(rowId), 'tenant_id': Variable<String>(tenantId), 'created_at_utc': now};
          await into(table).insert(_Stamped(fields, common));
        } else {
          await (update(table)..where((_) => idColumn.equals(rowId))).write(_Stamped(fields, shared));
        }
        // What receipts settled of a company's old balance stays settled (INV-05).
        if (existing != null && table.actualTableName == 'opening_balances') await keepOpeningSettled(existing);
        if (table.actualTableName == 'billing_contracts') await _oneFixedAmount(rowId);
        return (await byId().getSingle()).toJson();
      },
    );
  }

  /// Saves a group and its members as one operation. Members no longer listed leave the group;
  /// their past attendance is untouched, because every row keeps its own figures.
  Future<String> saveWorkerGroup({
    required String? id,
    required WorkerGroupsCompanion fields,
    required Map<String, MemberRate?> members,
    required String operationId,
    String? reason,
  }) async {
    final rowId = id ?? newUuid();
    Future<Facts> facts() async => (await recordFacts('worker_groups', (await (select(workerGroups)..where((g) => g.id.equals(rowId))).getSingle()).toJson()))!;
    var version = 1;
    Facts? before;
    if (id != null) {
      version = (await (select(workerGroups)..where((g) => g.id.equals(id))).getSingle()).version + 1;
      before = await facts();
    }
    return applyOperation(
      operationId: operationId,
      entity: 'worker_groups',
      recordId: rowId,
      version: version,
      action: id == null ? 'create' : 'update',
      reason: reason,
      detail: before == null ? null : () async => {'from': factsJson(before!), 'to': factsJson(await facts())},
      change: () async {
        final moment = DateTime.now().toUtc();
        final now = Variable<DateTime>(moment);
        final shared = <String, Expression>{
          'updated_at_utc': now,
          'actor_id': Variable<String>(actorId),
          'version': Variable<int>(version),
          'source_operation_id': Variable<String>(operationId),
        };
        if (id == null) {
          await into(workerGroups).insert(
            _Stamped(fields, {...shared, 'id': Variable<String>(rowId), 'tenant_id': Variable<String>(tenantId), 'created_at_utc': now}),
          );
        } else {
          await (update(workerGroups)..where((g) => g.id.equals(rowId))).write(_Stamped(fields, shared));
        }

        final current = await (select(workerGroupMembers)..where((m) => m.groupId.equals(rowId))).get();
        for (final old in current.where((m) => !members.containsKey(m.workerId))) {
          await (delete(workerGroupMembers)..where((m) => m.id.equals(old.id))).go();
        }
        for (final entry in members.entries) {
          final old = current.where((m) => m.workerId == entry.key).firstOrNull;
          if (old == null) {
            await into(workerGroupMembers).insert(
              WorkerGroupMembersCompanion.insert(
                id: newUuid(),
                tenantId: tenantId,
                createdAtUtc: moment,
                updatedAtUtc: moment,
                actorId: actorId,
                sourceOperationId: operationId,
                groupId: rowId,
                workerId: entry.key,
                rateFils: Value(entry.value?.fils),
                rateBasis: Value((entry.value?.basis ?? RateBasis.day).name),
              ),
            );
          } else if (old.rateFils != entry.value?.fils || (entry.value != null && old.rateBasis != entry.value!.basis.name)) {
            await (update(workerGroupMembers)..where((m) => m.id.equals(old.id))).write(
              WorkerGroupMembersCompanion(
                rateFils: Value(entry.value?.fils),
                rateBasis: Value((entry.value?.basis ?? RateBasis.day).name),
                updatedAtUtc: Value(moment),
                actorId: Value(actorId),
                version: Value(old.version + 1),
                sourceOperationId: Value(operationId),
              ),
            );
          }
        }
        final group = await (select(workerGroups)..where((g) => g.id.equals(rowId))).getSingle();
        final stored = await (select(workerGroupMembers)..where((m) => m.groupId.equals(rowId))).get();
        return {...group.toJson(), 'members': stored.map((m) => m.toJson()).toList()};
      },
    );
  }

  /// True if another pay contract with the same scope covers any of these dates, which would make the rate ambiguous.
  Future<bool> payContractOverlaps({
    required String workerId,
    required String? siteId,
    required String from,
    required String? to,
    String? exceptId,
  }) async {
    final rows = await (select(payContracts)..where((c) => c.workerId.equals(workerId))).get();
    return rows.any((c) => c.id != exceptId && c.siteId == siteId && datesOverlap(c.effectiveFrom, c.effectiveTo, from, to));
  }

  /// The same check for a client's billing contracts.
  Future<bool> billingContractOverlaps({
    required String clientId,
    required String? siteId,
    required String? workerId,
    required String from,
    required String? to,
    String? exceptId,
  }) async {
    final rows = await (select(billingContracts)..where((c) => c.clientId.equals(clientId))).get();
    return rows.any(
      (c) => c.id != exceptId && c.siteId == siteId && c.workerId == workerId && datesOverlap(c.effectiveFrom, c.effectiveTo, from, to),
    );
  }

  /// Runs inside the write of billing contract [id]: refuses a fixed monthly amount whose dates meet another one of the
  /// same company, at any site, since one fee a month covers the company (D-080 (1)). The same site and worker from
  /// another start date is that amount's new rate, which replaces it from then on (CALC-06), not a second amount.
  Future<void> _oneFixedAmount(String id) async {
    final saved = await (select(billingContracts)..where((c) => c.id.equals(id))).getSingle();
    if (saved.basis != RateBasis.monthFixed.name) return;
    final others = await (select(billingContracts)..where((c) => c.clientId.equals(saved.clientId) & c.basis.equals(RateBasis.monthFixed.name) & c.id.equals(id).not())).get();
    bool newRate(BillingContract c) => c.siteId == saved.siteId && c.workerId == saved.workerId && c.effectiveFrom != saved.effectiveFrom;
    if (others.any((c) => !newRate(c) && datesOverlap(c.effectiveFrom, c.effectiveTo, saved.effectiveFrom, saved.effectiveTo))) throw const SecondFixedAmount();
  }

  /// Suggestion only. The owner can type any code, and uniqueness is still checked on save.
  Future<String> nextWorkerCode() async {
    final count = await workers.count().getSingle();
    return 'W${(count + 1).toString().padLeft(3, '0')}';
  }

  Future<bool> workerCodeTaken(String code, {String? exceptId}) async {
    final query = select(workers)..where((w) => w.code.equals(code));
    if (exceptId != null) query.where((w) => w.id.isNotValue(exceptId));
    return (await query.get()).isNotEmpty;
  }
}
