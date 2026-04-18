import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/daily_task.dart';

final todoRepositoryProvider = Provider<TodoRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return TodoRepository(client);
});

class TodoRepository {
  const TodoRepository(this._client);

  final SupabaseClient _client;

  Future<List<DailyTask>> fetchTasksForDate(
      String userId, DateTime date) async {
    final response = await _client
        .from('daily_tasks')
        .select()
        .eq('user_id', userId)
        .eq('task_date', _dateOnly(date))
        .order('created_at');

    return (response as List<dynamic>)
        .map((item) => DailyTask.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _client
        .from('daily_tasks')
        .update({'status': status}).eq('id', taskId);
  }

  Future<void> createTaskLog({
    required String userId,
    required DailyTask task,
    required bool completed,
  }) async {
    await _client.from('task_logs').insert({
      'daily_task_id': task.id,
      'user_id': userId,
      'completed': completed,
      'value': task.targetValue,
      'metadata': {
        'category': task.category,
        'status': completed ? 'completed' : 'pending',
        'source': 'mobile',
      },
    });
  }

  Future<List<DailyTask>> ensureDailyPlan({
    required String userId,
    required DateTime taskDate,
    required UserProfile profile,
    String? workoutTitle,
  }) async {
    final existing = await fetchTasksForDate(userId, taskDate);
    if (existing.isNotEmpty) {
      return existing;
    }

    final stepTarget = _stepTarget(profile.activityLevel);
    final waterLiters = _waterTarget(profile.weightKg);
    final workoutTaskTitle = workoutTitle ?? _recommendedWorkoutTitle(profile);

    final tasks = [
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Eat a protein-first breakfast',
        'description':
            'Start the day with a balanced breakfast that supports ${profile.fitnessGoal ?? 'your goal'}.',
        'category': 'breakfast',
        'source': 'system',
        'points_reward': 10,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Have a balanced lunch',
        'description': 'Prioritize vegetables, protein, and slow carbs.',
        'category': 'lunch',
        'source': 'system',
        'points_reward': 10,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Finish a recovery-focused dinner',
        'description':
            'Keep dinner aligned with your calorie and recovery goals.',
        'category': 'dinner',
        'source': 'system',
        'points_reward': 10,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': workoutTaskTitle,
        'description':
            'Complete your scheduled workout and log how the session felt.',
        'category': 'workout',
        'source': 'system',
        'points_reward': 30,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Hit your hydration target',
        'description': 'Drink enough water steadily across the day.',
        'category': 'water',
        'source': 'system',
        'target_value': waterLiters,
        'target_unit': 'liters',
        'points_reward': 20,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Reach your step target',
        'description': 'Use walks and activity breaks to hit the target.',
        'category': 'steps',
        'source': 'system',
        'target_value': stepTarget,
        'target_unit': 'steps',
        'points_reward': 20,
        'status': 'pending',
        'is_required': true,
      },
      {
        'user_id': userId,
        'task_date': _dateOnly(taskDate),
        'title': 'Protect your sleep window',
        'description': 'Aim for at least 7.5 hours of recovery sleep.',
        'category': 'sleep',
        'source': 'system',
        'target_value': 7.5,
        'target_unit': 'hours',
        'points_reward': 10,
        'status': 'pending',
        'is_required': false,
      },
    ];

    final response = await _client
        .from('daily_tasks')
        .upsert(tasks, onConflict: 'user_id,task_date,title')
        .select();

    return (response as List<dynamic>)
        .map((item) => DailyTask.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<DailyTask> createTask({
    required String userId,
    required DateTime taskDate,
    required String title,
    required String category,
    String? description,
    int pointsReward = 10,
    String source = 'manual',
  }) async {
    final response = await _client
        .from('daily_tasks')
        .upsert({
          'user_id': userId,
          'task_date': _dateOnly(taskDate),
          'title': title,
          'description': description,
          'category': category,
          'source': source,
          'points_reward': pointsReward,
          'status': 'pending',
        }, onConflict: 'user_id,task_date,title')
        .select()
        .single();

    return DailyTask.fromMap(response);
  }

  int _stepTarget(String? activityLevel) {
    switch (activityLevel?.toLowerCase()) {
      case 'highly active':
        return 12000;
      case 'beginner':
        return 7000;
      default:
        return 9000;
    }
  }

  double _waterTarget(double? weightKg) {
    if (weightKg == null || weightKg <= 0) {
      return 2.5;
    }

    final liters = weightKg / 35;
    return double.parse(liters.clamp(2.2, 4.0).toStringAsFixed(1));
  }

  String _recommendedWorkoutTitle(UserProfile profile) {
    switch (profile.fitnessGoal?.toLowerCase()) {
      case 'lose fat':
        return '30-minute conditioning workout';
      case 'build muscle':
        return '45-minute strength workout';
      case 'improve endurance':
        return '40-minute cardio session';
      default:
        return '25-minute full-body session';
    }
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
