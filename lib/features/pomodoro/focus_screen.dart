import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import '../tracking/tracking_screen.dart';
import 'pomodoro_screen.dart';

/// Merged module: Pomodoro / Focus + Time Tracking.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Focus',
      showTitle: false,
      tabs: [
        (label: 'Pomodoro', icon: Icons.timer, body: PomodoroView()),
        (label: 'Tracking', icon: Icons.timeline, body: TrackingView()),
      ],
    );
  }
}
