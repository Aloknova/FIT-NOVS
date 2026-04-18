import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/user_points.dart';

final leaderboardPeriodProvider = StateProvider<String>((ref) => 'weekly');

final currentUserPointsProvider = FutureProvider<UserPoints?>((ref) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repository == null || user == null) {
    return null;
  }

  return repository.fetchOrCreateUserPoints(user.id);
});

final leaderboardEntriesProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) async {
  final repository = ref.watch(leaderboardRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final period = ref.watch(leaderboardPeriodProvider);

  if (repository == null || user == null) {
    return [];
  }

  return repository.fetchLeaderboard(periodType: period);
});
