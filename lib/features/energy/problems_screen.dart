import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';
import '../../shared/widgets.dart';
import '../ai/estimation_service.dart';

class ProblemsView extends ConsumerWidget {
  const ProblemsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(detectedProblemsProvider);

    return issuesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          EmptyState(icon: Icons.error_outline, title: 'Error', subtitle: '$e'),
      data: (issues) => issues.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              title: 'Sin problemas detectados',
              subtitle: 'Todo en orden por ahora',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final issue in issues) _IssueCard(issue: issue)],
            ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final ({String severity, String title, String detail}) issue;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (issue.severity) {
      'high' => (Colors.redAccent, Icons.error),
      'medium' => (Colors.orange, Icons.warning_amber),
      _ => (Colors.blueGrey, Icons.info_outline),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(issue.title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(issue.detail),
        trailing: Text(
          issue.severity,
          style: TextStyle(color: color, fontSize: 11),
        ),
      ),
    );
  }
}

final detectedProblemsProvider =
    FutureProvider<List<({String severity, String title, String detail})>>((
      ref,
    ) async {
      final issues = <({String severity, String title, String detail})>[];
      final tasks = await ref.watch(taskRepositoryProvider).watchAll().first;
      final now = DateTime.now();
      final active = tasks.where((t) => t.status != kStatusCompleted).toList();

      // Overdue tasks
      final overdue = active
          .where((t) => t.dueDate != null && t.dueDate!.isBefore(now))
          .toList();
      if (overdue.isNotEmpty) {
        issues.add((
          severity: 'high',
          title: '${overdue.length} tarea(s) vencida(s)',
          detail:
              'Revisa y reprograma o prioriza: ${overdue.take(3).map((t) => t.title).join(', ')}',
        ));
      }

      // Deadline impossible: estimated time remaining doesn't fit before due
      final bias = await ref.watch(estimationServiceProvider).estimateBias();
      final impossible = active.where((t) {
        if (t.dueDate == null || (t.estimatedMinutes ?? 0) == 0) return false;
        final predicted = (t.estimatedMinutes! * bias).round();
        final daysLeft = t.dueDate!.difference(now).inHours / 8; // ~8h workdays
        final requiredDays = predicted / 60.0;
        return requiredDays > daysLeft + 1;
      }).toList();
      if (impossible.isNotEmpty) {
        issues.add((
          severity: 'medium',
          title: 'Deadline difícil de cumplir',
          detail: impossible.take(3).map((t) => t.title).join(', '),
        ));
      }

      // Too many active tasks (context switching)
      if (active.length > 10) {
        issues.add((
          severity: 'low',
          title: 'Demasiadas tareas activas (${active.length})',
          detail: 'Demasiado cambio de contexto reduce el foco. Considera priorizar.',
        ));
      }

      // Estimation accuracy
      final precision = await ref
          .watch(estimationServiceProvider)
          .precisionPercent();
      if (precision > 0 && precision < 50) {
        issues.add((
          severity: 'low',
          title: 'Precisión de estimación baja ($precision%)',
          detail: 'Tus estimaciones suelen ser imprecisas. Usa la estimación inteligente.',
        ));
      }

      // Recurring backlog
      final recurring = tasks
          .where((t) => t.recurrenceId != null && t.status == kStatusCompleted)
          .length;
      if (recurring > 0) {
        issues.add((
          severity: 'low',
          title: '$recurring tarea(s) recurrente(s) en marcha',
          detail: 'Comprueba que el motor de recurrencias está generando las siguientes.',
        ));
      }

      return issues;
    });
