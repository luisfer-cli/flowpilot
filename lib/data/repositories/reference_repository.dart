import 'package:drift/drift.dart';

import '../../core/constants.dart';
import '../../core/utils/id.dart';
import '../local/database.dart';

class ReferenceRepository {
  ReferenceRepository(this._db);
  final FlowPilotDatabase _db;

  /// Seeds default reference data on first launch.
  Future<void> seedIfNeeded() async {
    final statusCount = await _db
        .customSelect(
          'SELECT COUNT(*) as c FROM task_statuses',
          readsFrom: {_db.taskStatuses},
        )
        .getSingle();
    if (statusCount.read<int>('c') > 0) return;

    await _db.batch((b) {
      for (var i = 0; i < kDefaultStatuses.length; i++) {
        b.insert(
          _db.taskStatuses,
          TaskStatusesCompanion.insert(
            name: kDefaultStatuses[i],
            orderIndex: Value(i),
          ),
        );
      }
      for (final area in kDefaultAreas) {
        b.insert(
          _db.areas,
          AreasCompanion.insert(id: generateId(), name: area),
        );
      }
      for (var i = 0; i < kDefaultContexts.length; i++) {
        b.insert(
          _db.contexts,
          ContextsCompanion.insert(
            id: generateId(),
            name: kDefaultContexts[i],
            orderIndex: Value(i),
          ),
        );
      }
      for (final category in const [
        'Trabajo',
        'Universidad',
        'Personal',
        'Salud',
        'Pasatiempo',
      ]) {
        b.insert(
          _db.categories,
          CategoriesCompanion.insert(
            id: category.toLowerCase(),
            name: category,
          ),
        );
      }
    });
  }

  Stream<List<TaskStatus>> watchStatuses() {
    return (_db.select(
      _db.taskStatuses,
    )..orderBy([(s) => OrderingTerm(expression: s.orderIndex)])).watch();
  }

  Stream<List<Context>> watchContexts() {
    return (_db.select(
      _db.contexts,
    )..orderBy([(c) => OrderingTerm(expression: c.orderIndex)])).watch();
  }

  Stream<List<Category>> watchCategories() {
    return (_db.select(
      _db.categories,
    )..orderBy([(c) => OrderingTerm(expression: c.name)])).watch();
  }

  Stream<List<Tag>> watchTags() {
    return (_db.select(
      _db.tags,
    )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  Future<void> insertContext(ContextsCompanion c) =>
      _db.into(_db.contexts).insert(c);

  Future<void> insertCategory(CategoriesCompanion c) =>
      _db.into(_db.categories).insert(c);

  Future<void> insertTag(TagsCompanion t) => _db.into(_db.tags).insert(t);

  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.taskTags,
      )..where((t) => t.taskId.equals(taskId))).go();
      for (final tagId in tagIds) {
        await _db
            .into(_db.taskTags)
            .insert(TaskTagsCompanion.insert(taskId: taskId, tagId: tagId));
      }
    });
  }

  Future<List<String>> tagIdsForTask(String taskId) async {
    final rows = await (_db.select(
      _db.taskTags,
    )..where((t) => t.taskId.equals(taskId))).get();
    return rows.map((r) => r.tagId).toList();
  }

  Future<Map<String, int>> countsByStatus() async {
    final rows = await _db
        .customSelect(
          'SELECT status, COUNT(*) as c FROM tasks WHERE is_archived = 0 GROUP BY status',
          readsFrom: {_db.tasks},
        )
        .get();
    return {for (final r in rows) r.read<String>('status'): r.read<int>('c')};
  }

  Future<String?> getSetting(String key) => _db.getSetting(key);

  Future<void> setSetting(String key, String? value) =>
      _db.setSetting(key, value);

  Future<Map<String, String?>> allSettings() => _db.allSettings();
}
