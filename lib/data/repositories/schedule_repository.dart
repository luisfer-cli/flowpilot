import 'package:drift/drift.dart';

import '../local/database.dart';
import '../../core/utils/time_utils.dart';

class ScheduleRepository {
  ScheduleRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<ScheduleTemplate>> watchTemplates() => (_db.select(
    _db.scheduleTemplates,
  )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).watch();

  Future<List<ScheduleTemplateBlock>> blocksFor(String templateId) =>
      (_db.select(_db.scheduleTemplateBlocks)
            ..where((b) => b.templateId.equals(templateId))
            ..orderBy([(b) => OrderingTerm(expression: b.weekday)]))
          .get();

  Future<void> insertTemplate(ScheduleTemplatesCompanion template) =>
      _db.into(_db.scheduleTemplates).insert(template);

  Future<void> updateTemplate(
    String id,
    ScheduleTemplatesCompanion template,
  ) async {
    await (_db.update(
      _db.scheduleTemplates,
    )..where((t) => t.id.equals(id))).write(template);
  }

  Stream<List<ScheduleTemplateBlock>> watchBlocks(String templateId) =>
      (_db.select(_db.scheduleTemplateBlocks)
            ..where((b) => b.templateId.equals(templateId))
            ..orderBy([
              (b) => OrderingTerm(expression: b.weekday),
              (b) => OrderingTerm(expression: b.startMinutes),
            ]))
          .watch();

  Future<void> insertBlock(ScheduleTemplateBlocksCompanion block) =>
      _db.into(_db.scheduleTemplateBlocks).insert(block);

  Future<void> deleteBlock(String id) async {
    await (_db.delete(
      _db.scheduleTemplateBlocks,
    )..where((b) => b.id.equals(id))).go();
  }

  Future<void> deleteTemplate(String id) async {
    await (_db.delete(
      _db.scheduleTemplateBlocks,
    )..where((b) => b.templateId.equals(id))).go();
    await (_db.delete(
      _db.scheduleTemplates,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<void> applyToWeek(String templateId, DateTime monday) async {
    final blocks = await blocksFor(templateId);
    final timeBlocks = _db.timeBlocks;
    await _db.transaction(() async {
      for (var day = 0; day < 7; day++) {
        await (_db.delete(timeBlocks)..where(
              (b) => b.dayKey.equals(dayKey(monday.add(Duration(days: day)))),
            ))
            .go();
      }
      for (final block in blocks) {
        final date = monday.add(Duration(days: block.weekday - 1));
        await _db
            .into(timeBlocks)
            .insert(
              TimeBlocksCompanion.insert(
                id: '${templateId}_${block.id}_${dayKey(date)}',
                dayKey: dayKey(date),
                startMinutes: block.startMinutes,
                endMinutes: block.endMinutes,
                title: Value(block.title),
                type: Value(block.type),
              ),
            );
      }
    });
  }
}
