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
    RoutineCompletions,
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(scheduleTemplates);
        await m.createTable(scheduleTemplateBlocks);
      }
      if (from < 3) {
        await m.addColumn(routines, routines.endTimeMinutes);
        await m.addColumn(routines, routines.categoryId);
        await customStatement('''
          INSERT OR IGNORE INTO categories (id, name)
          SELECT id, name FROM activity_categories
        ''');
        await customStatement('''
          UPDATE time_entries SET category_id = category_id
          WHERE category_id IS NOT NULL
        ''');
      }
      if (from < 4) {
        await m.addColumn(scheduleTemplates, scheduleTemplates.categoryId);
      }
      if (from < 5) {
        await customStatement('''
          UPDATE tasks
          SET status = 'Pendiente', is_archived = 1
          WHERE status = 'Cancelled'
        ''');
        await customStatement('''
          UPDATE tasks
          SET status = CASE
            WHEN status IN ('Next', 'In Progress') THEN 'En curso'
            WHEN status = 'Done' THEN 'Completada'
            ELSE 'Pendiente'
          END
          WHERE is_archived = 0
        ''');
        await customStatement('DELETE FROM task_statuses');
        await customStatement('''
          INSERT INTO task_statuses (name, order_index, color)
          VALUES ('Pendiente', 0, 0x9AA5B1),
                 ('En curso', 1, 0x9AA5B1),
                 ('Completada', 2, 0x9AA5B1)
        ''');
      }
      if (from < 6) {
        await m.createTable(routineCompletions);
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
