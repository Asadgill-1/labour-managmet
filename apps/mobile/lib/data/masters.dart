import 'package:domain/calc.dart';
import 'package:drift/drift.dart';

import 'tenant_database.dart';

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
    if (id != null) {
      final existing = await byId().getSingle();
      version = (existing.toJson()['version'] as int) + 1;
    }
    await applyOperation(
      operationId: operationId,
      entity: table.actualTableName,
      recordId: rowId,
      version: version,
      action: id == null ? 'create' : 'update',
      reason: reason,
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
        return (await byId().getSingle()).toJson();
      },
    );
    return rowId;
  }

  /// Saves a group and its members as one operation. Members no longer listed leave the group;
  /// their past attendance is untouched, because every row keeps its own figures.
  Future<String> saveWorkerGroup({
    required String? id,
    required WorkerGroupsCompanion fields,
    required Map<String, int?> members,
    required String operationId,
  }) async {
    final rowId = id ?? newUuid();
    var version = 1;
    if (id != null) {
      version = (await (select(workerGroups)..where((g) => g.id.equals(id))).getSingle()).version + 1;
    }
    await applyOperation(
      operationId: operationId,
      entity: 'worker_groups',
      recordId: rowId,
      version: version,
      action: id == null ? 'create' : 'update',
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
                dailyRateFils: Value(entry.value),
              ),
            );
          } else if (old.dailyRateFils != entry.value) {
            await (update(workerGroupMembers)..where((m) => m.id.equals(old.id))).write(
              WorkerGroupMembersCompanion(
                dailyRateFils: Value(entry.value),
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
    return rowId;
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
