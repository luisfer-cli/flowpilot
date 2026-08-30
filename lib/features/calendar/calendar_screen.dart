import 'package:drift/drift.dart' show Value;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/constants.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_card.dart';
import '../habits/routines_screen.dart';

/// Screen showing the calendar: day view (time blocking grid), week agenda
/// and month view.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum _CalView { day, week, month }

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  _CalView _view = _CalView.day;
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(formatFullDate(_selectedDate)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Nueva tarea',
            onPressed: () => goToTaskEdit(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _previous,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Anterior',
                ),
                Expanded(
                  child: Center(
                    child: SegmentedButton<_CalView>(
                      segments: const [
                        ButtonSegment(value: _CalView.day, label: Text('Día')),
                        ButtonSegment(
                          value: _CalView.week,
                          label: Text('Semana'),
                        ),
                        ButtonSegment(
                          value: _CalView.month,
                          label: Text('Mes'),
                        ),
                      ],
                      selected: {_view},
                      onSelectionChanged: (s) =>
                          setState(() => _view = s.first),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _next,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Siguiente',
                ),
              ],
            ),
          ),
        ),
      ),
      body: switch (_view) {
        _CalView.day => DayView(
          date: _selectedDate,
          onDateChanged: (d) => setState(() => _selectedDate = d),
        ),
        _CalView.week => _WeekView(
          start: startOfWeek(_selectedDate),
          onSelectDay: (d) {
            setState(() {
              _selectedDate = d;
              _view = _CalView.day;
            });
          },
        ),
        _CalView.month => _MonthView(
          selectedDate: _selectedDate,
          onSelectDay: (d) {
            setState(() {
              _selectedDate = d;
              _view = _CalView.day;
            });
          },
        ),
      },
    );
  }

  void _previous() {
    setState(() {
      switch (_view) {
        case _CalView.day:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        case _CalView.week:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        case _CalView.month:
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
          _selectedDate = DateTime(
            _focusedMonth.year,
            _focusedMonth.month,
            _selectedDate.day,
          );
      }
    });
  }

  void _next() {
    setState(() {
      switch (_view) {
        case _CalView.day:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
        case _CalView.week:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
        case _CalView.month:
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
          _selectedDate = DateTime(
            _focusedMonth.year,
            _focusedMonth.month,
            _selectedDate.day,
          );
      }
    });
  }
}

/// Day view: time blocking grid plus unscheduled tasks for that day.
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key, required this.date, this.onDateChanged});

  final DateTime date;
  final ValueChanged<DateTime>? onDateChanged;

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScheduledRoutines(date: widget.date),
        Expanded(flex: 3, child: TimeBlockGrid(date: widget.date)),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(flex: 2, child: _UnscheduledPanel(date: widget.date)),
      ],
    );
  }
}

class _ScheduledRoutines extends ConsumerWidget {
  const _ScheduledRoutines({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines =
        ref.watch(routinesProvider).valueOrNull ?? const <Routine>[];
    final scheduled = routines.where((routine) {
      if (routine.daysOfWeekJson == null || routine.daysOfWeekJson!.isEmpty) {
        return false;
      }
      try {
        final days = (jsonDecode(routine.daysOfWeekJson!) as List).cast<int>();
        return days.contains(date.weekday) && routine.active;
      } catch (_) {
        return false;
      }
    }).toList();
    if (scheduled.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          for (final routine in scheduled)
            ListTile(
              dense: true,
              leading: const Icon(Icons.repeat),
              title: Text(routine.name),
              subtitle: Text(
                '${((routine.timeOfDayMinutes ?? 0) ~/ 60).toString().padLeft(2, '0')}:${((routine.timeOfDayMinutes ?? 0) % 60).toString().padLeft(2, '0')}',
              ),
            ),
        ],
      ),
    );
  }
}

