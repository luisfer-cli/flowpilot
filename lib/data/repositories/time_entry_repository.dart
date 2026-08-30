import 'package:drift/drift.dart';

import '../local/database.dart';

class TimeEntryRepository {
  TimeEntryRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<TimeEntry>> watchAll({int? limit}) {
    final q = _db.select(_db.timeEntries)
      ..orderBy([
        (t) => OrderingTerm(expression: t.start, mode: OrderingMode.desc),
      ]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<TimeEntry?> watchRunning() {
    return (_db.select(_db.timeEntries)
          ..where((t) => t.end.isNull())
          ..limit(1)
          ..orderBy([
            (t) => OrderingTerm(expression: t.start, mode: OrderingMode.desc),
          ]))
        .watchSingleOrNull();
  }

  Future<String> startTimer({
    String? taskId,
    String? projectId,
    String? categoryId,
    String source = 'manual',
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return _db
        .into(_db.timeEntries)
        .insert(
          TimeEntriesCompanion.insert(
            id: id,
            start: DateTime.now(),
            taskId: Value(taskId),
            projectId: Value(projectId),
            categoryId: Value(categoryId),
            source: Value(source),
          ),
        )
        .then((_) => id);
  }

  Future<void> stopTimer(String entryId) async {
    final entry = await (_db.select(
      _db.timeEntries,
    )..where((t) => t.id.equals(entryId))).getSingle();
    if (entry.end != null) return;
    final end = DateTime.now();
    final minutes = end.difference(entry.start).inMinutes;
    await (_db.update(
      _db.timeEntries,
    )..where((t) => t.id.equals(entryId))).write(
      TimeEntriesCompanion(
        end: Value(end),
        durationMinutes: Value(minutes < 1 ? 1 : minutes),
      ),
    );
    if (entry.taskId != null) {
      final task = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(entry.taskId!))).getSingleOrNull();
      if (task != null) {
        await (_db.update(
          _db.tasks,
        )..where((t) => t.id.equals(entry.taskId!))).write(
          TasksCompanion(
            actualMinutes: Value(
              task.actualMinutes + (minutes < 1 ? 1 : minutes),
            ),
          ),
        );
      }
    }
  }

  Future<void> addManual({
    required DateTime start,
    required DateTime end,
    String? taskId,
    String? projectId,
    String? categoryId,
    String source = 'manual',
    String? note,
  }) {
    final minutes = end.difference(start).inMinutes;
    return _db
        .into(_db.timeEntries)
        .insert(
          TimeEntriesCompanion.insert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            start: start,
            end: Value(end),
            durationMinutes: Value(minutes < 1 ? 1 : minutes),
            taskId: Value(taskId),
            projectId: Value(projectId),
            categoryId: Value(categoryId),
            source: Value(source),
            note: Value(note),
          ),
        );
  }

  Future<void> updateEntry(String id, TimeEntriesCompanion entry) async {
    await (_db.update(
      _db.timeEntries,
    )..where((t) => t.id.equals(id))).write(entry);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.timeEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<int> totalMinutesBetween(DateTime start, DateTime end) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(duration_minutes), 0) as s FROM time_entries '
          'WHERE start >= ? AND start <= ?',
          variables: [Variable(start), Variable(end)],
          readsFrom: {_db.timeEntries},
        )
        .getSingle();
    return row.read<int>('s');
  }

  Future<({int focus, int total})> minutesByFocusBetween(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (_db.select(
      _db.timeEntries,
    )..where((t) => t.start.isBetweenValues(start, end))).get();
    var total = 0;
    var focus = 0;
    for (final t in rows) {
      final minutes = t.durationMinutes ?? 0;
      total += minutes;
      if (t.source == 'pomodoro' || t.taskId != null) focus += minutes;
    }
    return (focus: focus, total: total);
  }

  Future<int> minutesByTaskBetween(
    String taskId,
    DateTime start,
    DateTime end,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(duration_minutes), 0) as s FROM time_entries '
          'WHERE task_id = ? AND start >= ? AND start <= ?',
          variables: [Variable(taskId), Variable(start), Variable(end)],
          readsFrom: {_db.timeEntries},
        )
        .getSingle();
    return row.read<int>('s');
  }

  Future<int> minutesByProjectBetween(
    String projectId,
    DateTime start,
    DateTime end,
  ) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(duration_minutes), 0) as s FROM time_entries '
          'WHERE project_id = ? AND start >= ? AND start <= ?',
          variables: [Variable(projectId), Variable(start), Variable(end)],
          readsFrom: {_db.timeEntries},
        )
        .getSingle();
    return row.read<int>('s');
  }
}
