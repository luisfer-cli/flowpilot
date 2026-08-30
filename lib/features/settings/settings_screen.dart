import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../core/constants.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
      (ref) => AppSettingsNotifier(ref.watch(settingsServiceProvider)),
    );

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._service) : super(const AppSettings()) {
    _load();
  }

  final SettingsService _service;

  Future<void> _load() async {
    state = await _service.getAppSettings();
  }

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await _service.setAppSettings(state);
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(l10n.appearance),
          const SizedBox(height: 6),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => ref
                .read(appSettingsProvider.notifier)
                .update((current) => current.copyWith(themeMode: s.first)),
          ),
          const SizedBox(height: 16),
          SectionHeader(l10n.languageAndFormat),
          const SizedBox(height: 6),
          Card(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: settings.languageCode,
                  decoration: InputDecoration(
                    labelText: l10n.language,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [
                    DropdownMenuItem(value: 'es', child: Text(l10n.spanish)),
                    DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .update(
                          (current) => current.copyWith(languageCode: value),
                        );
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<DateFormatPreference>(
                  initialValue: settings.dateFormat,
                  decoration: InputDecoration(
                    labelText: l10n.dateFormat,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: DateFormatPreference.locale,
                      child: Text(l10n.accordingToLanguage),
                    ),
                    DropdownMenuItem(
                      value: DateFormatPreference.dayMonthYear,
                      child: Text('DD/MM/YYYY'),
                    ),
                    DropdownMenuItem(
                      value: DateFormatPreference.monthDayYear,
                      child: Text('MM/DD/YYYY'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .update(
                          (current) => current.copyWith(dateFormat: value),
                        );
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<HourFormatPreference>(
                  initialValue: settings.hourFormat,
                  decoration: InputDecoration(
                    labelText: l10n.hourFormat,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: HourFormatPreference.locale,
                      child: Text(l10n.accordingToLanguage),
                    ),
                    DropdownMenuItem(
                      value: HourFormatPreference.h24,
                      child: Text('24 horas'),
                    ),
                    DropdownMenuItem(
                      value: HourFormatPreference.h12,
                      child: Text('12 horas'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .update(
                          (current) => current.copyWith(hourFormat: value),
                        );
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text(l10n.weekStartsMonday),
                  value: settings.weekStartsMonday,
                  onChanged: (value) => ref
                      .read(appSettingsProvider.notifier)
                      .update(
                        (current) => current.copyWith(weekStartsMonday: value),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          SectionHeader(l10n.about),
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
          SectionHeader(l10n.data),
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
