import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/workout.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return WorkoutRepository(client);
});

class WorkoutRepository {
  const WorkoutRepository(this._client);

  final SupabaseClient _client;

  Future<List<Workout>> fetchWorkouts({
    String? difficulty,
    UserProfile? profile,
  }) async {
    try {
      var filterBuilder = _client.from('workouts').select();

      if (difficulty != null && difficulty.isNotEmpty) {
        filterBuilder = filterBuilder.eq('difficulty', difficulty);
      }

      final response = await filterBuilder.order('created_at');
      final workouts = (response as List<dynamic>)
          .map((item) => Workout.fromMap(item as Map<String, dynamic>))
          .toList();

      if (workouts.isNotEmpty) {
        return workouts;
      }
    } catch (_) {
      // Fall back to local starter workouts when the shared catalog is empty.
    }

    return _localCatalog(profile: profile, difficulty: difficulty);
  }

  Future<void> createWorkout({
    required Workout workout,
  }) async {
    await _client.from('workouts').insert(workout.toMap());
  }

  List<Workout> _localCatalog({
    UserProfile? profile,
    String? difficulty,
  }) {
    final goal = (profile?.fitnessGoal ?? 'Stay consistent').toLowerCase();
    final catalog = <Workout>[
      Workout(
        id: 'starter_beginner_strength',
        title: 'Starter strength circuit',
        description:
            'A low-friction full-body routine designed to build consistency.',
        difficulty: 'beginner',
        goalFocus: goal.contains('muscle') ? 'muscle gain' : 'general fitness',
        durationMinutes: 25,
        caloriesEstimate: 180,
        scheduleTemplate: const ['Mon', 'Wed', 'Fri'],
        instructions: const [
          'Warm up for 5 minutes',
          '3 rounds of squats, push-ups, rows, and planks',
          'Cool down and stretch',
        ],
        equipment: const ['Bodyweight', 'Resistance band'],
        isPremium: false,
      ),
      const Workout(
        id: 'beginner_fat_loss_walk',
        title: 'Fat-loss walk and core block',
        description: 'A simple cardio session with light core work.',
        difficulty: 'beginner',
        goalFocus: 'fat loss',
        durationMinutes: 30,
        caloriesEstimate: 220,
        scheduleTemplate: ['Tue', 'Thu', 'Sat'],
        instructions: [
          '20 minutes brisk walking',
          '3 rounds of mountain climbers and dead bugs',
          '5 minutes cooldown',
        ],
        equipment: ['Walking shoes'],
        isPremium: false,
      ),
      Workout(
        id: 'intermediate_hybrid',
        title: 'Hybrid performance builder',
        description:
            'Strength and conditioning for users ready to push harder.',
        difficulty: 'intermediate',
        goalFocus: goal.contains('endurance') ? 'endurance' : 'performance',
        durationMinutes: 40,
        caloriesEstimate: 320,
        scheduleTemplate: const ['Mon', 'Thu', 'Sat'],
        instructions: const [
          'Dynamic warmup',
          '4 rounds of goblet squats, presses, rows, and intervals',
          'Cooldown mobility',
        ],
        equipment: const ['Dumbbells', 'Bench'],
        isPremium: false,
      ),
      const Workout(
        id: 'intermediate_muscle',
        title: 'Muscle-building upper lower split',
        description: 'Higher-volume sessions focused on progressive overload.',
        difficulty: 'intermediate',
        goalFocus: 'muscle gain',
        durationMinutes: 50,
        caloriesEstimate: 360,
        scheduleTemplate: ['Mon', 'Tue', 'Thu', 'Fri'],
        instructions: [
          'Upper or lower split day',
          'Track reps and weights',
          'Finish with accessories and cooldown',
        ],
        equipment: ['Dumbbells', 'Barbell', 'Cable machine'],
        isPremium: false,
      ),
      const Workout(
        id: 'advanced_conditioning',
        title: 'Advanced conditioning ladder',
        description:
            'A demanding session for high-output fat loss and stamina work.',
        difficulty: 'advanced',
        goalFocus: 'fat loss',
        durationMinutes: 45,
        caloriesEstimate: 420,
        scheduleTemplate: ['Wed', 'Sat'],
        instructions: [
          'Interval ladder with rower or run',
          'Compound strength clusters',
          'Core finisher and cooldown',
        ],
        equipment: ['Rower or treadmill', 'Kettlebell'],
        isPremium: false,
      ),
      const Workout(
        id: 'advanced_endurance',
        title: 'Endurance engine session',
        description: 'Threshold and tempo work for performance-focused users.',
        difficulty: 'advanced',
        goalFocus: 'endurance',
        durationMinutes: 55,
        caloriesEstimate: 480,
        scheduleTemplate: ['Tue', 'Fri'],
        instructions: [
          'Tempo intervals',
          'Steady-state block',
          'Recovery walk and mobility',
        ],
        equipment: ['Track or treadmill', 'Heart-rate monitor'],
        isPremium: false,
      ),
    ];

    return catalog.where((workout) {
      if (difficulty != null && difficulty.isNotEmpty) {
        return workout.difficulty == difficulty;
      }
      return true;
    }).toList();
  }
}