class _UnscheduledPanel extends ConsumerWidget {
  const _UnscheduledPanel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksForDayProvider(date));
    final theme = Theme.of(context);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (tasks) {
        final active = tasks
            .where(
              (t) => t.status != kStatusDone && t.status != kStatusCancelled,
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SectionHeader(
                'Tareas del día',
                trailing: Text(
                  '${active.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: active.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_available,
                      title: 'Sin tareas para hoy',
                      subtitle: 'Usa + para añadir',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      itemCount: active.length,
                      itemBuilder: (_, i) => TaskCard(task: active[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The time blocking grid. Blocks can be dragged vertically and resized from
/// the bottom handle. Long-press an empty area to create a block.
class TimeBlockGrid extends ConsumerStatefulWidget {
  const TimeBlockGrid({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<TimeBlockGrid> createState() => _TimeBlockGridState();
}

const double _pxPerMinute = 0.72;
const int _snapMinutes = 15;

class _TimeBlockGridState extends ConsumerState<TimeBlockGrid> {
  final ScrollController _scroll = ScrollController(
    initialScrollOffset: 6 * 60 * _pxPerMinute,
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(blocksForDayProvider(dayKey(widget.date)));

    return blocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (blocks) {
        return Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * 60 * _pxPerMinute,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (details) =>
                        _createBlockAt(details.localPosition.dy, blocks),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hourLines(constraints.maxWidth),
                        for (final block in blocks)
                          Positioned(
                            left: 8,
                            right: 8,
                            top: block.startMinutes * _pxPerMinute,
                            height:
                                (block.endMinutes - block.startMinutes) *
                                _pxPerMinute,
                            child: _DraggableBlock(
                              block: block,
                              onMove: (deltaMin) => _moveBlock(block, deltaMin),
                              onResize: (deltaMin) =>
                                  _resizeBlock(block, deltaMin),
                              onTap: () => _editBlock(block),
                              onDelete: () => _deleteBlock(block),
                            ),
                          ),
                        if (blocks.isEmpty)
                          const Center(
                            child: Text(
                              'Mantén pulsado para crear un bloque de tiempo',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hourLines(double width) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var h = 0; h < 24; h++) {
      final top = h * 60 * _pxPerMinute;
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: top,
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(children: children);
  }

  Future<void> _createBlockAt(double dy, List<TimeBlock> blocks) async {
    final start = (_snapDown((dy / _pxPerMinute).round()));
    var end = start + 30;
    // Avoid overlapping: if a block occupies this slot, place after it.
    for (final b in blocks) {
      if (start < b.endMinutes && end > b.startMinutes) {
        end = b.endMinutes + 30;
        break;
      }
    }
    if (end > 24 * 60) end = 24 * 60;
    final type = await _chooseType();
    if (type == null || !mounted) return;
    await ref
        .read(timeBlockRepositoryProvider)
        .insert(
          TimeBlocksCompanion.insert(
            id: generateId(),
            dayKey: dayKey(widget.date),
            startMinutes: start,
            endMinutes: end,
            type: Value(type),
          ),
        );
  }

  Future<String?> _chooseType() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Tipo de bloque'),
              subtitle: Text('Puedes vincular una tarea después'),
            ),
            for (final (type, label) in const [
              (kBlockTypeFlexible, 'Flexible'),
              (kBlockTypeFixed, 'Fijo'),
              (kBlockTypeBuffer, 'Buffer'),
              (kBlockTypeTransition, 'Transición'),
            ])
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveBlock(TimeBlock block, int deltaMin) async {
    final duration = block.endMinutes - block.startMinutes;
    final newStart = (block.startMinutes + deltaMin)
        .clamp(0, 24 * 60 - duration)
        .toInt();
    final newEnd = newStart + duration;
    await ref
        .read(timeBlockRepositoryProvider)
        .move(block.id, block.dayKey, newStart, newEnd);
  }

  Future<void> _resizeBlock(TimeBlock block, int deltaMin) async {
    final newEnd = (block.endMinutes + deltaMin)
        .clamp(block.startMinutes + 10, 24 * 60)
        .toInt();
    await ref
        .read(timeBlockRepositoryProvider)
        .move(block.id, block.dayKey, block.startMinutes, newEnd);
  }

  Future<void> _deleteBlock(TimeBlock block) async {
    await ref.read(timeBlockRepositoryProvider).delete(block.id);
  }

  Future<void> _editBlock(TimeBlock block) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _BlockEditor(block: block),
    );
  }

  int _snapDown(int minutes) => minutes - (minutes % _snapMinutes);
}

class _DraggableBlock extends StatelessWidget {
  const _DraggableBlock({
    required this.block,
    required this.onMove,
    required this.onResize,
    required this.onTap,
    required this.onDelete,
  });

  final TimeBlock block;
  final ValueChanged<int> onMove;
  final ValueChanged<int> onResize;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(context, block.type);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onPanUpdate: (d) => onMove((d.delta.dy / _pxPerMinute).round()),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color, width: 1.4),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          block.type == kBlockTypeBuffer
                              ? Icons.hourglass_empty
                              : Icons.bolt,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            block.title?.isNotEmpty == true
                                ? block.title!
                                : _typeLabel(block.type),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtMinutes(block.startMinutes)}–${_fmtMinutes(block.endMinutes)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GestureDetector(
            onPanUpdate: (d) => onResize((d.delta.dy / _pxPerMinute).round()),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
              ),
              child: const Center(
                child: Icon(Icons.drag_handle, size: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(BuildContext context, String type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case kBlockTypeFixed:
        return scheme.primary;
      case kBlockTypeBuffer:
        return scheme.outline;
      case kBlockTypeTransition:
        return Colors.teal;
      default:
        return scheme.tertiary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case kBlockTypeFixed:
        return 'Fijo';
      case kBlockTypeBuffer:
        return 'Buffer';
      case kBlockTypeTransition:
        return 'Transición';
      default:
        return 'Flexible';
    }
  }

  String _fmtMinutes(int m) {
    final h = m ~/ 60;
    final min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
}

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({required this.block});

  final TimeBlock block;

  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  late TextEditingController _title;
  late String _type;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.block.title ?? '');
    _type = widget.block.type;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(activeTasksProvider);
    final tasks = tasksAsync.valueOrNull ?? const <Task>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      hintText: 'Título del bloque',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    ref
                        .read(timeBlockRepositoryProvider)
                        .delete(widget.block.id);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                  value: kBlockTypeFlexible,
                  child: Text('Flexible'),
                ),
                DropdownMenuItem(value: kBlockTypeFixed, child: Text('Fijo')),
                DropdownMenuItem(
                  value: kBlockTypeBuffer,
                  child: Text('Buffer'),
                ),
                DropdownMenuItem(
                  value: kBlockTypeTransition,
                  child: Text('Transición'),
                ),
              ],
              onChanged: (v) => setState(() => _type = v ?? kBlockTypeFlexible),
            ),
            const SizedBox(height: 12),
            Text(
              'Vincular tarea',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Sin tareas activas'),
              )
            else
              SizedBox(
                height: 150,
                child: ListView(
                  children: [
                    for (final t in tasks)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          widget.block.taskId == t.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: widget.block.taskId == t.id
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _linkTask(t.id),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _linkTask(String taskId) {
    ref
        .read(timeBlockRepositoryProvider)
        .update(widget.block.id, TimeBlocksCompanion(taskId: Value(taskId)));
  }

  void _save() {
    ref
        .read(timeBlockRepositoryProvider)
        .update(
          widget.block.id,
          TimeBlocksCompanion(
            title: Value(
              _title.text.trim().isEmpty ? null : _title.text.trim(),
            ),
            type: Value(_type),
          ),
        );
    Navigator.of(context).pop();
  }
}

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.start, required this.onSelectDay});

  final DateTime start;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Semana del ${formatDate(start)}',
              style: theme.textTheme.titleMedium,
            ),
          );
        }
        final day = days[i - 1];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${day.day}', style: const TextStyle(fontSize: 14)),
            ),
            title: Text(_weekdayName(day)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelectDay(day),
          ),
        );
      },
    );
  }

  String _weekdayName(DateTime d) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return names[d.weekday - 1];
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.selectedDate, required this.onSelectDay});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (tasks) {
        final daysWithTasks = <int>{};
        for (final t in tasks) {
          if (t.dueDate != null) daysWithTasks.add(dayKey(t.dueDate!));
          if (t.startDate != null) daysWithTasks.add(dayKey(t.startDate!));
        }
        return SingleChildScrollView(
          child: TableCalendar(
            locale: 'es',
            firstDay: DateTime(2020),
            lastDay: DateTime(2035),
            focusedDay: selectedDate,
            selectedDayPredicate: (d) => isSameDay(d, selectedDate),
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            eventLoader: (d) =>
                daysWithTasks.contains(dayKey(d)) ? [true] : const [],
            onDaySelected: (selected, focused) => onSelectDay(selected),
          ),
        );
      },
    );
  }
}

final blocksForDayProvider = StreamProvider.family<List<TimeBlock>, int>(
  (ref, day) => ref.watch(timeBlockRepositoryProvider).watchByDay(day),
);
