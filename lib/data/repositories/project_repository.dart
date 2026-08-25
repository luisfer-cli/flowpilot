import 'package:drift/drift.dart';

import '../local/database.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final FlowPilotDatabase _db;

  Stream<List<Project>> watchAll() {
    return (_db.select(
      _db.projects,
    )..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).watch();
  }

  Future<Project?> getById(String id) {
    return (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<Project?> getByIdStream(String id) {
    return (_db.select(
      _db.projects,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  Future<List<Project>> getByGoal(String goalId) {
    return (_db.select(
      _db.projects,
    )..where((p) => p.goalId.equals(goalId))).get();
  }

  Future<void> insert(ProjectsCompanion project) =>
      _db.into(_db.projects).insert(project);

  Future<void> update(String id, ProjectsCompanion project) async {
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      project.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
    await (_db.delete(
      _db.milestones,
    )..where((m) => m.projectId.equals(id))).go();
  }

  // Milestones
  Stream<List<Milestone>> watchMilestones(String projectId) {
    return (_db.select(_db.milestones)
          ..where((m) => m.projectId.equals(projectId))
          ..orderBy([(m) => OrderingTerm(expression: m.orderIndex)]))
        .watch();
  }

  Future<void> insertMilestone(MilestonesCompanion m) =>
      _db.into(_db.milestones).insert(m);

  Future<void> updateMilestone(String id, MilestonesCompanion m) async {
    await (_db.update(_db.milestones)..where((x) => x.id.equals(id))).write(m);
  }

  Future<void> deleteMilestone(String id) async {
    await (_db.delete(_db.milestones)..where((m) => m.id.equals(id))).go();
  }

  Future<void> toggleMilestone(String id, bool done) async {
    await (_db.update(_db.milestones)..where((m) => m.id.equals(id))).write(
      MilestonesCompanion(done: Value(done)),
    );
  }

  Future<int> milestonesDoneCount(String projectId) async {
    final rows = await (_db.select(
      _db.milestones,
    )..where((m) => m.projectId.equals(projectId))).get();
    return rows.where((m) => m.done).length;
  }
}
