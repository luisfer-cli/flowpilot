import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Areas,
    Goals,
    Projects,
    Milestones,
    TaskStatuses,
    Contexts,
    Categories,
    Tags,
    TaskTags,
    Tasks,
    RecurrenceRules,
    TimeBlocks,
    ScheduleTemplates,
    ScheduleTemplateBlocks,
    TimeEntries,
    ActivityCategories,
    PomodoroSessions,
    Habits,
    HabitCompletions,
    Routines,
    CalendarEvents,
    Reminders,
    Notes,
    Relations,
    EnergyLogs,
    AutomationRules,
    SettingsTable,
    JournalEntries,
  ],
)
class FlowPilotDatabase extends _$FlowPilotDatabase {
  FlowPilotDatabase(super.e);

  FlowPilotDatabase.overridden() : super(_openOverride());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(scheduleTemplates);
        await m.createTable(scheduleTemplateBlocks);
      }
    },
  );

  static LazyDatabase _openOverride() {
    return LazyDatabase(() async {
      Directory dbFolder;
      try {
        dbFolder = await getApplicationDocumentsDirectory();
      } on Object {
        // Some Linux sessions (containers, minimal WMs, or missing XDG user
        // dirs) do not provide a documents directory. Keep the app usable by
        // falling back to a private folder in the user's home directory.
        final home = Platform.environment['HOME'];
        dbFolder = Directory(
          p.join(home ?? Directory.systemTemp.path, '.flowpilot'),
        );
        await dbFolder.create(recursive: true);
      }
      final file = File(p.join(dbFolder.path, 'flowpilot.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  Future<int> setSetting(String key, String? value) {
    return (into(settingsTable).insertOnConflictUpdate(
      SettingsTableCompanion.insert(key: key, value: Value(value)),
    ));
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      settingsTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String?>> allSettings() async {
    final rows = await select(settingsTable).get();
    return {for (final r in rows) r.key: r.value};
  }
}
