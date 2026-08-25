import 'package:drift/drift.dart';

import '../local/database.dart';

class CalendarRepository {
  CalendarRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<CalendarEvent>> watchBetween(DateTime start, DateTime end) {
    return (_db.select(_db.calendarEvents)
          ..where((e) => e.start.isBetweenValues(start, end))
          ..orderBy([(e) => OrderingTerm(expression: e.start)]))
        .watch();
  }

  Stream<List<CalendarEvent>> watchByDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.calendarEvents)
          ..where(
            (e) =>
                e.start.isBetweenValues(start, end) |
                (e.start.isSmallerThanValue(start) &
                    e.end.isBiggerOrEqualValue(start)),
          )
          ..orderBy([(e) => OrderingTerm(expression: e.start)]))
        .watch();
  }

  Future<void> insertEvent(CalendarEventsCompanion e) =>
      _db.into(_db.calendarEvents).insert(e);

  Future<void> updateEvent(String id, CalendarEventsCompanion e) async {
    await (_db.update(
      _db.calendarEvents,
    )..where((x) => x.id.equals(id))).write(e);
  }

  Future<void> deleteEvent(String id) async {
    await (_db.delete(_db.calendarEvents)..where((e) => e.id.equals(id))).go();
  }

  Stream<List<Reminder>> watchUpcoming({DateTime? from}) {
    final now = from ?? DateTime.now();
    return (_db.select(_db.reminders)
          ..where(
            (r) =>
                r.enabled.equals(true) & r.triggerAt.isBiggerOrEqualValue(now),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.triggerAt)]))
        .watch();
  }

  Future<List<Reminder>> getUpcoming({DateTime? from}) async {
    final now = from ?? DateTime.now();
    return (_db.select(_db.reminders)
          ..where(
            (r) =>
                r.enabled.equals(true) & r.triggerAt.isBiggerOrEqualValue(now),
          )
          ..orderBy([(r) => OrderingTerm(expression: r.triggerAt)]))
        .get();
  }

  Future<void> insertReminder(RemindersCompanion r) =>
      _db.into(_db.reminders).insert(r);

  Future<void> deleteReminder(String id) async {
    await (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();
  }
}
