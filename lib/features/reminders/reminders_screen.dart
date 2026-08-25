import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/services/notifications_service.dart';
import '../../core/utils/id.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

/// Manages scheduled reminders: persists them and syncs with the system
/// notification scheduler.
class RemindersController {
  RemindersController(this._ref);
  final Ref _ref;

  Future<void> addReminder({
    required String targetType,
    String? targetId,
    required DateTime triggerAt,
    String? message,
  }) async {
    final id = generateId();
    await _ref
        .read(calendarRepositoryProvider)
        .insertReminder(
          RemindersCompanion.insert(
            id: id,
            targetType: targetType,
            targetId: targetId ?? '',
            triggerAt: triggerAt,
            message: Value(message),
          ),
        );
    // Use a deterministic int id for the OS notification.
    final notifId = id.hashCode & 0x7fffffff;
    await NotificationsService.instance.schedule(
      id: notifId,
      title: 'FlowPilot',
      body: message ?? 'Recordatorio',
      at: triggerAt,
    );
  }

  Future<void> deleteReminder(String id) async {
    await _ref.read(calendarRepositoryProvider).deleteReminder(id);
  }
}

final remindersControllerProvider = Provider<RemindersController>(
  (ref) => RemindersController(ref),
);

final upcomingRemindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(calendarRepositoryProvider).watchUpcoming(),
);

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordatorios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nuevo recordatorio',
            onPressed: () => _addReminder(context, ref),
          ),
        ],
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (reminders) => reminders.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none,
                title: 'Sin recordatorios',
                subtitle: 'Toca + para crear uno',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reminders.length,
                itemBuilder: (context, i) =>
                    _ReminderTile(reminder: reminders[i]),
              ),
      ),
    );
  }

  Future<void> _addReminder(BuildContext context, WidgetRef ref) async {
    final messageCtrl = TextEditingController();
    var when = DateTime.now().add(const Duration(hours: 1));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Nuevo recordatorio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Mensaje'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!dialogContext.mounted) return;
                  final date = await showDatePicker(
                    context: dialogContext,
                    initialDate: when,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                  );
                  if (date == null) return;
                  if (!dialogContext.mounted) return;
                  final time = await showTimePicker(
                    context: dialogContext,
                    initialTime: TimeOfDay.fromDateTime(when),
                  );
                  if (time == null) return;
                  setState(() {
                    when = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                },
                icon: const Icon(Icons.event),
                label: Text(
                  '${formatFullDate(when)} · ${formatTimeOfDay(when)}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (messageCtrl.text.trim().isNotEmpty) {
                  ref
                      .read(remindersControllerProvider)
                      .addReminder(
                        targetType: 'custom',
                        triggerAt: when,
                        message: messageCtrl.text.trim(),
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overdue = reminder.triggerAt.isBefore(DateTime.now());

    return Card(
      child: ListTile(
        leading: Icon(
          overdue ? Icons.notifications_active : Icons.notifications,
          color: overdue ? Colors.orange : theme.colorScheme.primary,
        ),
        title: Text(reminder.message ?? 'Recordatorio'),
        subtitle: Text(
          '${formatFullDate(reminder.triggerAt)} · ${formatTimeOfDay(reminder.triggerAt)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(remindersControllerProvider).deleteReminder(reminder.id),
        ),
      ),
    );
  }
}
