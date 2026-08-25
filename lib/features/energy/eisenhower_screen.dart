import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_card.dart';

/// Eisenhower matrix: urgency vs importance quadrant.
/// We derive urgency from due date proximity and importance from priority.
enum Quadrant { doFirst, schedule, delegate, eliminate }

class EisenhowerView extends ConsumerWidget {
  const EisenhowerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? const <Task>[];
    final urgent = tasks.where((t) => _isUrgent(t)).toList();
    final important = tasks.where((t) => t.priority >= 3).toList();
    final importantIds = important.map((t) => t.id).toSet();
    final urgentIds = urgent.map((t) => t.id).toSet();

    final doFirst = tasks
        .where((t) => importantIds.contains(t.id) && urgentIds.contains(t.id))
        .toList();
    final schedule = tasks
        .where((t) => importantIds.contains(t.id) && !urgentIds.contains(t.id))
        .toList();
    final delegate = tasks
        .where((t) => !importantIds.contains(t.id) && urgentIds.contains(t.id))
        .toList();
    final eliminate = tasks
        .where((t) => !importantIds.contains(t.id) && !urgentIds.contains(t.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _quadrant(
          context,
          'Hacer primero (urgente + importante)',
          doFirst,
          Colors.redAccent,
        ),
        _quadrant(
          context,
          'Programar (importante, no urgente)',
          schedule,
          Colors.blue,
        ),
        _quadrant(
          context,
          'Delegar (urgente, no importante)',
          delegate,
          Colors.orange,
        ),
        _quadrant(
          context,
          'Eliminar (ni urgente ni importante)',
          eliminate,
          Colors.grey,
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  bool _isUrgent(Task t) {
    if (t.dueDate == null) return false;
    return t.dueDate!.difference(DateTime.now()).inHours < 48;
  }

  Widget _quadrant(
    BuildContext context,
    String title,
    List<Task> tasks,
    Color color,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${tasks.length}', style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          if (tasks.isEmpty)
            const Padding(padding: EdgeInsets.all(8), child: Text('Vacío'))
          else
            for (final t in tasks) TaskCard(task: t, dense: true),
        ],
      ),
    );
  }
}
