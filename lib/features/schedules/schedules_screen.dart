import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class SchedulesView extends ConsumerWidget {
  const SchedulesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(scheduleTemplatesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Horarios semanales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Nuevo horario',
              icon: const Icon(Icons.add),
              onPressed: () => _createSchedule(context, ref),
            ),
          ],
        ),
        const Text(
          'Agrupa cursos, turnos o bloques que se repiten cada semana.',
        ),
        const SizedBox(height: 12),
        schedules.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('$error'),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.calendar_view_week,
                  title: 'Sin horarios',
                  subtitle: 'Crea uno para organizar tus cursos o actividades',
                )
              : Column(
                  children: [
                    for (final item in items) _ScheduleCard(template: item),
                  ],
                ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  Future<void> _createSchedule(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    String? categoryId;
    final categories =
        ref.read(globalCategoriesProvider).valueOrNull ?? const <Category>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo horario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Ej: Universidad'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Sin categoría'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => categoryId = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isNotEmpty) {
                  await ref
                      .read(scheduleRepositoryProvider)
                      .insertTemplate(
                        ScheduleTemplatesCompanion.insert(
                          id: generateId(),
                          name: name.text.trim(),
                          categoryId: Value(categoryId),
                          active: const Value(true),
                        ),
                      );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.template});
  final ScheduleTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(scheduleBlocksProvider(template.id));
    final category = ref
        .watch(globalCategoriesProvider)
        .valueOrNull
        ?.where((c) => c.id == template.categoryId)
        .firstOrNull;
    final accent = category == null
        ? Theme.of(context).colorScheme.primary
        : Color(category.color);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editSchedule(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 7, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (category != null)
                            Text(
                              category.name,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Switch(
                            value: template.active,
                            onChanged: (value) => ref
                                .read(scheduleRepositoryProvider)
                                .updateTemplate(
                                  template.id,
                                  ScheduleTemplatesCompanion(
                                    active: Value(value),
                                  ),
                                ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'delete') {
                                await ref
                                    .read(scheduleRepositoryProvider)
                                    .deleteTemplate(template.id);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar horario'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      blocks.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (items) => items.isEmpty
                            ? const Text('Toca para agregar cursos o bloques.')
                            : _BlockPreview(items: items, accent: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSchedule(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleEditor(template: template),
    );
  }

  static String _day(int day) =>
      const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][day - 1];
  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class _BlockPreview extends StatelessWidget {
  const _BlockPreview({required this.items, required this.accent});

  final List<ScheduleTemplateBlock> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ScheduleTemplateBlock>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.weekday, () => []).add(item);
    }
    return Column(
      children: [
        for (final entry in grouped.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    _ScheduleCard._day(entry.key),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${_ScheduleCard._time(item.startMinutes)}–${_ScheduleCard._time(item.endMinutes)}  ${item.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ScheduleEditor extends ConsumerWidget {
  const _ScheduleEditor({required this.template});
  final ScheduleTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(scheduleBlocksProvider(template.id));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _addBlock(context, ref),
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar curso',
                ),
              ],
            ),
            const Text('Agrega cada curso o bloque con sus días y horas.'),
            const SizedBox(height: 12),
            blocks.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => items.isEmpty
                  ? const Text('Todavía no hay bloques.')
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final block in items)
                            ListTile(
                              leading: Text(_ScheduleCard._day(block.weekday)),
                              title: Text(block.title),
                              subtitle: Text(
                                '${_ScheduleCard._time(block.startMinutes)}–${_ScheduleCard._time(block.endMinutes)}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(scheduleRepositoryProvider)
                                    .deleteBlock(block.id),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBlock(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final weekdays = <int>{1};
    var start = 9 * 60;
    var end = 10 * 60;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo curso o bloque'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Nombre'),
                autofocus: true,
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
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(_ScheduleCard._day(i)),
                      selected: weekdays.contains(i),
                      onSelected: (selected) => setState(
                        () => selected ? weekdays.add(i) : weekdays.remove(i),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _timeButton(
                      context,
                      'Inicio',
                      start,
                      (v) => setState(() => start = v),
                    ),
                  ),
                  Expanded(
                    child: _timeButton(
                      context,
                      'Fin',
                      end,
                      (v) => setState(() => end = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isNotEmpty &&
                    end > start &&
                    weekdays.isNotEmpty) {
                  for (final weekday in weekdays) {
                    await ref
                        .read(scheduleRepositoryProvider)
                        .insertBlock(
                          ScheduleTemplateBlocksCompanion.insert(
                            id: generateId(),
                            templateId: template.id,
                            weekday: weekday,
                            startMinutes: start,
                            endMinutes: end,
                            title: title.text.trim(),
                          ),
                        );
                  }
                }
                if (dialog.mounted) Navigator.pop(dialog);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
  }

  Widget _timeButton(
    BuildContext context,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) => TextButton(
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
      );
      if (picked != null) onChanged(picked.hour * 60 + picked.minute);
    },
    child: Text('$label ${_ScheduleCard._time(value)}'),
  );
}

final scheduleTemplatesProvider = StreamProvider<List<ScheduleTemplate>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchTemplates(),
);
final scheduleBlocksProvider =
    StreamProvider.family<List<ScheduleTemplateBlock>, String>(
      (ref, id) => ref.watch(scheduleRepositoryProvider).watchBlocks(id),
    );

final scheduleBlocksForDayProvider =
    FutureProvider.family<List<ScheduleAgendaBlock>, int>((ref, weekday) async {
      final templates = await ref.watch(scheduleTemplatesProvider.future);
      final repository = ref.watch(scheduleRepositoryProvider);
      final blocks = <ScheduleAgendaBlock>[];
      for (final template in templates.where((item) => item.active)) {
        blocks.addAll(
          (await repository.blocksFor(template.id))
              .where((block) => block.weekday == weekday)
              .map(
                (block) => ScheduleAgendaBlock(
                  startMinutes: block.startMinutes,
                  endMinutes: block.endMinutes,
                  title: block.title,
                  categoryId: template.categoryId,
                ),
              ),
        );
      }
      blocks.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      return blocks;
    });

class ScheduleAgendaBlock {
  const ScheduleAgendaBlock({
    required this.startMinutes,
    required this.endMinutes,
    required this.title,
    this.categoryId,
  });

  final int startMinutes;
  final int endMinutes;
  final String title;
  final String? categoryId;
}
