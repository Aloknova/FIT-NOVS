import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart' as wearable;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/health_summary.dart';

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(supabaseClientProvider));
});

class HealthRepository {
  HealthRepository(this._client);

  final SupabaseClient? _client;
  final wearable.Health _health = wearable.Health();

  static const List<wearable.HealthDataType> _types = [
    wearable.HealthDataType.STEPS,
    wearable.HealthDataType.HEART_RATE,
    wearable.HealthDataType.TOTAL_CALORIES_BURNED,
    wearable.HealthDataType.DISTANCE_WALKING_RUNNING,
    wearable.HealthDataType.SLEEP_ASLEEP,
  ];

  static const List<wearable.HealthDataAccess> _permissions = [
    wearable.HealthDataAccess.READ,
    wearable.HealthDataAccess.READ,
    wearable.HealthDataAccess.READ,
    wearable.HealthDataAccess.READ,
    wearable.HealthDataAccess.READ,
  ];

  Future<HealthConnectionState> getConnectionState() async {
    if (!Platform.isAndroid) {
      return const HealthConnectionState(
        platformSupported: false,
        healthConnectAvailable: false,
        permissionsGranted: false,
        needsActivityPermission: false,
        statusMessage:
            'Wearable sync is available on Android in this build of FitNova.',
      );
    }

    await _health.configure();

    final healthConnectAvailable = await _health.isHealthConnectAvailable();
    final activityPermissionGranted =
        await Permission.activityRecognition.isGranted;
    final permissionsGranted = healthConnectAvailable
        ? (await _health.hasPermissions(_types, permissions: _permissions) ??
            false)
        : false;

    return HealthConnectionState(
      platformSupported: true,
      healthConnectAvailable: healthConnectAvailable,
      permissionsGranted: permissionsGranted,
      needsActivityPermission: !activityPermissionGranted,
      statusMessage: _statusMessage(
        healthConnectAvailable: healthConnectAvailable,
        permissionsGranted: permissionsGranted,
        activityPermissionGranted: activityPermissionGranted,
      ),
    );
  }

  Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _health.configure();
    await _health.installHealthConnect();
  }

  Future<HealthSummary?> fetchTodaySummary(String userId) async {
    if (_client == null) {
      return null;
    }

    final startOfDay = _startOfDay(DateTime.now());
    final rows = await _client
        .from('health_metrics')
        .select()
        .eq('user_id', userId)
        .gte('recorded_at', startOfDay.toUtc().toIso8601String())
        .order('recorded_at', ascending: false)
        .limit(20);

    final mappedRows = (rows as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    if (mappedRows.isEmpty) {
      return null;
    }

    return HealthSummary.fromMetricRows(mappedRows);
  }

  Future<HealthSummary> syncToday(String userId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured yet.');
    }

    if (!Platform.isAndroid) {
      throw StateError('Wearable sync is only available on Android here.');
    }

    await _health.configure();

    final healthConnectAvailable = await _health.isHealthConnectAvailable();
    if (!healthConnectAvailable) {
      throw StateError(
        'Health Connect is not installed yet. Tap install, then return and sync again.',
      );
    }

    await _ensureActivityPermission();
    await _ensureReadPermissions();

    final now = DateTime.now();
    final startOfDay = _startOfDay(now);
    final sleepWindowStart = now.subtract(const Duration(hours: 24));

    final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;
    final metrics = await _health.getHealthDataFromTypes(
      types: const [
        wearable.HealthDataType.HEART_RATE,
        wearable.HealthDataType.TOTAL_CALORIES_BURNED,
        wearable.HealthDataType.DISTANCE_WALKING_RUNNING,
      ],
      startTime: startOfDay,
      endTime: now,
    );
    final sleepData = await _health.getHealthDataFromTypes(
      types: const [wearable.HealthDataType.SLEEP_ASLEEP],
      startTime: sleepWindowStart,
      endTime: now,
    );

    final latestHeartRate = _latestValueForType(
      metrics,
      wearable.HealthDataType.HEART_RATE,
    );
    final calories = _sumForType(
      metrics,
      wearable.HealthDataType.TOTAL_CALORIES_BURNED,
    );
    final distanceMeters = _sumForType(
      metrics,
      wearable.HealthDataType.DISTANCE_WALKING_RUNNING,
    );
    final sleepMinutes = _sumForType(
      sleepData,
      wearable.HealthDataType.SLEEP_ASLEEP,
    ).round();
    final source = _resolveSource([...metrics, ...sleepData]);

    final rowsToInsert = <Map<String, dynamic>>[];
    if (steps > 0) {
      rowsToInsert.add(
        _metricRow(
          userId: userId,
          metricType: 'steps',
          metricValue: steps.toDouble(),
          unit: 'count',
          source: source,
          recordedAt: now,
          metadata: {'provider': 'health_connect'},
        ),
      );
    }
    if (latestHeartRate != null) {
      rowsToInsert.add(
        _metricRow(
          userId: userId,
          metricType: 'heart_rate',
          metricValue: latestHeartRate,
          unit: 'bpm',
          source: source,
          recordedAt: now,
          metadata: {'provider': 'health_connect'},
        ),
      );
    }
    if (calories > 0) {
      rowsToInsert.add(
        _metricRow(
          userId: userId,
          metricType: 'calories',
          metricValue: calories,
          unit: 'kcal',
          source: source,
          recordedAt: now,
          metadata: {'provider': 'health_connect'},
        ),
      );
    }
    if (distanceMeters > 0) {
      rowsToInsert.add(
        _metricRow(
          userId: userId,
          metricType: 'distance',
          metricValue: distanceMeters,
          unit: 'm',
          source: source,
          recordedAt: now,
          metadata: {'provider': 'health_connect'},
        ),
      );
    }
    if (sleepMinutes > 0) {
      rowsToInsert.add(
        _metricRow(
          userId: userId,
          metricType: 'sleep',
          metricValue: sleepMinutes.toDouble(),
          unit: 'minute',
          source: source,
          recordedAt: now,
          metadata: {'provider': 'health_connect'},
        ),
      );
    }

    if (rowsToInsert.isNotEmpty) {
      await client.from('health_metrics').insert(rowsToInsert);
    }

    await _saveProgressLog(
      client: client,
      userId: userId,
      logDate: now,
      steps: steps > 0 ? steps : null,
      sleepMinutes: sleepMinutes > 0 ? sleepMinutes : null,
      caloriesBurned: calories > 0 ? calories.round() : null,
    );

    return HealthSummary(
      steps: steps,
      calories: calories,
      heartRate: latestHeartRate,
      distanceMeters: distanceMeters,
      sleepMinutes: sleepMinutes,
      lastSyncedAt: now,
      source: source,
    );
  }

  Future<void> _ensureActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      throw StateError(
        'Activity recognition permission is required to read daily movement data.',
      );
    }
  }

  Future<void> _ensureReadPermissions() async {
    final hasPermissions =
        await _health.hasPermissions(_types, permissions: _permissions) ??
            false;
    if (hasPermissions) {
      return;
    }

    final granted =
        await _health.requestAuthorization(_types, permissions: _permissions);
    if (!granted) {
      throw StateError(
        'Health Connect access was not granted. Please allow FitNova to read your activity data.',
      );
    }
  }

  Future<void> _saveProgressLog({
    required SupabaseClient client,
    required String userId,
    required DateTime logDate,
    int? steps,
    int? sleepMinutes,
    int? caloriesBurned,
  }) async {
    final dateOnly = _dateOnly(logDate);
    final existing = await client
        .from('progress_logs')
        .select()
        .eq('user_id', userId)
        .eq('log_date', dateOnly)
        .maybeSingle();

    final payload = <String, dynamic>{
      'user_id': userId,
      'log_date': dateOnly,
      'weight_kg': existing?['weight_kg'],
      'body_fat_percentage': existing?['body_fat_percentage'],
      'steps': steps ?? existing?['steps'],
      'water_liters': existing?['water_liters'],
      'sleep_minutes': sleepMinutes ?? existing?['sleep_minutes'],
      'workout_minutes': existing?['workout_minutes'],
      'calories_burned': caloriesBurned ?? existing?['calories_burned'],
      'mood_score': existing?['mood_score'],
      'notes': existing?['notes'],
    };

    await client.from('progress_logs').upsert(
          payload,
          onConflict: 'user_id,log_date',
        );
  }

  Map<String, dynamic> _metricRow({
    required String userId,
    required String metricType,
    required double metricValue,
    required String unit,
    required String source,
    required DateTime recordedAt,
    required Map<String, dynamic> metadata,
  }) {
    return {
      'user_id': userId,
      'metric_type': metricType,
      'metric_value': double.parse(metricValue.toStringAsFixed(2)),
      'metric_unit': unit,
      'source': source,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'metadata': metadata,
    };
  }

  double _sumForType(
    List<wearable.HealthDataPoint> points,
    wearable.HealthDataType type,
  ) {
    return points
        .where((point) => point.type == type)
        .fold<double>(0, (sum, point) => sum + _numericValue(point));
  }

  double? _latestValueForType(
    List<wearable.HealthDataPoint> points,
    wearable.HealthDataType type,
  ) {
    final typedPoints = points.where((point) => point.type == type).toList();
    if (typedPoints.isEmpty) {
      return null;
    }

    typedPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return _numericValue(typedPoints.first);
  }

  double _numericValue(wearable.HealthDataPoint point) {
    final value = point.value;
    if (value is wearable.NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return 0;
  }

  String _resolveSource(List<wearable.HealthDataPoint> points) {
    for (final point in points) {
      final sourceText =
          '${point.sourceName} ${point.sourceId}'.toLowerCase().trim();
      if (sourceText.contains('google') || sourceText.contains('fit')) {
        return 'google_fit';
      }
    }

    return 'device';
  }

  DateTime _startOfDay(DateTime time) {
    return DateTime(time.year, time.month, time.day);
  }

  String _dateOnly(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  String _statusMessage({
    required bool healthConnectAvailable,
    required bool permissionsGranted,
    required bool activityPermissionGranted,
  }) {
    if (!healthConnectAvailable) {
      return 'Install Health Connect to sync steps, sleep, calories, and heart rate.';
    }
    if (!activityPermissionGranted) {
      return 'Allow activity recognition so FitNova can read daily movement data.';
    }
    if (!permissionsGranted) {
      return 'Connect Health Connect and allow FitNova to read your wellness data.';
    }
    return 'Health sync is ready. Pull in today\'s activity whenever you want.';
  }
}
