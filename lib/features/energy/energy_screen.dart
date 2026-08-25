import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/time_utils.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

class EnergyView extends ConsumerStatefulWidget {
  const EnergyView({super.key});

  @override
  ConsumerState<EnergyView> createState() => _EnergyViewState();
}

class _EnergyViewState extends ConsumerState<EnergyView> {
  int _energy = 3;

  Future<void> _log() async {
    await ref.read(energyRepositoryProvider).log(energy: _energy);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Energía registrada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final avgAsync = ref.watch(averageEnergyProvider);
    final logsAsync = ref.watch(energyLogsProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Energía actual',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var e = 1; e <= 5; e++)
                      IconButton(
                        iconSize: 40,
                        icon: Icon(
                          e <= _energy ? Icons.bolt : Icons.bolt_outlined,
                          color: e <= _energy
                              ? Colors.amber.shade700
                              : theme.colorScheme.outline,
                        ),
                        onPressed: () => setState(() => _energy = e),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$_energy / 5', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _log,
                  icon: const Icon(Icons.save),
                  label: const Text('Registrar'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Energía media (7d)',
                value: avgAsync.valueOrNull == null
                    ? '—'
                    : avgAsync.valueOrNull!.toStringAsFixed(1),
                icon: Icons.show_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeader('Historial'),
        const SizedBox(height: 6),
        logsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (logs) => logs.isEmpty
              ? const EmptyState(
                  icon: Icons.bolt_outlined,
                  title: 'Sin registros',
                  subtitle: 'Registra tu energía para ver tendencias',
                )
              : Column(
                  children: [
                    for (final log in logs)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bolt, color: Colors.amber.shade700),
                        title: Text('${log.energy}/5'),
                        subtitle: Text(formatFullDate(log.timestamp)),
                        trailing: log.mood == null ? null : Text(log.mood!),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

final averageEnergyProvider = FutureProvider<double?>(
  (ref) => ref.watch(energyRepositoryProvider).averageEnergy(),
);

final energyLogsProvider = StreamProvider<List<EnergyLog>>(
  (ref) => ref.watch(energyRepositoryProvider).watchRecent(),
);
