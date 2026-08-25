import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

/// Shows the relationship graph for a selected task:
/// goal <-> project <-> task <-> pomodoro <-> time entries.
class RelationsScreen extends ConsumerStatefulWidget {
  const RelationsScreen({super.key});

  @override
  ConsumerState<RelationsScreen> createState() => _RelationsScreenState();
}

class _RelationsScreenState extends ConsumerState<RelationsScreen> {
  String? _selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? const <Task>[];
    final projects =
        ref.watch(projectsProvider).valueOrNull ?? const <Project>[];
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Relaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Selecciona una tarea para ver su grafo de relaciones.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _selectedTaskId,
            decoration: const InputDecoration(labelText: 'Tarea'),
            items: [
              for (final t in tasks)
                DropdownMenuItem(
                  value: t.id,
                  child: Text(t.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _selectedTaskId = v),
          ),
          const SizedBox(height: 16),
          if (_selectedTaskId == null)
            const EmptyState(
              icon: Icons.hub_outlined,
              title: 'Selecciona una tarea',
            )
          else
            _buildGraph(_selectedTaskId!, tasks, projects, goals),
        ],
      ),
    );
  }

  Widget _buildGraph(
    String taskId,
    List<Task> tasks,
    List<Project> projects,
    List<Goal> goals,
  ) {
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return const SizedBox.shrink();
    final project = task.projectId == null
        ? null
        : projects.where((p) => p.id == task.projectId).firstOrNull;
    final goal = task.goalId == null
        ? null
        : goals.where((g) => g.id == task.goalId).firstOrNull;
    final subtasks = tasks.where((t) => t.parentId == taskId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _node('Tarea', task.title, Icons.task_alt),
        if (goal != null) ...[
          const SizedBox(height: 8),
          _link(),
          _node('Objetivo', goal.title, Icons.flag),
        ],
        if (project != null) ...[
          const SizedBox(height: 8),
          _link(),
          _node('Proyecto', project.name, Icons.folder),
        ],
        if (subtasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _link(),
          for (final s in subtasks)
            _node('Subtarea', s.title, Icons.check_circle_outline),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Las relaciones conectan objetivo → proyecto → tarea → pomodoro → time entries '
              'para análisis profundos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _node(String kind, String label, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(kind),
      ),
    );
  }

  Widget _link() {
    return const Center(
      child: Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
    );
  }
}
