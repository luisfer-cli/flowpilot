import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/data/repositories/reports_repository.dart';
import 'package:flowpilot/data/repositories/habit_repository.dart';

void main() {
  test('routine completion is included in the report', () async {
    final db = FlowPilotDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final routineRepo = RoutineRepository(db);
    final today = DateTime.now();
    final routineId = 'routine-1';

    await routineRepo.insert(
      RoutinesCompanion.insert(
        id: routineId,
        name: 'Rutina diaria',
        timeOfDayMinutes: const Value(8 * 60),
        endTimeMinutes: const Value(9 * 60),
        daysOfWeekJson: Value('[${today.weekday}]'),
      ),
    );
    await routineRepo.toggleCompletion(routineId, today);

    final report = await ReportsRepository(db).load(
      ReportFilter(
        start: DateTime(today.year, today.month, today.day),
        end: DateTime(today.year, today.month, today.day, 23, 59, 59),
      ),
    );

    expect(report.plannedRoutineCount, 1);
    expect(report.completedRoutineCount, 1);
    expect(report.completedRoutineMinutes, 60);
  });
}
