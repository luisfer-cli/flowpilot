import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

/// Balance of life: time distribution across life areas (work, health, etc.)
class BalanceView extends ConsumerWidget {
  const BalanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProvider);
    final balanceAsync = ref.watch(lifeBalanceProvider);
    final theme = Theme.of(context);

    return areasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (areas) {
        final balance = balanceAsync.valueOrNull ?? const <String, int>{};
        final total = balance.values.fold(0, (a, b) => a + b);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (total == 0)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aún no hay tiempo registrado. Registra tiempo en las tareas para ver tu balance.',
                ),
              )
            else
              for (final area in areas)
                _AreaBar(
                  name: area.name,
                  minutes: balance[area.name] ?? 0,
                  total: total,
                  theme: theme,
                ),
            const SizedBox(height: 96),
          ],
        );
      },
    );
  }
}

class _AreaBar extends StatelessWidget {
  const _AreaBar({
    required this.name,
    required this.minutes,
    required this.total,
    required this.theme,
  });

  final String name;
  final int minutes;
  final int total;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : minutes / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
              Text(
                '${(pct * 100).round()}% · ${formatMinutes(minutes)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

final areasProvider = StreamProvider<List<Area>>(
  (ref) => ref.watch(goalRepositoryProvider).watchAreas(),
);

final lifeBalanceProvider = FutureProvider<Map<String, int>>((ref) async {
  final areas = await ref.watch(goalRepositoryProvider).watchAreas().first;
  final goals = await ref.watch(goalRepositoryProvider).watchObjectives().first;
  final tasks = await ref.watch(taskRepositoryProvider).watchAll().first;
  final entries = await ref.watch(timeEntryRepositoryProvider).watchAll().first;

  // Map: task id -> area name (through goal -> parent area)
  final goalArea = <String, String>{};
  for (final g in goals) {
    final area = areas.where((a) => a.id == g.parentId).firstOrNull;
    if (area != null) goalArea[g.id] = area.name;
  }
  final taskArea = <String, String>{};
  for (final t in tasks) {
    if (t.goalId != null && goalArea.containsKey(t.goalId)) {
      taskArea[t.id] = goalArea[t.goalId]!;
    } else if (t.projectId != null) {
      final project = await ref
          .watch(projectRepositoryProvider)
          .getById(t.projectId!);
      if (project?.goalId != null && goalArea.containsKey(project!.goalId)) {
        taskArea[t.id] = goalArea[project.goalId]!;
      }
    }
  }

  final byArea = <String, int>{for (final a in areas) a.name: 0};
  for (final e in entries) {
    final minutes = e.durationMinutes ?? 0;
    if (e.taskId != null && taskArea.containsKey(e.taskId)) {
      byArea[taskArea[e.taskId]!] =
          (byArea[taskArea[e.taskId]!] ?? 0) + minutes;
    }
  }
  return byArea;
});
