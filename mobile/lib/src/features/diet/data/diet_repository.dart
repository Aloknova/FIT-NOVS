import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/diet_plan.dart';

final dietRepositoryProvider = Provider<DietRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return DietRepository(client);
});

class DietRepository {
  const DietRepository(this._client);

  final SupabaseClient _client;

  Future<DietPlan?> fetchPlanForDate(String userId, DateTime date) async {
    final response = await _client
        .from('diet_plans')
        .select()
        .eq('user_id', userId)
        .eq('plan_date', _dateOnly(date))
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return DietPlan.fromMap(response);
  }

  Future<DietPlan> generatePlan({
    required String userId,
    required DateTime date,
    required UserProfile profile,
    bool forceRegenerate = false,
    List<Map<String, dynamic>>? aiMeals,
  }) async {
    if (!forceRegenerate && aiMeals == null) {
      final existing = await fetchPlanForDate(userId, date);
      if (existing != null) {
        return existing;
      }
    }

    Map<String, dynamic> aiPlan;

    if (aiMeals != null) {
      aiPlan = {
        'title': 'Suggested Meal Plan',
        'calorie_target': 2000,
        'protein_g': 150,
        'carbs_g': 200,
        'fat_g': 60,
        'meals': aiMeals,
      };
    } else {
      final response = await http.post(
        Uri.parse('${AppEnv.apiBaseUrl}/ai/diet-plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'profile': {
            'goal': profile.fitnessGoal,
            'age': profile.age,
            'gender': profile.gender,
            'weight_kg': profile.weightKg,
            'height_cm': profile.heightCm,
            'activity_level': profile.activityLevel,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate diet plan: ${response.body}');
      }

      aiPlan = jsonDecode(response.body) as Map<String, dynamic>;
    }

    final upsertResponse = await _client
        .from('diet_plans')
        .upsert({
          'user_id': userId,
          'title': aiPlan['title'] ?? 'Vegetarian Daily Plan',
          'plan_date': _dateOnly(date),
          'calorie_target': aiPlan['calorie_target'],
          'protein_g': aiPlan['protein_g'],
          'carbs_g': aiPlan['carbs_g'],
          'fat_g': aiPlan['fat_g'],
          'meals': aiPlan['meals'],
          'source': aiMeals != null ? 'coach' : 'ai',
          'is_active': true,
        }, onConflict: 'user_id,plan_date')
        .select()
        .single();

    return DietPlan.fromMap(upsertResponse);
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
