import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/wakelock.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';
import '../tasks/task_providers.dart';
import 'pomodoro_timer.dart';

class PomodoroView extends ConsumerStatefulWidget {
  const PomodoroView({super.key});

  @override
  ConsumerState<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends ConsumerState<PomodoroView> {
  bool _showConfig = false;

  @override
  void initState() {
    super.initState();
    setWakelock(true);
  }

  @override
  void dispose() {
    setWakelock(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(pomodoroControllerProvider.notifier);
    final state = ref.watch(pomodoroControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Pantalla de foco',
              onPressed: () => _openFullscreen(context),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Configuración',
              onPressed: () => setState(() => _showConfig = !_showConfig),
            ),
          ],
        ),
        _TimerCard(state: state, controller: controller),
        const SizedBox(height: 16),
        _TaskSelector(state: state, controller: controller),
        if (_showConfig) ...[
          const SizedBox(height: 16),
          _ConfigCard(controller: controller),
        ],
        const SizedBox(height: 16),
        _StatsToday(),
        const SizedBox(height: 16),
        SectionHeader('Historial'),
        const SizedBox(height: 6),
        _History(),
        const SizedBox(height: 96),
      ],
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _FocusFullscreen(),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.state, required this.controller});

  final PomodoroState state;
  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = state.phase;
    final phaseLabel = switch (phase) {
      PomodoroPhase.focus => 'Foco',
      PomodoroPhase.shortBreak => 'Descanso corto',
      PomodoroPhase.longBreak => 'Descanso largo',
    };
    final color = phase == PomodoroPhase.focus
        ? theme.colorScheme.primary
        : Colors.teal;
    final total = state.totalSeconds;
    final progress = total == 0 ? 0.0 : (total - state.timeLeftSeconds) / total;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              phaseLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                  Text(
                    _formatSeconds(state.timeLeftSeconds),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (
                  var i = 0;
                  i < controller.config.cyclesBeforeLongBreak;
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Icon(
                      i <
                              state.cycleCount %
                                  controller.config.cyclesBeforeLongBreak
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 12,
                      color:
                          i <
                              state.cycleCount %
                                  controller.config.cyclesBeforeLongBreak
                          ? color
                          : theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!state.isRunning &&
                    state.timeLeftSeconds < state.totalSeconds) ...[
                  FilledButton.icon(
                    onPressed: controller.resume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                  const SizedBox(width: 12),
                ] else if (state.isRunning) ...[
                  FilledButton.icon(
                    onPressed: controller.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: controller.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: controller.start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  ),
                ],
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: controller.skip,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Saltar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

class _TaskSelector extends ConsumerWidget {
  const _TaskSelector({required this.state, required this.controller});

  final PomodoroState state;
  final PomodoroController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider).valueOrNull ?? const <Task>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButtonFormField<String?>(
          initialValue: state.taskId,
          decoration: const InputDecoration(
            labelText: 'Tarea de foco',
            border: InputBorder.none,
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin tarea')),
            for (final t in tasks)
              DropdownMenuItem(
                value: t.id,
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => controller.setTask(v),
        ),
      ),
    );
  }
}

class _ConfigCard extends ConsumerWidget {
  const _ConfigCard({required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = controller.config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Configuración'),
            const SizedBox(height: 8),
            _StepperRow(
              label: 'Foco (min)',
              value: config.focusMinutes,
              min: 5,
              max: 120,
              step: 5,
              onChange: (v) => controller.updateConfig(
                PomodoroConfig(
                  focusMinutes: v,
                  shortBreakMinutes: config.shortBreakMinutes,
                  longBreakMinutes: config.longBreakMinutes,
                  cyclesBeforeLongBreak: config.cyclesBeforeLongBreak,
                ),
              ),
            ),
            _StepperRow(
              label: 'Descanso corto (min)',
              value: config.shortBreakMinutes,
              min: 1,
              max: 30,
              step: 1,
              onChange: (v) => controller.updateConfig(
                PomodoroConfig(
                  focusMinutes: config.focusMinutes,
                  shortBreakMinutes: v,
                  longBreakMinutes: config.longBreakMinutes,
                  cyclesBeforeLongBreak: config.cyclesBeforeLongBreak,
                ),
              ),
            ),
            _StepperRow(
              label: 'Descanso largo (min)',
              value: config.longBreakMinutes,
              min: 5,
              max: 60,
              step: 5,
              onChange: (v) => controller.updateConfig(
                PomodoroConfig(
                  focusMinutes: config.focusMinutes,
                  shortBreakMinutes: config.shortBreakMinutes,
                  longBreakMinutes: v,
                  cyclesBeforeLongBreak: config.cyclesBeforeLongBreak,
                ),
              ),
            ),
            _StepperRow(
              label: 'Ciclos antes de descanso largo',
              value: config.cyclesBeforeLongBreak,
              min: 2,
              max: 8,
              step: 1,
              onChange: (v) => controller.updateConfig(
                PomodoroConfig(
                  focusMinutes: config.focusMinutes,
                  shortBreakMinutes: config.shortBreakMinutes,
                  longBreakMinutes: config.longBreakMinutes,
                  cyclesBeforeLongBreak: v,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChange(value - step) : null,
        ),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChange(value + step) : null,
        ),
      ],
    );
  }
}

class _StatsToday extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final bounds = (start: startOfDay(now), end: endOfDay(now));
    final doneAsync = ref.watch(pomodorosDoneBetweenProvider(bounds));
    final minutesAsync = ref.watch(pomodoroFocusMinutesProvider(bounds));

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Pomodoros hoy',
            value: '${doneAsync.valueOrNull ?? 0}',
            icon: Icons.timer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            label: 'Focus hoy',
            value: formatMinutes(minutesAsync.valueOrNull ?? 0),
            icon: Icons.center_focus_strong,
          ),
        ),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(pomodoroHistoryProvider);

    return historyAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (sessions) => sessions.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Sin sesiones todavía',
              subtitle: 'Completa tu primer pomodoro',
            )
          : Column(
              children: [for (final s in sessions) _SessionTile(session: s)],
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final PomodoroSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final IconData icon;
    final Color color;
    if (session.completed) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (session.abandoned) {
      icon = Icons.block;
      color = Colors.redAccent;
    } else {
      icon = Icons.remove_circle_outline;
      color = Colors.orange;
    }
    final time = session.end ?? DateTime.now();
    final duration = session.completed
        ? '${session.plannedMinutes} min'
        : '${time.difference(session.start).inMinutes} min';

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          '${formatDate(session.start)} · ${formatTimeOfDay(session.start)}',
        ),
        subtitle: Text(
          session.completed
              ? 'Completada'
              : session.abandoned
              ? 'Abandonada'
              : 'Interrumpida',
        ),
        trailing: Text(
          duration,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FocusFullscreen extends ConsumerStatefulWidget {
  const _FocusFullscreen();

  @override
  ConsumerState<_FocusFullscreen> createState() => _FocusFullscreenState();
}

class _FocusFullscreenState extends ConsumerState<_FocusFullscreen> {
  @override
  void initState() {
    super.initState();
    setWakelock(true);
  }

  @override
  void dispose() {
    setWakelock(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroControllerProvider);
    final controller = ref.watch(pomodoroControllerProvider.notifier);
    final theme = Theme.of(context);
    final isFocus = state.phase == PomodoroPhase.focus;
    final color = isFocus ? theme.colorScheme.primary : Colors.teal;

    return Scaffold(
      backgroundColor: color.withValues(alpha: 0.06),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_fullscreen),
                tooltip: 'Salir',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isFocus ? 'FOCUS' : 'DESCANSO',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _fmt(state.timeLeftSeconds),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.taskId == null
                          ? ''
                          : ref
                                    .watch(taskByIdProvider(state.taskId!))
                                    .valueOrNull
                                    ?.title ??
                                '',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (state.isRunning)
                    FilledButton.icon(
                      onPressed: controller.pause,
                      icon: const Icon(Icons.pause),
                      label: const Text('Pausar'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: controller.resume,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Continuar'),
                    ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: controller.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Detener'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

final pomodoroHistoryProvider = StreamProvider<List<PomodoroSession>>(
  (ref) => ref.watch(pomodoroRepositoryProvider).watchRecent(),
);
