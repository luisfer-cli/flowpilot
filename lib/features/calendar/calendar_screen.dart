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
import '../schedules/schedules_screen.dart';
import '../settings/settings_screen.dart' show appSettingsProvider;

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
        Expanded(child: TimeBlockGrid(date: widget.date)),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(flex: 2, child: _UnscheduledPanel(date: widget.date)),
      ],
    );
  }
}

// Legacy summary widgets kept for compatibility with older deep links.
// ignore: unused_element
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
                '${_formatMinutes(routine.timeOfDayMinutes)}–${_formatMinutes(routine.endTimeMinutes)}',
              ),
            ),
        ],
      ),
    );
  }

  String _formatMinutes(int? minutes) {
    final value = minutes ?? 0;
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }
}

// ignore: unused_element
class _ScheduledCourses extends ConsumerWidget {
  const _ScheduledCourses({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(scheduleBlocksForDayProvider(date.weekday));
    return blocks.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Card(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  for (final block in items)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.school_outlined),
                      title: Text(block.title),
                      subtitle: Text(
                        '${_time(block.startMinutes)}–${_time(block.endMinutes)}',
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
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
            .where((t) => t.status != kStatusCompleted)
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
const double _gridHourInset = 8;
const double _gridBlockInset = 7;

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
    final blocksAsync = ref.watch(agendaItemsProvider(widget.date));

    return blocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (items) {
        final manualBlocks = [
          for (final item in items)
            if (item.manualBlock != null) item.manualBlock!,
        ];
        return Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: _gridHourInset + 24 * 60 * _pxPerMinute,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (details) =>
                        _createBlockAt(details.localPosition.dy, manualBlocks),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _hourLines(constraints.maxWidth),
                        for (final item in items)
                          Positioned(
                            left: _blockLeft(item, items, constraints.maxWidth),
                            width: _blockWidth(
                              item,
                              items,
                              constraints.maxWidth,
                            ),
                            top:
                                _gridHourInset +
                                _gridBlockInset +
                                item.startMinutes * _pxPerMinute,
                            height:
                                (item.endMinutes - item.startMinutes) *
                                _pxPerMinute,
                            child: item.manualBlock == null
                                ? _AgendaBlock(item: item)
                                : _DraggableBlock(
                                    block: item.manualBlock!,
                                    onMove: (deltaMin) =>
                                        _moveBlock(item.manualBlock!, deltaMin),
                                    onResize: (deltaMin) => _resizeBlock(
                                      item.manualBlock!,
                                      deltaMin,
                                    ),
                                    onTap: () => _editBlock(item.manualBlock!),
                                    onDelete: () =>
                                        _deleteBlock(item.manualBlock!),
                                  ),
                          ),
                        if (items.isEmpty)
                          const Center(
                            child: Text(
                              'Mantén pulsado para crear un bloque de tiempo',
                            ),
                          ),
                        if (isSameDay(widget.date, DateTime.now()))
                          Positioned(
                            top:
                                _gridHourInset +
                                (DateTime.now().hour * 60 +
                                        DateTime.now().minute) *
                                    _pxPerMinute,
                            left: 46,
                            right: 0,
                            child: IgnorePointer(
                              child: Container(
                                height: 2,
                                color: Theme.of(context).colorScheme.error,
                              ),
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

  double _blockLeft(AgendaItem item, List<AgendaItem> items, double width) {
    final overlaps = items
        .where(
          (other) =>
              other.startMinutes < item.endMinutes &&
              other.endMinutes > item.startMinutes,
        )
        .toList();
    final index = overlaps.indexOf(item);
    final columnWidth = (width - 54) / overlaps.length;
    return 46 + (index * columnWidth);
  }

  double _blockWidth(AgendaItem item, List<AgendaItem> items, double width) {
    final overlaps = items
        .where(
          (other) =>
              other.startMinutes < item.endMinutes &&
              other.endMinutes > item.startMinutes,
        )
        .length;
    return (width - 54) / overlaps - 8;
  }

  Widget _hourLines(double width) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var h = 0; h < 24; h++) {
      final top = _gridHourInset + h * 60 * _pxPerMinute;
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
    final minutes = ((dy - _gridHourInset) / _pxPerMinute).round().clamp(
      0,
      24 * 60,
    );
    final start = _snapDown(minutes);
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

class _AgendaBlock extends ConsumerWidget {
  const _AgendaBlock({required this.item});
  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = item.color ?? Theme.of(context).colorScheme.primary;
    final completed = item.routineId == null
        ? false
        : ref
                  .watch(
                    routineCompletionProvider((
                      routineId: item.routineId!,
                      date: item.routineDate!,
                    )),
                  )
                  .valueOrNull ??
              false;
    return Material(
      color: color.withValues(alpha: completed ? 0.25 : 0.14),
      child: InkWell(
        onTap: item.routineId != null
            ? () async {
                await ref
                    .read(routineRepositoryProvider)
                    .toggleCompletion(item.routineId!, item.routineDate!);
                ref.invalidate(
                  routineCompletionProvider((
                    routineId: item.routineId!,
                    date: item.routineDate!,
                  )),
                );
              }
            : item.taskId == null
            ? null
            : () => goToTaskEdit(context, id: item.taskId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 4),
              top: BorderSide(color: color, width: 1.2),
              bottom: BorderSide(
                color: color.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 48;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
                  if (!compact && item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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
    final settings = ref.watch(appSettingsProvider);

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
            locale: settings.languageCode,
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

class AgendaItem {
  const AgendaItem({
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    required this.source,
    this.subtitle,
    this.manualBlock,
    this.taskId,
    this.color,
    this.categoryId,
    this.routineId,
    this.routineDate,
  });

  final int startMinutes;
  final int endMinutes;
  final String title;
  final String source;
  final String? subtitle;
  final TimeBlock? manualBlock;
  final String? taskId;
  final Color? color;
  final String? categoryId;
  final String? routineId;
  final DateTime? routineDate;
}

final agendaItemsProvider = FutureProvider.family<List<AgendaItem>, DateTime>((
  ref,
  date,
) async {
  final items = <AgendaItem>[];
  final categories = await ref.watch(globalCategoriesProvider.future);
  Color? categoryColor(String? id) {
    if (id == null) return null;
    final category = categories.where((c) => c.id == id).firstOrNull;
    return category == null ? null : Color(category.color);
  }

  final manual = await ref
      .watch(timeBlockRepositoryProvider)
      .getByDay(dayKey(date));
  items.addAll(
    manual.map(
      (block) => AgendaItem(
        startMinutes: block.startMinutes,
        endMinutes: block.endMinutes,
        title: block.title?.isNotEmpty == true ? block.title! : 'Bloque',
        source: 'manual',
        subtitle: _agendaTime(block.startMinutes, block.endMinutes),
        manualBlock: block,
      ),
    ),
  );

  final scheduled = await ref.watch(
    scheduleBlocksForDayProvider(date.weekday).future,
  );
  items.addAll(
    scheduled.map(
      (block) => AgendaItem(
        startMinutes: block.startMinutes,
        endMinutes: block.endMinutes,
        title: block.title,
        source: 'schedule',
        subtitle: 'Horario semanal',
        categoryId: block.categoryId,
        color: categoryColor(block.categoryId),
      ),
    ),
  );

  final routines = await ref.watch(routinesProvider.future);
  for (final routine in routines) {
    if (!routine.active ||
        routine.timeOfDayMinutes == null ||
        routine.endTimeMinutes == null) {
      continue;
    }
    final days = _routineDays(routine.daysOfWeekJson);
    if (!days.contains(date.weekday)) continue;
    items.add(
      AgendaItem(
        startMinutes: routine.timeOfDayMinutes!,
        endMinutes: routine.endTimeMinutes!,
        title: routine.name,
        source: 'routine',
        subtitle: 'Rutina',
        categoryId: routine.categoryId,
        routineId: routine.id,
        routineDate: date,
        color: categoryColor(routine.categoryId),
      ),
    );
  }

  final tasks = await ref.watch(tasksForDayProvider(date).future);
  for (final task in tasks) {
    final due = task.dueDate;
    if (due == null || (due.hour == 0 && due.minute == 0)) continue;
    final start = due.hour * 60 + due.minute;
    items.add(
      AgendaItem(
        startMinutes: start,
        endMinutes: (start + (task.estimatedMinutes ?? 30)).clamp(
          start + 15,
          24 * 60,
        ),
        title: task.title,
        source: 'task',
        subtitle: 'Tarea',
        taskId: task.id,
        categoryId: task.categoryId,
        color: categoryColor(task.categoryId) ?? Colors.orange,
      ),
    );
  }
  items.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  return items;
});

List<int> _routineDays(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return (jsonDecode(json) as List).cast<int>();
  } catch (_) {
    return const [];
  }
}

String _agendaTime(int start, int end) =>
    '${_agendaClock(start)}–${_agendaClock(end)}';

String _agendaClock(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

final routineCompletionProvider =
    FutureProvider.family<bool, ({String routineId, DateTime date})>((
      ref,
      key,
    ) {
      return ref
          .watch(routineRepositoryProvider)
          .isCompletedOn(key.routineId, key.date);
    });
