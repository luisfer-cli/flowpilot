import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/features/recurrence/recurrence_engine.dart';

RecurrenceRule rule({
  String freq = 'daily',
  int interval = 1,
  String? days,
  int? dayOfMonth,
  DateTime? endDate,
}) {
  return RecurrenceRule(
    id: 'r1',
    frequency: freq,
    interval: interval,
    daysOfWeekJson: days,
    dayOfMonth: dayOfMonth,
    endDate: endDate,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final engine = RecurrenceEngine();

  test('daily advances one day', () {
    final next = engine.nextOccurrence(
      rule(),
      DateTime(2026, 1, 1),
      currentDue: DateTime(2026, 1, 1),
    );
    expect(next, DateTime(2026, 1, 2));
  });

  test('every X days advances by interval', () {
    final next = engine.nextOccurrence(
      rule(freq: 'every_x_days', interval: 3),
      DateTime(2026, 1, 1),
      currentDue: DateTime(2026, 1, 1),
    );
    expect(next, DateTime(2026, 1, 4));
  });

  test('weekly on specific days picks next matching weekday', () {
    // Weekdays 1..7 (Mon..Sun). Wed=3, Fri=5. From Tue Jan 6 2026 -> next Wed Jan 7.
    final next = engine.nextOccurrence(
      rule(freq: 'weekly', days: '3,5'),
      DateTime(2026, 1, 6),
      currentDue: DateTime(2026, 1, 6),
    );
    expect(next, DateTime(2026, 1, 7));
  });

  test('monthly uses day of month', () {
    final next = engine.nextOccurrence(
      rule(freq: 'monthly', dayOfMonth: 15),
      DateTime(2026, 1, 1),
      currentDue: DateTime(2026, 1, 15),
    );
    expect(next, DateTime(2026, 2, 15));
  });

  test('monthly clamps to month length', () {
    final next = engine.nextOccurrence(
      rule(freq: 'monthly', dayOfMonth: 31),
      DateTime(2026, 1, 31),
      currentDue: DateTime(2026, 1, 31),
    );
    // February 2026 has 28 days.
    expect(next, DateTime(2026, 2, 28));
  });

  test('repository exposes recurring tasks and retrieves rule', () async {
    final db = FlowPilotDatabase(NativeDatabase.memory());
    final repo = db;
    await repo
        .into(repo.recurrenceRules)
        .insert(RecurrenceRulesCompanion.insert(id: 'r-x', frequency: 'daily'));
    await repo
        .into(repo.tasks)
        .insert(
          TasksCompanion.insert(
            id: 't-x',
            title: 'Recurring',
            recurrenceId: const Value('r-x'),
            dueDate: Value(DateTime(2026, 1, 1)),
          ),
        );

    final engine2 = RecurrenceEngine();
    final taskRepo = db;
    final recurring = await taskRepo
        .customSelect(
          'SELECT * FROM tasks WHERE recurrence_id IS NOT NULL',
          readsFrom: {db.tasks},
        )
        .get();
    expect(recurring, hasLength(1));

    final r = await db.select(db.recurrenceRules).getSingle();
    final next = engine2.nextOccurrence(
      r,
      DateTime(2026, 1, 1),
      currentDue: DateTime(2026, 1, 1),
    );
    expect(next, DateTime(2026, 1, 2));

    await db.close();
  });
}
