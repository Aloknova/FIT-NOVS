import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../leaderboard/presentation/leaderboard_controller.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_snapshot.dart';

final analyticsSnapshotProvider =
    FutureProvider<AnalyticsSnapshot?>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final userPoints = ref.watch(currentUserPointsProvider).valueOrNull;

  if (repository == null || user == null) {
    return null;
  }

  return repository.fetchSnapshot(
    userId: user.id,
    userPoints: userPoints,
  );
});

final analyticsControllerProvider =
    StateNotifierProvider<AnalyticsController, AsyncValue<void>>((ref) {
  return AnalyticsController(ref);
});

class AnalyticsController extends StateNotifier<AsyncValue<void>> {
  AnalyticsController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> saveProgressLog({
    double? weightKg,
    int? steps,
    int? sleepMinutes,
    String? notes,
  }) async {
    final repository = _ref.read(analyticsRepositoryProvider);
    final user = _ref.read(currentUserProvider);

    if (repository == null || user == null) {
      state =
          AsyncError('Sign in before logging progress.', StackTrace.current);
      return;
    }

    state = const AsyncLoading();

    try {
      await repository.saveProgressLog(
        userId: user.id,
        logDate: DateTime.now(),
        weightKg: weightKg,
        steps: steps,
        sleepMinutes: sleepMinutes,
        notes: notes,
      );
      state = const AsyncData(null);
      _ref.invalidate(analyticsSnapshotProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
