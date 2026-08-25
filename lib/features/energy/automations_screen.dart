import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/database.dart';
import '../../shared/widgets.dart';

/// Automations: WHEN `trigger` THEN `action`. Rules are stored in the
/// automation_rules table; this screen shows the built-in ones and lets the
/// user toggle them.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(automationRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Automatizaciones')),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: '$e',
        ),
        data: (rules) => rules.isEmpty
            ? const EmptyState(
                icon: Icons.bolt_outlined,
                title: 'Sin reglas',
                subtitle: 'Crea reglas WHEN/THEN para automatizar',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rules.length,
                itemBuilder: (context, i) => _RuleCard(rule: rules[i]),
              ),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule});

  final AutomationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.auto_mode),
        title: Text(rule.name),
        subtitle: Text('WHEN ${rule.trigger}\nTHEN ${rule.actionsJson}'),
        value: rule.enabled,
        onChanged: (v) => ref
            .read(automationRepositoryProvider)
            .update(rule.id, AutomationRulesCompanion(enabled: Value(v))),
      ),
    );
  }
}

final automationRulesProvider = StreamProvider<List<AutomationRule>>(
  (ref) => ref.watch(automationRepositoryProvider).watchAll(),
);
