import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_service.dart';
import '../ai/openrouter_client.dart';
import '../tasks/task_providers.dart';

/// "¿Qué hago ahora?" — a single AI recommendation based on active tasks.
class WhatNowCard extends ConsumerStatefulWidget {
  const WhatNowCard({super.key});

  @override
  ConsumerState<WhatNowCard> createState() => _WhatNowCardState();
}

class _WhatNowCardState extends ConsumerState<WhatNowCard> {
  bool _loading = false;
  String? _result;
  String? _error;

  Future<void> _ask() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final active = ref.read(activeTasksProvider).valueOrNull ?? const [];
    final titles = active.take(20).map((t) => t.title).toList();
    try {
      final result = await ref
          .read(aiServiceProvider)
          .whatNow(activeTaskTitles: titles);
      if (mounted) setState(() => _result = result);
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '¿Qué hago ahora?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _loading ? null : _ask,
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              Text(_result!, style: theme.textTheme.bodyLarge),
            ] else if (_error == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Toca el botón para obtener una recomendación.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
