import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/theme.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);

  if (client == null) {
    return null;
  }

  return ProfileRepository(client);
});

final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final session = ref.watch(authSessionProvider).valueOrNull;

  if (repository == null || session == null) {
    return null;
  }

  return repository.fetchProfile(session.user.id);
});

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<UserProfile?> fetchProfile(String userId) async {
    final response =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (response == null) {
      return null;
    }

    return UserProfile.fromMap(response);
  }

  Future<UserProfile> upsertProfile({
    required String userId,
    required String email,
    required String fullName,
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String fitnessGoal,
    required String activityLevel,
    required AppThemePreference themePreference,
  }) async {
    final existingProfile = await fetchProfile(userId);
    final profile = UserProfile(
      id: userId,
      email: email,
      fullName: fullName,
      role: existingProfile?.role ?? 'user',
      age: age,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      fitnessGoal: fitnessGoal,
      activityLevel: activityLevel,
      themePreference: themePreference.storageValue,
      onboardingCompleted: true,
      isPremium: existingProfile?.isPremium ?? false,
      timezone: existingProfile?.timezone ?? 'UTC',
    );

    final response = await _client
        .from('profiles')
        .upsert(profile.toUpsertMap())
        .select()
        .single();

    return UserProfile.fromMap(response);
  }

  Future<UserProfile> updateThemePreference({
    required String userId,
    required AppThemePreference themePreference,
  }) async {
    final response = await _client
        .from('profiles')
        .update({
          'theme_preference': themePreference.storageValue,
        })
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }

  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? fitnessGoal,
    String? activityLevel,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (age != null) updates['age'] = age;
    if (gender != null) updates['gender'] = gender;
    if (heightCm != null) {
      updates['height_cm'] = heightCm;
      updates['weight_kg'] = weightKg ?? 0;
    }
    if (weightKg != null) updates['weight_kg'] = weightKg;
    if (heightCm != null && weightKg != null) {
      final h = heightCm / 100;
      updates['bmi'] = double.parse(
        (weightKg / (h * h)).toStringAsFixed(2),
      );
    }
    if (fitnessGoal != null) updates['fitness_goal'] = fitnessGoal;
    if (activityLevel != null) updates['activity_level'] = activityLevel;

    final response = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromMap(response);
  }
}
