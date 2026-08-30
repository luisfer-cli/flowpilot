import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import 'stats_screen.dart';

/// Focused reports module.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Reportes',
      tabs: [(label: 'Resumen', icon: Icons.insights, body: StatsView())],
    );
  }
}
