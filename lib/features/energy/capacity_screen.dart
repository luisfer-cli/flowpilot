import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';

/// Capacity: how much time is available vs occupied in the current week,
/// and estimated task load, to surface overload.
class CapacityView extends ConsumerWidget {
  const CapacityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bounds = _currentWeekBounds();
    final plannedAsync = ref.watch(plannedMinutesProvider(bounds));
    final taskLoadAsync = ref.watch(taskLoadMinutesProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        plannedAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (planned) {
            final taskLoad = taskLoadAsync.valueOrNull ?? 0;
            const available = 7 * 24 * 60; // full week (rough capacity)
            final free = available - planned;
            final overload = planned + taskLoad > available;

            return Column(
              children: [
                _Bar(
                  label: 'Tiempo planificado',
                  minutes: planned,
                  max: available,
                  color: theme.colorScheme.primary,
                ),
                _Bar(
                  label: 'Tiempo libre estimado',
                  minutes: free < 0 ? 0 : free,
                  max: available,
                  color: Colors.green,
                ),
                _Bar(
                  label: 'Carga de tareas (estimada)',
                  minutes: taskLoad,
                  max: available,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                Card(
                  color: overload ? Colors.red.withValues(alpha: 0.1) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          overload
                              ? Icons.warning_amber
                              : Icons.check_circle_outline,
                          color: overload ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            overload
                                ? 'Posible sobrecarga: planificado + tareas supera tu capacidad.'
                                : 'Tu carga parece razonable para la semana.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('¿Qué mover?'),
            subtitle: const Text(
              'Revisa los bloques fijos en el calendario. Convierte tareas a bloques flexibles si se solapan.',
            ),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.minutes,
    required this.max,
    required this.color,
  });

  final String label;
  final int minutes;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(formatMinutes(minutes), style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max == 0 ? 0 : (minutes / max).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

({DateTime start, DateTime end}) _currentWeekBounds() {
  final now = DateTime.now();
  final start = startOfWeek(now);
  return (
    start: start,
    end: start.add(const Duration(days: 6, hours: 23, minutes: 59)),
  );
}

final plannedMinutesProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      final blocks = await ref
          .watch(timeBlockRepositoryProvider)
          .getByDayRange(dayKey(range.start), dayKey(range.end));
      var total = 0;
      for (final b in blocks) {
        total += b.endMinutes - b.startMinutes;
      }
      return total;
    });

final taskLoadMinutesProvider = FutureProvider<int>((ref) async {
  final tasks = await ref.watch(taskRepositoryProvider).watchAll().first;
  var total = 0;
  for (final t in tasks) {
    total += t.estimatedMinutes ?? 0;
  }
  return total;
});
