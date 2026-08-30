import 'package:drift/drift.dart';

import '../../core/constants.dart';
import '../local/database.dart';

class GoalRepository {
  GoalRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Area>> watchAreas() {
    return (_db.select(
      _db.areas,
    )..orderBy([(a) => OrderingTerm(expression: a.orderIndex)])).watch();
  }

  Stream<List<Goal>> watchObjectives({String? areaId}) {
    return (_db.select(_db.goals)
          ..where(
            (g) =>
                g.type.equals('objective') &
                (areaId == null
                    ? const Constant(true)
                    : g.parentId.equals(areaId)),
          )
          ..orderBy([(g) => OrderingTerm(expression: g.createdAt)]))
        .watch();
  }

  Future<Goal?> getById(String id) {
    return (_db.select(
      _db.goals,
    )..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  Stream<Goal?> watchById(String id) {
    return (_db.select(
      _db.goals,
    )..where((g) => g.id.equals(id))).watchSingleOrNull();
  }

  Future<void> insertArea(AreasCompanion area) =>
      _db.into(_db.areas).insert(area);

  Future<void> updateArea(String id, AreasCompanion area) async {
    await (_db.update(_db.areas)..where((a) => a.id.equals(id))).write(area);
  }

  Future<void> deleteArea(String id) async {
    await (_db.delete(_db.areas)..where((a) => a.id.equals(id))).go();
  }

  Future<void> insertGoal(GoalsCompanion goal) =>
      _db.into(_db.goals).insert(goal);

  Future<void> updateGoal(String id, GoalsCompanion goal) async {
    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      goal.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  }

  /// Progress (0..1) computed from the goal's direct tasks, including subtasks.
  Future<double> progressOf(Goal goal) async {
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.goalId.equals(goal.id) & t.parentId.isNull())).get();
    if (tasks.isEmpty) return 0;
    var done = 0;
    for (final t in tasks) {
      if (t.status == kStatusCompleted) {
        done++;
      } else {
        final subs = await (_db.select(
          _db.tasks,
        )..where((s) => s.parentId.equals(t.id))).get();
        if (subs.isNotEmpty &&
            subs.every((s) => s.status == kStatusCompleted)) {
          done++;
        }
      }
    }
    return done / tasks.length;
  }

  Future<int> investedMinutes(Goal goal) async {
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.goalId.equals(goal.id))).get();
    final taskIds = tasks.map((t) => t.id).toList();
    if (taskIds.isEmpty) return 0;
    final entries = await _db
        .customSelect(
          'SELECT COALESCE(SUM(duration_minutes), 0) as s FROM time_entries '
          'WHERE task_id IN (${List.filled(taskIds.length, '?').join(',')})',
          variables: [for (final id in taskIds) Variable(id)],
          readsFrom: {_db.timeEntries, _db.tasks},
        )
        .getSingle();
    return entries.read<int>('s');
  }
}
