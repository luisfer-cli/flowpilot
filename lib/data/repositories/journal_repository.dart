import 'package:drift/drift.dart';

import '../local/database.dart';

class JournalRepository {
  JournalRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<JournalEntry>> watchRecent({int limit = 50}) {
    final q = _db.select(_db.journalEntries)
      ..orderBy([
        (e) => OrderingTerm(expression: e.dayKey, mode: OrderingMode.desc),
      ]);
    q.limit(limit);
    return q.watch();
  }

  Stream<JournalEntry?> watchByDay(int dayKey) {
    return (_db.select(
      _db.journalEntries,
    )..where((e) => e.dayKey.equals(dayKey))).watchSingleOrNull();
  }

  Future<JournalEntry?> getByDay(int dayKey) {
    return (_db.select(
      _db.journalEntries,
    )..where((e) => e.dayKey.equals(dayKey))).getSingleOrNull();
  }

  Future<void> upsert(JournalEntriesCompanion entry) {
    return _db.into(_db.journalEntries).insertOnConflictUpdate(entry);
  }

  Future<void> delete(int dayKey) async {
    await (_db.delete(
      _db.journalEntries,
    )..where((e) => e.dayKey.equals(dayKey))).go();
  }
}
