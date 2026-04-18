class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.periodType,
    required this.periodStart,
    required this.userId,
    required this.rank,
    required this.score,
    this.periodEnd,
  });

  final String id;
  final String periodType;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final String userId;
  final int rank;
  final int score;

  String get displayName => 'Athlete ${userId.substring(0, 6).toUpperCase()}';

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      id: map['id'] as String,
      periodType: map['period_type'] as String,
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: map['period_end'] == null
          ? null
          : DateTime.parse(map['period_end'] as String),
      userId: map['user_id'] as String,
      rank: map['rank'] as int,
      score: map['score'] as int,
    );
  }
}
