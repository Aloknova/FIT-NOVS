import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/local_store_service.dart';
import '../domain/offline_planner_task_record.dart';
import '../domain/planner_models.dart';

final plannerRepositoryProvider = Provider<PlannerRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    return null;
  }

  return PlannerRepository(
    client,
    ref.watch(localStoreServiceProvider),
    ref.watch(connectivityServiceProvider),
    const Uuid(),
  );
});

class PlannerRepository {
  PlannerRepository(
    this._client,
    this._localStore,
    this._connectivityService,
    this._uuid,
  );

  final SupabaseClient _client;
  final LocalStoreService _localStore;
  final ConnectivityService _connectivityService;
  final Uuid _uuid;

  Future<List<NoteItem>> fetchNotes(String userId) async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .limit(30);

    return (response as List<dynamic>)
        .map((item) => NoteItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<NoteItem> createNote({
    required String userId,
    required String title,
    required String content,
    String source = 'manual',
    List<String> tags = const [],
  }) async {
    final response = await _client
        .from('notes')
        .insert({
          'user_id': userId,
          'title': title,
          'content': content,
          'source': source,
          'tags': tags,
        })
        .select()
        .single();

    return NoteItem.fromMap(response);
  }

  Future<List<PlannerTaskItem>> fetchTasks(String userId) async {
    final cachedTasks = _readCachedTasks(userId);

    try {
      if (await _connectivityService.isOnline()) {
        final remoteTasks = await _fetchRemoteTasks(userId);
        await _mergeRemoteTasksIntoLocal(userId, remoteTasks);
        return _readCachedTasks(userId);
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Planner task refresh fell back to local cache.',
        scope: 'sync',
        details: {
          'userId': userId,
          'cachedTaskCount': cachedTasks.length,
          'error': error.toString(),
        },
      );
      AppLogger.error(
        'Planner task remote refresh failed.',
        scope: 'sync',
        error: error,
        stackTrace: stackTrace,
        details: {'userId': userId},
      );
    }

    return cachedTasks;
  }

  Future<PlannerTaskItem> createTask({
    required String userId,
    required String title,
    String? description,
    DateTime? dueAt,
    int priority = 3,
    bool createdByAi = false,
  }) async {
    final record = OfflinePlannerTaskRecord(
      localId: _uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      dueAt: dueAt,
      status: 'pending',
      priority: priority,
      createdByAi: createdByAi,
      synced: false,
      pendingAction: 'create',
      updatedAt: DateTime.now(),
    );

    await _localStore.savePlannerTaskRecord(record.localId, record.toMap());
    AppLogger.action(
      'planner_task_created_local',
      details: {
        'userId': userId,
        'localId': record.localId,
        'createdByAi': createdByAi,
      },
    );

    await _trySyncPendingTasks(userId);
    return _readTaskByLocalId(userId, record.localId) ?? record.toPlannerTaskItem();
  }

  Future<PlannerTaskItem> updateTaskStatus({
    required String userId,
    required PlannerTaskItem task,
    required String status,
  }) async {
    final record = _findRecord(
          userId,
          localId: task.id,
          remoteId: task.remoteId,
        ) ??
        OfflinePlannerTaskRecord.fromRemoteTask(
          task,
          userId: userId,
          localId: task.id,
        );

    final updatedRecord = record.copyWith(
      status: status,
      synced: false,
      pendingAction: record.remoteId == null ? 'create' : 'upsert',
      updatedAt: DateTime.now(),
    );

    await _localStore.savePlannerTaskRecord(
      updatedRecord.localId,
      updatedRecord.toMap(),
    );
    AppLogger.action(
      'planner_task_status_updated_local',
      details: {
        'userId': userId,
        'localId': updatedRecord.localId,
        'remoteId': updatedRecord.remoteId,
        'status': status,
      },
    );

    await _trySyncPendingTasks(userId);
    return _readTaskByLocalId(userId, updatedRecord.localId) ??
        updatedRecord.toPlannerTaskItem();
  }

  Future<List<PlannerTaskItem>> syncPendingTasks(String userId) async {
    if (!await _connectivityService.isOnline()) {
      return _readCachedTasks(userId);
    }

    final pendingRecords = _readRecords(userId)
        .where((record) => !record.synced || record.pendingAction != null)
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

    if (pendingRecords.isEmpty) {
      return fetchTasks(userId);
    }

    for (final record in pendingRecords) {
      try {
        final syncedRecord = await _syncTaskRecord(record);
        await _localStore.savePlannerTaskRecord(
          syncedRecord.localId,
          syncedRecord.toMap(),
        );
        AppLogger.info(
          'Planner task synced to Supabase.',
          scope: 'sync',
          details: {
            'userId': userId,
            'localId': syncedRecord.localId,
            'remoteId': syncedRecord.remoteId,
          },
        );
      } catch (error, stackTrace) {
        AppLogger.error(
          'Planner task sync failed.',
          scope: 'sync',
          error: error,
          stackTrace: stackTrace,
          details: {
            'userId': userId,
            'localId': record.localId,
            'remoteId': record.remoteId,
          },
        );
      }
    }

    return fetchTasks(userId);
  }

  Future<List<PlannerEventItem>> fetchEvents(String userId) async {
    final response = await _client
        .from('events')
        .select()
        .eq('user_id', userId)
        .order('start_at', ascending: true)
        .limit(40);

    return (response as List<dynamic>)
        .map((item) => PlannerEventItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<PlannerEventItem> createEvent({
    required String userId,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? description,
    String? location,
    String eventType = 'calendar',
    String source = 'manual',
  }) async {
    final response = await _client
        .from('events')
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'event_type': eventType,
          'start_at': startAt.toIso8601String(),
          'end_at': endAt?.toIso8601String(),
          'location': location,
          'source': source,
        })
        .select()
        .single();

    return PlannerEventItem.fromMap(response);
  }

  Future<List<AlarmItem>> fetchAlarms(String userId) async {
    final response = await _client
        .from('alarms')
        .select()
        .eq('user_id', userId)
        .order('alarm_time', ascending: true)
        .limit(30);

    return (response as List<dynamic>)
        .map((item) => AlarmItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<AlarmItem> createAlarm({
    required String userId,
    required String label,
    required String alarmTime,
    String repeatType = 'daily',
    String timezone = 'UTC',
    List<int> repeatDays = const [],
    String? linkedIntent,
  }) async {
    final response = await _client
        .from('alarms')
        .insert({
          'user_id': userId,
          'label': label,
          'alarm_time': alarmTime,
          'repeat_type': repeatType,
          'timezone': timezone,
          'repeat_days': repeatDays,
          'linked_intent': linkedIntent,
        })
        .select()
        .single();

    return AlarmItem.fromMap(response);
  }

  Future<AlarmItem> updateAlarmEnabled({
    required String alarmId,
    required bool isEnabled,
  }) async {
    final response = await _client
        .from('alarms')
        .update({'is_enabled': isEnabled})
        .eq('id', alarmId)
        .select()
        .single();

    return AlarmItem.fromMap(response);
  }

  Future<List<PlannerTaskItem>> _fetchRemoteTasks(String userId) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('status')
        .order('due_at', ascending: true)
        .limit(40);

    return (response as List<dynamic>)
        .map((item) => PlannerTaskItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  List<OfflinePlannerTaskRecord> _readRecords(String userId) {
    return _localStore
        .readPlannerTaskRecords(userId)
        .map(OfflinePlannerTaskRecord.fromMap)
        .toList();
  }

  List<PlannerTaskItem> _readCachedTasks(String userId) {
    final tasks = _readRecords(userId)
        .map((record) => record.toPlannerTaskItem())
        .toList();
    tasks.sort(_sortTasks);
    return tasks;
  }

  Future<void> _mergeRemoteTasksIntoLocal(
    String userId,
    List<PlannerTaskItem> remoteTasks,
  ) async {
    final localRecords = _readRecords(userId);

    for (final task in remoteTasks) {
      final existingRecord = localRecords.cast<OfflinePlannerTaskRecord?>().firstWhere(
            (record) => record?.remoteId == task.remoteId,
            orElse: () => null,
          );

      if (existingRecord != null &&
          (!existingRecord.synced || existingRecord.pendingAction != null)) {
        continue;
      }

      final mergedRecord = OfflinePlannerTaskRecord.fromRemoteTask(
        task,
        userId: userId,
        localId: existingRecord?.localId,
      );
      await _localStore.savePlannerTaskRecord(
        mergedRecord.localId,
        mergedRecord.toMap(),
      );
    }
  }

  OfflinePlannerTaskRecord? _findRecord(
    String userId, {
    String? localId,
    String? remoteId,
  }) {
    for (final record in _readRecords(userId)) {
      if (localId != null && record.localId == localId) {
        return record;
      }
      if (remoteId != null && record.remoteId == remoteId) {
        return record;
      }
    }
    return null;
  }

  PlannerTaskItem? _readTaskByLocalId(String userId, String localId) {
    final record = _findRecord(userId, localId: localId);
    return record?.toPlannerTaskItem();
  }

  Future<void> _trySyncPendingTasks(String userId) async {
    if (!await _connectivityService.isOnline()) {
      return;
    }

    await syncPendingTasks(userId);
  }

  Future<OfflinePlannerTaskRecord> _syncTaskRecord(
    OfflinePlannerTaskRecord record,
  ) async {
    final payload = {
      'user_id': record.userId,
      'title': record.title,
      'description': record.description,
      'due_at': record.dueAt?.toIso8601String(),
      'status': record.status,
      'priority': record.priority,
      'created_by_ai': record.createdByAi,
    };

    final response = record.remoteId == null
        ? await _client.from('tasks').insert(payload).select().single()
        : await _client
            .from('tasks')
            .update(payload)
            .eq('id', record.remoteId!)
            .select()
            .single();

    final remoteTask = PlannerTaskItem.fromMap(response);
    return OfflinePlannerTaskRecord.fromRemoteTask(
      remoteTask,
      userId: record.userId,
      localId: record.localId,
    );
  }

  int _sortTasks(PlannerTaskItem a, PlannerTaskItem b) {
    if (a.status != b.status) {
      return a.status.compareTo(b.status);
    }

    if (a.dueAt == null && b.dueAt == null) {
      return a.updatedAt?.compareTo(b.updatedAt ?? DateTime.now()) ?? 0;
    }
    if (a.dueAt == null) {
      return 1;
    }
    if (b.dueAt == null) {
      return -1;
    }
    return a.dueAt!.compareTo(b.dueAt!);
  }
}
