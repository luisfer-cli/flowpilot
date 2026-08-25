import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import 'breaks_screen.dart';
import 'energy_screen.dart';

/// Merged module: Energía + Descansos.
class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Bienestar',
      tabs: [
        (label: 'Energía', icon: Icons.bolt, body: EnergyView()),
        (label: 'Descansos', icon: Icons.self_improvement, body: BreaksView()),
      ],
    );
  }
}
