import 'package:drift/drift.dart';

import '../../core/constants.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../local/database.dart';

class TaskRepository {
  TaskRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Task>> watchAll({bool includeArchived = false}) {
    return (_db.select(_db.tasks)
          ..where(
            (t) => includeArchived
                ? const Constant(true)
                : t.isArchived.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.completedAt,
              mode: OrderingMode.asc,
              nulls: NullsOrder.first,
            ),
            (t) => OrderingTerm(expression: t.orderIndex),
          ]))
        .watch();
  }

  /// Tasks that carry a recurrence rule (for the recurrence engine).
  Future<List<Task>> getRecurring() {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.recurrenceId.isNotNull())).get();
  }

  /// Tracks with a recurrence rule whose next occurrence is on/before [date].
  Future<List<Task>> getRecurringDueOnOrBefore(DateTime date) async {
    final tasks = await getRecurring();
    return tasks.where((t) {
      final due = t.dueDate;
      return due != null && !due.isAfter(date);
    }).toList();
  }

  Future<RecurrenceRule?> getRecurrence(String id) {
    return (_db.select(
      _db.recurrenceRules,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Duplicates a task (including subtasks) and returns the new root id.
  Future<String> duplicate(String id) async {
    final source = await getById(id);
    if (source == null) throw StateError('Task not found: $id');
    final newId = generateId();
    await insert(_toDuplicateCompanion(source).copyWith(id: Value(newId)));
    final subs = await (_db.select(
      _db.tasks,
    )..where((t) => t.parentId.equals(id))).get();
    for (final sub in subs) {
      final newSubId = generateId();
      await insert(
        _toDuplicateCompanion(sub)
            .copyWith(id: Value(newSubId), parentId: Value(newId)),
      );
    }
    return newId;
  }

  TasksCompanion _toDuplicateCompanion(Task t) {
    return TasksCompanion(
      title: Value('${t.title} (copia)'),
      description: Value(t.description),
      status: Value('Inbox'),
      priority: Value(t.priority),
      contextId: Value(t.contextId),
      categoryId: Value(t.categoryId),
      projectId: Value(t.projectId),
      goalId: Value(t.goalId),
      startDate: Value(t.startDate),
      dueDate: Value(t.dueDate),
      estimatedMinutes: Value(t.estimatedMinutes),
      actualMinutes: const Value(0),
      energyRequired: Value(t.energyRequired),
      focusRequired: Value(t.focusRequired),
      checklistJson: Value(t.checklistJson),
      notes: Value(t.notes),
      orderIndex: Value(t.orderIndex),
    );
  }

  Future<void> insert(TasksCompanion task) => _db.into(_db.tasks).insert(task);

  Stream<List<Task>> watchByStatus(String status) {
    return (_db.select(_db.tasks)
          ..where((t) => t.status.equals(status) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .watch();
  }

  Stream<List<Task>> watchActive() {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.status.isNotIn([kStatusDone, kStatusCancelled]) &
                t.isArchived.equals(false),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Task>> watchSubtasks(String parentId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
        .watch();
  }

  /// Tasks that are scheduled on (or span) the given [date].
  Stream<List<Task>> watchForDay(DateTime date) {
    final start = startOfDay(date);
    final end = endOfDay(date);
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.isArchived.equals(false) &
                ((t.startDate.isBetweenValues(start, end)) |
                    (t.dueDate.isBetweenValues(start, end)) |
                    (t.startDate.isSmallerThanValue(start) &
                        t.dueDate.isBiggerOrEqualValue(start))),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.startDate)]))
        .watch();
  }

  Future<List<Task>> getByProject(String projectId) {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.projectId.equals(projectId))).get();
  }

  Future<List<Task>> getByGoal(String goalId) {
    return (_db.select(_db.tasks)..where((t) => t.goalId.equals(goalId))).get();
  }

  Future<Task?> getById(String id) {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Task?> watchById(String id) {
    return (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<void> update(String id, TasksCompanion task) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      task.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(id))).go();
  }

  Future<void> complete(String id, {bool done = true}) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(done ? kStatusDone : 'Next'),
        completedAt: Value(done ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setStatus(String id, String status) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(status),
        completedAt: Value(status == kStatusDone ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> countDoneBetween(DateTime start, DateTime end) {
    return _db
        .customSelect(
          'SELECT COUNT(*) as c FROM tasks WHERE status = ? '
          'AND completed_at >= ? AND completed_at <= ?',
          variables: [Variable(kStatusDone), Variable(start), Variable(end)],
          readsFrom: {_db.tasks},
        )
        .getSingle()
        .then((r) => r.read<int>('c'));
  }

  Future<int> countAll() {
    return _db
        .customSelect(
          'SELECT COUNT(*) as c FROM tasks WHERE is_archived = 0',
          readsFrom: {_db.tasks},
        )
        .getSingle()
        .then((r) => r.read<int>('c'));
  }

  Future<int> countOverdue() {
    return _db
        .customSelect(
          'SELECT COUNT(*) as c FROM tasks '
          'WHERE status NOT IN (?, ?) AND due_date < ? AND is_archived = 0',
          variables: [
            Variable(kStatusDone),
            Variable(kStatusCancelled),
            Variable(DateTime.now()),
          ],
          readsFrom: {_db.tasks},
        )
        .getSingle()
        .then((r) => r.read<int>('c'));
  }

  Future<({int total, int done})> projectProgress(String projectId) async {
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.projectId.equals(projectId))).get();
    final done = rows.where((t) => t.status == kStatusDone).length;
    return (total: rows.length, done: done);
  }

  Future<({int estimated, int actual})> projectTime(String projectId) async {
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.projectId.equals(projectId))).get();
    return (
      estimated: rows.fold(0, (s, t) => s + (t.estimatedMinutes ?? 0)),
      actual: rows.fold(0, (s, t) => s + t.actualMinutes),
    );
  }
}
