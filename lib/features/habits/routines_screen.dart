import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class RoutinesView extends ConsumerStatefulWidget {
  const RoutinesView({super.key});

  @override
  ConsumerState<RoutinesView> createState() => _RoutinesViewState();
}

class _RoutinesViewState extends ConsumerState<RoutinesView> {
  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva rutina',
            onPressed: () => _addRoutine(context, ref),
          ),
        ),
        routinesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Error',
            subtitle: '$e',
          ),
          data: (routines) => routines.isEmpty
              ? const EmptyState(
                  icon: Icons.playlist_add_check,
                  title: 'Sin rutinas',
                  subtitle: 'Crea rutinas como "Mañana" o "Noche"',
                )
              : Column(
                  children: [
                    for (final r in routines) _RoutineCard(routine: r),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addRoutine(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var timeOfDayMinutes = 8 * 60;
    final days = <int>{1, 2, 3, 4, 5};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva rutina programada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ej: Rutina de mañana',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Hora de inicio')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: timeOfDayMinutes ~/ 60,
                          minute: timeOfDayMinutes % 60,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(
                          () => timeOfDayMinutes =
                              picked.hour * 60 + picked.minute,
                        );
                      }
                    },
                    child: Text(
                      '${(timeOfDayMinutes ~/ 60).toString().padLeft(2, '0')}:${(timeOfDayMinutes % 60).toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Días',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(
                        const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][day - 1],
                      ),
                      selected: days.contains(day),
                      onSelected: (selected) => setDialogState(
                        () => selected ? days.add(day) : days.remove(day),
                      ),
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
                      .read(routineRepositoryProvider)
                      .insert(
                        RoutinesCompanion.insert(
                          id: generateId(),
                          name: nameCtrl.text.trim(),
                          timeOfDayMinutes: Value(timeOfDayMinutes),
                          daysOfWeekJson: Value(jsonEncode(days.toList())),
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
}

class _RoutineCard extends ConsumerStatefulWidget {
  const _RoutineCard({required this.routine});

  final Routine routine;

  @override
  ConsumerState<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends ConsumerState<_RoutineCard> {
  final _stepCtrl = TextEditingController();
  bool _expanded = false;
  late List<String> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _parseSteps(widget.routine.stepsJson);
  }

  List<String> _parseSteps(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      return (jsonDecode(json) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveSteps() async {
    await ref
        .read(routineRepositoryProvider)
        .update(
          widget.routine.id,
          RoutinesCompanion(stepsJson: Value(jsonEncode(_steps))),
        );
  }

  void _addStep() {
    final text = _stepCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _steps.add(text);
      _stepCtrl.clear();
    });
    _saveSteps();
  }

  void _removeStep(int i) {
    setState(() => _steps.removeAt(i));
    _saveSteps();
  }

  @override
  void dispose() {
    _stepCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.routine.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref
                      .read(routineRepositoryProvider)
                      .delete(widget.routine.id),
                ),
              ],
            ),
            if (!_expanded && _steps.isNotEmpty)
              Text(
                '${_steps.length} paso(s)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            if (!_expanded && widget.routine.daysOfWeekJson != null)
              Text(
                'Programada · ${_formatTime(widget.routine.timeOfDayMinutes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            if (_expanded) ...[
              const Divider(height: 1),
              const SizedBox(height: 4),
              for (var i = 0; i < _steps.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text('${i + 1}.', style: theme.textTheme.bodyMedium),
                  title: Text(_steps[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeStep(i),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Añadir paso…',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addStep(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addStep),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(int? minutes) {
    final value = minutes ?? 0;
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }
}

final routinesProvider = StreamProvider<List<Routine>>(
  (ref) => ref.watch(routineRepositoryProvider).watchAll(),
);
