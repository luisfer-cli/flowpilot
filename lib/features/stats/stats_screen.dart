import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

enum _Range { today, week, month }

class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  _Range _range = _Range.today;

  ({DateTime start, DateTime end}) get _bounds {
    final now = DateTime.now();
    switch (_range) {
      case _Range.today:
        return (start: startOfDay(now), end: endOfDay(now));
      case _Range.week:
        final weekStart = startOfWeek(now);
        return (
          start: weekStart,
          end: weekStart.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          ),
        );
      case _Range.month:
        return (
          start: startOfMonth(now),
          end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds;
    final doneAsync = ref.watch(tasksDoneBetweenProvider(bounds));
    final totalAsync = ref.watch(totalMinutesBetweenProvider(bounds));
    final activeAsync = ref.watch(activeTasksProvider);
    final byProjectAsync = ref.watch(projectMinutesProvider(bounds));
    final byCategoryAsync = ref.watch(categoryMinutesProvider(bounds));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Range>(
          segments: const [
            ButtonSegment(value: _Range.today, label: Text('Hoy')),
            ButtonSegment(value: _Range.week, label: Text('Semana')),
            ButtonSegment(value: _Range.month, label: Text('Mes')),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Completadas',
                value: '${doneAsync.valueOrNull ?? 0}',
                icon: Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Pendientes',
                value: '${activeAsync.valueOrNull?.length ?? 0}',
                icon: Icons.pending_actions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Horas trabajadas',
                value: _hours(totalAsync.valueOrNull ?? 0),
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                label: 'Focus time',
                value: _hours(totalAsync.valueOrNull ?? 0),
                icon: Icons.center_focus_strong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeader('Tiempo por proyecto'),
        const SizedBox(height: 6),
        byProjectAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (entries) {
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Sin tiempo registrado en este periodo'),
              );
            }
            final max = entries.values.reduce((a, b) => a > b ? a : b);
            return Column(
              children: [
                for (final e in entries.entries)
                  _ProjectBar(name: e.key, minutes: e.value, max: max),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        SectionHeader('Tiempo por actividad'),
        const SizedBox(height: 6),
        byCategoryAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (entries) => entries.isEmpty
              ? const Text('Sin actividad categorizada en este periodo')
              : Column(
                  children: [
                    for (final entry in entries.entries)
                      ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: Text(_hours(entry.value)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  String _hours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _ProjectBar extends StatelessWidget {
  const _ProjectBar({
    required this.name,
    required this.minutes,
    required this.max,
  });

  final String name;
  final int minutes;
  final int max;

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
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatMinutes(minutes), style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max == 0 ? 0 : minutes / max,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

final projectMinutesProvider =
    FutureProvider.family<Map<String, int>, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      final projects = await ref
          .watch(projectRepositoryProvider)
          .watchAll()
          .first;
      final entries = await ref
          .watch(timeEntryRepositoryProvider)
          .watchAll()
          .first;
      final idToName = {for (final p in projects) p.id: p.name};
      final byProject = <String, int>{};
      for (final e in entries) {
        if (e.start.isBefore(range.start) || e.start.isAfter(range.end)) {
          continue;
        }
        final minutes = e.durationMinutes ?? 0;
        if (e.projectId != null) {
          byProject[idToName[e.projectId!] ?? e.projectId!] =
              (byProject[idToName[e.projectId!] ?? e.projectId!] ?? 0) +
              minutes;
        } else if (e.taskId != null) {
          final task = await ref
              .watch(taskRepositoryProvider)
              .getById(e.taskId!);
          if (task?.projectId != null) {
            final name = idToName[task!.projectId!] ?? task.projectId!;
            byProject[name] = (byProject[name] ?? 0) + minutes;
          }
        }
      }
      final sorted = byProject.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return {
        for (final e in sorted)
          if (e.value > 0) e.key: e.value,
      };
    });

final categoryMinutesProvider =
    FutureProvider.family<Map<String, int>, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      final categories = await ref.watch(activityCategoriesProvider.future);
      final names = {
        for (final category in categories) category.id: category.name,
      };
      final entries = await ref
          .watch(timeEntryRepositoryProvider)
          .watchAll()
          .first;
      final totals = <String, int>{};
      for (final entry in entries) {
        if (entry.categoryId == null ||
            entry.start.isBefore(range.start) ||
            entry.start.isAfter(range.end)) {
          continue;
        }
        final name = names[entry.categoryId!];
        if (name != null) {
          totals[name] = (totals[name] ?? 0) + (entry.durationMinutes ?? 0);
        }
      }
      return Map.fromEntries(
        totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );
    });
