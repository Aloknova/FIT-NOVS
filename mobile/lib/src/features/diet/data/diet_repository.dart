import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    final calorieTarget = _estimateCalories(profile);
    final proteinG = ((profile.weightKg ?? 70) * 1.8).roundToDouble();
    final fatG = ((profile.weightKg ?? 70) * 0.8).roundToDouble();
    final carbsG = (((calorieTarget - (proteinG * 4) - (fatG * 9)) / 4))
        .clamp(120, 420)
        .roundToDouble();

    final meals = aiMeals ?? _buildMeals(
      goal: profile.fitnessGoal ?? 'Stay consistent',
      calorieTarget: calorieTarget,
      proteinG: proteinG,
      date: date,
    );

    final response = await _client
        .from('diet_plans')
        .upsert({
          'user_id': userId,
          'title': _planTitle(profile.fitnessGoal),
          'plan_date': _dateOnly(date),
          'calorie_target': calorieTarget,
          'protein_g': proteinG,
          'carbs_g': carbsG,
          'fat_g': fatG,
          'meals': meals,
          'source': 'coach',
          'is_active': true,
        }, onConflict: 'user_id,plan_date')
        .select()
        .single();

    return DietPlan.fromMap(response);
  }

  int _estimateCalories(UserProfile profile) {
    final weight = profile.weightKg ?? 70;
    final height = profile.heightCm ?? 170;
    final age = profile.age ?? 25;
    final gender = (profile.gender ?? '').toLowerCase();

    final base = gender == 'female'
        ? (10 * weight) + (6.25 * height) - (5 * age) - 161
        : (10 * weight) + (6.25 * height) - (5 * age) + 5;

    final multiplier = switch ((profile.activityLevel ?? '').toLowerCase()) {
      'highly active' => 1.75,
      'beginner' => 1.3,
      _ => 1.55,
    };

    var result = base * multiplier;
    switch ((profile.fitnessGoal ?? '').toLowerCase()) {
      case 'lose fat':
        result -= 350;
        break;
      case 'build muscle':
        result += 250;
        break;
      case 'improve endurance':
        result += 150;
        break;
    }

    final rounded = (result / 50).round() * 50;
    return rounded.clamp(1500, 3600).toInt();
  }

  List<Map<String, dynamic>> _buildMeals({
    required String goal,
    required int calorieTarget,
    required double proteinG,
    required DateTime date,
  }) {
    final breakfastCalories = (calorieTarget * 0.25).round();
    final lunchCalories = (calorieTarget * 0.35).round();
    final snackCalories = (calorieTarget * 0.15).round();
    final dinnerCalories = calorieTarget - breakfastCalories - lunchCalories - snackCalories;

    final goalHint = goal.toLowerCase();
    final dayIndex = date.difference(DateTime(2024, 1, 1)).inDays.abs();

    final breakfasts = goalHint.contains('muscle')
        ? ['Scrambled eggs (4) with spinach and whole grain toast', 'Oatmeal with whey protein and almonds', 'Protein smoothie with banana and peanut butter']
        : goalHint.contains('fat') || goalHint.contains('loss')
            ? ['Greek yogurt bowl with berries and chia', 'Avocado toast with poached egg', 'Spinach and mushroom egg white omelet']
            : ['Paneer and veggie wrap with fruit', 'Overnight oats with mixed berries', 'Cottage cheese with pineapple'];

    final lunches = goalHint.contains('muscle')
        ? ['Chicken rice bowl with mixed vegetables', 'Beef mince with sweet potato and greens', 'Large turkey wrap with avocado']
        : goalHint.contains('fat') || goalHint.contains('loss')
            ? ['Grilled chicken salad with light vinaigrette', 'Lentil soup with a side of mixed greens', 'Tuna salad lettuce wraps']
            : ['Balanced rice bowl with lean protein and salad', 'Whole wheat turkey sandwich', 'Baked salmon with quinoa'];

    final snacks = goalHint.contains('muscle')
        ? ['Banana, peanut butter, and whey smoothie', 'Cottage cheese and almonds', 'Protein bar']
        : goalHint.contains('fat') || goalHint.contains('loss')
            ? ['Carrot sticks with hummus', 'Apple slices with a dash of cinnamon', 'Edamame']
            : ['Fruit, nuts, and a protein snack', 'Rice cakes with peanut butter', 'Hard-boiled eggs'];

    final dinners = goalHint.contains('muscle')
        ? ['Steak with roasted potatoes and asparagus', 'Heavy recovery dinner with chicken, rice, and broccoli', 'Salmon fillet with quinoa']
        : goalHint.contains('fat') || goalHint.contains('loss')
            ? ['Baked chicken breast with roasted vegetables', 'White fish with steamed bok choy', 'Zucchini noodles with lean turkey meatballs']
            : ['Recovery dinner with lean protein and veggies', 'Shrimp stir-fry', 'Grilled tofu with veggies'];

    return [
      {
        'type': 'Breakfast',
        'food': breakfasts[dayIndex % breakfasts.length],
        'calories': breakfastCalories,
        'protein_g': (proteinG * 0.25).round(),
      },
      {
        'type': 'Lunch',
        'food': lunches[dayIndex % lunches.length],
        'calories': lunchCalories,
        'protein_g': (proteinG * 0.35).round(),
      },
      {
        'type': 'Snack',
        'food': snacks[dayIndex % snacks.length],
        'calories': snackCalories,
        'protein_g': (proteinG * 0.15).round(),
      },
      {
        'type': 'Dinner',
        'food': dinners[dayIndex % dinners.length],
        'calories': dinnerCalories,
        'protein_g': (proteinG * 0.25).round(),
      },
    ];
  }

  String _planTitle(String? goal) {
    switch (goal?.toLowerCase()) {
      case 'lose fat':
        return 'Fat-loss meal plan';
      case 'build muscle':
        return 'Muscle-building meal plan';
      case 'improve endurance':
        return 'Endurance fueling plan';
      default:
        return 'Balanced daily meal plan';
    }
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
