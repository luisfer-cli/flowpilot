import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import '../shared/widgets.dart';

/// Hub "Más": groups all secondary modules by category.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Ajustes',
            onPressed: () => context.push(AppRouter.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'Enfoque', Icons.center_focus_strong, [
            (Icons.timer, 'Focus', AppRouter.focus),
            (Icons.self_improvement, 'Bienestar', AppRouter.wellbeing),
          ]),
          _section(context, 'Planificación', Icons.event_note, [
            (Icons.calendar_month, 'Calendario', AppRouter.calendar),
            (Icons.reviews, 'Revisiones', AppRouter.review),
            (
              Icons.notifications_outlined,
              'Recordatorios',
              AppRouter.reminders,
            ),
            (Icons.grid_view, 'Priorizar', AppRouter.prioritize),
          ]),
          _section(context, 'Crecimiento', Icons.trending_up, [
            (Icons.flag, 'Objetivos', AppRouter.goals),
            (Icons.check_circle_outline, 'Hábitos', AppRouter.habits),
            (Icons.menu_book, 'Diario', AppRouter.journal),
          ]),
          _section(context, 'Captura e IA', Icons.auto_awesome, [
            (Icons.inbox_outlined, 'Inbox', AppRouter.inbox),
            (Icons.search, 'Búsqueda universal', AppRouter.search),
            (Icons.smart_toy_outlined, 'Asistente IA', AppRouter.aiAssistant),
          ]),
          _section(context, 'Sistema', Icons.settings, [
            (Icons.auto_mode, 'Automatizaciones', AppRouter.automations),
            (Icons.hub_outlined, 'Relaciones', AppRouter.relations),
            (Icons.settings, 'Ajustes', AppRouter.settings),
          ]),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData sectionIcon,
    List<(IconData, String, String)> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Icon(items[i].$1),
                    title: Text(items[i].$2),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(items[i].$3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
