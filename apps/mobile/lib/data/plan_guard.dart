import 'package:drift/drift.dart';

import 'licence.dart';
import 'masters.dart';
import 'tenant_database.dart';

/// Why the company's plan holds a write back.
enum PlanBlock {
  /// No licence on this phone yet.
  noLicence,

  /// The trial or the plan ended, or there never was one.
  ended,

  /// Seven days, or the plan's end, passed since the last check online.
  leaseOver,

  /// The phone's clock went back.
  clockBack,

  /// The plan's number of active workers is reached.
  workerLimit,

  /// The plan's number of client companies is reached.
  clientLimit,

  /// More active workers than the plan holds, as after a trial or a smaller plan (PLAN-04).
  workersOver,

  /// More active client companies than the plan holds.
  clientsOver,
}

/// The plan refused a write. Nothing was written (T21c).
class PlanRefused implements Exception {
  const PlanRefused(this.block, {this.limit});

  final PlanBlock block;

  /// The plan's number, when a number is the reason.
  final int? limit;

  @override
  String toString() => 'PlanRefused(${block.name}${limit == null ? '' : ', $limit'})';
}

/// What a plan that ended, or a company over its plan, still lets through beside archiving: the company's own details,
/// its letterhead, papers of what is already entered, and a restore (PLAN-03, PLAN-06, D-072). Everything else waits.
const _alwaysAllowed = {'tenant_profiles', 'document_templates', 'document_assets', 'issued_documents', 'restores'};

/// Why the plan [view] shows holds back a write to [entity], or null when it may go through. [workers] and [clients]
/// are the company's active counts before the write.
PlanRefused? planRefusal(LicenceView view, {required String entity, required WriteEffect effect, required int workers, required int clients}) {
  if (effect == WriteEffect.archives || _alwaysAllowed.contains(entity)) return null;
  final block = switch (view.status) {
    LicenceStatus.active => null,
    LicenceStatus.none => PlanBlock.noLicence,
    LicenceStatus.ended => PlanBlock.ended,
    LicenceStatus.leaseOver => PlanBlock.leaseOver,
    LicenceStatus.clockBack => PlanBlock.clockBack,
  };
  if (block != null) return PlanRefused(block);
  final licence = view.licence!;
  if (licence.workers case final limit? when workers > limit) return PlanRefused(PlanBlock.workersOver, limit: limit);
  if (licence.clients case final limit? when clients > limit) return PlanRefused(PlanBlock.clientsOver, limit: limit);
  if (effect != WriteEffect.activates) return null;
  if (licence.workers case final limit? when entity == 'workers' && workers >= limit) return PlanRefused(PlanBlock.workerLimit, limit: limit);
  if (licence.clients case final limit? when entity == 'clients' && clients >= limit) return PlanRefused(PlanBlock.clientLimit, limit: limit);
  return null;
}

/// The guard for [db]'s single write path under the licence on this phone. A null view is a company with no plans.
/// The rows are counted only when the plan has a number to hold them to.
WriteGuard planGuard(TenantDatabase db, LicenceView? Function() view) => (entity, effect) async {
  final now = view();
  if (now == null || effect == WriteEffect.archives) return;
  final counted = now.status == LicenceStatus.active && (now.licence!.workers != null || now.licence!.clients != null);
  final counts = counted ? await activeCounts(db) : (workers: 0, clients: 0);
  final refusal = planRefusal(now, entity: entity, effect: effect, workers: counts.workers, clients: counts.clients);
  if (refusal != null) throw refusal;
};

extension PlanChoice on TenantDatabase {
  /// Archives every active row of [table] not in [keep], all or none, and says how many: the answer of a company over
  /// its plan to "which stay active?" (PLAN-04). Only the row is set aside by [archived], so history and balances stay
  /// as they were, and each one is in the record of changes with [reason].
  Future<int> archiveAllBut<T extends Table, D extends DataClass>(TableInfo<T, D> table, Insertable<D> archived, Set<String> keep, {required String reason}) {
    return transaction(() async {
      final active = table.columnsByName['active']! as Expression<bool>;
      final rest = [
        for (final row in await (select(table)..where((_) => active.equals(true))).get())
          if (row.toJson()['id'] case final String id when !keep.contains(id)) id,
      ];
      for (final id in rest) {
        await saveRow(table, id: id, operationId: newUuid(), reason: reason, fields: archived);
      }
      return rest.length;
    });
  }
}
