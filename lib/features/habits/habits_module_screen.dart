import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import 'routines_screen.dart';
import '../schedules/schedules_screen.dart';

/// Minimal planning module focused on repeatable routines.
class HabitsModuleScreen extends StatelessWidget {
  const HabitsModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Planificación',
      showTitle: false,
      tabs: [
        (
          label: 'Rutinas',
          icon: Icons.playlist_add_check,
          body: RoutinesView(),
        ),
        (
          label: 'Horarios',
          icon: Icons.calendar_view_week_outlined,
          body: SchedulesView(),
        ),
      ],
    );
  }
}
