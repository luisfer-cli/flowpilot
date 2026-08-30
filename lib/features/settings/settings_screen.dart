import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../core/constants.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import 'settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(settingsServiceProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._service) : super(ThemeMode.system) {
    _load();
  }

  final SettingsService _service;

  Future<void> _load() async {
    final mode = await _service.getThemeMode();
    state = switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _service.setThemeMode(mode.name);
  }
}

final apiKeyProvider = FutureProvider<String?>(
  (ref) => ref.watch(settingsServiceProvider).getApiKey(),
);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    await ref
        .read(settingsServiceProvider)
        .setApiKey(_apiKeyController.text.trim());
    ref.invalidate(apiKeyProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Clave guardada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final apiKey = ref.watch(apiKeyProvider).valueOrNull;
    if (_apiKeyController.text.isEmpty && apiKey != null) {
      _apiKeyController.text = apiKey;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader('Apariencia'),
          const SizedBox(height: 6),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
              ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 24),
          SectionHeader('IA · OpenRouter'),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clave de API (se guarda cifrada en el dispositivo).',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (defaultTargetPlatform == TargetPlatform.linux) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'En Linux se guarda sin cifrar (no hay secret service).',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'sk-or-…',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save_outlined),
                        onPressed: _saveApiKey,
                        tooltip: 'Guardar',
                      ),
                    ),
                    onSubmitted: (_) => _saveApiKey(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          SectionHeader('Acerca de'),
          const SizedBox(height: 6),
          Card(
            child: ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('FlowPilot'),
              subtitle: const Text(
                'Planificación y productividad personal · v1.0',
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader('Datos'),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Exportar tareas (JSON)'),
                  onTap: () => _exportTasks(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart),
                  title: const Text('Exportar CSV'),
                  onTap: () => _exportCsv(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('Exportar Markdown'),
                  onTap: () => _exportMarkdown(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: const Text('Exportar calendario (ICS)'),
                  onTap: () => _exportIcs(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Backup completo (JSON)'),
                  onTap: () => _exportBackup(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }

  Future<void> _exportTasks(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).watchAll().first;
    final projects = await ref.read(projectRepositoryProvider).watchAll().first;
    final projectNames = {for (final p in projects) p.id: p.name};
    final json = _tasksToJson(tasks, projectNames);
    final file = XFile.fromData(
      Uint8List.fromList(_utf8(json)),
      mimeType: 'application/json',
      name:
          'flowpilot-export-${DateTime.now().toIso8601String().substring(0, 10)}.json',
    );
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  Future<void> _shareText(String content, String ext, String mime) async {
    final file = XFile.fromData(
      Uint8List.fromList(_utf8(content)),
      mimeType: mime,
      name:
          'flowpilot-${DateTime.now().toIso8601String().substring(0, 10)}.$ext',
    );
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).watchAll().first;
    final buffer = StringBuffer(
      'id,title,status,priority,estimated,actual,due\n',
    );
    for (final t in tasks) {
      buffer.write(
        '${t.id},${_escCsv(t.title)},${t.status},${t.priority},'
        '${t.estimatedMinutes ?? 0},${t.actualMinutes},${t.dueDate ?? ''}\n',
      );
    }
    await _shareText(buffer.toString(), 'csv', 'text/csv');
  }

  Future<void> _exportMarkdown(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).watchAll().first;
    final buffer = StringBuffer('# FlowPilot - Tareas\n\n');
    for (final t in tasks) {
      buffer.write(
        '- [${t.status == kStatusCompleted ? 'x' : ' '}] **${t.title}**',
      );
      if (t.dueDate != null) buffer.write(' (vence ${formatDate(t.dueDate!)})');
      buffer.write('\n');
    }
    await _shareText(buffer.toString(), 'md', 'text/markdown');
  }

  Future<void> _exportIcs(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).watchAll().first;
    final buffer = StringBuffer('BEGIN:VCALENDAR\nVERSION:2.0\n');
    for (final t in tasks) {
      final due = t.dueDate;
      if (due == null) continue;
      buffer.write('BEGIN:VEVENT\n');
      buffer.write('UID:${t.id}\n');
      buffer.write('SUMMARY:${_escIcs(t.title)}\n');
      final stamp = _icsDate(due);
      buffer.write('DTSTART:$stamp\nDTEND:$stamp\n');
      buffer.write('END:VEVENT\n');
    }
    buffer.write('END:VCALENDAR');
    await _shareText(buffer.toString(), 'ics', 'text/calendar');
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final tasks = await ref.read(taskRepositoryProvider).watchAll().first;
    final projects = await ref.read(projectRepositoryProvider).watchAll().first;
    final goals = await ref
        .read(goalRepositoryProvider)
        .watchObjectives()
        .first;
    final blocks = await ref
        .read(timeBlockRepositoryProvider)
        .getByDayRange(0, 99999999);
    final json = _backupToJson(tasks, projects, goals, blocks);
    await _shareText(json, 'json', 'application/json');
  }

  String _backupToJson(
    List<Task> tasks,
    List<Project> projects,
    List<Goal> goals,
    List<TimeBlock> blocks,
  ) {
    final buffer = StringBuffer(
      '{\n"exportedAt":"${DateTime.now().toIso8601String()}",\n',
    );
    buffer.write('"tasks":${_tasksToJson(tasks, {})},\n');
    buffer.write(
      '"projects":[${projects.map((p) => '{"name":"${_esc(p.name)}"}').join(',')}],\n',
    );
    buffer.write(
      '"goals":[${goals.map((g) => '{"title":"${_esc(g.title)}"}').join(',')}],\n',
    );
    buffer.write('"timeBlocks":${blocks.length}\n}');
    return buffer.toString();
  }

  String _escCsv(String s) =>
      s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;

  String _escIcs(String s) => s.replaceAll('\n', ' ').replaceAll(',', '\\,');

  String _icsDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}'
      '${d.minute.toString().padLeft(2, '0')}00';

  String _tasksToJson(List<Task> tasks, Map<String, String> projectNames) {
    final buffer = StringBuffer('[\n');
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      buffer.write('  {');
      buffer.write('"id":"${t.id}","title":"${_esc(t.title)}"');
      buffer.write(',"status":"${t.status}"');
      buffer.write(',"priority":${t.priority}');
      buffer.write(',"project":"${_esc(projectNames[t.projectId] ?? '')}"');
      buffer.write(',"estimatedMinutes":${t.estimatedMinutes ?? 0}');
      buffer.write(',"actualMinutes":${t.actualMinutes}');
      buffer.write(',"dueDate":"${t.dueDate?.toIso8601String() ?? ''}"');
      buffer.write('}');
      if (i < tasks.length - 1) buffer.write(',');
      buffer.write('\n');
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _esc(String s) => s.replaceAll('"', '\\"');

  List<int> _utf8(String s) => s.codeUnits;
}
