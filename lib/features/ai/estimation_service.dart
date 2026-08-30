import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants.dart';

/// Estimates how long a task will actually take based on historical
/// estimation accuracy. The more history, the more accurate the prediction.
class EstimationService {
  EstimationService(this._ref);
  final Ref _ref;

  /// Historical bias: avg(actual / estimated) across completed tasks that had
  /// an estimate. >1 means we underestimate; <1 means we overestimate.
  Future<double> estimateBias() async {
    final completed = await _completedWithEstimates();
    if (completed.isEmpty) return 1.0;
    var sum = 0.0;
    for (final t in completed) {
      sum += t.actualMinutes / t.estimatedMinutes;
    }
    return sum / completed.length;
  }

  /// Predicted duration in minutes for a task with [estimatedMinutes].
  Future<int> predictMinutes(int? estimatedMinutes) async {
    if (estimatedMinutes == null || estimatedMinutes <= 0) return 0;
    final bias = await estimateBias();
    return (estimatedMinutes * bias).round();
  }

  /// Precision % of past estimates (clamped to 0..100).
  Future<int> precisionPercent() async {
    final completed = await _completedWithEstimates();
    if (completed.isEmpty) return 0;
    var acc = 0.0;
    for (final t in completed) {
      final ratio = t.actualMinutes / t.estimatedMinutes;
      acc += ratio <= 1 ? ratio : 1 / ratio;
    }
    return ((acc / completed.length) * 100).round();
  }

  Future<int> historyCount() async {
    final tasks = await _ref.read(taskRepositoryProvider).watchAll().first;
    return tasks
        .where((t) => t.actualMinutes > 0 && (t.estimatedMinutes ?? 0) > 0)
        .length;
  }

  Future<List<dynamic>> _completedWithEstimates() async {
    final tasks = await _ref.read(taskRepositoryProvider).watchAll().first;
    return tasks
        .where(
          (t) =>
              t.actualMinutes > 0 &&
              (t.estimatedMinutes ?? 0) > 0 &&
              t.status == kStatusCompleted,
        )
        .toList();
  }
}

final estimationServiceProvider = Provider<EstimationService>(
  (ref) => EstimationService(ref),
);

final estimateBiasProvider = FutureProvider<double>(
  (ref) => ref.watch(estimationServiceProvider).estimateBias(),
);

final estimationPrecisionProvider = FutureProvider<int>(
  (ref) => ref.watch(estimationServiceProvider).precisionPercent(),
);

final estimationHistoryProvider = FutureProvider<int>(
  (ref) => ref.watch(estimationServiceProvider).historyCount(),
);
