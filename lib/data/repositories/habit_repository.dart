import 'package:drift/drift.dart';

import '../local/database.dart';

class EnergyRepository {
  EnergyRepository(this._db);
  final FlowPilotDatabase _db;

  Future<void> log({required int energy, String? mood, String? note}) {
    return _db
        .into(_db.energyLogs)
        .insert(
          EnergyLogsCompanion.insert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            timestamp: DateTime.now(),
            energy: energy,
            mood: Value(mood),
            note: Value(note),
          ),
        );
  }

  Stream<List<EnergyLog>> watchRecent({int limit = 50}) {
    final q = _db.select(_db.energyLogs)
      ..orderBy([
        (e) => OrderingTerm(expression: e.timestamp, mode: OrderingMode.desc),
      ]);
    q.limit(limit);
    return q.watch();
  }

  /// Average energy in the last [days] days. Returns null if no logs.
  Future<double?> averageEnergy({int days = 7}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final rows = await (_db.select(
      _db.energyLogs,
    )..where((e) => e.timestamp.isBiggerOrEqualValue(from))).get();
    if (rows.isEmpty) return null;
    return rows.map((e) => e.energy).reduce((a, b) => a + b) / rows.length;
  }
}

class HabitRepository {
  HabitRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Habit>> watchAll() {
    return (_db.select(
      _db.habits,
    )..orderBy([(h) => OrderingTerm(expression: h.name)])).watch();
  }

  Future<void> insert(HabitsCompanion habit) =>
      _db.into(_db.habits).insert(habit);

  Future<void> update(String id, HabitsCompanion habit) async {
    await (_db.update(_db.habits)..where((h) => h.id.equals(id))).write(habit);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();
    await (_db.delete(
      _db.habitCompletions,
    )..where((h) => h.habitId.equals(id))).go();
  }

  Stream<List<HabitCompletion>> watchCompletions(String habitId) {
    return (_db.select(_db.habitCompletions)
          ..where((h) => h.habitId.equals(habitId))
          ..orderBy([
            (h) => OrderingTerm(expression: h.date, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Future<bool> isDoneOn(Habit habit, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows =
        await (_db.select(_db.habitCompletions)..where(
              (h) =>
                  h.habitId.equals(habit.id) &
                  h.date.isBetweenValues(start, end),
            ))
            .get();
    return rows.isNotEmpty;
  }

  Future<void> toggleCompletion(Habit habit, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final existing =
        await (_db.select(_db.habitCompletions)..where(
              (h) =>
                  h.habitId.equals(habit.id) &
                  h.date.isBetweenValues(start, end),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (_db.delete(
        _db.habitCompletions,
      )..where((h) => h.id.equals(existing.id))).go();
    } else {
      await _db
          .into(_db.habitCompletions)
          .insert(
            HabitCompletionsCompanion.insert(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              habitId: habit.id,
              date: start,
            ),
          );
    }
  }

  /// Current streak in days (consecutive days up to today with a completion).
  Future<int> streak(Habit habit) async {
    final completions =
        await (_db.select(_db.habitCompletions)
              ..where((h) => h.habitId.equals(habit.id))
              ..orderBy([
                (h) =>
                    OrderingTerm(expression: h.date, mode: OrderingMode.desc),
              ]))
            .get();
    final doneDays = completions
        .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
        .toSet();
    var count = 0;
    var cursor = DateTime.now();
    // If today not done yet, start checking from yesterday.
    if (!doneDays.contains(DateTime(cursor.year, cursor.month, cursor.day))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (true) {
      final key = DateTime(cursor.year, cursor.month, cursor.day);
      if (doneDays.contains(key)) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }
}

class RoutineRepository {
  RoutineRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Routine>> watchAll() {
    return (_db.select(
      _db.routines,
    )..orderBy([(r) => OrderingTerm(expression: r.name)])).watch();
  }

  Future<void> insert(RoutinesCompanion routine) =>
      _db.into(_db.routines).insert(routine);

  Future<void> update(String id, RoutinesCompanion routine) async {
    await (_db.update(
      _db.routines,
    )..where((r) => r.id.equals(id))).write(routine);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.routines)..where((r) => r.id.equals(id))).go();
  }
}
