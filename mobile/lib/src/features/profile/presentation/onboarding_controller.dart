import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/theme.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, AsyncValue<void>>((ref) {
  return OnboardingController(ref);
});

class OnboardingController extends StateNotifier<AsyncValue<void>> {
  OnboardingController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  ProfileRepository get _repository {
    final repository = _ref.read(profileRepositoryProvider);

    if (repository == null) {
      throw StateError(
        'Supabase is not configured yet. Add the app environment values before running FitNova.',
      );
    }

    return repository;
  }

  Future<UserProfile> submitProfile({
    required String fullName,
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required String activityLevel,
    required AppThemePreference themePreference,
  }) async {
    state = const AsyncLoading();

    try {
      final user = _ref.read(currentUserProvider);

      if (user == null) {
        throw StateError('You need to sign in before completing onboarding.');
      }

      final profile = await _repository.upsertProfile(
        userId: user.id,
        email: user.email ?? '',
        fullName: fullName.trim(),
        age: age,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        fitnessGoal: fitnessGoal,
        activityLevel: activityLevel,
        themePreference: themePreference,
      );

      _ref.invalidate(currentProfileProvider);
      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
