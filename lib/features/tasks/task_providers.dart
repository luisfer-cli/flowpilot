import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/database.dart';

final statusesProvider = StreamProvider<List<TaskStatus>>(
  (ref) => ref.watch(referenceRepositoryProvider).watchStatuses(),
);

final contextsProvider = StreamProvider<List<Context>>(
  (ref) => ref.watch(referenceRepositoryProvider).watchContexts(),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(referenceRepositoryProvider).watchCategories(),
);

final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(referenceRepositoryProvider).watchTags(),
);

final projectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

final goalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).watchObjectives(),
);

final allTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAll(),
);

final activeTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchActive(),
);

final countsByStatusProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(referenceRepositoryProvider).countsByStatus(),
);

final taskByIdProvider = StreamProvider.family<Task?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchById(id),
);

final projectByIdProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).getByIdStream(id),
);

final tasksForDayProvider = StreamProvider.family<List<Task>, DateTime>(
  (ref, date) => ref.watch(taskRepositoryProvider).watchForDay(date),
);

final subtasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, taskId) => ref.watch(taskRepositoryProvider).watchSubtasks(taskId),
);

final projectTasksProvider = FutureProvider.family<List<Task>, String>(
  (ref, projectId) => ref.watch(taskRepositoryProvider).getByProject(projectId),
);

final goalTasksProvider = FutureProvider.family<List<Task>, String>(
  (ref, goalId) => ref.watch(taskRepositoryProvider).getByGoal(goalId),
);

final projectProgressProvider =
    FutureProvider.family<({int total, int done}), String>(
      (ref, projectId) =>
          ref.watch(taskRepositoryProvider).projectProgress(projectId),
    );

final projectTimeProvider =
    FutureProvider.family<({int estimated, int actual}), String>(
      (ref, projectId) =>
          ref.watch(taskRepositoryProvider).projectTime(projectId),
    );

/// Number of tasks completed between two dates.
final tasksDoneBetweenProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      return ref
          .watch(taskRepositoryProvider)
          .countDoneBetween(range.start, range.end);
    });

/// Total tracked minutes between two dates.
final totalMinutesBetweenProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>(
      (ref, range) => ref
          .watch(timeEntryRepositoryProvider)
          .totalMinutesBetween(range.start, range.end),
    );
