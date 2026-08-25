import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_card.dart';

/// "Tengo 20 minutos y estoy en el teléfono" → shows suitable tasks.
class ContextView extends ConsumerStatefulWidget {
  const ContextView({super.key});

  @override
  ConsumerState<ContextView> createState() => _ContextViewState();
}

class _ContextViewState extends ConsumerState<ContextView> {
  String? _contextId;
  int _availableMinutes = 20;

  @override
  Widget build(BuildContext context) {
    final contextsAsync = ref.watch(contextsProvider);
    final tasksAsync = ref.watch(activeTasksProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _contextId,
                  decoration: const InputDecoration(labelText: 'Contexto'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Cualquiera'),
                    ),
                    for (final c
                        in contextsAsync.valueOrNull ?? const <Context>[])
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _contextId = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Tiempo disponible:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _availableMinutes,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10 min')),
                        DropdownMenuItem(value: 20, child: Text('20 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 60, child: Text('1 h')),
                        DropdownMenuItem(value: 120, child: Text('2 h')),
                      ],
                      onChanged: (v) =>
                          setState(() => _availableMinutes = v ?? 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        tasksAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (tasks) {
            final filtered = tasks.where((t) {
              if (_contextId != null && t.contextId != _contextId) {
                return false;
              }
              if (t.estimatedMinutes != null &&
                  t.estimatedMinutes! > _availableMinutes + 10) {
                return false;
              }
              return true;
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  'Tareas adecuadas',
                  trailing: Text(
                    '${filtered.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off,
                    title: 'Sin tareas adecuadas',
                    subtitle: 'Cambia el contexto o el tiempo disponible',
                  )
                else
                  for (final t in filtered) TaskCard(task: t),
              ],
            );
          },
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}
