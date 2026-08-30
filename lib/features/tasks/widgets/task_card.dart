import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/constants.dart';
import '../../../core/utils/time_utils.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets.dart';
import '../../recurrence/recurrence_engine.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({super.key, required this.task, this.dense = false});

  final Task task;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = task.status == kStatusCompleted;
    final category = task.categoryId == null
        ? null
        : ref
              .watch(globalCategoriesProvider)
              .valueOrNull
              ?.where((item) => item.id == task.categoryId)
              .firstOrNull;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => goToTaskEdit(context, id: task.id),
        child: Padding(
          padding: EdgeInsets.all(dense ? 10 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompleteBox(task: task, done: done),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: done
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                        if (task.priority > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.flag,
                            size: 16,
                            color: kPriorityColors[task.priority],
                          ),
                        ],
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty &&
                        !dense) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (category != null)
                          _LabelChip(
                            text: category.name,
                            color: Color(category.color),
                          ),
                        if (task.dueDate != null) _DueChip(task: task),
                        if (task.estimatedMinutes != null)
                          TimeBadge(
                            minutes: task.estimatedMinutes!,
                            icon: Icons.schedule,
                          ),
                        if (task.actualMinutes > 0)
                          TimeBadge(
                            minutes: task.actualMinutes,
                            icon: Icons.timelapse,
                          ),
                        if (task.energyRequired != null)
                          Icon(
                            Icons.bolt,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteBox extends ConsumerWidget {
  const _CompleteBox({required this.task, required this.done});

  final Task task;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Checkbox(
      value: done,
      onChanged: (_) async {
        await ref.read(taskRepositoryProvider).complete(task.id, done: !done);
        if (task.recurrenceId != null && !done) {
          await ref.read(recurrenceServiceProvider).onTaskCompleted(task);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate!;
    final now = DateTime.now();
    final overdue = due.isBefore(now) && task.status != kStatusCompleted;
    final color = overdue
        ? const Color(0xFFE05555)
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overdue ? Icons.error_outline : Icons.event,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            overdue ? 'Vencida · ${formatDate(due)}' : formatDate(due),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared task providers used across features.
final taskByIdProvider = StreamProvider.family<Task?, String>(
  (ref, id) => ref.watch(taskRepositoryProvider).watchById(id),
);

final projectByIdProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref.watch(projectRepositoryProvider).getByIdStream(id),
);

final projectNameForTaskProvider = FutureProvider.family<String?, String>((
  ref,
  projectId,
) async {
  final project = await ref.watch(projectRepositoryProvider).getById(projectId);
  return project?.name;
});
