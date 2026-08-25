import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/time_utils.dart';
import '../pomodoro/pomodoro_timer.dart';
import '../tasks/task_providers.dart';

const _xpPerTask = 10;
const _xpPerPomodoro = 20;

int levelForXp(int xp) => (xp / 100).floor() + 1;

int xpForLevel(int level) => (level - 1) * 100;

/// Gamification card (XP, level). Embedded in the productivity profile.
class GamificationCard extends ConsumerWidget {
  const GamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = startOfWeek(DateTime.now());
    final weekEnd = weekStart.add(
      const Duration(days: 6, hours: 23, minutes: 59),
    );
    final doneAsync = ref.watch(
      tasksDoneBetweenProvider((start: weekStart, end: weekEnd)),
    );
    final pomosAsync = ref.watch(
      pomodorosDoneBetweenProvider((start: weekStart, end: weekEnd)),
    );
    final theme = Theme.of(context);

    final xp =
        (doneAsync.valueOrNull ?? 0) * _xpPerTask +
        (pomosAsync.valueOrNull ?? 0) * _xpPerPomodoro;
    final level = levelForXp(xp);
    final levelFloor = xpForLevel(level);
    final nextLevel = xpForLevel(level + 1);
    final progress = (nextLevel - levelFloor) == 0
        ? 1.0
        : ((xp - levelFloor) / (nextLevel - levelFloor)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.amber.shade700),
            const SizedBox(height: 8),
            Text(
              'Nivel $level',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text('$xp XP', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              '${nextLevel - xp} XP para el nivel ${level + 1}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
