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
    TimeEntries,
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
  int get schemaVersion => 1;

  static LazyDatabase _openOverride() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
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
