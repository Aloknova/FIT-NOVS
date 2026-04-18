class HealthSummary {
  const HealthSummary({
    this.steps = 0,
    this.calories = 0,
    this.heartRate,
    this.distanceMeters = 0,
    this.sleepMinutes = 0,
    this.lastSyncedAt,
    this.source = 'device',
  });

  final int steps;
  final double calories;
  final double? heartRate;
  final double distanceMeters;
  final int sleepMinutes;
  final DateTime? lastSyncedAt;
  final String source;

  bool get hasData =>
      steps > 0 ||
      calories > 0 ||
      distanceMeters > 0 ||
      sleepMinutes > 0 ||
      heartRate != null;

  double get distanceKm => distanceMeters / 1000;

  Map<String, dynamic> toAiContextMap() {
    return {
      'health_summary': {
        'steps': steps,
        'calories': calories,
        'heart_rate': heartRate,
        'distance_meters': distanceMeters,
        'distance_km': distanceKm,
        'sleep_minutes': sleepMinutes,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'source': source,
      },
    };
  }

  factory HealthSummary.fromMetricRows(List<Map<String, dynamic>> rows) {
    int steps = 0;
    double calories = 0;
    double distanceMeters = 0;
    int sleepMinutes = 0;
    double? heartRate;
    DateTime? lastSyncedAt;
    String source = 'device';

    final latestByType = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final metricType = row['metric_type']?.toString();
      if (metricType == null) {
        continue;
      }

      latestByType.putIfAbsent(metricType, () => row);

      final recordedAt = DateTime.tryParse(row['recorded_at']?.toString() ?? '');
      if (recordedAt != null &&
          (lastSyncedAt == null || recordedAt.isAfter(lastSyncedAt))) {
        lastSyncedAt = recordedAt;
      }

      final rowSource = row['source']?.toString();
      if (rowSource != null && rowSource.isNotEmpty && source == 'device') {
        source = rowSource;
      }
    }

    for (final entry in latestByType.entries) {
      final value = _toDouble(entry.value['metric_value']) ?? 0;

      switch (entry.key) {
        case 'steps':
          steps = value.round();
          break;
        case 'calories':
          calories = value;
          break;
        case 'distance':
          distanceMeters = value;
          break;
        case 'sleep':
          sleepMinutes = value.round();
          break;
        case 'heart_rate':
          heartRate = value;
          break;
      }
    }

    return HealthSummary(
      steps: steps,
      calories: calories,
      heartRate: heartRate,
      distanceMeters: distanceMeters,
      sleepMinutes: sleepMinutes,
      lastSyncedAt: lastSyncedAt,
      source: source,
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

class HealthConnectionState {
  const HealthConnectionState({
    required this.platformSupported,
    required this.healthConnectAvailable,
    required this.permissionsGranted,
    required this.needsActivityPermission,
    required this.statusMessage,
  });

  final bool platformSupported;
  final bool healthConnectAvailable;
  final bool permissionsGranted;
  final bool needsActivityPermission;
  final String statusMessage;

  bool get isReady =>
      platformSupported &&
      healthConnectAvailable &&
      permissionsGranted &&
      !needsActivityPermission;

  String get primaryActionLabel {
    if (!platformSupported) {
      return 'Android only';
    }
    if (!healthConnectAvailable) {
      return 'Install Health Connect';
    }
    if (!permissionsGranted || needsActivityPermission) {
      return 'Connect Health';
    }
    return 'Sync now';
  }
}
