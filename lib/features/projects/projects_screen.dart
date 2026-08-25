import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Objetivos',
            onPressed: () => context.push(AppRouter.goals),
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (projects) {
          final goals = goalsAsync.valueOrNull ?? const <Goal>[];
          if (projects.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open,
              title: 'Sin proyectos',
              subtitle: 'Organiza tus tareas en proyectos',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, i) => _ProjectCard(
              project: projects[i],
              goalTitle: projects[i].goalId == null
                  ? null
                  : goals
                        .where((g) => g.id == projects[i].goalId)
                        .firstOrNull
                        ?.title,
            ),
          );
        },
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, this.goalTitle});

  final Project project;
  final String? goalTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(projectProgressProvider(project.id));
    final timeAsync = ref.watch(projectTimeProvider(project.id));
    final theme = Theme.of(context);
    final color = Color(project.color);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => goToProjectEdit(context, id: project.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (goalTitle != null)
                    Text(
                      goalTitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  project.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              progressAsync.when(
                loading: () => const LinearProgressIndicator(),
                data: (p) {
                  final percent = p.total == 0 ? 0.0 : p.done / p.total;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Progreso: ${(percent * 100).round()}% · ${p.done}/${p.total} tareas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  );
                },
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (project.deadline != null)
                    _InfoPill(
                      icon: Icons.event,
                      text: 'Deadline: ${formatDate(project.deadline!)}',
                    ),
                  timeAsync.valueOrNull != null
                      ? _InfoPill(
                          icon: Icons.timer_outlined,
                          text:
                              'Est ${formatMinutes(timeAsync.valueOrNull!.estimated)} · Real ${formatMinutes(timeAsync.valueOrNull!.actual)}',
                        )
                      : const SizedBox.shrink(),
                  _InfoPill(
                    icon: Icons.circle,
                    text: project.status == 'done' ? 'Completado' : 'Activo',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

final projectProgressProvider =
    FutureProvider.family<({int total, int done}), String>(
      (ref, projectId) =>
          ref.watch(taskRepositoryProvider).projectProgress(projectId),
    );

final projectTimeProvider =
    FutureProvider.family<({int estimated, int actual}), String>(
      (ref, projectId) =>
          ref.watch(taskRepositoryProvider).projectTime(projectId),
    );
