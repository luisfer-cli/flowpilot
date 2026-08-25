import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Diario')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (entries) {
          final today = dayKey(DateTime.now());
          final hasToday = entries.any((e) => e.dayKey == today);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('Entrada de hoy'),
                  subtitle: Text(hasToday ? 'Editar' : 'Escribe tu día'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditor(context, ref, DateTime.now()),
                ),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.menu_book,
                  title: 'Sin entradas',
                  subtitle: 'Registra tu primera entrada del día',
                )
              else
                for (final e in entries)
                  _JournalTile(
                    entry: e,
                    onTap: () =>
                        _openEditor(context, ref, dateFromDayKey(e.dayKey)),
                  ),
            ],
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, DateTime date) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => JournalEditorScreen(date: date)));
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = entry.mood;
    return Card(
      child: ListTile(
        leading: Icon(
          mood == null ? Icons.menu_book : _moodIcon(mood),
          color: mood == null ? theme.colorScheme.outline : _moodColor(mood),
        ),
        title: Text(
          entry.title?.isNotEmpty == true
              ? entry.title!
              : formatDate(dateFromDayKey(entry.dayKey)),
        ),
        subtitle: Text(
          entry.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Editor for a single day's journal entry.
class JournalEditorScreen extends ConsumerStatefulWidget {
  const JournalEditorScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  int? _mood;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await ref
        .read(journalRepositoryProvider)
        .getByDay(dayKey(widget.date));
    if (entry != null) {
      _title.text = entry.title ?? '';
      _content.text = entry.content;
      _mood = entry.mood;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty) return;
    final day = dayKey(widget.date);
    final existing = await ref.read(journalRepositoryProvider).getByDay(day);
    await ref
        .read(journalRepositoryProvider)
        .upsert(
          JournalEntriesCompanion(
            id: Value(existing?.id ?? generateId()),
            dayKey: Value(day),
            title: Value(
              _title.text.trim().isEmpty ? null : _title.text.trim(),
            ),
            content: Value(_content.text.trim()),
            mood: Value(_mood),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(formatFullDate(widget.date)),
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
                Text('¿Cómo te sientes?', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var m = 1; m <= 5; m++)
                      IconButton(
                        iconSize: 32,
                        icon: Icon(
                          _moodIcon(m),
                          color: m <= (_mood ?? 0)
                              ? _moodColor(m)
                              : theme.colorScheme.outline,
                        ),
                        onPressed: () => setState(() => _mood = m),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'Título (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  autofocus: true,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: 'Escribe sobre tu día…',
                  ),
                ),
              ],
            ),
    );
  }
}

final journalEntriesProvider = StreamProvider<List<JournalEntry>>(
  (ref) => ref.watch(journalRepositoryProvider).watchRecent(),
);

IconData _moodIcon(int mood) {
  switch (mood) {
    case 1:
      return Icons.sentiment_very_dissatisfied;
    case 2:
      return Icons.sentiment_dissatisfied;
    case 3:
      return Icons.sentiment_neutral;
    case 4:
      return Icons.sentiment_satisfied;
    default:
      return Icons.sentiment_very_satisfied;
  }
}

Color _moodColor(int mood) {
  switch (mood) {
    case 1:
      return Colors.red;
    case 2:
      return Colors.orange;
    case 3:
      return Colors.amber;
    case 4:
      return Colors.lightGreen;
    default:
      return Colors.green;
  }
}
