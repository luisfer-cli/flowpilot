import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Proyectos',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Análisis',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Más',
          ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    final index = navigationShell.currentIndex;
    if (index == 0) {
      return FloatingActionButton.extended(
        onPressed: () => goToTaskEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      );
    }
    if (index == 1) {
      return FloatingActionButton.extended(
        onPressed: () => goToTaskEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Tarea'),
      );
    }
    if (index == 2) {
      return FloatingActionButton.extended(
        onPressed: () => goToProjectEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Proyecto'),
      );
    }
    return const SizedBox.shrink();
  }
}
