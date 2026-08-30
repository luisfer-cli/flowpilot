import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants.dart';
import '../../../core/utils/id.dart';
import '../../../data/local/database.dart';
import '../../../shared/widgets.dart';
import '../checklist_model.dart';
import '../task_providers.dart';

/// Checklist editor bound to a task's checklistJson field.
class ChecklistEditor extends ConsumerWidget {
  const ChecklistEditor({
    super.key,
    required this.taskId,
    required this.initialJson,
  });

  final String taskId;
  final String? initialJson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(taskRepositoryProvider);
    final items = parseChecklist(initialJson);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Checklist'),
        const SizedBox(height: 4),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Sin elementos. Añade uno abajo.'),
          )
        else
          for (var i = 0; i < items.length; i++)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: items[i].done,
              title: Text(
                items[i].text,
                style: TextStyle(
                  decoration: items[i].done ? TextDecoration.lineThrough : null,
                ),
              ),
              onChanged: (v) {
                final updated = [...items];
                updated[i] = ChecklistItem(
                  text: items[i].text,
                  done: v ?? false,
                );
                repo.update(
                  taskId,
                  TasksCompanion(
                    checklistJson: Value(encodeChecklist(updated)),
                  ),
                );
              },
            ),
        const SizedBox(height: 4),
        _AddChecklistItem(
          onAdd: (text) {
            final updated = [...items, ChecklistItem(text: text)];
            repo.update(
              taskId,
              TasksCompanion(checklistJson: Value(encodeChecklist(updated))),
            );
          },
        ),
      ],
    );
  }
}

class _AddChecklistItem extends StatefulWidget {
  const _AddChecklistItem({required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  State<_AddChecklistItem> createState() => _AddChecklistItemState();
}

class _AddChecklistItemState extends State<_AddChecklistItem> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Añadir elemento…',
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(icon: const Icon(Icons.add), onPressed: _submit),
      ],
    );
  }
}

/// Subtask list: add, complete and delete child tasks under a parent task.
class SubtaskEditor extends ConsumerWidget {
  const SubtaskEditor({super.key, required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasksAsync = ref.watch(subtasksProvider(parentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Subtareas'),
        const SizedBox(height: 4),
        subtasksAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (subtasks) => subtasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Sin subtareas.'),
                )
              : Column(
                  children: [
                    for (final sub in subtasks)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: sub.status == kStatusCompleted,
                        title: Text(
                          sub.title,
                          style: TextStyle(
                            decoration: sub.status == kStatusCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              ref.read(taskRepositoryProvider).delete(sub.id),
                        ),
                        onChanged: (_) async {
                          await ref
                              .read(taskRepositoryProvider)
                              .complete(
                                sub.id,
                                done: sub.status != kStatusCompleted,
                              );
                        },
                      ),
                  ],
                ),
        ),
        _AddSubtask(parentId: parentId),
      ],
    );
  }
}

class _AddSubtask extends ConsumerStatefulWidget {
  const _AddSubtask({required this.parentId});

  final String parentId;

  @override
  ConsumerState<_AddSubtask> createState() => _AddSubtaskState();
}

class _AddSubtaskState extends ConsumerState<_AddSubtask> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref
        .read(taskRepositoryProvider)
        .insert(
          TasksCompanion.insert(
            id: generateId(),
            title: text,
            status: const Value(kStatusPending),
            parentId: Value(widget.parentId),
          ),
        );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Añadir subtarea…',
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(icon: const Icon(Icons.add), onPressed: _submit),
      ],
    );
  }
}
