class ProgressLog {
  const ProgressLog({
    required this.id,
    required this.userId,
    required this.logDate,
    this.weightKg,
    this.steps,
    this.caloriesBurned,
    this.sleepMinutes,
    this.notes,
  });

  final String id;
  final String userId;
  final DateTime logDate;
  final double? weightKg;
  final int? steps;
  final int? caloriesBurned;
  final int? sleepMinutes;
  final String? notes;

  factory ProgressLog.fromMap(Map<String, dynamic> map) {
    return ProgressLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      logDate: DateTime.parse(map['log_date'] as String),
      weightKg: map['weight_kg'] == null
          ? null
          : double.tryParse(map['weight_kg'].toString()),
      steps: map['steps'] as int?,
      caloriesBurned: map['calories_burned'] as int?,
      sleepMinutes: map['sleep_minutes'] as int?,
      notes: map['notes'] as String?,
    );
  }
}
