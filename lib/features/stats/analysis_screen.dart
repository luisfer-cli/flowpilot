import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import '../energy/balance_screen.dart';
import '../energy/capacity_screen.dart';
import '../energy/problems_screen.dart';
import '../energy/profile_screen.dart';
import 'stats_screen.dart';

/// Merged analytics module: Resumen (stats) + Capacidad + Problemas + Perfil
/// + Balance de vida.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Análisis',
      tabs: [
        (label: 'Resumen', icon: Icons.insights, body: StatsView()),
        (label: 'Capacidad', icon: Icons.speed, body: CapacityView()),
        (
          label: 'Problemas',
          icon: Icons.report_problem_outlined,
          body: ProblemsView(),
        ),
        (
          label: 'Perfil',
          icon: Icons.person_pin,
          body: ProductivityProfileView(),
        ),
        (label: 'Balance', icon: Icons.donut_large, body: BalanceView()),
      ],
    );
  }
}
