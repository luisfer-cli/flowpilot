import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../categories/category_manager.dart';
import '../../data/repositories/reports_repository.dart';

enum _Range { today, week, month, custom }

class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});

  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  late final DateTime _now = DateTime.now();
  _Range _range = _Range.today;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _categoryId;

  ({DateTime start, DateTime end}) get _bounds {
    final now = _now;
    DateTime bounded(DateTime end) => end.isAfter(now) ? now : end;
    switch (_range) {
      case _Range.today:
        return (start: startOfDay(now), end: bounded(endOfDay(now)));
      case _Range.week:
        final start = startOfWeek(now);
        return (
          start: start,
          end: bounded(
            start.add(
              const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
            ),
          ),
        );
      case _Range.month:
        return (
          start: startOfMonth(now),
          end: bounded(DateTime(now.year, now.month + 1, 0, 23, 59, 59)),
        );
      case _Range.custom:
        return (
          start: _customStart ?? startOfDay(now),
          end: bounded(
            _customEnd == null ? endOfDay(now) : endOfDay(_customEnd!),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _bounds;
    final filter = (
      start: bounds.start,
      end: bounds.end,
      categoryId: _categoryId,
    );
    final report = ref.watch(reportsSnapshotProvider(filter));
    final categories =
        ref.watch(globalCategoriesProvider).valueOrNull ?? const <Category>[];
    final selectedCategory = categories
        .where((category) => category.id == _categoryId)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<_Range>(
                segments: const [
                  ButtonSegment(value: _Range.today, label: Text('Hoy')),
                  ButtonSegment(value: _Range.week, label: Text('Semana')),
                  ButtonSegment(value: _Range.month, label: Text('Mes')),
                ],
                selected: {_range == _Range.custom ? _Range.today : _range},
                onSelectionChanged: (selected) => setState(() {
                  _range = selected.first;
                }),
              ),
            ),
            IconButton(
              tooltip: 'Elegir periodo',
              icon: Icon(
                Icons.date_range,
                color: _range == _Range.custom
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: _pickRange,
            ),
            IconButton(
              tooltip: 'Gestionar categorías',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => showCategoryManager(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          initialValue: _categoryId,
          decoration: const InputDecoration(
            labelText: 'Categoría del reporte',
            prefixIcon: Icon(Icons.label_outline),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todas las categorías'),
            ),
            for (final category in categories)
              DropdownMenuItem(value: category.id, child: Text(category.name)),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        if (_range == _Range.custom && _customStart != null) ...[
          const SizedBox(height: 6),
          Text(
            '${formatDate(_customStart!)} - ${formatDate(_customEnd ?? _customStart!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('No se pudo cargar el reporte: $error'),
          data: (snapshot) =>
              _ReportContent(snapshot: snapshot, category: selectedCategory),
        ),
      ],
    );
  }

  Future<void> _pickRange() async {
    final now = _now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(
        start: _customStart ?? startOfDay(now),
        end: _customEnd ?? endOfDay(now),
      ),
    );
    if (picked == null) return;
    setState(() {
      _range = _Range.custom;
      _customStart = picked.start;
      _customEnd = picked.end;
    });
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.snapshot, this.category});

  final ReportsSnapshot snapshot;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final focusPercent = snapshot.totalMinutes == 0
        ? 0.0
        : snapshot.focusMinutes / snapshot.totalMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Completadas',
                value: '${snapshot.completedTasks}',
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Pendientes',
                value: '${snapshot.pendingTasks}',
                icon: Icons.pending_actions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Tiempo registrado',
                value: _hours(snapshot.totalMinutes),
                icon: Icons.timer_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Foco',
                value:
                    '${_hours(snapshot.focusMinutes)} (${(focusPercent * 100).round()}%)',
                icon: Icons.center_focus_strong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: category == null
              ? 'Tiempo por categoría'
              : 'Tiempo en ${category!.name}',
          icon: Icons.label_outline,
          child: snapshot.categoryMinutes.isEmpty
              ? const Text('Sin tiempo categorizado en este periodo')
              : Column(
                  children: [
                    for (final entry in snapshot.categoryMinutes.entries)
                      _MetricRow(label: entry.key, value: _hours(entry.value)),
                  ],
                ),
        ),
        if (snapshot.categoryTaskCompletions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Tareas completadas por categoría',
            icon: Icons.task_alt,
            child: Column(
              children: [
                for (final entry in snapshot.categoryTaskCompletions.entries)
                  _MetricRow(label: entry.key, value: '${entry.value}'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Pomodoro y foco',
          icon: Icons.local_fire_department_outlined,
          child: Column(
            children: [
              _MetricRow(
                label: 'Sesiones completadas',
                value: '${snapshot.pomodoroSessions}',
              ),
              _MetricRow(
                label: 'Tiempo Pomodoro',
                value: _hours(snapshot.pomodoroMinutes),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Rutinas',
          icon: Icons.repeat,
          child: Column(
            children: [
              _MetricRow(
                label: 'Cumplimiento',
                value: '${(snapshot.routineCompletionRate * 100).round()}%',
              ),
              _MetricRow(
                label: 'Realizadas',
                value:
                    '${snapshot.completedRoutineCount}/${snapshot.plannedRoutineCount}',
              ),
              _MetricRow(
                label: 'Minutos cumplidos',
                value:
                    '${_hours(snapshot.completedRoutineMinutes)} de ${_hours(snapshot.plannedRoutineMinutes)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Horarios planificados',
          icon: Icons.calendar_month_outlined,
          child: Column(
            children: [
              _MetricRow(
                label: 'Tiempo programado',
                value: _hours(snapshot.plannedScheduleMinutes),
              ),
              _MetricRow(
                label: 'Tiempo registrado',
                value: _hours(snapshot.totalMinutes),
              ),
              _MetricRow(
                label: 'Diferencia',
                value: _signedHours(
                  snapshot.totalMinutes - snapshot.plannedScheduleMinutes,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _hours(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  static String _signedHours(int minutes) {
    if (minutes == 0) return '0m';
    return minutes > 0 ? '+${_hours(minutes)}' : '-${_hours(-minutes)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

final reportsSnapshotProvider =
    FutureProvider.family<
      ReportsSnapshot,
      ({DateTime start, DateTime end, String? categoryId})
    >((ref, filter) {
      return ref
          .watch(reportsRepositoryProvider)
          .load(
            ReportFilter(
              start: filter.start,
              end: filter.end,
              categoryId: filter.categoryId,
            ),
          );
    });
