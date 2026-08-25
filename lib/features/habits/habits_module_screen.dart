import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import 'habits_screen.dart';
import 'routines_screen.dart';

/// Merged module: Hábitos + Rutinas.
class HabitsModuleScreen extends StatelessWidget {
  const HabitsModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Hábitos',
      tabs: [
        (
          label: 'Hábitos',
          icon: Icons.check_circle_outline,
          body: HabitsView(),
        ),
        (
          label: 'Rutinas',
          icon: Icons.playlist_add_check,
          body: RoutinesView(),
        ),
      ],
    );
  }
}
