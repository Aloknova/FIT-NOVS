import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../leaderboard/domain/user_points.dart';
import '../domain/analytics_snapshot.dart';
import '../domain/progress_log.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }
  return AnalyticsRepository(client);
});

class AnalyticsRepository {
  const AnalyticsRepository(this._client);

  final SupabaseClient _client;

  Future<AnalyticsSnapshot> fetchSnapshot({
    required String userId,
    required UserPoints? userPoints,
  }) async {
    final weekStart = DateTime.now().subtract(const Duration(days: 6));
    final tasksResponse = await _client
        .from('daily_tasks')
        .select('task_date,status')
        .eq('user_id', userId)
        .gte('task_date', _dateOnly(weekStart))
        .order('task_date');

    final progressResponse = await _client
        .from('progress_logs')
        .select()
        .eq('user_id', userId)
        .order('log_date')
        .limit(14);

    final tasks = tasksResponse as List<dynamic>;
    final progressLogs = (progressResponse as List<dynamic>)
        .map((item) => ProgressLog.fromMap(item as Map<String, dynamic>))
        .toList();

    final totalTasks = tasks.length;
    final completedTasks =
        tasks.where((task) => task['status']?.toString() == 'completed').length;
    final completionRate =
        totalTasks == 0 ? 0 : ((completedTasks / totalTasks) * 100).round();

    final weeklyCompletion = List<int>.generate(7, (index) {
      final day = DateTime.now().subtract(Duration(days: 6 - index));
      final dayString = _dateOnly(day);
      final dayTasks =
          tasks.where((task) => task['task_date']?.toString() == dayString);
      if (dayTasks.isEmpty) {
        return 0;
      }
      final done =
          dayTasks.where((task) => task['status']?.toString() == 'completed');
      return ((done.length / dayTasks.length) * 100).round();
    });

    return AnalyticsSnapshot(
      userPoints: userPoints,
      completionRate: completionRate,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
      weeklyCompletion: weeklyCompletion,
      progressLogs: progressLogs,
      insight: _buildInsight(
        completionRate: completionRate,
        progressLogs: progressLogs,
      ),
    );
  }

  Future<ProgressLog> saveProgressLog({
    required String userId,
    required DateTime logDate,
    double? weightKg,
    int? steps,
    int? sleepMinutes,
    String? notes,
  }) async {
    final response = await _client
        .from('progress_logs')
        .upsert({
          'user_id': userId,
          'log_date': _dateOnly(logDate),
          'weight_kg': weightKg,
          'steps': steps,
          'sleep_minutes': sleepMinutes,
          'notes': notes,
        }, onConflict: 'user_id,log_date')
        .select()
        .single();

    return ProgressLog.fromMap(response);
  }

  String _buildInsight({
    required int completionRate,
    required List<ProgressLog> progressLogs,
  }) {
    if (completionRate >= 80) {
      return 'Consistency is strong. Keep stacking repeatable wins and the app can push harder recommendations.';
    }
    if (completionRate >= 50) {
      return 'You are building momentum. Tightening your task completion rate is the fastest way to improve outcomes.';
    }
    if (progressLogs.isNotEmpty) {
      return 'Progress logging has started. Focus on completing the basics daily so the insights become sharper.';
    }

    return 'Start with daily tasks and quick progress logs to unlock meaningful weekly insights.';
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
