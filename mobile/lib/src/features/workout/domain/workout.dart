class Workout {
  const Workout({
    required this.id,
    this.createdBy,
    required this.title,
    this.description,
    required this.difficulty,
    required this.goalFocus,
    required this.durationMinutes,
    this.caloriesEstimate,
    required this.scheduleTemplate,
    required this.instructions,
    required this.equipment,
    required this.isPremium,
  });

  final String id;
  final String? createdBy;
  final String title;
  final String? description;
  final String difficulty;
  final String goalFocus;
  final int durationMinutes;
  final int? caloriesEstimate;
  final List<dynamic> scheduleTemplate;
  final List<dynamic> instructions;
  final List<dynamic> equipment;
  final bool isPremium;

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as String,
      createdBy: map['created_by'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      difficulty: map['difficulty'] as String,
      goalFocus: map['goal_focus'] as String,
      durationMinutes: map['duration_minutes'] as int,
      caloriesEstimate: map['calories_estimate'] as int?,
      scheduleTemplate: map['schedule_template'] as List<dynamic>? ?? [],
      instructions: map['instructions'] as List<dynamic>? ?? [],
      equipment: map['equipment'] as List<dynamic>? ?? [],
      isPremium: map['is_premium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'difficulty': difficulty,
      'goal_focus': goalFocus,
      'duration_minutes': durationMinutes,
      'calories_estimate': caloriesEstimate,
      'schedule_template': scheduleTemplate,
      'instructions': instructions,
      'equipment': equipment,
      'is_premium': isPremium,
    };
  }
}
