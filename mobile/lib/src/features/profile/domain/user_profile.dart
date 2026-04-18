class UserProfile {
  const UserProfile({
    required this.id,
    required this.themePreference,
    required this.onboardingCompleted,
    this.email,
    this.fullName,
    this.role = 'user',
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.fitnessGoal,
    this.activityLevel,
    this.isPremium = false,
    this.timezone = 'UTC',
  });

  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final String? fitnessGoal;
  final String? activityLevel;
  final String themePreference;
  final bool onboardingCompleted;
  final bool isPremium;
  final String timezone;

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }

    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }

    return 'FitNova User';
  }

  String get firstName {
    final name = displayName.trim();
    if (name.isEmpty) {
      return 'Athlete';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  bool get isAdmin => role == 'admin';

  double? get calculatedBmi =>
      calculateBmi(heightCm: heightCm, weightKg: weightKg);

  String get bmiCategory {
    final value = bmi ?? calculatedBmi;

    if (value == null) {
      return 'Not available';
    }

    if (value < 18.5) {
      return 'Underweight';
    }

    if (value < 25) {
      return 'Healthy';
    }

    if (value < 30) {
      return 'Overweight';
    }

    return 'Obesity risk';
  }

  static double? calculateBmi({
    required double? heightCm,
    required double? weightKg,
  }) {
    if (heightCm == null ||
        weightKg == null ||
        heightCm <= 0 ||
        weightKg <= 0) {
      return null;
    }

    final heightMeters = heightCm / 100;
    return double.parse(
        (weightKg / (heightMeters * heightMeters)).toStringAsFixed(2));
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      role: (map['role'] as String?) ?? 'user',
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      heightCm: _toDouble(map['height_cm']),
      weightKg: _toDouble(map['weight_kg']),
      bmi: _toDouble(map['bmi']),
      fitnessGoal: map['fitness_goal'] as String?,
      activityLevel: map['activity_level'] as String?,
      themePreference: (map['theme_preference'] as String?) ?? 'system',
      onboardingCompleted: (map['onboarding_completed'] as bool?) ?? false,
      isPremium: (map['is_premium'] as bool?) ?? false,
      timezone: (map['timezone'] as String?) ?? 'UTC',
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'bmi': calculatedBmi,
      'fitness_goal': fitnessGoal,
      'activity_level': activityLevel,
      'theme_preference': themePreference,
      'onboarding_completed': onboardingCompleted,
      'is_premium': isPremium,
      'timezone': timezone,
    };
  }

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? role,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    double? bmi,
    String? fitnessGoal,
    String? activityLevel,
    String? themePreference,
    bool? onboardingCompleted,
    bool? isPremium,
    String? timezone,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bmi: bmi ?? this.bmi,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      themePreference: themePreference ?? this.themePreference,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      isPremium: isPremium ?? this.isPremium,
      timezone: timezone ?? this.timezone,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
