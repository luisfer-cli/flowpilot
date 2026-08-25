import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../ai/estimation_service.dart';
import '../pomodoro/pomodoro_timer.dart';
import 'gamification_card.dart';

/// Builds a personal productivity profile from tracked data (includes the
/// gamification card with XP/level).
class ProductivityProfileView extends ConsumerWidget {
  const ProductivityProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precisionAsync = ref.watch(estimationPrecisionProvider);
    final historyAsync = ref.watch(estimationHistoryProvider);
    final focusAsync = ref.watch(
      pomodoroFocusMinutesProvider((
        start: startOfDay(DateTime.now()),
        end: endOfDay(DateTime.now()),
      )),
    );
    final bestHourAsync = ref.watch(bestHourProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const GamificationCard(),
        const SizedBox(height: 12),
        bestHourAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (best) => _ProfileRow(
            icon: Icons.access_time,
            label: 'Mejor franja',
            value: best ?? 'Sin datos aún',
          ),
        ),
        _ProfileRow(
          icon: Icons.center_focus_strong,
          label: 'Focus hoy',
          value: formatMinutes(focusAsync.valueOrNull ?? 0),
        ),
        _ProfileRow(
          icon: Icons.percent,
          label: 'Precisión de estimación',
          value: precisionAsync.valueOrNull == null
              ? '—'
              : '${precisionAsync.valueOrNull}%',
        ),
        _ProfileRow(
          icon: Icons.history,
          label: 'Historial de estimaciones',
          value: '${historyAsync.valueOrNull ?? 0}',
        ),
        _ProfileRow(
          icon: Icons.timer,
          label: 'Pomodoro recomendado',
          value: '50/10',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Este perfil se construye automáticamente a partir de tus datos '
              '(mejor franja, foco, precisión de estimaciones, XP).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

final bestHourProvider = FutureProvider<String?>((ref) async {
  final entries = await ref.watch(timeEntryRepositoryProvider).watchAll().first;
  final byHour = <int, int>{};
  for (final e in entries) {
    if (e.durationMinutes == null || e.durationMinutes! == 0) continue;
    final hour = e.start.hour;
    byHour[hour] = (byHour[hour] ?? 0) + e.durationMinutes!;
  }
  if (byHour.isEmpty) return null;
  final best = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '${best.toString().padLeft(2, '0')}:00–${(best + 1).toString().padLeft(2, '0')}:00';
});
