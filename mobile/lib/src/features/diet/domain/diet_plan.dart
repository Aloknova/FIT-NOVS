class DietPlan {
  const DietPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.planDate,
    required this.calorieTarget,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.meals,
    required this.source,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime planDate;
  final int calorieTarget;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final List<dynamic> meals;
  final String source;
  final bool isActive;

  factory DietPlan.fromMap(Map<String, dynamic> map) {
    return DietPlan(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      planDate: DateTime.parse(map['plan_date'] as String),
      calorieTarget: map['calorie_target'] as int,
      proteinG: map['protein_g'] != null
          ? double.tryParse(map['protein_g'].toString())
          : null,
      carbsG: map['carbs_g'] != null
          ? double.tryParse(map['carbs_g'].toString())
          : null,
      fatG: map['fat_g'] != null
          ? double.tryParse(map['fat_g'].toString())
          : null,
      meals: map['meals'] as List<dynamic>? ?? [],
      source: map['source'] as String,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
