import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/user_points.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return LeaderboardRepository(client);
});

class LeaderboardRepository {
  const LeaderboardRepository(this._client);

  final SupabaseClient _client;

  Future<UserPoints> fetchOrCreateUserPoints(String userId) async {
    final response = await _client
        .from('user_points')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      return UserPoints.fromMap(response);
    }

    final created = await _client
        .from('user_points')
        .upsert({
          'user_id': userId,
          'total_points': 0,
          'level': 1,
          'current_streak': 0,
          'longest_streak': 0,
        })
        .select()
        .single();

    return UserPoints.fromMap(created);
  }

  Future<UserPoints> applyPointsChange({
    required String userId,
    required int pointsDelta,
    required DateTime activityDate,
  }) async {
    final current = await fetchOrCreateUserPoints(userId);
    final normalizedActivityDate = DateTime(
      activityDate.year,
      activityDate.month,
      activityDate.day,
    );
    final normalizedLastDate = current.lastActivityDate == null
        ? null
        : DateTime(
            current.lastActivityDate!.year,
            current.lastActivityDate!.month,
            current.lastActivityDate!.day,
          );

    final totalPoints =
        (current.totalPoints + pointsDelta).clamp(0, 1000000).toInt();
    var currentStreak = current.currentStreak;
    var longestStreak = current.longestStreak;

    if (pointsDelta > 0) {
      if (normalizedLastDate == null) {
        currentStreak = 1;
      } else {
        final difference =
            normalizedActivityDate.difference(normalizedLastDate).inDays;
        if (difference <= 0) {
          currentStreak =
              current.currentStreak == 0 ? 1 : current.currentStreak;
        } else if (difference == 1) {
          currentStreak = current.currentStreak + 1;
        } else {
          currentStreak = 1;
        }
      }
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    }

    final level = 1 + (totalPoints ~/ 250);

    final updated = await _client
        .from('user_points')
        .upsert({
          'user_id': userId,
          'total_points': totalPoints,
          'level': level,
          'current_streak': currentStreak,
          'longest_streak': longestStreak,
          'last_activity_date': _dateOnly(
            pointsDelta > 0 ? normalizedActivityDate : current.lastActivityDate,
          ),
        })
        .select()
        .single();

    return UserPoints.fromMap(updated);
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    String periodType = 'weekly',
  }) async {
    final response = await _client
        .from('leaderboard')
        .select()
        .eq('period_type', periodType)
        .order('period_start', ascending: false)
        .order('rank')
        .limit(20);

    return (response as List<dynamic>)
        .map((item) => LeaderboardEntry.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) {
      return null;
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
