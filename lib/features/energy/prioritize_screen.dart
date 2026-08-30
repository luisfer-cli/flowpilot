import 'package:flutter/material.dart';

import '../../shared/module_tabs.dart';
import 'context_screen.dart';
import 'eisenhower_screen.dart';

/// Merged module: Matriz Eisenhower + Por contexto.
class PrioritizeScreen extends StatelessWidget {
  const PrioritizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleTabHost(
      title: 'Priorizar',
      showTitle: false,
      tabs: [
        (label: 'Matriz', icon: Icons.grid_view, body: EisenhowerView()),
        (label: 'Contexto', icon: Icons.place, body: ContextView()),
      ],
    );
  }
}
