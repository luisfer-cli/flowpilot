import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../ai/ai_service.dart';
import '../ai/openrouter_client.dart';

/// Inbox: capture free text and let the AI turn it into structured tasks.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _text = TextEditingController();
  bool _analyzing = false;
  List<ParsedTask>? _parsed;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_text.text.trim().isEmpty) return;
    setState(() {
      _analyzing = true;
      _error = null;
      _parsed = null;
    });
    try {
      final result = await ref
          .read(aiServiceProvider)
          .parseBrainDump(_text.text.trim());
      if (!mounted) return;
      setState(() => _parsed = result);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _saveParsed(ParsedTask task) async {
    DateTime? due;
    if (task.due != null && task.due!.isNotEmpty) {
      due = DateTime.tryParse(task.due!);
    }
    await ref
        .read(taskRepositoryProvider)
        .insert(
          TasksCompanion.insert(
            id: generateId(),
            title: task.title,
            priority: Value(task.priority),
            notes: Value(task.notes),
            dueDate: Value(due),
            status: const Value('Inbox'),
          ),
        );
    if (!mounted) return;
    setState(() => _parsed?.remove(task));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Tarea creada: ${task.title}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escribe todo lo que tengas en la cabeza. La IA lo convierte en tareas.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Ej: Terminar el portfolio, comprar comida y estudiar Kubernetes…',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _analyzing ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_analyzing ? 'Analizando…' : 'Analizar con IA'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_parsed != null) ...[
            const SizedBox(height: 20),
            SectionHeader(
              'Tareas detectadas',
              trailing: Text(
                '${_parsed!.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 6),
            for (final task in _parsed!)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: Text(task.title),
                  subtitle: Text(_parsedSubtitle(task)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle),
                    tooltip: 'Guardar tarea',
                    onPressed: () => _saveParsed(task),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  String _parsedSubtitle(ParsedTask task) {
    final parts = <String>[];
    if (task.due != null && task.due!.isNotEmpty) {
      parts.add('Vence: ${task.due}');
    }
    if (task.priority > 0) parts.add('Prioridad: ${task.priority}');
    if (task.notes != null && task.notes!.isNotEmpty) parts.add(task.notes!);
    return parts.join(' · ');
  }
}
