import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class HabitsView extends ConsumerStatefulWidget {
  const HabitsView({super.key});

  @override
  ConsumerState<HabitsView> createState() => _HabitsViewState();
}

class _HabitsViewState extends ConsumerState<HabitsView> {
  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo hábito',
            onPressed: () => _addHabit(context, ref),
          ),
        ),
        habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Error',
            subtitle: '$e',
          ),
          data: (habits) => habits.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Sin hábitos',
                  subtitle: 'Crea tu primer hábito',
                )
              : Column(
                  children: [for (final h in habits) _HabitTile(habit: h)],
                ),
        ),
      ],
    );
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var frequency = 'daily';
    var interval = 1;
    final daysOfWeek = <int>{};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Nuevo hábito'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Nombre del hábito',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Diario')),
                  DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                ],
                onChanged: (v) => setState(() => frequency = v ?? 'daily'),
              ),
              const SizedBox(height: 8),
              if (frequency == 'weekly')
                Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(_weekdayShort(d)),
                        selected: daysOfWeek.contains(d),
                        onSelected: (sel) => setState(() {
                          sel ? daysOfWeek.add(d) : daysOfWeek.remove(d);
                        }),
                      ),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ref
                      .read(habitRepositoryProvider)
                      .insert(
                        HabitsCompanion.insert(
                          id: generateId(),
                          name: nameCtrl.text.trim(),
                          frequency: frequency,
                          interval: Value(interval),
                          daysOfWeekJson: Value(
                            daysOfWeek.isEmpty
                                ? null
                                : jsonEncode(daysOfWeek.toList()),
                          ),
                        ),
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayShort(int d) {
    const names = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return names[d - 1];
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doneAsync = ref.watch(habitDoneTodayProvider(habit.id));
    final streakAsync = ref.watch(habitStreakProvider(habit.id));
    final theme = Theme.of(context);
    final done = doneAsync.valueOrNull ?? false;
    final streak = streakAsync.valueOrNull ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: done,
              onChanged: (_) => ref
                  .read(habitRepositoryProvider)
                  .toggleCompletion(habit, DateTime.now()),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: streak > 0
                            ? Colors.orange
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak días',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  ref.read(habitRepositoryProvider).delete(habit.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchAll(),
);

final habitDoneTodayProvider = FutureProvider.family<bool, String>((
  ref,
  habitId,
) async {
  final habit = await ref
      .watch(habitRepositoryProvider)
      .watchAll()
      .first
      .then((h) => h.where((x) => x.id == habitId).firstOrNull);
  if (habit == null) return false;
  return ref.watch(habitRepositoryProvider).isDoneOn(habit, DateTime.now());
});

final habitStreakProvider = FutureProvider.family<int, String>((
  ref,
  habitId,
) async {
  final habit = await ref
      .watch(habitRepositoryProvider)
      .watchAll()
      .first
      .then((h) => h.where((x) => x.id == habitId).firstOrNull);
  if (habit == null) return 0;
  return ref.watch(habitRepositoryProvider).streak(habit);
});
