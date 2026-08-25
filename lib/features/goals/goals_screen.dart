import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProvider);
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            tooltip: 'Nuevo objetivo',
            onPressed: () => goToGoalEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Nueva área',
            onPressed: () => _addArea(context, ref),
          ),
        ],
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (areas) {
          final goals = goalsAsync.valueOrNull ?? const <Goal>[];
          if (areas.isEmpty && goals.isEmpty) {
            return const EmptyState(
              icon: Icons.flag,
              title: 'Sin objetivos',
              subtitle: 'Define tus áreas de vida y objetivos',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionHeader('Áreas de vida'),
              const SizedBox(height: 6),
              if (areas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Crea tu primera área'),
                )
              else
                for (final area in areas) _AreaTile(area: area),
              const SizedBox(height: 24),
              SectionHeader('Objetivos'),
              const SizedBox(height: 6),
              if (goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Sin objetivos aún'),
                )
              else
                for (final goal in goals) _GoalTile(goal: goal),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
    );
  }
}

class _AreaTile extends ConsumerWidget {
  const _AreaTile({required this.area});

  final Area area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(area.color);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(Icons.category, color: color, size: 20),
        ),
        title: Text(area.name),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') {
              goToGoalEdit(context);
            }
            if (v == 'delete') {
              ref.read(goalRepositoryProvider).deleteArea(area.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(goalProgressProvider(goal.id));
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => goToGoalEdit(context, id: goal.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (goal.deadline != null)
                    Text(
                      '${goal.deadline!.difference(DateTime.now()).inDays} días',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              progressAsync.when(
                loading: () => const LinearProgressIndicator(),
                data: (p) {
                  return Column(
                    children: [
                      LinearProgressIndicator(
                        value: p,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(p * 100).round()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  );
                },
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final goalProgressProvider = FutureProvider.family<double, String>((
  ref,
  goalId,
) async {
  final goal = await ref.watch(goalRepositoryProvider).getById(goalId);
  if (goal == null) return 0;
  return ref.watch(goalRepositoryProvider).progressOf(goal);
});

final goalInvestedProvider = FutureProvider.family<int, String>((
  ref,
  goalId,
) async {
  final goal = await ref.watch(goalRepositoryProvider).getById(goalId);
  if (goal == null) return 0;
  return ref.watch(goalRepositoryProvider).investedMinutes(goal);
});

final areasProvider = StreamProvider<List<Area>>(
  (ref) => ref.watch(goalRepositoryProvider).watchAreas(),
);

Future<void> _addArea(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nueva área de vida'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Trabajo, Salud, …'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  final name = controller.text.trim();
  if (name.isEmpty) return;
  await ref
      .read(goalRepositoryProvider)
      .insertArea(AreasCompanion.insert(id: generateId(), name: name));
}
