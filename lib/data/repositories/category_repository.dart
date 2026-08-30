import 'package:drift/drift.dart';

import '../local/database.dart';

/// The single category catalogue shared by tasks, time entries and routines.
class CategoryRepository {
  CategoryRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Category>> watchAll() => (_db.select(
    _db.categories,
  )..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();

  Future<void> insert(CategoriesCompanion category) =>
      _db.into(_db.categories).insert(category);

  Future<void> rename(String id, String name) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(name)),
    );
  }

  Future<void> update(String id, CategoriesCompanion category) async {
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(category);
  }

  Future<void> delete(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.categoryId.equals(id))).write(
      const TasksCompanion(categoryId: Value(null)),
    );
    await (_db.update(_db.timeEntries)..where((t) => t.categoryId.equals(id)))
        .write(const TimeEntriesCompanion(categoryId: Value(null)));
    await (_db.update(_db.routines)..where((r) => r.categoryId.equals(id)))
        .write(const RoutinesCompanion(categoryId: Value(null)));
    await (_db.update(_db.scheduleTemplates)
          ..where((t) => t.categoryId.equals(id)))
        .write(const ScheduleTemplatesCompanion(categoryId: Value(null)));
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  Future<void> seedIfNeeded() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;
    for (final name in const [
      'Trabajo',
      'Universidad',
      'Personal',
      'Salud',
      'Pasatiempo',
    ]) {
      await insert(
        CategoriesCompanion.insert(id: name.toLowerCase(), name: name),
      );
    }
  }
}
