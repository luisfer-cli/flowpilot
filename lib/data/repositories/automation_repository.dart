import 'package:drift/drift.dart';

import '../local/database.dart';

class AutomationRepository {
  AutomationRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<AutomationRule>> watchAll() {
    return (_db.select(_db.automationRules)).watch();
  }

  Future<void> insert(AutomationRulesCompanion rule) =>
      _db.into(_db.automationRules).insert(rule);

  Future<void> update(String id, AutomationRulesCompanion rule) async {
    await (_db.update(
      _db.automationRules,
    )..where((r) => r.id.equals(id))).write(rule);
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.automationRules)..where((r) => r.id.equals(id))).go();
  }

  /// Seeds a default set of useful automation rules on first launch.
  Future<void> seedIfNeeded() async {
    final count = await _db
        .customSelect(
          'SELECT COUNT(*) as c FROM automation_rules',
          readsFrom: {_db.automationRules},
        )
        .getSingle();
    if (count.read<int>('c') > 0) return;

    await _db.batch((b) {
      b.insert(
        _db.automationRules,
        AutomationRulesCompanion.insert(
          id: 'auto_1',
          name: 'Actualizar proyecto al completar',
          trigger: 'task_completed',
          actionsJson: const Value('["update_project_progress"]'),
        ),
      );
      b.insert(
        _db.automationRules,
        AutomationRulesCompanion.insert(
          id: 'auto_2',
          name: 'Recalcular objetivo al completar',
          trigger: 'task_completed',
          actionsJson: const Value('["recalculate_goal"]'),
        ),
      );
    });
  }
}
