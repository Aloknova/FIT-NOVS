import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../analytics/presentation/analytics_controller.dart';
import '../data/health_repository.dart';
import '../domain/health_summary.dart';

final healthConnectionStateProvider =
    FutureProvider<HealthConnectionState>((ref) async {
  final repository = ref.watch(healthRepositoryProvider);
  return repository.getConnectionState();
});

final healthTodaySummaryProvider = FutureProvider<HealthSummary?>((ref) async {
  final repository = ref.watch(healthRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return null;
  }

  return repository.fetchTodaySummary(user.id);
});

final healthSyncControllerProvider =
    StateNotifierProvider<HealthSyncController, AsyncValue<HealthSummary?>>(
        (ref) {
  return HealthSyncController(ref);
});

class HealthSyncController extends StateNotifier<AsyncValue<HealthSummary?>> {
  HealthSyncController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> syncToday() async {
    final repository = _ref.read(healthRepositoryProvider);
    final user = _ref.read(currentUserProvider);

    if (user == null) {
      state = AsyncError(
        'Sign in before syncing wearable data.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    try {
      final summary = await repository.syncToday(user.id);
      state = AsyncData(summary);
      _ref.invalidate(healthTodaySummaryProvider);
      _ref.invalidate(healthConnectionStateProvider);
      _ref.invalidate(analyticsSnapshotProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> installHealthConnect() async {
    final repository = _ref.read(healthRepositoryProvider);
    state = const AsyncLoading();

    try {
      await repository.installHealthConnect();
      state = const AsyncData(null);
      _ref.invalidate(healthConnectionStateProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
