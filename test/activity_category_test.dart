import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/data/repositories/category_repository.dart';

void main() {
  test('seeds editable activity categories', () async {
    final db = FlowPilotDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CategoryRepository(db);
    await repo.seedIfNeeded();
    expect(
      (await repo.watchAll().first).map((c) => c.name),
      containsAll([
        'Trabajo',
        'Universidad',
        'Personal',
        'Salud',
        'Pasatiempo',
      ]),
    );
  });
}
