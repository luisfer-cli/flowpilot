import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets.dart';

class BreaksView extends ConsumerStatefulWidget {
  const BreaksView({super.key});

  @override
  ConsumerState<BreaksView> createState() => _BreaksViewState();
}

class _BreaksViewState extends ConsumerState<BreaksView> {
  static const _maxConsecutiveKey = 'breaks_max_consecutive';
  static const _maxDailyKey = 'breaks_max_daily';

  int _maxConsecutive = 3; // hours
  int _maxDaily = 8; // hours

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _maxConsecutive = prefs.getInt(_maxConsecutiveKey) ?? 3;
      _maxDaily = prefs.getInt(_maxDailyKey) ?? 8;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxConsecutiveKey, _maxConsecutive);
    await prefs.setInt(_maxDailyKey, _maxDaily);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Límites de trabajo'),
                const SizedBox(height: 8),
                _Stepper(
                  label: 'Máx. horas consecutivas',
                  value: _maxConsecutive,
                  min: 1,
                  max: 8,
                  onChange: (v) => setState(() {
                    _maxConsecutive = v;
                    _save();
                  }),
                ),
                _Stepper(
                  label: 'Máx. horas al día',
                  value: _maxDaily,
                  min: 4,
                  max: 16,
                  onChange: (v) => setState(() {
                    _maxDaily = v;
                    _save();
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Recordatorios de descanso'),
                const SizedBox(height: 6),
                const Text(
                  'Al alcanzar el límite de horas, FlowPilot te avisará para que hagas una pausa.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.hourglass_bottom),
            title: const Text('Buffers entre actividades'),
            subtitle: const Text(
              'Usa bloques de tipo "Buffer" en el calendario para dar margen entre tareas.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Crea un bloque Buffer en el calendario (vista día, mantener pulsado)',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Tip de recuperación'),
                const SizedBox(height: 6),
                Text(
                  'Después de $_maxConsecutive horas seguidas, tómate un descanso largo. '
                  'Combínalo con los descansos del Pomodoro para mantener el foco.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min ? () => onChange(value - 1) : null,
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChange(value + 1) : null,
        ),
      ],
    );
  }
}
