import '../../leaderboard/domain/user_points.dart';
import 'progress_log.dart';

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.userPoints,
    required this.completionRate,
    required this.completedTasks,
    required this.totalTasks,
    required this.weeklyCompletion,
    required this.progressLogs,
    required this.insight,
  });

  final UserPoints? userPoints;
  final int completionRate;
  final int completedTasks;
  final int totalTasks;
  final List<int> weeklyCompletion;
  final List<ProgressLog> progressLogs;
  final String insight;

  double? get weightChange {
    final weights = progressLogs
        .where((log) => log.weightKg != null)
        .map((log) => log.weightKg!)
        .toList();

    if (weights.length < 2) {
      return null;
    }

    return double.parse((weights.last - weights.first).toStringAsFixed(1));
  }
}
