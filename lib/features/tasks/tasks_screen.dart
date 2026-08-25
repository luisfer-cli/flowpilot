import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import 'task_providers.dart';
import 'widgets/task_card.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _selectedStatus;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusesAsync = ref.watch(statusesProvider);
    final tasksAsync = ref.watch(allTasksProvider);
    final countsAsync = ref.watch(countsByStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: statusesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Error',
            subtitle: '$e',
          ),
          data: (statuses) {
            final tasks = tasksAsync.valueOrNull ?? const <Task>[];
            final counts = countsAsync.valueOrNull ?? const <String, int>{};
            final filtered = _filterTasks(tasks);
            final grouped = _groupByStatus(filtered, statuses);

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildFilters(statuses, counts)),
                if (_query.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${filtered.length} resultado(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                if (grouped.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.task_alt,
                      title: 'Sin tareas',
                      subtitle: 'Toca el botón + para crear una tarea',
                    ),
                  )
                else
                  for (final entry in grouped)
                    SliverToBoxAdapter(
                      child: _buildSection(entry.key, entry.value),
                    ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters(List<TaskStatus> statuses, Map<String, int> counts) {
    final chips = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text('Todas'),
          selected: _selectedStatus == null,
          onSelected: (_) => setState(() => _selectedStatus = null),
        ),
      ),
      for (final s in statuses)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FilterChip(
            label: Text('${s.name} (${counts[s.name] ?? 0})'),
            selected: _selectedStatus == s.name,
            onSelected: (_) => setState(() => _selectedStatus = s.name),
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar tareas…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(TaskStatus status, List<Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(status.name, trailing: Text('${tasks.length}')),
          const SizedBox(height: 6),
          for (final task in tasks) TaskCard(task: task),
        ],
      ),
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    var result = tasks.where((t) => !t.isArchived).toList();
    if (_selectedStatus != null) {
      result = result.where((t) => t.status == _selectedStatus).toList();
    }
    if (_query.isNotEmpty) {
      result = result.where((t) {
        return t.title.toLowerCase().contains(_query) ||
            (t.description?.toLowerCase().contains(_query) ?? false);
      }).toList();
    }
    return result;
  }

  List<MapEntry<TaskStatus, List<Task>>> _groupByStatus(
    List<Task> tasks,
    List<TaskStatus> statuses,
  ) {
    final groups = <String, List<Task>>{};
    for (final t in tasks) {
      groups.putIfAbsent(t.status, () => []).add(t);
    }
    // Sort statuses in pipeline order, active first.
    final ordered = [
      ...statuses.where((s) => !_isTerminal(s.name)),
      ...statuses.where((s) => _isTerminal(s.name)),
    ];
    return [
      for (final s in ordered)
        if (groups.containsKey(s.name)) MapEntry(s, groups[s.name]!),
    ];
  }

  bool _isTerminal(String status) =>
      status == kStatusDone || status == kStatusCancelled;
}
