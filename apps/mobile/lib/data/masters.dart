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
