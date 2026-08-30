import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;

import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/data/repositories/schedule_repository.dart';

void main() {
  test('applies a weekly template to the current week', () async {
    final db = FlowPilotDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ScheduleRepository(db);
    await repo.insertTemplate(
      ScheduleTemplatesCompanion.insert(id: 'work', name: 'Trabajo'),
    );
    await repo.insertBlock(
      ScheduleTemplateBlocksCompanion.insert(
        id: 'focus',
        templateId: 'work',
        weekday: 1,
        startMinutes: 540,
        endMinutes: 600,
        title: 'Trabajo profundo',
        type: const Value('fixed'),
      ),
    );

    await repo.applyToWeek('work', DateTime(2026, 8, 24));
    final blocks = await db.select(db.timeBlocks).get();
    expect(blocks, hasLength(1));
    expect(blocks.single.title, 'Trabajo profundo');
    expect(blocks.single.dayKey, 20260824);
  });
}
