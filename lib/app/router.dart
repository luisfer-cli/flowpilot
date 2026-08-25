import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/ai_assistant_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/energy/automations_screen.dart';
import '../features/energy/journal_screen.dart';
import '../features/energy/relations_screen.dart';
import '../features/energy/search_screen.dart';
import '../features/energy/wellbeing_screen.dart';
import '../features/goals/goal_edit_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/habits/habits_module_screen.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/pomodoro/focus_screen.dart';
import '../features/energy/prioritize_screen.dart';
import '../features/projects/project_edit_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/analysis_screen.dart';
import '../features/tasks/task_edit_screen.dart';
import '../features/tasks/tasks_screen.dart';
import 'home_shell.dart';
import 'more_screen.dart';

class AppRouter {
  static const today = '/';
  static const tasks = '/tasks';
  static const projects = '/projects';
  static const stats = '/stats';
  static const more = '/more';
  static const settings = '/settings';
  static const taskEdit = '/task/edit';
  static const projectEdit = '/project/edit';
  static const goalEdit = '/goal/edit';
  static const goals = '/goals';
  static const focus = '/focus';
  static const wellbeing = '/wellbeing';
  static const prioritize = '/prioritize';
  static const habits = '/habits';
  static const calendar = '/calendar';
  static const review = '/review';
  static const reminders = '/reminders';
  static const inbox = '/inbox';
  static const aiAssistant = '/ai';
  static const search = '/search';
  static const relations = '/relations';
  static const automations = '/automations';
  static const journal = '/journal';

  static GoRouter router() {
    return GoRouter(
      initialLocation: today,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              HomeShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: today, builder: (_, _) => const TodayView()),
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
                  path: projects,
                  builder: (_, _) => const ProjectsScreen(),
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
                GoRoute(path: more, builder: (_, _) => const MoreScreen()),
              ],
            ),
          ],
        ),
        GoRoute(
          path: taskEdit,
          builder: (_, state) =>
              TaskEditScreen(taskId: state.uri.queryParameters['id']),
        ),
        GoRoute(
          path: projectEdit,
          builder: (_, state) =>
              ProjectEditScreen(projectId: state.uri.queryParameters['id']),
        ),
        GoRoute(
          path: goalEdit,
          builder: (_, state) =>
              GoalEditScreen(goalId: state.uri.queryParameters['id']),
        ),
        GoRoute(path: settings, builder: (_, _) => const SettingsScreen()),
        GoRoute(path: goals, builder: (_, _) => const GoalsScreen()),
        GoRoute(path: focus, builder: (_, _) => const FocusScreen()),
        GoRoute(path: wellbeing, builder: (_, _) => const WellbeingScreen()),
        GoRoute(path: prioritize, builder: (_, _) => const PrioritizeScreen()),
        GoRoute(path: habits, builder: (_, _) => const HabitsModuleScreen()),
        GoRoute(path: calendar, builder: (_, _) => const CalendarScreen()),
        GoRoute(path: review, builder: (_, _) => const ReviewScreen()),
        GoRoute(path: reminders, builder: (_, _) => const RemindersScreen()),
        GoRoute(path: inbox, builder: (_, _) => const InboxScreen()),
        GoRoute(
          path: aiAssistant,
          builder: (_, _) => const AiAssistantScreen(),
        ),
        GoRoute(path: search, builder: (_, _) => const SearchScreen()),
        GoRoute(path: relations, builder: (_, _) => const RelationsScreen()),
        GoRoute(
          path: automations,
          builder: (_, _) => const AutomationsScreen(),
        ),
        GoRoute(path: journal, builder: (_, _) => const JournalScreen()),
      ],
    );
  }
}

class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    return const CalendarScreen();
  }
}

/// Helper for navigating to a task edit (create or edit).
void goToTaskEdit(BuildContext context, {String? id}) {
  final uri = Uri(path: AppRouter.taskEdit, queryParameters: {'id': ?id});
  context.push(uri.toString());
}

void goToProjectEdit(BuildContext context, {String? id}) {
  final uri = Uri(path: AppRouter.projectEdit, queryParameters: {'id': ?id});
  context.push(uri.toString());
}

void goToGoalEdit(BuildContext context, {String? id}) {
  final uri = Uri(path: AppRouter.goalEdit, queryParameters: {'id': ?id});
  context.push(uri.toString());
}
