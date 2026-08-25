import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_card.dart';

const _palette = <int>[
  0x5B8DEF,
  0xE05555,
  0xF2A83B,
  0x2FA37D,
  0x8E44AD,
  0x3A6EA5,
  0xD35400,
  0x16A085,
];

class ProjectEditScreen extends ConsumerStatefulWidget {
  const ProjectEditScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends ConsumerState<ProjectEditScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _goalId;
  DateTime? _deadline;
  int _color = _palette.first;
  String _status = 'active';
  bool _loading = true;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.projectId;
    if (id != null) {
      final p = await ref.read(projectRepositoryProvider).getById(id);
      if (p != null) {
        setState(() {
          _projectId = p.id;
          _name.text = p.name;
          _description.text = p.description ?? '';
          _goalId = p.goalId;
          _deadline = p.deadline;
          _color = p.color;
          _status = p.status;
        });
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }
    final repo = ref.read(projectRepositoryProvider);
    final companion = ProjectsCompanion(
      name: Value(_name.text.trim()),
      description: Value(
        _description.text.trim().isEmpty ? null : _description.text.trim(),
      ),
      goalId: Value(_goalId),
      deadline: Value(_deadline),
      color: Value(_color),
      status: Value(_status),
    );
    if (_projectId == null) {
      await repo.insert(companion.copyWith(id: Value(generateId())));
    } else {
      await repo.update(_projectId!, companion);
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];
    final tasksAsync = _projectId == null
        ? null
        : ref.watch(projectTasksProvider(_projectId!));
    final progressAsync = _projectId == null
        ? null
        : ref.watch(projectProgressProvider(_projectId!));
    final timeAsync = _projectId == null
        ? null
        : ref.watch(projectTimeProvider(_projectId!));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_projectId == null ? 'Nuevo proyecto' : _name.text),
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
                if (_projectId != null && timeAsync?.valueOrNull != null) ...[
                  _MetricsCard(
                    progress: progressAsync?.valueOrNull,
                    time: timeAsync?.valueOrNull,
                    deadline: _deadline,
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _goalId,
                  decoration: const InputDecoration(labelText: 'Objetivo'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin objetivo'),
                    ),
                    for (final g in goals)
                      DropdownMenuItem(value: g.id, child: Text(g.title)),
                  ],
                  onChanged: (v) => setState(() => _goalId = v),
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Activo'),
                          ),
                          DropdownMenuItem(
                            value: 'done',
                            child: Text('Completado'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('Archivado'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'active'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in _palette)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: _color == c
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_projectId != null) ...[
                  const SizedBox(height: 24),
                  _MilestonesSection(projectId: _projectId!),
                  const SizedBox(height: 24),
                  SectionHeader('Tareas'),
                  const SizedBox(height: 6),
                  tasksAsync?.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (tasks) => tasks.isEmpty
                            ? const EmptyState(
                                icon: Icons.task_alt,
                                title: 'Sin tareas',
                                subtitle:
                                    'Añade tareas desde la pestaña Tareas',
                              )
                            : Column(
                                children: [
                                  for (final t in tasks) TaskCard(task: t),
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

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({this.progress, this.time, this.deadline});

  final ({int total, int done})? progress;
  final ({int estimated, int actual})? time;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = progress;
    final percent = (p == null || p.total == 0) ? 0.0 : p.done / p.total;
    final daysLeft = deadline?.difference(DateTime.now()).inDays;
    final color = daysLeft == null || daysLeft >= 0 ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progreso', style: theme.textTheme.titleSmall),
                Text(
                  '${(percent * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: 'Estimado',
                  value: formatMinutes(time?.estimated ?? 0),
                ),
                _Metric(label: 'Real', value: formatMinutes(time?.actual ?? 0)),
                _Metric(
                  label: 'Deadline',
                  value: daysLeft == null
                      ? '—'
                      : daysLeft < 0
                      ? 'Vencido'
                      : '$daysLeft días',
                  color: color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesAsync = ref.watch(milestonesProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Milestones',
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addMilestone(context, ref),
          ),
        ),
        milestonesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (milestones) => milestones.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin milestones'),
                )
              : Column(
                  children: [
                    for (final m in milestones) _MilestoneTile(milestone: m),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addMilestone(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo milestone'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Título'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final title = controller.text.trim();
    if (title.isEmpty) return;
    await ref
        .read(projectRepositoryProvider)
        .insertMilestone(
          MilestonesCompanion.insert(
            id: generateId(),
            projectId: projectId,
            title: title,
          ),
        );
  }
}

class _MilestoneTile extends ConsumerWidget {
  const _MilestoneTile({required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: milestone.done,
        onChanged: (v) => ref
            .read(projectRepositoryProvider)
            .toggleMilestone(milestone.id, v ?? false),
      ),
      title: Text(
        milestone.title,
        style: TextStyle(
          decoration: milestone.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: milestone.deadline == null
          ? null
          : Text('Para el ${formatDate(milestone.deadline!)}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () =>
            ref.read(projectRepositoryProvider).deleteMilestone(milestone.id),
      ),
    );
  }
}

final milestonesProvider = StreamProvider.family<List<Milestone>, String>(
  (ref, projectId) =>
      ref.watch(projectRepositoryProvider).watchMilestones(projectId),
);
