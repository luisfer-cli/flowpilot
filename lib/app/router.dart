import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/habits/habits_module_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/pomodoro/pomodoro_screen.dart';
import '../features/stats/analysis_screen.dart';
import '../features/tasks/task_edit_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/settings/settings_screen.dart';
import 'home_shell.dart';

class AppRouter {
  static const tasks = '/';
  static const pomodoro = '/pomodoro';
  static const agenda = '/agenda';
  static const routines = '/routines';
  static const stats = '/reports';
  static const taskEdit = '/task/edit';
  static const settings = '/settings';

  static GoRouter router() => GoRouter(
    initialLocation: agenda,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: agenda, builder: (_, _) => const CalendarScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: tasks, builder: (_, _) => const TasksScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: pomodoro,
                builder: (_, _) => const PomodoroModuleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: routines,
                builder: (_, _) => const HabitsModuleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: stats, builder: (_, _) => const AnalysisScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: settings,
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: taskEdit,
        builder: (_, state) =>
            TaskEditScreen(taskId: state.uri.queryParameters['id']),
      ),
    ],
  );
}

void goToTaskEdit(BuildContext context, {String? id}) {
  final uri = Uri(path: AppRouter.taskEdit, queryParameters: {'id': ?id});
  context.push(uri.toString());
}
