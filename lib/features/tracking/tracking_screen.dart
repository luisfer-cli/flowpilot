import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

class TrackingView extends ConsumerStatefulWidget {
  const TrackingView({super.key});

  @override
  ConsumerState<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<TrackingView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runningAsync = ref.watch(runningEntryProvider);
    final entriesAsync = ref.watch(recentEntriesProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        runningAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Error',
            subtitle: '$e',
          ),
          data: (entry) {
            if (entry == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Sin temporizador activo')),
                      FilledButton.icon(
                        onPressed: () => _startTimer(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final elapsed = DateTime.now().difference(entry.start);
            final taskName = entry.taskId == null
                ? null
                : ref.watch(taskByIdProvider(entry.taskId!)).valueOrNull?.title;
            return Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            taskName ?? 'Temporizador',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatElapsed(elapsed),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _stopTimer(entry),
                            icon: const Icon(Icons.stop),
                            label: const Text('Detener'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _discardEntry(entry),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Descartar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SectionHeader('Añadir tiempo manual'),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_chart),
            title: const Text('Añadir entrada'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _addManual(),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          'Historial',
          trailing: IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Gestionar categorías',
            onPressed: _manageCategories,
          ),
        ),
        const SizedBox(height: 8),
        entriesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (entries) => entries.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'Sin registros',
                  subtitle: 'El tiempo registrado aparece aquí',
                )
              : Column(
                  children: [for (final e in entries) _EntryTile(entry: e)],
                ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _startTimer() async {
    final tasks = await ref.read(taskRepositoryProvider).watchActive().first;
    if (!mounted) return;
    final selected =
        await showModalBottomSheet<({String taskId, String? categoryId})>(
          context: context,
          builder: (context) => SafeArea(
            child: tasks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay tareas activas'),
                  )
                : _StartTrackingSheet(tasks: tasks),
          ),
        );
    if (selected == null) return;
    await ref
        .read(timeEntryRepositoryProvider)
        .startTimer(taskId: selected.taskId, categoryId: selected.categoryId);
  }

  Future<void> _stopTimer(TimeEntry entry) async {
    await ref.read(timeEntryRepositoryProvider).stopTimer(entry.id);
  }

  Future<void> _discardEntry(TimeEntry entry) async {
    await ref.read(timeEntryRepositoryProvider).delete(entry.id);
  }

  Future<void> _addManual() async {
    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day, 9);
    var end = start.add(const Duration(hours: 1));
    String? taskId;
    String? categoryId;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickTime(bool isStart) async {
            final base = isStart ? start : end;
            final t = await showTimePicker(
              context: dialogContext,
              initialTime: TimeOfDay.fromDateTime(base),
            );
            if (t != null) {
              setDialogState(() {
                final updated = DateTime(
                  base.year,
                  base.month,
                  base.day,
                  t.hour,
                  t.minute,
                );
                if (isStart) {
                  start = updated;
                  if (!end.isAfter(start)) {
                    end = start.add(const Duration(hours: 1));
                  }
                } else {
                  end = updated;
                  if (end.isBefore(start)) {
                    start = end.subtract(const Duration(hours: 1));
                  }
                }
              });
            }
          }

          final tasks =
              ref.watch(activeTasksProvider).valueOrNull ?? const <Task>[];
          final categories =
              ref.watch(activityCategoriesProvider).valueOrNull ??
              const <ActivityCategory>[];

          return AlertDialog(
            title: const Text('Añadir tiempo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickTime(true),
                        child: Text('Inicio ${formatTimeOfDay(start)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pickTime(false),
                        child: Text('Fin ${formatTimeOfDay(end)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin categoría'),
                    ),
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => categoryId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: taskId,
                  decoration: const InputDecoration(labelText: 'Tarea'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin tarea'),
                    ),
                    for (final t in tasks)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => taskId = v),
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
                  ref
                      .read(timeEntryRepositoryProvider)
                      .addManual(
                        start: start,
                        end: end,
                        taskId: taskId,
                        categoryId: categoryId,
                      );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _manageCategories() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Categorías de actividad'),
        content: Consumer(
          builder: (context, ref, _) {
            final categories =
                ref.watch(activityCategoriesProvider).valueOrNull ??
                const <ActivityCategory>[];
            return SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final category in categories)
                    ListTile(
                      title: Text(category.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(activityCategoryRepositoryProvider)
                            .delete(category.id),
                      ),
                    ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ref
                    .read(activityCategoryRepositoryProvider)
                    .insert(
                      ActivityCategoriesCompanion.insert(
                        id: generateId(),
                        name: controller.text.trim(),
                      ),
                    );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _StartTrackingSheet extends ConsumerStatefulWidget {
  const _StartTrackingSheet({required this.tasks});
  final List<Task> tasks;

  @override
  ConsumerState<_StartTrackingSheet> createState() =>
      _StartTrackingSheetState();
}

class _StartTrackingSheetState extends ConsumerState<_StartTrackingSheet> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(activityCategoriesProvider).valueOrNull ??
        const <ActivityCategory>[];
    return ListView(
      shrinkWrap: true,
      children: [
        const ListTile(title: Text('¿En qué actividad trabajas?')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin categoría')),
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ),
        for (final task in widget.tasks)
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () =>
                Navigator.of(context)
                    .pop((taskId: task.id, categoryId: _categoryId)),
          ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});

  final TimeEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryName = entry.categoryId == null
        ? null
        : ref
              .watch(activityCategoriesProvider)
              .valueOrNull
              ?.where((category) => category.id == entry.categoryId)
              .firstOrNull
              ?.name;
    final taskNameAsync = entry.taskId == null
        ? null
        : ref.watch(projectNameForTaskProvider2(entry.taskId!));
    final theme = Theme.of(context);
    final duration = entry.durationMinutes;

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.play_circle_outline,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          categoryName ?? taskNameAsync?.valueOrNull ?? 'Sin categoría',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatDate(entry.start)} · ${formatTimeOfDay(entry.start)}–${entry.end == null ? '…' : formatTimeOfDay(entry.end!)}',
        ),
        trailing: Text(
          duration == null ? '—' : formatMinutes(duration),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

final runningEntryProvider = StreamProvider<TimeEntry?>(
  (ref) => ref.watch(timeEntryRepositoryProvider).watchRunning(),
);

final recentEntriesProvider = StreamProvider<List<TimeEntry>>(
  (ref) => ref.watch(timeEntryRepositoryProvider).watchAll(limit: 50),
);

final projectNameForTaskProvider2 = FutureProvider.family<String?, String>((
  ref,
  taskId,
) async {
  final task = await ref.watch(taskRepositoryProvider).getById(taskId);
  if (task == null || task.projectId == null) return null;
  final project = await ref
      .watch(projectRepositoryProvider)
      .getById(task.projectId!);
  return project?.name ?? task.title;
});
