import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (
        icon: Icons.calendar_today_outlined,
        selected: Icons.calendar_today,
        label: l10n.agenda,
      ),
      (
        icon: Icons.check_circle_outline,
        selected: Icons.check_circle,
        label: l10n.tasks,
      ),
      (icon: Icons.timer_outlined, selected: Icons.timer, label: l10n.pomodoro),
      (
        icon: Icons.repeat_outlined,
        selected: Icons.repeat,
        label: l10n.routines,
      ),
      (
        icon: Icons.insights_outlined,
        selected: Icons.insights,
        label: l10n.reports,
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        label: l10n.settings,
      ),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useRail = constraints.maxWidth >= 840;
          final content = AppContent(maxWidth: 1360, child: navigationShell);
          if (!useRail) return content;
          return Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) => navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  ),
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 20),
                    child: Icon(Icons.auto_awesome_motion_outlined),
                  ),
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selected),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 840) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            destinations: [
              for (final item in destinations)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selected),
                  label: item.label,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final index = navigationShell.currentIndex;
    if (index == 1) {
      return FloatingActionButton.extended(
        onPressed: () => goToTaskEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      );
    }
    return const SizedBox.shrink();
  }
}
