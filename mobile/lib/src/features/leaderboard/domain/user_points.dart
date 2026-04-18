class UserPoints {
  const UserPoints({
    required this.userId,
    required this.totalPoints,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });

  final String userId;
  final int totalPoints;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  factory UserPoints.fromMap(Map<String, dynamic> map) {
    return UserPoints(
      userId: map['user_id'] as String,
      totalPoints: map['total_points'] as int? ?? 0,
      level: map['level'] as int? ?? 1,
      currentStreak: map['current_streak'] as int? ?? 0,
      longestStreak: map['longest_streak'] as int? ?? 0,
      lastActivityDate: map['last_activity_date'] == null
          ? null
          : DateTime.parse(map['last_activity_date'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'total_points': totalPoints,
      'level': level,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_activity_date':
          lastActivityDate == null ? null : _dateOnly(lastActivityDate!),
    };
  }

  UserPoints copyWith({
    int? totalPoints,
    int? level,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
  }) {
    return UserPoints(
      userId: userId,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
    );
  }

  static String _dateOnly(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
