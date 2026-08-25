import 'package:drift/drift.dart';

import '../local/database.dart';

class NoteRepository {
  NoteRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Note>> watchAll() {
    return (_db.select(_db.notes)..orderBy([
          (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  Future<void> insert(NotesCompanion n) => _db.into(_db.notes).insert(n);

  Future<void> delete(String id) async {
    await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
  }

  // Relations graph
  Future<void> addRelation({
    required String fromType,
    required String fromId,
    required String toType,
    required String toId,
    String? relationType,
  }) async {
    final existing =
        await (_db.select(_db.relations)..where(
              (r) =>
                  r.fromType.equals(fromType) &
                  r.fromId.equals(fromId) &
                  r.toType.equals(toType) &
                  r.toId.equals(toId),
            ))
            .getSingleOrNull();
    if (existing != null) return;
    await _db
        .into(_db.relations)
        .insert(
          RelationsCompanion.insert(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fromType: fromType,
            fromId: fromId,
            toType: toType,
            toId: toId,
            relationType: Value(relationType),
          ),
        );
  }

  Future<void> removeRelation(String id) async {
    await (_db.delete(_db.relations)..where((r) => r.id.equals(id))).go();
  }

  Stream<List<Relation>> watchFor(String type, String id) {
    return (_db.select(_db.relations)..where(
          (r) =>
              (r.fromType.equals(type) & r.fromId.equals(id)) |
              (r.toType.equals(type) & r.toId.equals(id)),
        ))
        .watch();
  }
}
