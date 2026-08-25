import 'package:drift/drift.dart';

import '../local/database.dart';

class PomodoroRepository {
  PomodoroRepository(this._db);
  final FlowPilotDatabase _db;

  Future<void> insertSession(PomodoroSessionsCompanion session) =>
      _db.into(_db.pomodoroSessions).insert(session);

  Future<void> updateSession(
    String id,
    PomodoroSessionsCompanion session,
  ) async {
    await (_db.update(
      _db.pomodoroSessions,
    )..where((s) => s.id.equals(id))).write(session);
  }

  Future<void> deleteSession(String id) async {
    await (_db.delete(
      _db.pomodoroSessions,
    )..where((s) => s.id.equals(id))).go();
  }

  Stream<List<PomodoroSession>> watchRecent({int limit = 30}) {
    final q = _db.select(_db.pomodoroSessions)
      ..orderBy([
        (s) => OrderingTerm(expression: s.start, mode: OrderingMode.desc),
      ]);
    q.limit(limit);
    return q.watch();
  }

  Stream<List<PomodoroSession>> watchBetween(DateTime start, DateTime end) {
    return (_db.select(
      _db.pomodoroSessions,
    )..where((s) => s.start.isBetweenValues(start, end))).watch();
  }

  Future<int> completedCountBetween(DateTime start, DateTime end) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) as c FROM pomodoro_sessions '
          'WHERE completed = 1 AND start >= ? AND start <= ?',
          variables: [Variable(start), Variable(end)],
          readsFrom: {_db.pomodoroSessions},
        )
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> focusMinutesBetween(DateTime start, DateTime end) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(planned_minutes), 0) as s FROM pomodoro_sessions '
          'WHERE completed = 1 AND start >= ? AND start <= ?',
          variables: [Variable(start), Variable(end)],
          readsFrom: {_db.pomodoroSessions},
        )
        .getSingle();
    return row.read<int>('s');
  }

  Future<int> interruptionsBetween(DateTime start, DateTime end) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(interruptions), 0) as s FROM pomodoro_sessions '
          'WHERE start >= ? AND start <= ?',
          variables: [Variable(start), Variable(end)],
          readsFrom: {_db.pomodoroSessions},
        )
        .getSingle();
    return row.read<int>('s');
  }
}
