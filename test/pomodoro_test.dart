import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flowpilot/data/local/database.dart';
import 'package:flowpilot/data/repositories/pomodoro_repository.dart';
import 'package:flowpilot/features/pomodoro/pomodoro_timer.dart';

void main() {
  late FlowPilotDatabase db;
  late PomodoroRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = FlowPilotDatabase(NativeDatabase.memory());
    repo = PomodoroRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('start runs focus phase and pause stops it', () async {
    final controller = PomodoroController(repo: repo);
    await Future<void>.delayed(Duration.zero);

    controller.start();
    expect(controller.state.isRunning, isTrue);
    expect(controller.state.phase, PomodoroPhase.focus);

    controller.pause();
    expect(controller.state.isRunning, isFalse);
    expect(controller.state.phase, PomodoroPhase.focus);

    controller.dispose();
  });

  test('stop resets to focus and does not create completed session', () async {
    final controller = PomodoroController(repo: repo);
    await Future<void>.delayed(Duration.zero);

    controller.start();
    await controller.stop();

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.phase, PomodoroPhase.focus);

    final sessions = await repo.watchRecent().first;
    expect(sessions.where((s) => s.completed), isEmpty);

    controller.dispose();
  });

  test('setting a task propagates to state', () async {
    final controller = PomodoroController(repo: repo);
    await Future<void>.delayed(Duration.zero);

    controller.setTask('task-1');
    expect(controller.state.taskId, 'task-1');

    controller.setTask(null);
    expect(controller.state.taskId, isNull);

    controller.dispose();
  });
}
