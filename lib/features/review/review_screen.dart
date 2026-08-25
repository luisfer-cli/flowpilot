import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../core/utils/time_utils.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

enum _Period { daily, weekly }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _Period _period = _Period.daily;

  ({DateTime start, DateTime end}) get _bounds {
    final now = DateTime.now();
    switch (_period) {
      case _Period.daily:
        return (start: startOfDay(now), end: endOfDay(now));
      case _Period.weekly:
        final weekStart = startOfWeek(now);
        return (
          start: weekStart,
          end: weekStart.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds;
    final doneAsync = ref.watch(tasksDoneBetweenProvider(bounds));
    final workedAsync = ref.watch(totalMinutesBetweenProvider(bounds));
    final blocksAsync = ref.watch(blocksInRangeProvider(bounds));
    final delayedAsync = ref.watch(delayedTasksProvider(bounds));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Revisión')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.daily, label: Text('Diaria')),
              ButtonSegment(value: _Period.weekly, label: Text('Semanal')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _period == _Period.daily
                        ? 'Resumen del día'
                        : 'Resumen de la semana',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Tareas completadas',
                    value: '${doneAsync.valueOrNull ?? 0}',
                    icon: Icons.check_circle,
                  ),
                  _SummaryRow(
                    label: 'Tiempo trabajado',
                    value: formatMinutes(workedAsync.valueOrNull ?? 0),
                    icon: Icons.timer_outlined,
                  ),
                  _SummaryRow(
                    label: 'Tiempo planificado',
                    value: formatMinutes(blocksAsync.valueOrNull ?? 0),
                    icon: Icons.calendar_today,
                  ),
                  _SummaryRow(
                    label: 'Tareas retrasadas',
                    value: '${delayedAsync.valueOrNull ?? 0}',
                    icon: Icons.error_outline,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader('¿Qué salió bien / mal?'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _factRow(
                    theme,
                    Icons.thumb_up_outlined,
                    doneAsync.valueOrNull == null
                        ? 'Revisa tus tareas completadas.'
                        : 'Completaste ${doneAsync.valueOrNull} tarea(s).',
                  ),
                  const SizedBox(height: 8),
                  _factRow(
                    theme,
                    Icons.timeline,
                    'Estimación vs real: mira tu precisión en Estadísticas.',
                  ),
                  const SizedBox(height: 8),
                  _factRow(
                    theme,
                    Icons.lightbulb_outline,
                    '¿Hubo interrupciones o cambios? Anótalos para mejorar la planificación.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Widget _factRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

final blocksInRangeProvider =
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

final delayedTasksProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      final tasks = await ref.watch(taskRepositoryProvider).watchAll().first;
      return tasks
          .where(
            (t) =>
                t.dueDate != null &&
                !t.dueDate!.isBefore(range.start) &&
                !t.dueDate!.isAfter(range.end) &&
                t.status != kStatusDone &&
                t.status != kStatusCancelled,
          )
          .length;
    });
