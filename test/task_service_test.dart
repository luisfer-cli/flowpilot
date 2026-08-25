import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowpilot/app/providers.dart';
import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/data/repositories/task_repository.dart';
import 'package:flowpilot/features/recurrence/recurrence_engine.dart';

void main() {
  late FlowPilotDatabase db;
  late TaskRepository taskRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FlowPilotDatabase(NativeDatabase.memory());
    taskRepo = TaskRepository(db);
    await db.customSelect('SELECT 1').getSingle();
  });

  tearDown(() async {
    await db.close();
  });

  test('duplicate copies a task and its subtasks', () async {
    await taskRepo.insert(TasksCompanion.insert(id: 'parent', title: 'Tarea'));
    await taskRepo.insert(
      TasksCompanion.insert(
        id: 'sub1',
        title: 'Subtarea',
        parentId: const Value('parent'),
      ),
    );

    final newId = await taskRepo.duplicate('parent');

    final parent = await taskRepo.getById('parent');
    final copy = await taskRepo.getById(newId);
    expect(copy, isNotNull);
    expect(copy!.title, 'Tarea (copia)');
    expect(parent!.id, isNot(newId));

    final subs = await db
        .customSelect(
          'SELECT * FROM tasks WHERE parent_id = ?',
          variables: [Variable(newId)],
          readsFrom: {db.tasks},
        )
        .get();
    expect(subs, hasLength(1));
  });

  test('recurrence engine generates next instance via service', () async {
    // Seed a rule + recurring task.
    await db
        .into(db.recurrenceRules)
        .insert(RecurrenceRulesCompanion.insert(id: 'rr', frequency: 'daily'));
    final task = Task(
      id: 'recur',
      title: 'Estudiar',
      status: 'Inbox',
      priority: 0,
      actualMinutes: 0,
      isEvent: false,
      isArchived: false,
      orderIndex: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 1),
      recurrenceId: 'rr',
    );

    // Provide overrides so the service can read the repos.
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await container.read(recurrenceServiceProvider).onTaskCompleted(task);

    final created = await db
        .customSelect(
          'SELECT * FROM tasks WHERE title = ? AND id != ?',
          variables: [Variable('Estudiar'), Variable('recur')],
          readsFrom: {db.tasks},
        )
        .get();
    expect(created, hasLength(1));
    expect(created.first.read<String>('recurrence_id'), 'rr');
  });
}
