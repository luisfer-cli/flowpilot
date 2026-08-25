import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_card.dart';

/// Universal search across tasks, projects, goals and notes.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(allTasksProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final notesAsync = ref.watch(notesProvider);

    final q = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar tareas, proyectos, objetivos, notas…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const EmptyState(
                    icon: Icons.search,
                    title: 'Escribe para buscar',
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _taskResults(tasksAsync.valueOrNull ?? const [], q),
                      _projectResults(projectsAsync.valueOrNull ?? const [], q),
                      _goalResults(goalsAsync.valueOrNull ?? const [], q),
                      _noteResults(notesAsync.valueOrNull ?? const [], q),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _taskResults(List<Task> tasks, String q) {
    final matches = tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              (t.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tareas (${matches.length})'),
        for (final t in matches.take(10)) TaskCard(task: t, dense: true),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _projectResults(List<Project> projects, String q) {
    final matches = projects
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Proyectos (${matches.length})'),
        for (final p in matches.take(10))
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: Color(p.color)),
              title: Text(p.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToProjectEdit(context, id: p.id),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _goalResults(List<Goal> goals, String q) {
    final matches = goals
        .where((g) => g.title.toLowerCase().contains(q))
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Objetivos (${matches.length})'),
        for (final g in matches.take(10))
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag),
              title: Text(g.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goToGoalEdit(context, id: g.id),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _noteResults(List<Note> notes, String q) {
    final matches = notes
        .where((n) => n.content.toLowerCase().contains(q))
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Notas (${matches.length})'),
        for (final n in matches.take(10))
          Card(
            child: ListTile(
              leading: const Icon(Icons.note),
              title: Text(
                n.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(formatDate(n.createdAt)),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

final notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(noteRepositoryProvider).watchAll(),
);
