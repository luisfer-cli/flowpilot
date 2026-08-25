import 'package:drift/drift.dart';

import '../local/database.dart';

class TimeBlockRepository {
  TimeBlockRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<TimeBlock>> watchByDay(int dayKey) {
    return (_db.select(_db.timeBlocks)
          ..where((b) => b.dayKey.equals(dayKey))
          ..orderBy([(b) => OrderingTerm(expression: b.startMinutes)]))
        .watch();
  }

  Future<List<TimeBlock>> getByDay(int dayKey) {
    return (_db.select(_db.timeBlocks)
          ..where((b) => b.dayKey.equals(dayKey))
          ..orderBy([(b) => OrderingTerm(expression: b.startMinutes)]))
        .get();
  }

  Future<List<TimeBlock>> getByDayRange(int fromKey, int toKey) {
    return (_db.select(
      _db.timeBlocks,
    )..where((b) => b.dayKey.isBetweenValues(fromKey, toKey))).get();
  }

  Stream<List<TimeBlock>> watchByTask(String taskId) {
    return (_db.select(
      _db.timeBlocks,
    )..where((b) => b.taskId.equals(taskId))).watch();
  }

  Future<TimeBlock?> getById(String id) {
    return (_db.select(
      _db.timeBlocks,
    )..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  Future<void> insert(TimeBlocksCompanion block) =>
      _db.into(_db.timeBlocks).insert(block);

  Future<void> update(String id, TimeBlocksCompanion block) async {
    await (_db.update(_db.timeBlocks)..where((b) => b.id.equals(id))).write(
      block.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> move(
    String id,
    int dayKey,
    int startMinutes,
    int endMinutes,
  ) async {
    await (_db.update(_db.timeBlocks)..where((b) => b.id.equals(id))).write(
      TimeBlocksCompanion(
        dayKey: Value(dayKey),
        startMinutes: Value(startMinutes),
        endMinutes: Value(endMinutes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.timeBlocks)..where((b) => b.id.equals(id))).go();
  }

  Future<void> deleteForDay(int dayKey) async {
    await (_db.delete(
      _db.timeBlocks,
    )..where((b) => b.dayKey.equals(dayKey))).go();
  }
}
