import 'package:drift/drift.dart';

import '../local/database.dart';

class ActivityCategoryRepository {
  ActivityCategoryRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<ActivityCategory>> watchAll() => (_db.select(
    _db.activityCategories,
  )..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();

  Future<void> insert(ActivityCategoriesCompanion category) =>
      _db.into(_db.activityCategories).insert(category);

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.activityCategories)..where((c) => c.id.equals(id)))
        .write(ActivityCategoriesCompanion(name: Value(name)));
  }

  Future<void> delete(String id) async {
    await (_db.update(_db.timeEntries)..where((e) => e.categoryId.equals(id)))
        .write(const TimeEntriesCompanion(categoryId: Value(null)));
    await (_db.delete(
      _db.activityCategories,
    )..where((c) => c.id.equals(id))).go();
  }

  Future<void> seedIfNeeded() async {
    if (await _db
        .select(_db.activityCategories)
        .get()
        .then((v) => v.isNotEmpty)) {
      return;
    }
    for (final name in const [
      'Trabajo',
      'Estudio',
      'Personal',
      'Salud',
      'Descanso',
    ]) {
      await insert(
        ActivityCategoriesCompanion.insert(id: name.toLowerCase(), name: name),
      );
    }
  }
}
