import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../data/diet_repository.dart';
import '../domain/diet_plan.dart';

final dietDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dailyDietProvider = FutureProvider<DietPlan?>((ref) async {
  final repository = ref.watch(dietRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final date = ref.watch(dietDateProvider);

  if (repository == null || user == null) {
    return null;
  }

  return repository.fetchPlanForDate(user.id, date);
});

final dietControllerProvider =
    StateNotifierProvider<DietController, AsyncValue<void>>((ref) {
  return DietController(ref);
});

class DietController extends StateNotifier<AsyncValue<void>> {
  DietController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> generatePlan({bool forceRegenerate = false}) async {
    final repository = _ref.read(dietRepositoryProvider);
    final user = _ref.read(currentUserProvider);
    final profile = _ref.read(currentProfileProvider).valueOrNull;
    final date = _ref.read(dietDateProvider);

    if (repository == null || user == null || profile == null) {
      state = AsyncError(
        'Sign in and complete onboarding before generating a diet plan.',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();

    try {
      await repository.generatePlan(
        userId: user.id,
        date: date,
        profile: profile,
        forceRegenerate: forceRegenerate,
      );
      state = const AsyncData(null);
      _ref.invalidate(dailyDietProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
