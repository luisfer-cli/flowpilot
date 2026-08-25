import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';

/// Pure date-computation logic for recurrence rules. Kept free of side
/// effects so it can be unit tested.
class RecurrenceEngine {
  /// Returns the next occurrence date strictly after [from] that matches
  /// [rule]. Returns null if the rule ends before [from].
  DateTime? nextOccurrence(
    RecurrenceRule rule,
    DateTime from, {
    DateTime? currentDue,
  }) {
    final base = currentDue ?? from;
    switch (rule.frequency) {
      case kFreqDaily:
        return _afterEnd(base, from).add(Duration(days: rule.interval));
      case kFreqEveryXDays:
        return _afterEnd(base, from).add(Duration(days: rule.interval));
      case kFreqWeekly:
        final days = _parseDays(rule.daysOfWeekJson);
        if (days.isEmpty) {
          return _afterEnd(base, from).add(Duration(days: 7 * rule.interval));
        }
        return _nextWeekday(_afterEnd(base, from), days);
      case kFreqMonthly:
        final nextMonth = DateTime(
          _afterEnd(base, from).year,
          _afterEnd(base, from).month + 1,
          1,
        );
        final day = (rule.dayOfMonth ?? base.day).clamp(
          1,
          _daysInMonth(nextMonth),
        );
        var candidate = DateTime(nextMonth.year, nextMonth.month, day);
        if (!candidate.isAfter(from)) {
          candidate = DateTime(nextMonth.year, nextMonth.month + 1, day);
        }
        return candidate;
      default:
        return null;
    }
  }

  DateTime _afterEnd(DateTime base, DateTime from) {
    // If the current due is already past, start from it.
    final anchor = base.isAfter(from) ? base : from;
    return DateTime(anchor.year, anchor.month, anchor.day);
  }

  DateTime _nextWeekday(DateTime after, List<int> weekdays) {
    for (var i = 1; i <= 14; i++) {
      final candidate = after.add(Duration(days: i));
      if (weekdays.contains(candidate.weekday)) return candidate;
    }
    return after.add(const Duration(days: 7));
  }

  List<int> _parseDays(String? json) {
    if (json == null || json.isEmpty) return const [];
    return json
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  int _daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  bool get hasRecurrence => true;
}

/// Applies the recurrence engine: when a recurring task is completed, creates
/// the next occurrence (a fresh task) from the stored rule.
class RecurrenceService {
  RecurrenceService(this._ref);
  final Ref _ref;

  final RecurrenceEngine _engine = RecurrenceEngine();

  Future<void> onTaskCompleted(Task task) async {
    if (task.recurrenceId == null) return;
    final rule = await _ref
        .read(taskRepositoryProvider)
        .getRecurrence(task.recurrenceId!);
    if (rule == null) return;
    final due = task.dueDate ?? DateTime.now();
    final next = _engine.nextOccurrence(rule, DateTime.now(), currentDue: due);
    if (next == null) return;
    if (rule.endDate != null && next.isAfter(rule.endDate!)) return;

    final newId = generateId();
    await _ref
        .read(taskRepositoryProvider)
        .insert(
          TasksCompanion(
            id: Value(newId),
            title: Value(task.title),
            description: Value(task.description),
            status: const Value('Inbox'),
            priority: Value(task.priority),
            contextId: Value(task.contextId),
            categoryId: Value(task.categoryId),
            projectId: Value(task.projectId),
            goalId: Value(task.goalId),
            dueDate: Value(next),
            estimatedMinutes: Value(task.estimatedMinutes),
            energyRequired: Value(task.energyRequired),
            focusRequired: Value(task.focusRequired),
            checklistJson: Value(task.checklistJson),
            notes: Value(task.notes),
            recurrenceId: Value(rule.id),
          ),
        );
  }
}

final recurrenceEngineProvider = Provider<RecurrenceEngine>(
  (ref) => RecurrenceEngine(),
);

final recurrenceServiceProvider = Provider<RecurrenceService>(
  (ref) => RecurrenceService(ref),
);
