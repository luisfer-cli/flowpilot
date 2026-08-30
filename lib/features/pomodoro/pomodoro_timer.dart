import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../core/services/notifications_service.dart';
import '../../core/utils/id.dart';
import '../../data/local/database.dart';
import '../../data/repositories/pomodoro_repository.dart';
import '../../data/repositories/time_entry_repository.dart';

enum PomodoroPhase { focus, shortBreak, longBreak }

class PomodoroConfig {
  const PomodoroConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 20,
    this.cyclesBeforeLongBreak = 4,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;

  static const _focusKey = 'pomo_focus';
  static const _shortKey = 'pomo_short';
  static const _longKey = 'pomo_long';
  static const _cyclesKey = 'pomo_cycles';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_focusKey, focusMinutes);
    await prefs.setInt(_shortKey, shortBreakMinutes);
    await prefs.setInt(_longKey, longBreakMinutes);
    await prefs.setInt(_cyclesKey, cyclesBeforeLongBreak);
  }

  static Future<PomodoroConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PomodoroConfig(
      focusMinutes: prefs.getInt(_focusKey) ?? 25,
      shortBreakMinutes: prefs.getInt(_shortKey) ?? 5,
      longBreakMinutes: prefs.getInt(_longKey) ?? 20,
      cyclesBeforeLongBreak: prefs.getInt(_cyclesKey) ?? 4,
    );
  }

  String get label => '$focusMinutes/$shortBreakMinutes';
}

class PomodoroState {
  const PomodoroState({
    this.phase = PomodoroPhase.focus,
    this.timeLeftSeconds = 25 * 60,
    this.isRunning = false,
    this.cycleCount = 0,
    this.taskId,
    this.categoryId,
  });

  final PomodoroPhase phase;
  final int timeLeftSeconds;
  final bool isRunning;
  final int cycleCount;
  final String? taskId;
  final String? categoryId;

  int get totalSeconds {
    switch (phase) {
      case PomodoroPhase.focus:
        return 25 * 60;
      case PomodoroPhase.shortBreak:
        return 5 * 60;
      case PomodoroPhase.longBreak:
        return 20 * 60;
    }
  }

