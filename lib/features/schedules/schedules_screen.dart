import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(scheduleTemplatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Horarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTemplate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo horario'),
      ),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.schedule,
                title: 'Sin horarios',
                subtitle: 'Crea una plantilla para organizar tu semana',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Plantillas semanales',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final item in items) _TemplateTile(template: item),
                  const SizedBox(height: 96),
                ],
              ),
      ),
    );
  }

  Future<void> _createTemplate(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nuevo horario'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Semana laboral'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final repository = ref.read(scheduleRepositoryProvider);
                final templateId = generateId();
                await repository.insertTemplate(
                  ScheduleTemplatesCompanion.insert(
                    id: templateId,
                    name: controller.text.trim(),
                  ),
                );
                // Start with a useful weekday preset instead of an empty template.
                for (var weekday = 1; weekday <= 5; weekday++) {
                  await repository.insertBlock(
                    ScheduleTemplateBlocksCompanion.insert(
                      id: generateId(),
                      templateId: templateId,
                      weekday: weekday,
                      startMinutes: 9 * 60,
                      endMinutes: 17 * 60,
                      title: 'Bloque principal',
                    ),
                  );
                }
              }
              if (dialog.mounted) Navigator.pop(dialog);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});
  final ScheduleTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const Icon(Icons.view_week_outlined),
      title: Text(template.name),
      subtitle: const Text('Plantilla semanal'),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'apply') {
            await ref
                .read(scheduleRepositoryProvider)
                .applyToWeek(template.id, startOfWeek(DateTime.now()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Horario aplicado a esta semana')),
              );
            }
          } else {
            await ref
                .read(scheduleRepositoryProvider)
                .deleteTemplate(template.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'apply', child: Text('Aplicar esta semana')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    ),
  );
}

final scheduleTemplatesProvider = StreamProvider<List<ScheduleTemplate>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchTemplates(),
);
