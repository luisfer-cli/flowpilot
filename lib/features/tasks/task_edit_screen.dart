import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import 'widgets/task_editors.dart';

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({super.key, this.taskId});

  final String? taskId;

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _estimated = TextEditingController();
  final _startDate = TextEditingController();
  final _dueDate = TextEditingController();

  String? _status;
  int _priority = kPriorityNone;
  String? _contextId;
  String? _categoryId;
  String? _projectId;
  String? _goalId;
  String? _parentId;
  int? _energy;
  int? _focus;
  DateTime? _start;
  DateTime? _due;
  int? _estimatedMinutes;
  final Set<String> _selectedTags = {};

  // Recurrence
  bool _recurring = false;
  final String _frequency = kFreqWeekly;
  final int _interval = 1;
  final Set<int> _daysOfWeek = {};
  int? _dayOfMonth;

  bool _loading = true;
  Task? _currentTask;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.taskId;
    if (id == null) {
      setState(() {
        _status = 'Inbox';
        _loading = false;
      });
      return;
    }
    final task = await ref.read(taskRepositoryProvider).getById(id);
    if (task == null) {
      setState(() => _loading = false);
      return;
    }
    final tags = await ref
        .read(referenceRepositoryProvider)
        .tagIdsForTask(task.id);
    setState(() {
      _currentTask = task;
      _title.text = task.title;
      _description.text = task.description ?? '';
      _estimated.text = task.estimatedMinutes?.toString() ?? '';
      _startDate.text = task.startDate == null
          ? ''
          : formatDate(task.startDate!);
      _dueDate.text = task.dueDate == null ? '' : formatDate(task.dueDate!);
      _status = task.status;
      _priority = task.priority;
      _contextId = task.contextId;
      _categoryId = task.categoryId;
      _projectId = task.projectId;
      _goalId = task.goalId;
      _parentId = task.parentId;
      _energy = task.energyRequired;
      _focus = task.focusRequired;
      _start = task.startDate;
      _due = task.dueDate;
      _estimatedMinutes = task.estimatedMinutes;
      _selectedTags.addAll(tags);
      if (task.recurrenceId != null) {
        _recurring = true;
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _estimated.dispose();
    _startDate.dispose();
    _dueDate.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    TextEditingController ctrl,
    void Function(DateTime?) set,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      set(picked);
      ctrl.text = formatDate(picked);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El título es obligatorio')));
      return;
    }
    final taskRepo = ref.read(taskRepositoryProvider);

    String? recurrenceId;
    if (_recurring) {
      recurrenceId = generateId();
      await ref
          .read(databaseProvider)
          .into(ref.read(databaseProvider).recurrenceRules)
          .insert(
            RecurrenceRulesCompanion.insert(
              id: recurrenceId,
              frequency: _frequency,
              interval: Value(_interval),
              daysOfWeekJson: Value(
                _daysOfWeek.isEmpty
                    ? null
                    : _daysOfWeek.map((d) => d.toString()).join(','),
              ),
              dayOfMonth: Value(_dayOfMonth),
            ),
          );
    }

    final companion = TasksCompanion(
      title: Value(_title.text.trim()),
      description: Value(
        _description.text.trim().isEmpty ? null : _description.text.trim(),
      ),
      status: Value(_status ?? 'Inbox'),
      priority: Value(_priority),
      contextId: Value(_contextId),
      categoryId: Value(_categoryId),
      projectId: Value(_projectId),
      goalId: Value(_goalId),
      parentId: Value(_parentId),
      startDate: Value(_start),
      dueDate: Value(_due),
      estimatedMinutes: Value(_estimatedMinutes),
      energyRequired: Value(_energy),
      focusRequired: Value(_focus),
      recurrenceId: Value(recurrenceId),
    );

    final String taskId;
    if (widget.taskId == null) {
      taskId = generateId();
      await taskRepo.insert(companion.copyWith(id: Value(taskId)));
    } else {
      taskId = widget.taskId!;
      await taskRepo.update(taskId, companion);
    }
    await ref
        .read(referenceRepositoryProvider)
        .setTaskTags(taskId, _selectedTags.toList());

    if (mounted) context.pop();
  }

  Future<void> _handleAction(String action) async {
    final task = _currentTask;
    if (task == null) return;
    final taskRepo = ref.read(taskRepositoryProvider);
    switch (action) {
      case 'duplicate':
        await taskRepo.duplicate(task.id);
        if (mounted) context.pop();
      case 'snooze':
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        await taskRepo.update(
          task.id,
          TasksCompanion(dueDate: Value(tomorrow), status: const Value('Next')),
        );
        if (mounted) context.pop();
      case 'reschedule':
        await _reschedule(task);
      case 'to_event':
        await taskRepo.update(
          task.id,
          const TasksCompanion(isEvent: Value(true)),
        );
        if (mounted) context.pop();
    }
  }

  Future<void> _reschedule(Task task) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: task.dueDate == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(task.dueDate!),
    );
    if (time == null || !mounted) return;
    final when = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    await ref
        .read(taskRepositoryProvider)
        .update(
          task.id,
          TasksCompanion(dueDate: Value(when), status: const Value('Next')),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'Nueva tarea' : 'Editar tarea'),
        actions: [
          if (widget.taskId != null)
            PopupMenuButton<String>(
              onSelected: (v) => _handleAction(v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                PopupMenuItem(value: 'snooze', child: Text('Posponer')),
                PopupMenuItem(value: 'reschedule', child: Text('Reprogramar')),
                PopupMenuItem(
                  value: 'to_event',
                  child: Text('Convertir en evento'),
                ),
              ],
            ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  autofocus: widget.taskId == null,
                  decoration: const InputDecoration(
                    hintText: '¿Qué hay que hacer?',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Descripción'),
                ),
                const SizedBox(height: 20),
                _dropdown(
                  'Prioridad',
                  kPriorityLabels.entries.toList(),
                  kPriorityLabels.keys
                      .map((k) => '${kPriorityLabels[k]}')
                      .toList(),
                  _priority == 0
                      ? kPriorityLabels[0]
                      : kPriorityLabels[_priority],
                  (label) {
                    final entry = kPriorityLabels.entries.firstWhere(
                      (e) => e.value == label,
                      orElse: () => MapEntry(0, kPriorityLabels[0]!),
                    );
                    setState(() => _priority = entry.key);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estimated,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimación (min)',
                        ),
                        onChanged: (v) => _estimatedMinutes = int.tryParse(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(_startDate, (d) => _start = d),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Inicio',
                          ),
                          child: Text(
                            _startDate.text.isEmpty
                                ? 'Sin fecha'
                                : _startDate.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(_dueDate, (d) => _due = d),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Deadline',
                          ),
                          child: Text(
                            _dueDate.text.isEmpty ? 'Sin fecha' : _dueDate.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _energySelector()),
                  ],
                ),
                const SizedBox(height: 20),
                if (widget.taskId != null && _currentTask != null) ...[
                  ChecklistEditor(
                    taskId: widget.taskId!,
                    initialJson: _currentTask!.checklistJson,
                  ),
                  const SizedBox(height: 20),
                  SubtaskEditor(parentId: widget.taskId!),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 96),
              ],
            ),
    );
  }

  Widget _energySelector() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Energía'),
      child: Row(
        children: [
          for (var e = 1; e <= 5; e++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  e <= (_energy ?? 0) ? Icons.bolt : Icons.bolt_outlined,
                  color: e <= (_energy ?? 0) ? Colors.amber.shade700 : null,
                ),
                onPressed: () => setState(() => _energy = e),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    List<T> items,
    List<String> labels,
    String? selected,
    void Function(String) onSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: InputDecoration(labelText: label),
        items: [
          if (items.isNotEmpty)
            for (var i = 0; i < items.length; i++)
              DropdownMenuItem(value: labels[i], child: Text(labels[i])),
        ],
        onChanged: items.isEmpty
            ? null
            : (v) => v == null ? null : onSelected(v),
      ),
    );
  }
}
