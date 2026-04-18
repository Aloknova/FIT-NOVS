class DailyTask {
  const DailyTask({
    required this.id,
    required this.userId,
    required this.taskDate,
    required this.title,
    required this.category,
    required this.source,
    required this.status,
    required this.pointsReward,
    required this.isRequired,
    this.description,
    this.targetValue,
    this.targetUnit,
    this.scheduledTime,
  });

  final String id;
  final String userId;
  final DateTime taskDate;
  final String title;
  final String? description;
  final String category;
  final String source;
  final double? targetValue;
  final String? targetUnit;
  final int pointsReward;
  final bool isRequired;
  final String status;
  final String? scheduledTime;

  bool get isCompleted => status == 'completed';

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      taskDate: DateTime.parse(map['task_date'] as String),
      title: map['title'] as String,
      description: map['description'] as String?,
      category: map['category'] as String,
      source: map['source'] as String,
      targetValue: map['target_value'] != null
          ? double.tryParse(map['target_value'].toString())
          : null,
      targetUnit: map['target_unit'] as String?,
      pointsReward: map['points_reward'] as int? ?? 0,
      isRequired: map['is_required'] as bool? ?? true,
      status: map['status'] as String,
      scheduledTime: map['scheduled_time'] as String?,
    );
  }

  DailyTask copyWith({
    String? status,
  }) {
    return DailyTask(
      id: id,
      userId: userId,
      taskDate: taskDate,
      title: title,
      description: description,
      category: category,
      source: source,
      targetValue: targetValue,
      targetUnit: targetUnit,
      pointsReward: pointsReward,
      isRequired: isRequired,
      status: status ?? this.status,
      scheduledTime: scheduledTime,
    );
  }
}