  PomodoroState copyWith({
    PomodoroPhase? phase,
    int? timeLeftSeconds,
    bool? isRunning,
    int? cycleCount,
    String? taskId,
    bool clearTask = false,
    String? categoryId,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
      isRunning: isRunning ?? this.isRunning,
      cycleCount: cycleCount ?? this.cycleCount,
      taskId: clearTask ? null : (taskId ?? this.taskId),
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

class PomodoroController extends StateNotifier<PomodoroState> {
  PomodoroController({required this.repo, this.timeRepo})
    : super(const PomodoroState()) {
    _loadConfig();
  }

  final PomodoroRepository repo;
  final TimeEntryRepository? timeRepo;
  Timer? _ticker;
  PomodoroConfig _config = const PomodoroConfig();
  String? _sessionId;
  DateTime? _sessionStart;
  String? _trackerEntryId;

  /// Optional callback fired when a phase completes (focus or break).
  void Function(PomodoroPhase completed)? onPhaseComplete;

  PomodoroConfig get config => _config;

  Future<void> _loadConfig() async {
    _config = await PomodoroConfig.load();
    if (!state.isRunning) {
      state = state.copyWith(timeLeftSeconds: _config.focusMinutes * 60);
    }
  }

  Future<void> updateConfig(PomodoroConfig config) async {
    _config = config;
    await config.save();
    if (!state.isRunning) {
      state = state.copyWith(timeLeftSeconds: _config.focusMinutes * 60);
    }
  }

  void setTask(String? taskId) {
    state = state.copyWith(taskId: taskId, clearTask: taskId == null);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void start() {
    if (state.isRunning) return;
    if (state.phase != PomodoroPhase.focus ||
        state.timeLeftSeconds >= state.totalSeconds) {
      _beginPhase(PomodoroPhase.focus);
    }
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    state = state.copyWith(isRunning: true);
    if (state.phase == PomodoroPhase.focus) _startTracker();
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(isRunning: false);
    _stopTracker();
  }

  void resume() {
    if (state.isRunning) return;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    state = state.copyWith(isRunning: true);
    if (state.phase == PomodoroPhase.focus) _startTracker();
  }

  /// Stops the current focus session, saving it as interrupted/abandoned.
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _stopTracker();
    if (_sessionId != null && state.phase == PomodoroPhase.focus) {
      final elapsed = DateTime.now().difference(_sessionStart!);
      final abandoned = elapsed.inMinutes < (_config.focusMinutes / 2);
      await repo.updateSession(
        _sessionId!,
        PomodoroSessionsCompanion(
          end: Value(DateTime.now()),
          completed: const Value(false),
          interruptions: Value(1),
          abandoned: Value(abandoned),
        ),
      );
      _sessionId = null;
    }
    _sessionStart = null;
    state = state.copyWith(
      phase: PomodoroPhase.focus,
      timeLeftSeconds: _config.focusMinutes * 60,
      isRunning: false,
    );
  }

  /// Skips the current phase without saving a completed session.
  Future<void> skip() async {
    await _stopTracker();
    if (state.phase == PomodoroPhase.focus) {
      await _saveInterrupted();
    }
    _sessionId = null;
    _sessionStart = null;
    _beginPhase(_nextPhaseAfter(PomodoroPhase.focus));
  }

  void resetCycle() {
    state = state.copyWith(cycleCount: 0);
  }

  void _tick() {
    final left = state.timeLeftSeconds - 1;
    if (left <= 0) {
      _completePhase();
    } else {
      state = state.copyWith(timeLeftSeconds: left);
    }
  }

  Future<void> _completePhase() async {
    _ticker?.cancel();
    _ticker = null;
    final completed = state.phase;
    await _stopTracker();
    if (completed == PomodoroPhase.focus) {
      await _saveCompleted();
      state = state.copyWith(cycleCount: state.cycleCount + 1);
    }
    onPhaseComplete?.call(completed);
    _beginPhase(_nextPhaseAfter(completed));
  }

  void _beginPhase(PomodoroPhase phase) {
    final seconds = switch (phase) {
      PomodoroPhase.focus => _config.focusMinutes * 60,
      PomodoroPhase.shortBreak => _config.shortBreakMinutes * 60,
      PomodoroPhase.longBreak => _config.longBreakMinutes * 60,
    };
    _sessionStart = phase == PomodoroPhase.focus ? DateTime.now() : null;
    _sessionId = phase == PomodoroPhase.focus ? generateId() : null;
    state = state.copyWith(
      phase: phase,
      timeLeftSeconds: seconds,
      isRunning: false,
    );
  }

  PomodoroPhase _nextPhaseAfter(PomodoroPhase phase) {
    if (phase == PomodoroPhase.focus) {
      final isLastCycle =
          (state.cycleCount + 1) % _config.cyclesBeforeLongBreak == 0;
      return isLastCycle ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
    }
    return PomodoroPhase.focus;
  }

  Future<void> _saveCompleted() async {
    if (_sessionId == null) return;
    await repo.insertSession(
      PomodoroSessionsCompanion.insert(
        id: _sessionId!,
        taskId: Value(state.taskId),
        start: _sessionStart ?? DateTime.now(),
        plannedMinutes: _config.focusMinutes,
        completed: const Value(true),
      ),
    );
    _sessionId = null;
  }

  Future<void> _saveInterrupted() async {
    if (_sessionId == null) return;
    final elapsed = DateTime.now().difference(_sessionStart!);
    await repo.updateSession(
      _sessionId!,
      PomodoroSessionsCompanion(
        end: Value(DateTime.now()),
        completed: const Value(false),
        interruptions: Value(1),
        abandoned: Value(elapsed.inMinutes < (_config.focusMinutes / 2)),
      ),
    );
    _sessionId = null;
  }

  Future<void> _startTracker() async {
    if (_trackerEntryId != null || timeRepo == null) return;
    _trackerEntryId = await timeRepo!.startTimer(
      taskId: state.taskId,
      categoryId: state.categoryId,
      source: 'pomodoro',
    );
  }

  Future<void> _stopTracker() async {
    final id = _trackerEntryId;
    _trackerEntryId = null;
    if (id != null && timeRepo != null) await timeRepo!.stopTimer(id);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final pomodoroControllerProvider =
    StateNotifierProvider<PomodoroController, PomodoroState>((ref) {
      final controller = PomodoroController(
        repo: ref.watch(pomodoroRepositoryProvider),
        timeRepo: ref.watch(timeEntryRepositoryProvider),
      );
      controller.onPhaseComplete = (phase) {
        SystemSound.play(SystemSoundType.alert);
        final isFocus = phase == PomodoroPhase.focus;
        NotificationsService.instance.show(
          id: isFocus ? 1001 : 1002,
          title: isFocus ? '¡Descanso!' : '¡A trabajar!',
          body: isFocus
              ? 'Pomodoro completado. Tómate un descanso.'
              : 'Descanso terminado. Nueva sesión de foco.',
        );
      };
      return controller;
    });

/// Completed pomodoros between two dates.
final pomodorosDoneBetweenProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      return ref
          .watch(pomodoroRepositoryProvider)
          .completedCountBetween(range.start, range.end);
    });

final pomodoroFocusMinutesProvider =
    FutureProvider.family<int, ({DateTime start, DateTime end})>((
      ref,
      range,
    ) async {
      return ref
          .watch(pomodoroRepositoryProvider)
          .focusMinutesBetween(range.start, range.end);
    });
