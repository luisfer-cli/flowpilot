import 'dart:convert';

import 'package:drift/drift.dart';

import '../local/database.dart';

class ReportFilter {
  const ReportFilter({required this.start, required this.end, this.categoryId});

  final DateTime start;
  final DateTime end;
  final String? categoryId;
}

class ReportsSnapshot {
  const ReportsSnapshot({
    required this.totalMinutes,
    required this.focusMinutes,
    required this.pomodoroMinutes,
    required this.pomodoroSessions,
    required this.completedTasks,
    required this.pendingTasks,
    required this.categoryMinutes,
    required this.categoryTaskCompletions,
    required this.plannedRoutineCount,
    required this.completedRoutineCount,
    required this.plannedRoutineMinutes,
    required this.completedRoutineMinutes,
    required this.plannedScheduleMinutes,
  });

  final int totalMinutes;
  final int focusMinutes;
  final int pomodoroMinutes;
  final int pomodoroSessions;
  final int completedTasks;
  final int pendingTasks;
  final Map<String, int> categoryMinutes;
  final Map<String, int> categoryTaskCompletions;
  final int plannedRoutineCount;
  final int completedRoutineCount;
  final int plannedRoutineMinutes;
  final int completedRoutineMinutes;
  final int plannedScheduleMinutes;

  double get routineCompletionRate => plannedRoutineCount == 0
      ? 0
      : completedRoutineCount / plannedRoutineCount;
}

class ReportsRepository {
  ReportsRepository(this._db);
  final FlowPilotDatabase _db;

  Future<ReportsSnapshot> load(ReportFilter filter) async {
    final categories = await _db.select(_db.categories).get();
    final categoryNames = {for (final c in categories) c.id: c.name};
    final entries = await (_db.select(
      _db.timeEntries,
    )..where((e) => e.start.isBetweenValues(filter.start, filter.end))).get();
    final tasks = await (_db.select(_db.tasks)).get();
    final taskById = {for (final task in tasks) task.id: task};

    var totalMinutes = 0;
    var focusMinutes = 0;
    var pomodoroMinutes = 0;
    var pomodoroSessions = 0;
    final categoryMinutes = <String, int>{};
    for (final entry in entries) {
      final minutes = entry.durationMinutes ?? 0;
      final categoryId = entry.categoryId ?? taskById[entry.taskId]?.categoryId;
      if (filter.categoryId != null && categoryId != filter.categoryId) {
        continue;
      }
      totalMinutes += minutes;
      if (entry.source == 'pomodoro' || entry.taskId != null) {
        focusMinutes += minutes;
      }
      if (entry.source == 'pomodoro') pomodoroMinutes += minutes;
      if (categoryId != null || filter.categoryId == null) {
        final name = categoryId == null
            ? 'Sin categoría'
            : categoryNames[categoryId] ?? 'Sin categoría';
        categoryMinutes[name] = (categoryMinutes[name] ?? 0) + minutes;
      }
    }

    final sessions =
        await (_db.select(_db.pomodoroSessions)..where(
              (s) =>
                  s.start.isBetweenValues(filter.start, filter.end) &
                  s.completed.equals(true),
            ))
            .get();
    pomodoroSessions = sessions.where((session) {
      if (filter.categoryId == null) return true;
      return taskById[session.taskId]?.categoryId == filter.categoryId;
    }).length;

    var completedTasks = 0;
    var pendingTasks = 0;
    final categoryTaskCompletions = <String, int>{};
    for (final task in tasks) {
      if (task.isArchived ||
          (filter.categoryId != null && task.categoryId != filter.categoryId)) {
        continue;
      }
      final relevant =
          task.completedAt != null &&
          task.completedAt!.isBetween(filter.start, filter.end);
      if (task.status == 'Completada' && relevant) {
        completedTasks++;
        final categoryId = task.categoryId;
        if (categoryId != null) {
          final name = categoryNames[categoryId] ?? 'Sin categoría';
          categoryTaskCompletions[name] =
              (categoryTaskCompletions[name] ?? 0) + 1;
        }
      } else if (task.status != 'Completada' && _taskIsInRange(task, filter)) {
        pendingTasks++;
      }
    }

    final routines = await (_db.select(
      _db.routines,
    )..where((r) => r.active.equals(true))).get();
    final completions = await (_db.select(
      _db.routineCompletions,
    )..where((r) => r.date.isBetweenValues(filter.start, filter.end))).get();
    final completedRoutineKeys = {
      for (final completion in completions)
        '${completion.routineId}:${_dayKey(completion.date)}',
    };
    var plannedRoutineCount = 0;
    var completedRoutineCount = 0;
    var plannedRoutineMinutes = 0;
    var completedRoutineMinutes = 0;
    for (
      var day = _dayOnly(filter.start);
      !day.isAfter(_dayOnly(filter.end));
      day = day.add(const Duration(days: 1))
    ) {
      for (final routine in routines) {
        if (filter.categoryId != null &&
            routine.categoryId != filter.categoryId) {
          continue;
        }
        if (!_daysForRoutine(routine.daysOfWeekJson).contains(day.weekday) ||
            routine.timeOfDayMinutes == null ||
            routine.endTimeMinutes == null) {
          continue;
        }
        final minutes = routine.endTimeMinutes! - routine.timeOfDayMinutes!;
        plannedRoutineCount++;
        plannedRoutineMinutes += minutes;
        if (completedRoutineKeys.contains('${routine.id}:${_dayKey(day)}')) {
          completedRoutineCount++;
          completedRoutineMinutes += minutes;
        }
      }
    }

    final templates = await (_db.select(
      _db.scheduleTemplates,
    )..where((t) => t.active.equals(true))).get();
    var plannedScheduleMinutes = 0;
    for (final template in templates) {
      if (filter.categoryId != null &&
          template.categoryId != filter.categoryId) {
        continue;
      }
      final blocks = await (_db.select(
        _db.scheduleTemplateBlocks,
      )..where((b) => b.templateId.equals(template.id))).get();
      for (
        var day = _dayOnly(filter.start);
        !day.isAfter(_dayOnly(filter.end));
        day = day.add(const Duration(days: 1))
      ) {
        for (final block in blocks) {
          if (block.weekday == day.weekday) {
            plannedScheduleMinutes += block.endMinutes - block.startMinutes;
          }
        }
      }
    }

    return ReportsSnapshot(
      totalMinutes: totalMinutes,
      focusMinutes: focusMinutes,
      pomodoroMinutes: pomodoroMinutes,
      pomodoroSessions: pomodoroSessions,
      completedTasks: completedTasks,
      pendingTasks: pendingTasks,
      categoryMinutes: _sorted(categoryMinutes),
      categoryTaskCompletions: _sorted(categoryTaskCompletions),
      plannedRoutineCount: plannedRoutineCount,
      completedRoutineCount: completedRoutineCount,
      plannedRoutineMinutes: plannedRoutineMinutes,
      completedRoutineMinutes: completedRoutineMinutes,
      plannedScheduleMinutes: plannedScheduleMinutes,
    );
  }

  bool _taskIsInRange(Task task, ReportFilter filter) {
    return (task.dueDate != null &&
            task.dueDate!.isBetween(filter.start, filter.end)) ||
        (task.startDate != null &&
            task.startDate!.isBetween(filter.start, filter.end));
  }

  List<int> _daysForRoutine(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List).cast<int>();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> _sorted(Map<String, int> values) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dayKey(DateTime value) => '${value.year}-${value.month}-${value.day}';
}

extension on DateTime {
  bool isBetween(DateTime start, DateTime end) =>
      !isBefore(start) && !isAfter(end);
}
