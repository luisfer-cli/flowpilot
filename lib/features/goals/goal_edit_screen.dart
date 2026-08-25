import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import 'goals_screen.dart';

class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String? _areaId;
  DateTime? _deadline;
  int? _targetMinutes;
  bool _loading = true;
  String? _goalId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.goalId;
    if (id != null) {
      final g = await ref.read(goalRepositoryProvider).getById(id);
      if (g != null) {
        setState(() {
          _goalId = g.id;
          _title.text = g.title;
          _notes.text = g.notes ?? '';
          _areaId = g.parentId;
          _deadline = g.deadline;
          _targetMinutes = g.targetMinutes;
        });
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El título es obligatorio')));
      return;
    }
    final repo = ref.read(goalRepositoryProvider);
    final companion = GoalsCompanion(
      title: Value(_title.text.trim()),
      parentId: Value(_areaId),
      deadline: Value(_deadline),
      targetMinutes: Value(_targetMinutes),
      notes: Value(_notes.text.trim().isEmpty ? null : _notes.text.trim()),
    );
    if (_goalId == null) {
      await repo.insertGoal(companion.copyWith(id: Value(generateId())));
    } else {
      await repo.updateGoal(_goalId!, companion);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider).valueOrNull ?? const <Area>[];
    final projectsAsync = _goalId == null
        ? null
        : ref.watch(projectsForGoalProvider(_goalId!));
    final progressAsync = _goalId == null
        ? null
        : ref.watch(goalProgressProvider(_goalId!));
    final investedAsync = _goalId == null
        ? null
        : ref.watch(goalInvestedProvider(_goalId!));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_goalId == null ? 'Nuevo objetivo' : 'Editar objetivo'),
        actions: [
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
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notas'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _areaId,
                  decoration: const InputDecoration(labelText: 'Área'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin área'),
                    ),
                    for (final a in areas)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _areaId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deadline ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                          setState(() => _deadline = picked);
                        }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Deadline',
                          ),
                          child: Text(
                            _deadline == null
                                ? 'Sin fecha'
                                : formatDate(_deadline!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Horas objetivo',
                        ),
                        onChanged: (v) =>
                            _targetMinutes = (int.tryParse(v) ?? 0) * 60,
                      ),
                    ),
                  ],
                ),
                if (_goalId != null) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: 'Progreso',
                          value: progressAsync?.valueOrNull == null
                              ? '—'
                              : '${(progressAsync!.valueOrNull! * 100).round()}%',
                          icon: Icons.percent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: 'Tiempo invertido',
                          value: formatMinutes(investedAsync?.valueOrNull ?? 0),
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionHeader('Proyectos'),
                  const SizedBox(height: 6),
                  projectsAsync?.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (projects) => projects.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('Sin proyectos vinculados'),
                              )
                            : Column(
                                children: [
                                  for (final p in projects)
                                    Card(
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.folder,
                                          color: Color(p.color),
                                        ),
                                        title: Text(p.name),
                                        trailing: Text(
                                          p.deadline == null
                                              ? ''
                                              : formatDate(p.deadline!),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ) ??
                      const SizedBox.shrink(),
                ],
                const SizedBox(height: 96),
              ],
            ),
    );
  }
}

final projectsForGoalProvider = FutureProvider.family<List<Project>, String>(
  (ref, goalId) => ref.watch(projectRepositoryProvider).getByGoal(goalId),
);
