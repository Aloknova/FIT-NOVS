import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/local_notifications_service.dart';
import '../../profile/data/profile_repository.dart';
import '../data/planner_repository.dart';
import '../domain/planner_models.dart';

final plannerNotesProvider = FutureProvider<List<NoteItem>>((ref) async {
  final repository = ref.watch(plannerRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchNotes(user.id);
});

final plannerTasksProvider = FutureProvider<List<PlannerTaskItem>>((ref) async {
  final repository = ref.watch(plannerRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchTasks(user.id);
});

final plannerEventsProvider =
    FutureProvider<List<PlannerEventItem>>((ref) async {
  final repository = ref.watch(plannerRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchEvents(user.id);
});

final plannerAlarmsProvider = FutureProvider<List<AlarmItem>>((ref) async {
  final repository = ref.watch(plannerRepositoryProvider);
  final user = ref.watch(currentUserProvider);

  if (repository == null || user == null) {
    return const [];
  }

  return repository.fetchAlarms(user.id);
});

final plannerControllerProvider =
    StateNotifierProvider<PlannerController, AsyncValue<void>>((ref) {
  return PlannerController(ref);
});

class PlannerController extends StateNotifier<AsyncValue<void>> {
  PlannerController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> createNote({
    required String title,
    required String content,
    String source = 'manual',
    List<String> tags = const [],
  }) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.createNote(
        userId: user.id,
        title: title,
        content: content,
        source: source,
        tags: tags,
      );
      _ref.invalidate(plannerNotesProvider);
    });
  }

  Future<void> createTask({
    required String title,
    String? description,
    DateTime? dueAt,
    int priority = 3,
    bool createdByAi = false,
  }) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.createTask(
        userId: user.id,
        title: title,
        description: description,
        dueAt: dueAt,
        priority: priority,
        createdByAi: createdByAi,
      );
      _ref.invalidate(plannerTasksProvider);
    });
  }

  Future<void> toggleTask(PlannerTaskItem task) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null) {
        return;
      }
      if (user == null) {
        return;
      }

      await repository.updateTaskStatus(
        userId: user.id,
        task: task,
        status: task.isCompleted ? 'pending' : 'completed',
      );
      _ref.invalidate(plannerTasksProvider);
    });
  }

  Future<void> createEvent({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? description,
    String? location,
    String eventType = 'calendar',
    String source = 'manual',
  }) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.createEvent(
        userId: user.id,
        title: title,
        startAt: startAt,
        endAt: endAt,
        description: description,
        location: location,
        eventType: eventType,
        source: source,
      );
      _ref.invalidate(plannerEventsProvider);
    });
  }

  Future<void> createAlarm({
    required String label,
    required String alarmTime,
    String repeatType = 'daily',
    String? linkedIntent,
  }) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      final profile = _ref.read(currentProfileProvider).valueOrNull;
      if (repository == null || user == null) {
        return;
      }

      final repeatDays = repeatType == 'weekdays'
          ? const [1, 2, 3, 4, 5]
          : const <int>[];

      final alarm = await repository.createAlarm(
        userId: user.id,
        label: label,
        alarmTime: alarmTime,
        repeatType: repeatType,
        timezone: profile?.timezone ?? 'UTC',
        repeatDays: repeatDays,
        linkedIntent: linkedIntent,
      );
      await LocalNotificationsService.instance.scheduleAlarm(alarm);
      _ref.invalidate(plannerAlarmsProvider);
    });
  }

  Future<void> toggleAlarm(AlarmItem alarm) async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      if (repository == null) {
        return;
      }

      final updatedAlarm = await repository.updateAlarmEnabled(
        alarmId: alarm.id,
        isEnabled: !alarm.isEnabled,
      );
      if (updatedAlarm.isEnabled) {
        await LocalNotificationsService.instance.scheduleAlarm(updatedAlarm);
      } else {
        await LocalNotificationsService.instance.cancelAlarm(updatedAlarm);
      }
      _ref.invalidate(plannerAlarmsProvider);
    });
  }

  Future<void> syncLocalAlarms() async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      final alarms = await repository.fetchAlarms(user.id);
      await LocalNotificationsService.instance.syncAlarms(alarms);
      _ref.invalidate(plannerAlarmsProvider);
    });
  }

  Future<void> syncOfflineTasks() async {
    await _run(() async {
      final repository = _ref.read(plannerRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      if (repository == null || user == null) {
        return;
      }

      await repository.syncPendingTasks(user.id);
      _ref.invalidate(plannerTasksProvider);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
