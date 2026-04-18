import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/planner/domain/planner_models.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(initializationSettings);

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> syncAlarms(List<AlarmItem> alarms) async {
    await initialize();

    for (final alarm in alarms) {
      if (alarm.isEnabled) {
        await scheduleAlarm(alarm);
      } else {
        await cancelAlarm(alarm);
      }
    }
  }

  Future<void> scheduleAlarm(AlarmItem alarm) async {
    await initialize();
    await cancelAlarm(alarm);

    if (!alarm.isEnabled) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fitnova_alarms',
        'FitNova alarms',
        channelDescription:
            'Wake-up calls, reminders, and planner alarms from FitNova.',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
    );

    final location = _locationFor(alarm.timezone);
    final timeParts = alarm.alarmTime.split(':');
    final hour = int.tryParse(timeParts.elementAtOrNull(0) ?? '') ?? 6;
    final minute = int.tryParse(timeParts.elementAtOrNull(1) ?? '') ?? 0;

    if (alarm.repeatType == 'daily') {
      await _plugin.zonedSchedule(
        _notificationIdForAlarm(alarm.id),
        alarm.label,
        'FitNova reminder for ${alarm.label}',
        _nextDateTime(location, hour, minute),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }

    const weekdayDefaults = [1, 2, 3, 4, 5];
    final repeatingDays = alarm.repeatDays.isNotEmpty
        ? alarm.repeatDays
        : alarm.repeatType == 'weekdays'
            ? weekdayDefaults
            : const <int>[];

    if (repeatingDays.isNotEmpty) {
      for (final weekday in repeatingDays) {
        await _plugin.zonedSchedule(
          _notificationIdForAlarm(alarm.id, suffix: weekday),
          alarm.label,
          'FitNova reminder for ${alarm.label}',
          _nextWeekdayDateTime(location, weekday, hour, minute),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return;
    }

    await _plugin.zonedSchedule(
      _notificationIdForAlarm(alarm.id),
      alarm.label,
      'FitNova reminder for ${alarm.label}',
      _nextDateTime(location, hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAlarm(AlarmItem alarm) async {
    await initialize();

    await _plugin.cancel(_notificationIdForAlarm(alarm.id));

    final repeatingDays = alarm.repeatDays.isNotEmpty
        ? alarm.repeatDays
        : alarm.repeatType == 'weekdays'
            ? const [1, 2, 3, 4, 5]
            : const <int>[];

    for (final weekday in repeatingDays) {
      await _plugin.cancel(_notificationIdForAlarm(alarm.id, suffix: weekday));
    }
  }

  tz.Location _locationFor(String timezone) {
    try {
      return tz.getLocation(timezone);
    } catch (_) {
      return tz.UTC;
    }
  }

  tz.TZDateTime _nextDateTime(tz.Location location, int hour, int minute) {
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextWeekdayDateTime(
    tz.Location location,
    int weekday,
    int hour,
    int minute,
  ) {
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  int _notificationIdForAlarm(String alarmId, {int suffix = 0}) {
    var hash = 17;
    for (final codeUnit in alarmId.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return (hash + suffix) & 0x3fffffff;
  }
}
