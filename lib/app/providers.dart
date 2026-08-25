import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import '../data/repositories/automation_repository.dart';
import '../data/repositories/calendar_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/habit_repository.dart';
import '../data/repositories/journal_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/pomodoro_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/reference_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/time_block_repository.dart';
import '../data/repositories/time_entry_repository.dart';

/// In-memory database provider. Overridden in tests with a memory database.
final databaseProvider = Provider<FlowPilotDatabase>((ref) {
  final db = FlowPilotDatabase.overridden();
  ref.onDispose(db.close);
  return db;
});

/// Seeds reference data (statuses, areas, contexts) on first launch.
final seedProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await db.customSelect('SELECT 1').getSingle();
  await ReferenceRepository(db).seedIfNeeded();
  await AutomationRepository(db).seedIfNeeded();
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(databaseProvider)),
);

final timeBlockRepositoryProvider = Provider<TimeBlockRepository>(
  (ref) => TimeBlockRepository(ref.watch(databaseProvider)),
);

final timeEntryRepositoryProvider = Provider<TimeEntryRepository>(
  (ref) => TimeEntryRepository(ref.watch(databaseProvider)),
);

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(databaseProvider)),
);

final referenceRepositoryProvider = Provider<ReferenceRepository>(
  (ref) => ReferenceRepository(ref.watch(databaseProvider)),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(databaseProvider)),
);

final pomodoroRepositoryProvider = Provider<PomodoroRepository>(
  (ref) => PomodoroRepository(ref.watch(databaseProvider)),
);

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(databaseProvider)),
);

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.watch(databaseProvider)),
);

final energyRepositoryProvider = Provider<EnergyRepository>(
  (ref) => EnergyRepository(ref.watch(databaseProvider)),
);

final automationRepositoryProvider = Provider<AutomationRepository>(
  (ref) => AutomationRepository(ref.watch(databaseProvider)),
);

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(ref.watch(databaseProvider)),
);
